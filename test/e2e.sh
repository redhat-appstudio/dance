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

Test the Helm chart.

Optional arguments:
    -t, --test TEST_NAME
        Name of the test(s) to run. Must be one of:
          apply, upgrade, version, template
        By default all tests are run, except upgrade.
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

set_defaults() {
  ACTIONS=()
  DEFAULT_ACTIONS=(version template apply test)
  HELM_CHART="$(
    cd "$SCRIPT_DIR/.." >/dev/null
    pwd
  )"
  NAMESPACE="dance-installer"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -t | --test)
      shift
      ACTIONS+=("$1")
      ;;
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
      shift
      PASSTHROUGH_ARGS=($@)
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
  if
    [ "$(echo "${ACTIONS[*]}" | grep -c "install")" = "1" -a "$(echo "${ACTIONS[*]}" | grep -c "upgrade")" = "1" ]
  then
    echo "Cannot run 'install' and 'upgrade' together" >&2
    exit 1
  fi
}

apply() {
  # Because the chart is idempotent there is no
  # need to track if the chart as already been
  # applied.
  $HELM_CHART/bin/make.sh apply -- "${PASSTHROUGH_ARGS[@]}"
}

template() {
  echo -n "Template: "

  cat "$SCRIPT_DIR/data/helm-chart/template.yaml" |
    diff - <($HELM_CHART/bin/make.sh template) &&
    echo "OK" ||
    {
      echo "FAIL"
      echo "You must update '$SCRIPT_DIR/data/helm-chart/template.yaml'." >&2
      exit 1
    }
}

test() {
  $HELM_CHART/bin/make.sh test
}

upgrade() {
  BASE_VERSION="0.x"
  echo "## Installing base version '$BASE_VERSION'"
  $HELM_CHART/bin/make.sh apply -- --version "$BASE_VERSION" "${PASSTHROUGH_ARGS[@]}"
  echo "## Applying upgrade"
  $HELM_CHART/bin/make.sh template --version "$BASE_VERSION" | diff - <($HELM_CHART/bin/make.sh template) || true
  apply
}

version() {
  echo -n "Version: "
  VERSION="$(cat "$HELM_CHART/Chart.yaml" | grep "^version:" | sed 's:.* ::')"
  if [ "$(git ls-remote --tags https://github.com/redhat-appstudio/helm-repository.git "$VERSION" | wc -l)" != "0" ]; then
    echo "Version '$VERSION' already exists."
    echo "You must update 'version' in 'Chart.yaml'." >&2
    exit 1
  fi
  echo "OK"
}

main() {
  set_defaults
  parse_args "$@"
  init
  for ACTION in "${ACTIONS[@]:-${DEFAULT_ACTIONS[@]}}"; do
    echo "# Test: $ACTION"
    $ACTION
    echo
  done
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi
