#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

CONFIG_JSON="/etc/hypervisor/config.json"
TMP=$(mktemp)
cp "$CONFIG_JSON" "$TMP"

# Example: update Ubuntu stable and devel latest 3
update_ubuntu() {
  local base="https://releases.ubuntu.com"
  mapfile -t vers < <(curl -fsSL "$base/" | grep -Eo '>[0-9]{2}\.[0-9]{2}/<' | tr -d '</>' | sort -Vr | head -n 3)
  for v in "${vers[@]}"; do
    url="$base/$v/ubuntu-$v-live-server-amd64.iso"
    csum="$base/$v/SHA256SUMS"
    sig="$base/$v/SHA256SUMS.gpg"
    jq --arg name "Ubuntu $v LTS" --arg url "$url" --argjson ch "\"stable\"" \
       --arg c "$csum" --arg s "$sig" \
       '.iso_presets += [{name:$name,url:$url,channel:"stable",checksum_urls:[$c],signature_urls:[$s],gpg_key_urls:["https://ubuntu.com/security/ubuntu-keyring.gpg"]}]' "$TMP" > "$TMP.new" && mv "$TMP.new" "$TMP"
  done
}

# Similar functions could be added for Fedora/Debian (omitted for brevity)

update_ubuntu

mv "$TMP" "$CONFIG_JSON"
echo "Updated $CONFIG_JSON with latest Ubuntu releases (3)."
