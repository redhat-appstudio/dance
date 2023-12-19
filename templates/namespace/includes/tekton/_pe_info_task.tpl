{{ define "dance.namespace.pe_info_task" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: {{ .Chart.Name }}-pe-info
spec:
  description: >-
    Display the configuration information needed by the Platform
    Engineer to configure the RHDH.
  steps:
    - env:
      - name: ARGOCD_HOSTNAME
        valueFrom:
          secretKeyRef:
            name: {{ .Chart.Name }}-argocd-secret
            key: hostname
      - name: ARGOCD_TOKEN
        valueFrom:
          secretKeyRef:
            name: {{ .Chart.Name }}-argocd-secret
            key: api-token
      - name: DEVELOPER_HUB_HOSTNAME
        valueFrom:
          secretKeyRef:
            name: {{ .Chart.Name }}-developer-hub-secret
            key: hostname
      - name: PIPELINES_PAC_GH_SECRET
        valueFrom:
          secretKeyRef:
            name: {{ .Chart.Name }}-pipelines-secret
            key: webhook-github-secret
      - name: PIPELINES_PAC_URL
        valueFrom:
          secretKeyRef:
            name: {{ .Chart.Name }}-pipelines-secret
            key: webhook-url
      image: "k8s.gcr.io/hyperkube:v1.12.1"
      name: setup
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail

        # Output information in YAML so that it can easily be
        # post-processed if necessary.
        cat << _EOF_
        gitops:
          api-token: \$ARGOCD_TOKEN
          hostname: \$ARGOCD_HOSTNAME
        developer-hub:
          hostname: \$DEVELOPER_HUB_HOSTNAME
        pipelines:
          pipelines-as-code:
            github:
              # The docs URL explains how to setup the GitHub Application.
              # Set dummy values for the homepage URL and webhook URL, and
              # replace them with the final values after the chart is installed.
              docs-url: https://pipelinesascode.com/docs/install/github_apps/
              homepage-url: https://\$DEVELOPER_HUB_HOSTNAME
              webhook:
                secret: \$PIPELINES_PAC_GH_SECRET
                url: \$PIPELINES_PAC_URL
        _EOF_
      workingDir: /tmp
{{ end }}