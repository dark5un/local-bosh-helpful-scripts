#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# global stuff
# shellcheck source="$script_dir/.envrc"
source "$script_dir/.envrc"
# shellcheck source="$script_dir/lib.sh"
source "$script_dir/lib.sh"

state="$script_dir/bosh-state.json"
creds="$script_dir/bosh-vars-store.yml"
deployment_vars="$script_dir/bosh-deployment-vars.yml"
cpi_override="$script_dir/ops/cpi_override.yml"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

parse_params() {
  # default values of variables set from params
  while :; do
    case "${1-}" in
    -h | --help) usage "Destroy local BOSH director" ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  return 0
}

parse_params "$@"
setup_colors

# The code

bosh_deployment_path="$script_dir/../bosh-deployment"
if [ ! -d "$bosh_deployment_path" ]; then
  git clone https://github.com/cloudfoundry/bosh-deployment.git "$script_dir/../bosh-deployment"
fi

pushd "$bosh_deployment_path"
  bosh delete-env ./bosh.yml \
  --state "$state" \
  --ops-file=./virtualbox/cpi.yml \
  --ops-file=./virtualbox/outbound-network.yml \
  --ops-file=./bosh-lite.yml \
  --ops-file=./bosh-lite-runc.yml \
  --ops-file=./uaa.yml \
  --ops-file=./credhub.yml \
  --ops-file=./jumpbox-user.yml \
  --ops-file=./misc/dns-addon.yml \
  --ops-file="$cpi_override" \
  --vars-store="$creds" \
  --vars-store="$deployment_vars"
popd
