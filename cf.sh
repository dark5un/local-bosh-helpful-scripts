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
  while :; do
    case "${1-}" in
    -h | --help) usage "Deploy Cloud Foundry under local BOSH director" ;;
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
cf_deployment_path="${script_dir}/../cf-deployment"
if [ ! -d "$cf_deployment_path" ]; then
  git clone https://github.com/cloudfoundry/cf-deployment.git "$cf_deployment_path"
fi

stemcells_path="$script_dir/stemcells"
stemcell_os=$(bosh interpolate --path=/stemcells/0/os "${cf_deployment_path}/cf-deployment.yml")
stemcell_version=$(bosh interpolate --path=/stemcells/0/version "${cf_deployment_path}/cf-deployment.yml")
stemcell_url="https://bosh.io/d/stemcells/bosh-warden-boshlite-${stemcell_os}-go_agent?v=${stemcell_version}"
stemcell_file="$stemcells_path/bosh-stemcell-${stemcell_version}-warden-boshlite-${stemcell_os}-go_agent.tgz"
if [ ! -f "$stemcell_file" ]; then
  wget "${stemcell_url}" --output-document="${stemcell_file}"
fi
bosh -e "$BOSH_ENVIRONMENT" -n upload-stemcell "$stemcell_file"

pushd "$cf_deployment_path"

bosh -e "$BOSH_ENVIRONMENT" -n update-cloud-config iaas-support/bosh-lite/cloud-config.yml
bosh -e "$BOSH_ENVIRONMENT" -n -d cf deploy cf-deployment.yml \
  --ops-file=operations/bosh-lite.yml \
  --var=system_domain=bosh-lite.com

popd

cf api https://api.bosh-lite.com --skip-ssl-validation
admin_password=$(credhub get -q -n /bosh-lite/cf/cf_admin_password)
cf login -u admin -p "$admin_password"

cf create-space system
cf target -s system