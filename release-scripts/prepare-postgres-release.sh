#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# global stuff
# shellcheck source="$script_dir/.envrc"
source "$script_dir/.envrc"
# shellcheck source="$script_dir/lib.sh"
source "$script_dir/../lib.sh"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

parse_params() {
  # default values of variables set from params

  while :; do
    case "${1-}" in
    -h | --help) usage "Prepare postgres bosh release workspace";;
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

# script logic here

postgres_release_work_path="${script_dir}/../../../work/postgres-release"
postgres_release_path="${postgres_release_work_path}/postgres-release"
postgres_ci_env_path="${postgres_release_work_path}/postgres-ci-env/pipeline_vars"
postgres_ci_env="${postgres_ci_env_path}/postgres.yml"

mkdir -p "$postgres_release_work_path"
mkdir -p "$postgres_ci_env_path"

cat<<EOF > "$postgres_ci_env"
bosh2_director: $(bosh interpolate "${script_dir}/../bosh-deployment-vars.yml" --path=/internal_ip)
bosh2_director_name: $(bosh interpolate "${script_dir}/../bosh-deployment-vars.yml" --path=/internal_ip)
bosh2_user: admin
bosh2_password: $(bosh interpolate "${script_dir}/../bosh-vars-store.yml" --path=/admin_password)
bosh2_ca_cert: $(bosh --json interpolate "${script_dir}/../bosh-vars-store.yml" --path=/director_ssl/ca | grep "BEGIN CERTIFICATE")
stemcell_version: 621.125
EOF

if [ ! -d "$postgres_release_path" ]; then
  git clone https://github.com/cloudfoundry/postgres-release.git "$postgres_release_path"
fi

# Configuring pipelines

concourse_username=$(bosh interpolate "${script_dir}/../concourse-vars-file.yml" --path=/local_user.username)
concourse_password=$(bosh interpolate "${script_dir}/../concourse-vars-file.yml" --path=/local_user.password)
concourse_url=$(bosh interpolate "${script_dir}/../concourse-vars-file.yml" --path=/external_url)

fly -t pgci \
  login \
    --concourse-url="$concourse_url" \
    --username="$concourse_username" \
    --password="$concourse_password"

pipeline=acceptance-tests

fly -t pgci \
  set-pipeline \
      --pipeline=$pipeline \
      --config="${postgres_release_path}/ci/pipelines/$pipeline.yml" \
      --load-vars-from="$postgres_ci_env"