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
      {
      ################################################################################
      # Dependencies
      ################################################################################

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

      ################################################################################
      # Central Service
      ################################################################################

      echo "* Configure ACS Central Service"
      helm upgrade --install -n stackrox --create-namespace \
        stackrox-central-services rhacs/central-services \
        --set central.exposure.route.enabled=true \
        --set central.persistence.none=true \
        --set imagePullSecrets.useFromDefaultServiceAccount=true \
        | tee central.log

      PASSWORD="$(grep "^ *[A-Za-z0-9]\+$" central.log | tr -d ' ')"
      if [ -n "${PASSWORD:-}" ]; then
        echo -n "Create secret: "
        oc create secret generic -n stackrox central-credentials --from-literal="password=$PASSWORD" --from-literal="user=admin"
      else
        PASSWORD="$(
          oc get secrets -n stackrox central-credentials -o yaml \
          | grep " password: " \
          | cut -d ' ' -f4 \
          | base64 -d
          )"
      fi

      ################################################################################
      # Init bundle
      ################################################################################
      # Source: https://github.com/redhat-cop/gitops-catalog/blob/main/advanced-cluster-security-operator/instance/base/create-cluster-init-bundle-job.yaml
      if kubectl get secret/sensor-tls &> /dev/null; then
        echo "* Configure cluster-init bundle: cluster-init bundle has already been configured, doing nothing"
      else
        echo -n "* Waiting on central: "
        # Wait for central to be ready
        attempt_counter=0
        max_attempts=20
        URL="https://$(kubectl get routes -n stackrox central -o yaml | grep "^  host: " | cut -d' ' -f4)"
        until $(curl -k --output /dev/null --silent --head --fail "$URL"); do
            if [ ${attempt_counter} -eq ${max_attempts} ];then
              echo "Max attempts reached waiting for central to be available at '$URL'"
              false
            fi

            printf '.'
            attempt_counter=$(($attempt_counter+1))
            sleep 5
        done
        echo "OK"

        echo "* Configuring cluster-init bundle: "
        export DATA={\"name\":\"local-cluster\"}
        curl -k -o /tmp/bundle.json -X POST -u "admin:$PASSWORD" -H "Content-Type: application/json" --data $DATA https://central/v1/cluster-init/init-bundles

        echo "Bundle received"
        cat /tmp/bundle.json

        echo "Applying bundle"
        # No jq in container, python to the rescue
        cat /tmp/bundle.json | python3 -c "import sys, json; print(json.load(sys.stdin)['kubectlBundle'])" | base64 -d | oc apply -f -
        # Touch SecuredCluster to force operator to reconcile
        oc label SecuredCluster local-cluster cluster-init-job-status=created
      fi

      # echo "* Configure ACS Secured Cluster Service"
      # echo helm upgrade --install -n stackrox --create-namespace \
      #   stackrox-secured-cluster-services rhacs/secured-cluster-services \
      #   --set scanner.disable=false \
      #   --set clusterName=local \
      #   # -f <path_to_cluster_init_bundle.yaml> \
      #   # --set centralEndpoint=<endpoint_of_central_service>
      # sleep 900
      } || { echo "FAILED"; sleep 900; }
{{ end }}