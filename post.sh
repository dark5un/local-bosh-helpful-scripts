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
xenial_stemcell_version=621.125
xenial_stemcell_url="https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-xenial-go_agent?v=${xenial_stemcell_version}"
xenial_stemcell_file="$stemcells_path/bosh-warden-boshlite-ubuntu-xenial-${xenial_stemcell_version}.tgz"
bionic_stemcell_version=1.79
bionic_stemcell_url="https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-bionic-go_agent?v=${bionic_stemcell_version}"
bionic_stemcell_file="$stemcells_path/bosh-warden-boshlite-ubuntu-bionic-${bionic_stemcell_version}.tgz"
bosh_dns_release_version=1.31.0
bosh_dns_release_url="https://bosh.io/d/github.com/cloudfoundry/bosh-dns-release?v=${bosh_dns_release_version}"
bosh_dns_release_file="$binary_releases_path/bosh-dns-release-${bosh_dns_release_version}.tgz"

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

if [ ! -f "$xenial_stemcell_file" ]; then
  wget "${xenial_stemcell_url}" --output-document="${xenial_stemcell_file}"
fi
if [ ! -f "$bionic_stemcell_file" ]; then
  wget "${bionic_stemcell_url}" --output-document="${bionic_stemcell_file}"
fi

bosh -e "$BOSH_ENVIRONMENT" -n upload-stemcell "$xenial_stemcell_file"
bosh -e "$BOSH_ENVIRONMENT" -n upload-stemcell "$bionic_stemcell_file"

if [ ! -f "$bosh_dns_release_file" ]; then
  wget "${bosh_dns_release_url}" --output-document="${bosh_dns_release_file}"
fi

bosh -e "$BOSH_ENVIRONMENT" -n upload-release "${bosh_dns_release_file}"
bosh -e "$BOSH_ENVIRONMENT" -n update-runtime-config ../bosh-deployment/runtime-configs/dns.yml
