{{ define "dance.acs.test_pipeline" }}
# oc create -n {{ .Release.Namespace }} -f acs-pipelinerun.yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: acs-test-
spec:
  pipelineSpec:
    tasks:
    - name: deploy-check
      taskRef:
        resolver: cluster
        params:
          - name: kind
            value: task
          - name: name
            value: acs-deploy-check
          - name: namespace
            value: {{ .Release.Namespace }}
      params:
        - name: deployment_url
          value: https://raw.githubusercontent.com/jduimovich/quarkus-1/main/argocd/components/q/base/deployment.yaml
        - name: insecure-skip-tls-verify
          value: true
    - name: image-check
      taskRef:
        resolver: cluster
        params:
          - name: kind
            value: task
          - name: name
            value: acs-image-check
          - name: namespace
            value: {{ .Release.Namespace }}
      params:
        - name: image
          value: quay.io/team-helium/miner
        - name: image_digest
          value: sha256:19bffd927a8dc70be5995eeba4ede675f57eca6222329477a50d65dc06880e3c
        - name: insecure-skip-tls-verify
          value: true
    - name: image-scan
      taskRef:
        resolver: cluster
        params:
          - name: kind
            value: task
          - name: name
            value: acs-image-scan
          - name: namespace
            value: {{ .Release.Namespace }}
      params:
        - name: image
          value: quay.io/team-helium/miner
        - name: image_digest
          value: sha256:19bffd927a8dc70be5995eeba4ede675f57eca6222329477a50d65dc06880e3c
        - name: insecure-skip-tls-verify
          value: true
{{ end }}