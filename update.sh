#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
versions_file="$script_dir/versions.json"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command nix
require_command nix-prefetch-url

curl_args=(
  -fsSL
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

github_latest_release() {
  local repo="$1"
  curl "${curl_args[@]}" "https://api.github.com/repos/${repo}/releases/latest"
}

asset_url() {
  local release_json="$1"
  local asset_name="$2"

  jq -er --arg name "$asset_name" '
    .assets[]
    | select(.name == $name)
    | .browser_download_url
  ' <<<"$release_json"
}

prefetch_sri_hash() {
  local url="$1"
  local nix32_hash

  nix32_hash="$(nix-prefetch-url --type sha256 "$url")"
  nix hash convert --hash-algo sha256 --to sri "$nix32_hash"
}

linux_repo="imputnet/helium-linux"

echo "Fetching latest release metadata from GitHub..."
linux_release="$(github_latest_release "$linux_repo")"

linux_version="$(jq -er '.tag_name' <<<"$linux_release")"

linux_x86_64_name="helium-${linux_version}-x86_64_linux.tar.xz"
linux_aarch64_name="helium-${linux_version}-arm64_linux.tar.xz"

linux_x86_64_url="$(asset_url "$linux_release" "$linux_x86_64_name")"
linux_aarch64_url="$(asset_url "$linux_release" "$linux_aarch64_name")"

echo "Prefetching hashes..."
linux_x86_64_hash="$(prefetch_sri_hash "$linux_x86_64_url")"
linux_aarch64_hash="$(prefetch_sri_hash "$linux_aarch64_url")"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

jq -n \
  --arg linux_version "$linux_version" \
  --arg linux_x86_64_url "$linux_x86_64_url" \
  --arg linux_x86_64_hash "$linux_x86_64_hash" \
  --arg linux_aarch64_url "$linux_aarch64_url" \
  --arg linux_aarch64_hash "$linux_aarch64_hash" \
  '{
    versions: {
      linux: $linux_version
    },
    srcs: {
      "x86_64-linux": {
        url: $linux_x86_64_url,
        hash: $linux_x86_64_hash
      },
      "aarch64-linux": {
        url: $linux_aarch64_url,
        hash: $linux_aarch64_hash
      }
    }
  }' >"$tmp_file"

mv "$tmp_file" "$versions_file"
trap - EXIT

echo "Updated $versions_file"
echo "linux version: $linux_version"
