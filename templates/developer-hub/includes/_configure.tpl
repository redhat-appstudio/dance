{{ define "dance.developer-hub.configure" }}
{{ if and (index .Values "developer-hub") (index .Values "developer-hub" "quay-token") }}
- name: configure-developer-hub
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      echo -n "* Waiting for route: "
      until kubectl get route -n redhat-dance installer-developer-hub -o name --ignore-not-found >/dev/null ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo -n "* Waiting for UI: "
      URL="https://$(kubectl get route -n redhat-dance installer-developer-hub -o jsonpath='{.spec.host}')"
      until curl --fail --location --output /dev/null --silent "$URL"; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}
{{ end }}