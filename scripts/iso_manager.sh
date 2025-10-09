#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

ISOS_DIR="${1:-/var/lib/hypervisor/isos}"
USER_PROFILES_DIR="${2:-/var/lib/hypervisor/vm_profiles}"
CONFIG_JSON="/etc/hypervisor/config.json"
: "${DIALOG:=whiptail}"
export DIALOG

require() {
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing: $bin" >&2; exit 1; }
  done
}
require "$DIALOG" curl sha256sum jq awk sed gpg

mkdir -p "$ISOS_DIR" "$USER_PROFILES_DIR"

# Import a GPG key URL into the hypervisor keyring (non-interactive)
import_key_url() {
  local url="$1"
  [[ -z "$url" ]] && return 1
  tmp=$(mktemp)
  if curl -fsSL "$url" -o "$tmp"; then
    GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --import "$tmp" >/dev/null 2>&1 || true
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"; return 1
}

# Try to automatically find and import a vendor GPG key
auto_import_vendor_key() {
  local signature_url="$1" checksum_url="$2" iso_url="$3" preset_key_url="$4"
  # Prefer explicit preset key
  if [[ -n "$preset_key_url" ]]; then
    import_key_url "$preset_key_url" && return 0
  fi
  # Heuristic: try common key filenames in the directory of signature/checksum/ISO
  local base dir candidates c
  base="${signature_url%/*}"
  [[ -z "$base" || "$base" == "$signature_url" ]] && base="${checksum_url%/*}"
  [[ -z "$base" || "$base" == "$checksum_url" ]] && base="${iso_url%/*}"
  dir="$base"
  candidates=(
    "$dir/KEYS" "$dir/KEYS.txt" "$dir/KEYS.gpg" "$dir/keyring.gpg" "$dir/gpg.key" "$dir/Release.key" "$dir/GPG-KEY" "$dir/GPG-KEYS" "$dir/pubkey.gpg"
  )
  for c in "${candidates[@]}"; do
    import_key_url "$c" && return 0
  done
  return 1
}

choose_iso() {
  local files=()
  shopt -s nullglob
  for f in "$ISOS_DIR"/*.iso; do files+=("$f" " "); done
  shopt -u nullglob
  if (( ${#files[@]} == 0 )); then
    $DIALOG --msgbox "No ISOs found in $ISOS_DIR" 8 50
    return 1
  fi
  $DIALOG --menu "Select ISO" 20 70 10 "${files[@]}" 3>&1 1>&2 2>&3
}

choose_profile() {
  local entries=()
  shopt -s nullglob
  for f in "$USER_PROFILES_DIR"/*.json; do entries+=("$f" " "); done
  shopt -u nullglob
  if (( ${#entries[@]} == 0 )); then
    $DIALOG --msgbox "No user profiles in $USER_PROFILES_DIR" 8 60
    return 1
  fi
  $DIALOG --menu "Select Profile" 20 70 10 "${entries[@]}" 3>&1 1>&2 2>&3
}

store_sidecar_checksum() {
  local iso="$1"
  local sidecar="${iso}.sha256"
  sha256sum "$iso" > "$sidecar"
}

try_fetch_checksum() {
  local url="$1" filename
  filename=$(basename "$url")
  local base="${url%/*}"
  local candidates=(
    "$url.sha256" "$url.sha256sum" "$url.sha256.txt" "$url.CHECKSUM" "$base/SHA256SUMS" "$base/sha256sums.txt"
  )
  for c in "${candidates[@]}"; do
    if curl -fsL "$c" -o "$ISOS_DIR/.checksums.tmp"; then
      # Look for a line with a 64-hex hash and the filename
      if awk -v fn="$filename" 'BEGIN{IGNORECASE=1} { if ($1 ~ /^[a-f0-9]{64}$/ && index($0, fn)) { print $1; exit 0 } }' "$ISOS_DIR/.checksums.tmp"; then
        rm -f "$ISOS_DIR/.checksums.tmp"
        return 0
      fi
    fi
  done
  return 1
}

download_iso() {
  local url checksum filename tmp auto
  local preset_choice
  if [[ -f "$CONFIG_JSON" ]]; then
    # Build preset menu
    mapfile -t names < <(jq -r '.iso_presets[]?.name' "$CONFIG_JSON")
    mapfile -t urls < <(jq -r '.iso_presets[]?.url' "$CONFIG_JSON")
    mapfile -t preset_checksum_urls < <(jq -r '.iso_presets[]?.checksum_url // empty' "$CONFIG_JSON")
    mapfile -t preset_signature_urls < <(jq -r '.iso_presets[]?.signature_url // empty' "$CONFIG_JSON")
    mapfile -t preset_gpg_keys < <(jq -r '.iso_presets[]?.gpg_key_url // empty' "$CONFIG_JSON")
    if (( ${#names[@]} > 0 )); then
      local items=()
      for i in "${!names[@]}"; do items+=("$i" "${names[$i]}"); done
      preset_choice=$($DIALOG --menu "ISO presets (or Cancel for manual URL)" 20 70 10 "${items[@]}" 3>&1 1>&2 2>&3 || true)
      if [[ -n "${preset_choice:-}" ]]; then
        url="${urls[$preset_choice]}"
        preset_checksum_url="${preset_checksum_urls[$preset_choice]:-}"
        preset_signature_url="${preset_signature_urls[$preset_choice]:-}"
        preset_gpg_key_url="${preset_gpg_keys[$preset_choice]:-}"
      fi
    fi
  fi
  if [[ -z "${url:-}" ]]; then
    url=$($DIALOG --inputbox "ISO URL" 10 70 3>&1 1>&2 2>&3) || return 1
  fi
  # Attempt to obtain checksum from preset sources
  auto=""
  filename=$(basename "$url")
  tmpdir=$(mktemp -d)
  if [[ -n "${preset_checksum_url:-}" ]]; then
    checks_file="$tmpdir/checksums.txt"
    curl -fsSL "$preset_checksum_url" -o "$checks_file" || true
    if [[ -s "$checks_file" ]]; then
      if [[ -n "${preset_signature_url:-}" ]]; then
        sig_file="$tmpdir/checksums.sig"
        curl -fsSL "$preset_signature_url" -o "$sig_file" || true
        if [[ -s "$sig_file" ]]; then
          # Auto-import vendor key if possible, then verify
          auto_import_vendor_key "$preset_signature_url" "$preset_checksum_url" "$url" "${preset_gpg_key_url:-}" || true
          if ! GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --verify "$sig_file" "$checks_file"; then
            # If verification failed (likely missing key), ask user to provide key URL
            if $DIALOG --yesno "Signature verification failed. Provide a GPG key URL to import?" 10 70; then
              import_gpg_key || true
              GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --verify "$sig_file" "$checks_file" || $DIALOG --msgbox "WARNING: Signature still not verified" 8 60
            else
              $DIALOG --msgbox "WARNING: Signature verification not completed" 8 60
            fi
          fi
        fi
      fi
      # Parse checksum line for our filename (support common formats)
      auto=$(awk -v fn="$filename" 'BEGIN{IGNORECASE=1}
        $1 ~ /^[a-f0-9]{64}$/ && index($0, fn){print $1; exit}
        match($0, /SHA256 \(([^)]+)\) = ([a-f0-9]{64})/, m){ if (m[1]==fn){print m[2]; exit} }
      ' "$checks_file")
    fi
  fi
  # Fallback to heuristic from URL base
  [[ -z "$auto" ]] && auto=$(try_fetch_checksum "$url" || true)
  if [[ -n "$auto" ]]; then
    checksum="$auto"
  else
    checksum=$($DIALOG --inputbox "Expected SHA256 (optional)" 10 70 3>&1 1>&2 2>&3 || true)
  fi
  filename=$(basename "$url")
  tmp="$ISOS_DIR/.partial-$filename"
  if command -v isoctl >/dev/null 2>&1; then
    isoctl download --url "$url" --out "$tmp" || { $DIALOG --msgbox "isoctl download failed" 8 50; return 1; }
  else
    curl -L -C - "$url" -o "$tmp"
  fi
  mv "$tmp" "$ISOS_DIR/$filename"
  if [[ -n "${checksum:-}" ]]; then
    if echo "$checksum  $ISOS_DIR/$filename" | sha256sum -c -; then
      store_sidecar_checksum "$ISOS_DIR/$filename"
      $DIALOG --msgbox "Downloaded and verified: $filename" 8 60
    else
      $DIALOG --msgbox "Checksum FAILED" 8 40
      return 1
    fi
  else
    # Generate sidecar anyway for offline integrity
    store_sidecar_checksum "$ISOS_DIR/$filename"
    $DIALOG --msgbox "Downloaded: $filename" 8 50
  fi
}

validate_iso() {
  local iso checksum side
  iso=$(choose_iso || true) || return 1
  side="${iso}.sha256"
  if [[ -f "$side" ]]; then
    if sha256sum -c "$side"; then $DIALOG --msgbox "Checksum OK (sidecar)" 8 40; else $DIALOG --msgbox "Checksum FAILED" 8 40; fi
    return 0
  fi
  checksum=$($DIALOG --inputbox "Expected SHA256" 10 70 3>&1 1>&2 2>&3) || return 1
  echo "$checksum  $iso" | sha256sum -c - && $DIALOG --msgbox "Checksum OK" 8 30 || $DIALOG --msgbox "Checksum FAILED" 8 40
}

verify_gpg() {
  local url asc_url iso asc tmpdir
  iso=$(choose_iso || true) || return 1
  asc_url=$($DIALOG --inputbox "Signature URL (.asc or CHECKSUMS.sig)" 10 70 3>&1 1>&2 2>&3) || return 1
  tmpdir=$(mktemp -d)
  asc="$tmpdir/$(basename "$asc_url")"
  curl -fsSL "$asc_url" -o "$asc" || { $DIALOG --msgbox "Failed to download signature" 8 50; rm -rf "$tmpdir"; return 1; }
  GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --verify "$asc" "$iso" && $DIALOG --msgbox "GPG signature VERIFIED" 8 40 || $DIALOG --msgbox "GPG verification FAILED" 8 40
  rm -rf "$tmpdir"
}

import_gpg_key() {
  local key_url tmp
  key_url=$($DIALOG --inputbox "GPG public key URL" 10 70 3>&1 1>&2 2>&3) || return 1
  tmp=$(mktemp)
  curl -fsSL "$key_url" -o "$tmp" || { $DIALOG --msgbox "Failed to fetch key" 8 40; rm -f "$tmp"; return 1; }
  GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --import "$tmp" && $DIALOG --msgbox "Key imported" 8 30 || $DIALOG --msgbox "Key import FAILED" 8 40
  rm -f "$tmp"
}

import_local_iso() {
  local path
  path=$($DIALOG --inputbox "Path to local ISO (pre-mounted)" 10 70 3>&1 1>&2 2>&3) || return 1
  [[ -f "$path" ]] || { $DIALOG --msgbox "Not found: $path" 8 40; return 1; }
  cp -v "$path" "$ISOS_DIR/"
  store_sidecar_checksum "$ISOS_DIR/$(basename "$path")"
}

attach_iso_to_profile() {
  local iso prof
  iso=$(choose_iso || true) || return 1
  prof=$(choose_profile || true) || return 1
  tmp=$(mktemp)
  jq --arg p "$iso" '.iso_path = $p' "$prof" > "$tmp" && mv "$tmp" "$prof"
  $DIALOG --msgbox "Attached ISO to profile:\n$prof" 10 60
}

list_isos() {
  ls -1 "$ISOS_DIR"/*.iso 2>/dev/null || true
}

while true; do
  choice=$($DIALOG --menu "ISO Manager" 22 80 12 \
    1 "Download ISO (auto-checksum when available)" \
    2 "Validate ISO checksum" \
    3 "Import ISO from local path" \
    4 "Attach ISO to a VM profile" \
    5 "GPG: Import key" \
    6 "GPG: Verify ISO signature" \
    7 "List ISOs" \
    8 "Exit" 3>&1 1>&2 2>&3) || exit 0
  case "$choice" in
    1) download_iso ;;
    2) validate_iso ;;
    3) import_local_iso ;;
    4) attach_iso_to_profile ;;
    5) import_gpg_key ;;
    6) verify_gpg ;;
    7) list_isos | ${PAGER:-less} ;;
    8) exit 0 ;;
  esac
done
