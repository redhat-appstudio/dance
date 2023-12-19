{{ define "dance.developer-hub.configure" }}
- name: configure-developer-hub
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      CHART="{{ .Chart.Name }}"

      echo -n "* Waiting for route: "
      until kubectl get route {{ .Release.Name }}-developer-hub -o name >/dev/null ; do
        echo -n "."
        sleep 3
      done
      HOSTNAME="$(kubectl get routes {{ .Release.Name }}-developer-hub -o jsonpath="{.spec.host}")"
      echo -n "."
      if [ "$(kubectl get secret "$CHART-developer-hub-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
        kubectl create secret generic "$CHART-developer-hub-secret" \
          --from-literal="hostname=$HOSTNAME" >/dev/null
      fi
      echo "OK"

      echo -n "* Waiting for UI: "
      until curl --fail --location --output /dev/null --silent "https://$HOSTNAME"; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}