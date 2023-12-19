{{ define "dance.pipelines.configure" }}
- name: configure-pipelines
  image: quay.io/redhat-appstudio/appstudio-utils:dbbdd82734232e6289e8fbae5b4c858481a7c057
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

      #
      # All actions MUST be idempotent
      #
      CHART="{{ .Chart.Name }}"
      PIPELINES_NAMESPACE="openshift-pipelines"

      echo -n "* Waiting for pipelines operator deployment: "
      until kubectl get namespace "$PIPELINES_NAMESPACE" >/dev/null 2>&1; do
        echo -n "."
        sleep 3
      done
      until kubectl get route -n "$PIPELINES_NAMESPACE" pipelines-as-code-controller >/dev/null 2>&1; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo -n "* Update the TektonConfig resource: "
      until kubectl get tektonconfig config >/dev/null 2>&1; do
        echo -n "."
        sleep 3
      done
      kubectl patch tektonconfig config --type 'merge' --patch '{{ include "dance.includes.tektonconfig" . | indent 8 }}' >/dev/null
      echo "OK"

      echo -n "* Configuring Chains secret: "
      SECRET="signing-secrets"
      if [ "$(kubectl get secret -n "$PIPELINES_NAMESPACE" "$SECRET" -o jsonpath='{.data}' --ignore-not-found --allow-missing-template-keys)" == "" ]; then
        # Delete secret/signing-secrets if already exists since by default cosign creates immutable secrets
        echo -n "."
        kubectl delete secrets  -n "$PIPELINES_NAMESPACE" "$SECRET" --ignore-not-found=true

        # To make this run conveniently without user input let's create a random password
        echo -n "."
        RANDOM_PASS=$( openssl rand -base64 30 )

        # Generate the key pair secret directly in the cluster.
        # The secret should be created as immutable.
        echo -n "."
        env COSIGN_PASSWORD=$RANDOM_PASS cosign generate-key-pair "k8s://$PIPELINES_NAMESPACE/$SECRET" >/dev/null
      fi
      # If the secret is not marked as immutable, make it so.
      if [ "$(kubectl get secret -n "$PIPELINES_NAMESPACE" "$SECRET" -o jsonpath='{.immutable}')" != "true" ]; then
        echo -n "."
        kubectl patch secret -n "$PIPELINES_NAMESPACE" "$SECRET" --dry-run=client -o yaml \
          --patch='{"immutable": true}' \
        | kubectl apply -f - >/dev/null
      fi
      echo "OK"

      echo -n "* Configuring Pipelines-as-Code: "
      if [ "$(kubectl get secret "$CHART-pipelines-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
        echo -n "."
        WEBHOOK_SECRET="$(openssl rand -hex 20)"
        kubectl create secret generic "$CHART-pipelines-secret" \
          --from-literal="webhook-github-secret=$WEBHOOK_SECRET" \
          --from-literal="webhook-url=$(kubectl get routes -n "$PIPELINES_NAMESPACE" pipelines-as-code-controller -o jsonpath="https://{.spec.host}")" >/dev/null
      else
        WEBHOOK_SECRET="$(kubectl get secret "$CHART-pipelines-secret" ) -o jsonpath="{.data.webhook-github-secret}" | base64 -d"
      fi
      if [ "$(kubectl get secret -n "$PIPELINES_NAMESPACE" "pipelines-as-code-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
        echo -n "."
        kubectl -n "$PIPELINES_NAMESPACE" create secret generic pipelines-as-code-secret \
          --from-literal github-application-id="{{ (index .Values "pipelines" "pipelines-as-code" "github" "application-id") }}" \
          --from-literal github-private-key="$(echo "{{ (index .Values "pipelines" "pipelines-as-code" "github" "private-key") | b64enc }}" | base64 -d)" \
          --from-literal webhook.secret="$WEBHOOK_SECRET" \
          --dry-run=client -o yaml | kubectl apply -f - >/dev/null
      fi
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}