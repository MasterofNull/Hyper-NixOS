#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"
ROOT="/etc/hypervisor"
CONFIG_JSON="$ROOT/config.json"
IMAGES_DIR="/var/lib/hypervisor/images"
mkdir -p "$IMAGES_DIR"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" curl sha256sum jq gpg

store_sidecar_checksum() { sha256sum "$1" > "$1.sha256"; }

import_key_url() {
  local url="$1"; [[ -z "$url" ]] && return 1
  tmp=$(mktemp)
  if curl -fsSL "$url" -o "$tmp"; then
    GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --import "$tmp" >/dev/null 2>&1 || true
    rm -f "$tmp"; return 0
  fi
  rm -f "$tmp"; return 1
}

auto_import_vendor_key() {
  local signature_url="$1" checksum_url="$2" image_url="$3" preset_key_url="$4"
  [[ -n "$preset_key_url" ]] && import_key_url "$preset_key_url" && return 0
  local base dir candidates c
  base="${signature_url%/*}"; [[ -z "$base" || "$base" == "$signature_url" ]] && base="${checksum_url%/*}"
  [[ -z "$base" || "$base" == "$checksum_url" ]] && base="${image_url%/*}"
  dir="$base"
  candidates=("$dir/KEYS" "$dir/KEYS.txt" "$dir/keyring.gpg" "$dir/GPG-KEY" "$dir/pubkey.gpg")
  for c in "${candidates[@]}"; do import_key_url "$c" && return 0; done
  return 1
}

list_images() { ls -1 "$IMAGES_DIR"/* 2>/dev/null || true; }

choose_image() {
  local files=(); shopt -s nullglob; for f in "$IMAGES_DIR"/*; do files+=("$f" " "); done; shopt -u nullglob
  (( ${#files[@]} == 0 )) && { $DIALOG --msgbox "No images in $IMAGES_DIR" 8 50; return 1; }
  $DIALOG --menu "Select image" 22 80 14 "${files[@]}" 3>&1 1>&2 2>&3
}

download_image() {
  local names urls checksum_lists signature_lists gpg_lists preset_choice url filename tmpdir auto checks_file sig_file
  if [[ -f "$CONFIG_JSON" ]]; then
    mapfile -t names < <(jq -r '.cloud_image_presets[]?.name' "$CONFIG_JSON")
    mapfile -t urls < <(jq -r '.cloud_image_presets[]?.url' "$CONFIG_JSON")
    mapfile -t checksum_lists < <(jq -r '.cloud_image_presets[]? | (.checksum_urls // []) | @sh' "$CONFIG_JSON")
    mapfile -t signature_lists < <(jq -r '.cloud_image_presets[]? | (.signature_urls // []) | @sh' "$CONFIG_JSON")
    mapfile -t gpg_lists < <(jq -r '.cloud_image_presets[]? | (.gpg_key_urls // []) | @sh' "$CONFIG_JSON")
    if (( ${#names[@]} > 0 )); then
      local items=(); for i in "${!names[@]}"; do items+=("$i" "${names[$i]}"); done
      preset_choice=$($DIALOG --menu "Cloud image presets (or Cancel for manual URL)" 20 70 12 "${items[@]}" 3>&1 1>&2 2>&3 || true)
      if [[ -n "$preset_choice" ]]; then
        url="${urls[$preset_choice]}"
        preset_checksum_list=$(eval echo ${checksum_lists[$preset_choice]:-})
        preset_signature_list=$(eval echo ${signature_lists[$preset_choice]:-})
        preset_gpg_key_list=$(eval echo ${gpg_lists[$preset_choice]:-})
      fi
    fi
  fi
  if [[ -z "${url:-}" ]]; then
    url=$($DIALOG --inputbox "Cloud image URL" 10 70 3>&1 1>&2 2>&3) || return 1
  fi
  filename=$(basename "$url"); tmpdir=$(mktemp -d)
  auto=""
  if [[ -n "${preset_checksum_list:-}" ]]; then
    for preset_checksum_url in $preset_checksum_list; do
      checks_file="$tmpdir/checksums.txt"
      curl -fsSL "$preset_checksum_url" -o "$checks_file" || { rm -f "$checks_file"; continue; }
      if [[ -s "$checks_file" ]]; then
        if [[ -n "${preset_signature_list:-}" ]]; then
          for preset_signature_url in $preset_signature_list; do
            sig_file="$tmpdir/checksums.sig"
            curl -fsSL "$preset_signature_url" -o "$sig_file" || { rm -f "$sig_file"; continue; }
            if [[ -s "$sig_file" ]]; then
              if [[ -n "${preset_gpg_key_list:-}" ]]; then
                for kurl in $preset_gpg_key_list; do auto_import_vendor_key "$preset_signature_url" "$preset_checksum_url" "$url" "$kurl" || true; done
              else
                auto_import_vendor_key "$preset_signature_url" "$preset_checksum_url" "$url" "" || true
              fi
              GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --verify "$sig_file" "$checks_file" || true
            fi
          done
        fi
        auto=$(awk -v fn="$filename" 'BEGIN{IGNORECASE=1}
          $1 ~ /^[a-f0-9]{64}$/ && index($0, fn){print $1; exit}
          match($0, /SHA256 \(([^)]+)\) = ([a-f0-9]{64})/, m){ if (m[1]==fn){print m[2]; exit} }
        ' "$checks_file")
        [[ -n "$auto" ]] && break
      fi
    done
  fi
  tmp="$IMAGES_DIR/.partial-$filename"
  curl -L -C - "$url" -o "$tmp"
  mv "$tmp" "$IMAGES_DIR/$filename"
  if [[ -n "$auto" ]]; then echo "$auto  $IMAGES_DIR/$filename" | sha256sum -c - || $DIALOG --msgbox "Checksum mismatch" 8 40; fi
  store_sidecar_checksum "$IMAGES_DIR/$filename"
  $DIALOG --msgbox "Downloaded image: $filename" 8 50
}

while true; do
  choice=$($DIALOG --menu "Cloud Image Manager" 22 90 12 \
    1 "Download cloud image (verified when possible)" \
    2 "List images" \
    3 "Help" \
    4 "Exit" 3>&1 1>&2 2>&3) || exit 0
  case "$choice" in
    1) download_image ;;
    2) list_images | ${PAGER:-less} ;;
    3) $DIALOG --msgbox "Cloud images are base OS disks (qcow2/raw) optimized for cloud-init.\n\nUse wizard to point at the image and add cloud-init user/meta data.\nImages are stored in: $IMAGES_DIR" 14 70 ;;
    4) exit 0 ;;
  esac
done
