{{ define "dance.configure.acs" }}
- name: configure-acs
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      # The OperatorGroup is required to install the operator.
      # c.f. https://olm.operatorframework.io/docs/tasks/install-operator-with-olm/#prerequisites
      echo -n "* OperatorGroup: "
      if [ "$(oc get operatorgroups -n rhacs-operator 2>/dev/null | wc -l)" = "0" ];then
        cat << EOF | oc create -f -
      {{ include "dance.includes.operatorgroup" . | indent 6}}
      EOF
      else
        echo "OK"
      fi

      CRDS=( centrals securedclusters )
      for CRD in "${CRDS[@]}"; do
        echo -n "* Waiting for '$CRD' CRD: "
        while [ $(kubectl api-resources 2>/dev/null | grep -c "^$CRD ") = "0" ] ; do
          echo -n "."
          sleep 3
        done
        echo "OK"
      done

      echo -n "* Installing Helm: "
      {
      {{ include "dance.shared.install_helm" . | indent 6}}
      } >/dev/null
      helm version

      echo -n "* Installing roxctl CLI: "
      arch="$(uname -m | sed "s/x86_64//")"; arch="${arch:+-$arch}"
      acs_version="$(
        oc get csvs \
        | grep --extended-regex --only-matching "^rhacs-operator\.[^ ]*" \
        | grep --extended-regex --only-matching "[0-9]+\.[0-9]+\.[0-9]+"
      )"
      curl --fail --location --output /usr/bin/roxctl --silent "https://mirror.openshift.com/pub/rhacs/assets/$acs_version/bin/Linux/roxctl${arch}"
      chmod +x /usr/bin/roxctl
      roxctl version

      echo -n "* Add RHACS chart repository: "
      helm repo add rhacs https://mirror.openshift.com/pub/rhacs/charts/

      echo "* Configure ACS Central Service"
      helm upgrade --install -n stackrox --create-namespace \
        stackrox-central-services rhacs/central-services \
        --set central.exposure.route.enabled=true \
        --set central.persistence.none=true \
        --set imagePullSecrets.useFromDefaultServiceAccount=true \
        | tee central.log
      password="$(grep "^ *[A-Za-z0-9]\+$" central.log | tr -d ' ')"
      if [ -n "${password:-}" ]; then
        echo -n "Create secret: "
        oc create secret generic -n stackrox central-credentials --from-literal="password=$password" --from-literal="user=admin"
      else
        password="$(
          oc get secrets -n stackrox central-credentials -o yaml \
          | grep " password: " \
          | cut -d ' ' -f4 \
          | base64 -d
          )"
      fi

      echo "* Configure ACS Secured Cluster Service"
      echo helm upgrade --install -n stackrox --create-namespace \
        stackrox-secured-cluster-services rhacs/secured-cluster-services \
        --set scanner.disable=false \
        --set clusterName=local \
        # -f <path_to_cluster_init_bundle.yaml> \
        # --set centralEndpoint=<endpoint_of_central_service>
      sleep 900
{{ end }}