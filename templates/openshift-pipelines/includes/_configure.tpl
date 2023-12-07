{{ define "dance.pipelines.configure" }}
- name: configure-pipelines
  image: "k8s.gcr.io/hyperkube:v1.12.1"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      CRD="tektonconfigs"
      echo -n "* Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo -n "* Waiting for pipelines operator deployment: "
      until kubectl get "$CRD" config -n openshift-pipelines >/dev/null 2>&1; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      # All actions must be idempotent
      echo -n "* Update the TektonConfig resource: "
      kubectl patch "$CRD" config --type 'merge' --patch '{{ include "dance.includes.tektonconfig" . | indent 8 }}' >/dev/null
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}