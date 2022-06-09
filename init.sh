#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# global stuff
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
    -h | --help) usage "Create a local BOSH director" ;;
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
netstat_output="$(netstat -rn | grep '10.244' | cut -f 1 -d ' ')"
if [ "$netstat_output" != "10.244/16" ]; then
  sudo route add -net 10.244.0.0/16 192.168.56.6
fi

cat<<EOF >"$deployment_vars"
director_name: bosh-lite
internal_ip: 192.168.56.6
internal_gw: 192.168.56.1
internal_cidr: 192.168.56.0/24
outbound_network_name: NatNetwork
local_deployment_path: $script_dir
EOF

bosh_deployment_path="${script_dir}/../bosh-deployment"
if [ ! -d "$bosh_deployment_path" ]; then
  git clone https://github.com/cloudfoundry/bosh-deployment.git "$bosh_deployment_path"
fi

pushd "$bosh_deployment_path"

bosh create-env ./bosh.yml \
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
  --vars-file="$deployment_vars"

popd

cat<<EOF >.envrc
export BOSH_ENVIRONMENT=vbox
export BOSH_CA_CERT="$( bosh interpolate "./bosh-vars-store.yml" --path /director_ssl/ca )"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$( bosh interpolate "./bosh-vars-store.yml" --path /admin_password )

export CREDHUB_SERVER=https://192.168.56.6:8844
export CREDHUB_CA_CERT="$( bosh interpolate "./bosh-vars-store.yml" --path=/credhub_tls/ca )
$( bosh interpolate "./bosh-vars-store.yml" --path=/uaa_ssl/ca )"
export CREDHUB_CLIENT=credhub-admin
export CREDHUB_SECRET=$( bosh interpolate "./bosh-vars-store.yml" --path=/credhub_admin_client_secret )
EOF

bosh alias-env vbox -e 192.168.56.6 --ca-cert <(bosh int ./bosh-vars-store.yml --path /director_ssl/ca)
