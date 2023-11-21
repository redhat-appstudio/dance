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

Manage the Helm chart in '$NAMESPACE' as '$APP_NAME'.

Commands:
    apply
        Apply (install/update) the helm chart.
    delete
        Delete the helm chart.
    release
        Package and release the helm chart.
    template
        Render the helm chart.

Optional arguments:
    -a, --app-name APP_NAME
        Name of the application.
        Default: $APP_NAME
    -n, --namespace NAMESPACE
        Namespace where the application will be deployed.
        Default: $NAMESPACE
    --version VERSION
        Version of the helm chart to install.
        The version can end with 'x' to install the latest
        version (1.2.x to install the latest patch version,
        1.x to install the latest minor version).
        Default: current repository
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

set_defaults() {
  NAMESPACE=${NAMESPACE:-redhat-dance}
  APP_NAME=${APP_NAME:-installer}
  HELM_CHART="$(
    cd "$SCRIPT_DIR/.." >/dev/null
    pwd
  )"
  VERSION="$HELM_CHART"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    apply | delete | release | template)
      ACTION="$1"
      ;;
    -a | --app-name)
      shift
      APP_NAME="$1"
      ;;
    -n | --namespace)
      shift
      NAMESPACE="$1"
      ;;
    --version)
      shift
      VERSION="$(echo "$1" | cut -dx -f1)"
      VERSION=$(
        git ls-remote --tags https://github.com/redhat-appstudio/helm-repository.git "$VERSION*" |
          sed 's:.*refs/tags/::' |
          sort --version-sort |
          tail -1
      )
      VERSION="https://redhat-appstudio.github.io/helm-repository/dance-$VERSION.tgz"
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
  if [ -z "${ACTION:-}" ]; then
    echo "[ERROR] Command is missing" >&2
    exit 1
  fi
  helm="helm -n $NAMESPACE"
}

init() {
  helm repo add dance https://redhat-appstudio.github.io/helm-repository/ >/dev/null
  helm repo update dance >/dev/null
}

delete() {
  $helm uninstall "$APP_NAME"
  $helm list
}

apply() {
  $helm upgrade --install --create-namespace "$APP_NAME" "$VERSION"
  $helm list
}

release() {
  branch=$(git branch --show-current)
  # Check that the repository is in the right state
  if ! git diff --exit-code >/dev/null; then
    echo "Cannot release a version with uncommitted changes" >&2
    exit 1
  fi
  if ! git diff origin/$branch --exit-code >/dev/null; then
    echo "Cannot release a version that is not synced to the origin" >&2
    exit 1
  fi

  # Check out repository
  HELM_REPOSITORY="$(mktemp -d)"
  git clone git@github.com:redhat-appstudio/helm-repository.git \
    --branch "$branch" \
    --single-branch "$HELM_REPOSITORY"

  # Create package
  cd "$HELM_CHART"
  helm package --destination "$HELM_REPOSITORY" .
  _get_versions
  git tag --force "$version"
  git push --tags

  # Update version
  sed -i -e "s|^version: \+$version$|version: $next_version|" Chart.yaml
  git add .
  git commit -m "Init v$next_version"
  git push

  # Release package
  cd "$HELM_REPOSITORY"
  helm repo index .
  git add .
  git commit -m "Release $version
  
  Updates from $previous_version:
  $(
    git -C "$HELM_CHART" log \
      --reverse --format="  - %s" "$previous_version^..$version" \
      -- Chart.yaml values.yaml templates |
      tail -n +2
  )
  "
  git push
  git tag --force "$version"
  git push --tags
  cd -
  rm -rf "$HELM_REPOSITORY"
}

template() {
  $helm template "$APP_NAME" "$VERSION"
}

_get_versions() {
  version="$(
    git -C "$HELM_REPOSITORY" status | cut -c4- |
      grep --extended-regex --only-matching "([0-9]+\.){3}tgz$" |
      cut -d. -f 1-3
  )"

  for previous_version in $(
    git log --simplify-by-decoration --format=%D |
      sed -e 's|, tag: |\n|g' -e 's|^tag: ||' |
      grep --extended-regex "^([0-9]+\.){2}[0-9]+$" |
      sort --reverse --sort=version
  ); do
    if [ "$(echo -e "$previous_version\n$version" | sort --sort=version | head -1)" != "$version" ]; then
      break
    fi
    unset previous_version
  done

  major_minor="$(echo "$version" | cut -d. -f 1,2)"
  patch="$(echo "$(($(echo "$version" | cut -d. -f 3) + 1))")"
  next_version="$major_minor.$patch"
}

main() {
  set_defaults
  parse_args "$@"
  init
  $ACTION
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi
