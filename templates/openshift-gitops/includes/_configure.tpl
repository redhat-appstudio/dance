{{ define "dance.gitops.configure" }}
- name: configure-gitops
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/sh
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      echo -n "* Installing 'argocd' CLI: "
      curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
      chmod 555 argocd
      ./argocd version --client | head -1 | cut -d' ' -f2
      
      CRD="argocds"
      echo -n "* Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo -n "* Waiting for gitops operator deployment: "
      until kubectl get "$CRD" openshift-gitops -n openshift-gitops >/dev/null 2>&1; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      #
      # All actions must be idempotent
      #
      CHART="{{ .Chart.Name }}"
      ARGOCD_NAMESPACE="{{ index .Values "openshift-gitops" "argocd-namespace" }}"
      echo -n "* ArgoCD resource: "
      until kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; do
        echo -n "."
        sleep 3
      done
      cat << EOF | kubectl apply -n "$ARGOCD_NAMESPACE" -f - >/dev/null
      {{ include "dance.include.argocd" . | indent 8 }}
      EOF
      echo "OK"

      echo -n "* ArgoCD dashboard: "
      test_cmd="kubectl get route -n  "$ARGOCD_NAMESPACE" "$CHART-argocd-server" --ignore-not-found -o jsonpath={.spec.host}"
      argocd_hostname="$(${test_cmd})"
      until curl --fail --insecure --output /dev/null --silent "https://$argocd_hostname"; do
        echo -n "."
        sleep 2
        argocd_hostname="$(${test_cmd})"
      done
      echo "OK"

      echo -n "* ArgoCD Login: "
      argocd_password="$(kubectl get secret -n "$ARGOCD_NAMESPACE" "$CHART-argocd-cluster" -o jsonpath="{.data.admin\.password}" | base64 --decode)"
      ./argocd login "$argocd_hostname" --grpc-web --insecure --username admin --password "$argocd_password" >/dev/null
      echo "OK"
      # echo "argocd login '$argocd_hostname' --grpc-web --insecure --username admin --password '$argocd_password'"

      echo -n "* ArgoCD 'admin-$CHART' token: "
      if [ "$(kubectl get secret "$CHART-argocd-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
        echo -n "."
        API_TOKEN="$(./argocd account generate-token --account "admin-$CHART")"
        echo -n "."
        kubectl create secret generic "$CHART-argocd-secret" \
          --from-literal="admin-$CHART=$API_TOKEN" >/dev/null
      fi
      echo "OK"

      echo -n "* Disable ArgoCD admin user: "
      kubectl patch argocd -n "$ARGOCD_NAMESPACE" "$CHART-argocd" --type 'merge' --patch '{{ include "dance.argocd.user_admin" . | indent 8 }}' >/dev/null
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}