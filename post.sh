#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# global stuff
# shellcheck source="$script_dir/.envrc"
source "$script_dir/.envrc"
# shellcheck source="$script_dir/lib.sh"
source "$script_dir/lib.sh"

stemcells_path="$script_dir/stemcells"
binary_releases_path="$script_dir/binary-releases"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

parse_params() {
  # default values of variables set from params
  while :; do
    case "${1-}" in
    -h | --help) usage "Configure local BOSH director" ;;
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
mkdir -p "$stemcells_path" "$binary_releases_path"
bosh -e "$BOSH_ENVIRONMENT" -n update-cloud-config ./cloud-config.yml

pushd "$stemcells_path"
  for s in "ubuntu-xenial" "ubuntu-bionic"; do
    version_file="${s}.version"
    touch "$version_file"
    curl "https://bosh.io/api/v1/stemcells/bosh-warden-boshlite-${s}-go_agent" \
      -H "Accept: application/json" \
      --silent \
      --output "bosh-warden-boshlite-${s}-go_agent.json"
    latest_version="$(bosh interpolate "./bosh-warden-boshlite-${s}-go_agent.json" --path=/0/version)"
    version_saved="$(cat "$version_file")"

    if [ "$latest_version" != "$version_saved" ]; then
      echo "upgrading stemcell from ${version_saved} to ${latest_version}"
      stemcell_url="$(bosh interpolate "./bosh-warden-boshlite-${s}-go_agent.json" --path=/0/regular/url)"
      wget "$stemcell_url"
      echo "$latest_version" > "$version_file"
    fi
  done
popd

pushd "$stemcells_path"
for s in bosh-stemcell-*-warden-boshlite* ; do
  bosh -e "$BOSH_ENVIRONMENT" -n upload-stemcell "$s"
done
popd

bosh_dns_release_version=1.31.0
bosh_dns_release_url="https://bosh.io/d/github.com/cloudfoundry/bosh-dns-release?v=${bosh_dns_release_version}"
bosh_dns_release_file="$binary_releases_path/bosh-dns-release-${bosh_dns_release_version}.tgz"

if [ ! -f "$bosh_dns_release_file" ]; then
  wget "${bosh_dns_release_url}" --output-document="${bosh_dns_release_file}"
fi

bosh -e "$BOSH_ENVIRONMENT" -n upload-release "${bosh_dns_release_file}"

bosh -e "$BOSH_ENVIRONMENT" -n update-runtime-config ../bosh-deployment/runtime-configs/dns.yml
