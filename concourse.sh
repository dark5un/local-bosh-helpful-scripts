#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# global stuff
# shellcheck source="$script_dir/.envrc"
source "$script_dir/.envrc"
# shellcheck source="$script_dir/lib.sh"
source "$script_dir/lib.sh"

vars_store="$script_dir/concourse-vars-store.yml"
vars_file="$script_dir/concourse-vars-file.yml"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

parse_params() {
  # default values of variables set from params
  while :; do
    case "${1-}" in
    -h | --help) usage "Deploy concourse CI local BOSH director" ;;
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
cat<<EOF >"$vars_file"
credhub_url: "$CREDHUB_SERVER"
credhub_client_id: "$CREDHUB_CLIENT"
credhub_client_secret: "$CREDHUB_SECRET"
credhub_ca_cert: "$CREDHUB_CA_CERT"
local_user.username: admin
local_user.password: admin
web_ip: 10.244.15.2
external_url: http://10.244.15.2:8080
network_name: concourse
web_vm_type: concourse
db_vm_type: concourse
db_persistent_disk_type: db
worker_vm_type: concourse
deployment_name: concourse
azs: [z1]
EOF

concourse_bosh_deployment_path="${script_dir}/../concourse-bosh-deployment"
if [ ! -d "$concourse_bosh_deployment_path" ]; then
  git clone https://github.com/concourse/concourse-bosh-deployment.git "$concourse_bosh_deployment_path"
fi

pushd "$concourse_bosh_deployment_path/cluster"

bosh -e $BOSH_ENVIRONMENT -n update-cloud-config cloud_configs/vbox.yml

bosh -e $BOSH_ENVIRONMENT -n deploy -d concourse concourse.yml \
  --vars-store="$vars_store" \
  --ops-file=operations/static-web.yml \
  --ops-file=operations/basic-auth.yml \
  --ops-file=operations/credhub.yml \
  --ops-file=operations/credhub-tls-skip-verify.yml \
  --vars-file=../versions.yml \
  --vars-file="$vars_file"

popd