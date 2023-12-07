{{ define "dance.gitops.configure" }}
- name: configure-gitops
  image: "k8s.gcr.io/hyperkube:v1.12.1"
  command:
    - /bin/sh
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail
      
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
      echo -n "* ArgoCD resource: "
      cat << EOF | kubectl apply -n {{ index .Values "openshift-gitops" "argocd-namespace" }} -f - >/dev/null
      {{ include "dance.include.argocd" . | indent 8 }}
      EOF
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}