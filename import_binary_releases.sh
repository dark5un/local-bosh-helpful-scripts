#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# global stuff
# shellcheck source="$script_dir/.envrc"
source "$script_dir/.envrc"
# shellcheck source="$script_dir/lib.sh"
source "$script_dir/lib.sh"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

parse_params() {
  # default values of variables set from params
  flag=0
  deployment_used=''

  while :; do
    case "${1-}" in
    -h | --help) usage "Import binary releases to speed up deployment";;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -f | --flag) flag=1 ;; # example flag
    -d | --deployment) # example named parameter
      deployment_used="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  # check required params and arguments
  [[ -z "${deployment_used-}" ]] && die "Missing required parameter: deployment"

  return 0
}

parse_params "$@"
setup_colors

# script logic here
releases_path="${script_dir}/binary-releases/${deployment_used}"

for r in "$releases_path"/*.tgz; do
    bosh -e "$BOSH_ENVIRONMENT" -n upload-release "$r"
done
