#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(
  cd "$(dirname "$0")" >/dev/null
  pwd
)"

usage() {
  echo "
Usage:
    ${0##*/} [options]

Freeze the dependencies.

Optional arguments:
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

set_defaults() {
  ACTIONS=(helm)
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -d | --debug)
      set -x
      DEBUG="--debug"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      # End of arguments
      break
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done
}

init() {
  PROJECT_DIR="$(
    cd "$SCRIPT_DIR/../.." >/dev/null
    pwd
  )"
}

helm() {
  URL="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
  cat <<EOF >"$PROJECT_DIR/templates/shared/_install_helm.tpl"
{{ define "dance.shared.install_helm" }}
# Source: $URL
$(curl --silent "$URL" | tail -n +2)
{{end}}
EOF
}

main() {
  set_defaults
  parse_args "$@"
  init
  for ACTION in "${ACTIONS[@]}"; do
    $ACTION
  done
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi
