#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
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
    mapfile -t chans < <(jq -r '.iso_presets[]? | (.channel // "stable")' "$CONFIG_JSON")
    mapfile -t preset_checksum_urls < <(jq -r '.iso_presets[]? | (.checksum_urls // [.checksum_url]) | map(select(. != null and . != "")) | @sh' "$CONFIG_JSON")
    mapfile -t preset_signature_urls < <(jq -r '.iso_presets[]? | (.signature_urls // [.signature_url]) | map(select(. != null and . != "")) | @sh' "$CONFIG_JSON")
    mapfile -t preset_gpg_keys < <(jq -r '.iso_presets[]? | (.gpg_key_urls // [.gpg_key_url]) | map(select(. != null and . != "")) | @sh' "$CONFIG_JSON")
    if (( ${#names[@]} > 0 )); then
      # Choose channel first when both exist
      local have_stable=false have_unstable=false; for c in "${chans[@]}"; do [[ "$c" == stable ]] && have_stable=true; [[ "$c" == unstable ]] && have_unstable=true; done
      local chan_sel="stable"
      if $have_unstable; then
        chan_sel=$($DIALOG --menu "Choose channel" 12 50 2 stable "Stable releases" unstable "Unstable/devel" 3>&1 1>&2 2>&3 || echo stable)
      fi
      local items=()
      for i in "${!names[@]}"; do
        if [[ "${chans[$i]}" == "$chan_sel" ]]; then
          items+=("$i" "${names[$i]}")
        elif [[ "$chan_sel" == stable && -z "${chans[$i]}" ]]; then
          items+=("$i" "${names[$i]}")
        fi
      done
      # Fallback to all if filter empty
      if (( ${#items[@]} == 0 )); then
        for i in "${!names[@]}"; do items+=("$i" "${names[$i]}"); done
      fi
      preset_choice=$($DIALOG --menu "ISO presets (${chan_sel}) (or Cancel for manual URL)" 20 72 12 "${items[@]}" 3>&1 1>&2 2>&3 || true)
      if [[ -n "${preset_choice:-}" ]]; then
        url="${urls[$preset_choice]}"
        preset_checksum_list=$(eval echo ${preset_checksum_urls[$preset_choice]:-})
        preset_signature_list=$(eval echo ${preset_signature_urls[$preset_choice]:-})
        preset_gpg_key_list=$(eval echo ${preset_gpg_keys[$preset_choice]:-})
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
  # Try a list of checksum/signature/key URLs (first one that works)
  if [[ -n "${preset_checksum_list:-}" ]]; then
    for preset_checksum_url in $preset_checksum_list; do
      checks_file="$tmpdir/checksums.txt"
      curl -fsSL "$preset_checksum_url" -o "$checks_file" || { rm -f "$checks_file"; continue; }
      if [[ -s "$checks_file" ]]; then
        # Try signatures for the checksum file if any
        if [[ -n "${preset_signature_list:-}" ]]; then
          for preset_signature_url in $preset_signature_list; do
            sig_file="$tmpdir/checksums.sig"
            curl -fsSL "$preset_signature_url" -o "$sig_file" || { rm -f "$sig_file"; continue; }
            if [[ -s "$sig_file" ]]; then
              # Attempt to import vendor keys before verify
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
      # Mark ISO as verified for security enforcement
      touch "$ISOS_DIR/$filename.sha256.verified"
      $DIALOG --msgbox "Downloaded and verified: $filename" 8 60
    else
      $DIALOG --msgbox "Checksum FAILED" 8 40
      return 1
    fi
  else
    # Generate sidecar anyway for offline integrity
    store_sidecar_checksum "$ISOS_DIR/$filename"
    $DIALOG --msgbox "Downloaded: $filename (WARNING: not verified)" 8 50
  fi
}

# Noninteractive download for CLI invocation
download_iso_cli() {
  local url="$1" checksum="$2" preset_checksum_url="$3" preset_signature_url="$4" preset_gpg_key_url="$5"
  local filename tmpdir checks_file sig_file tmp
  filename=$(basename "$url")
  tmpdir=$(mktemp -d)
  if [[ -z "$checksum" && -n "$preset_checksum_url" ]]; then
    checks_file="$tmpdir/checksums.txt"
    curl -fsSL "$preset_checksum_url" -o "$checks_file" || true
    if [[ -s "$checks_file" ]]; then
      if [[ -n "$preset_signature_url" ]]; then
        sig_file="$tmpdir/checksums.sig"
        curl -fsSL "$preset_signature_url" -o "$sig_file" || true
        if [[ -s "$sig_file" ]]; then
          auto_import_vendor_key "$preset_signature_url" "$preset_checksum_url" "$url" "${preset_gpg_key_url:-}" || true
          GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --verify "$sig_file" "$checks_file" || true
        fi
      fi
      checksum=$(awk -v fn="$filename" 'BEGIN{IGNORECASE=1} $1 ~ /^[a-f0-9]{64}$/ && index($0, fn){print $1; exit} match($0, /SHA256 \(([^)]+)\) = ([a-f0-9]{64})/, m){ if (m[1]==fn){print m[2]; exit} }' "$checks_file")
    fi
  fi
  tmp="$ISOS_DIR/.partial-$filename"
  if command -v isoctl >/dev/null 2>&1; then
    isoctl download --url "$url" --out "$tmp" || return 1
  else
    curl -L -C - "$url" -o "$tmp"
  fi
  mv "$tmp" "$ISOS_DIR/$filename"
  if [[ -n "$checksum" ]]; then echo "$checksum  $ISOS_DIR/$filename" | sha256sum -c - || return 1; fi
  sha256sum "$ISOS_DIR/$filename" > "$ISOS_DIR/$filename.sha256"
  echo "$ISOS_DIR/$filename"
}

validate_iso() {
  local iso checksum side
  iso=$(choose_iso || true) || return 1
  side="${iso}.sha256"
  if [[ -f "$side" ]]; then
    if sha256sum -c "$side"; then
      touch "$iso.sha256.verified"
      $DIALOG --msgbox "Checksum OK (sidecar)" 8 40
    else
      $DIALOG --msgbox "Checksum FAILED" 8 40
    fi
    return 0
  fi
  checksum=$($DIALOG --inputbox "Expected SHA256" 10 70 3>&1 1>&2 2>&3) || return 1
  if echo "$checksum  $iso" | sha256sum -c -; then
    touch "$iso.sha256.verified"
    $DIALOG --msgbox "Checksum OK" 8 30
  else
    $DIALOG --msgbox "Checksum FAILED" 8 40
  fi
}

verify_gpg() {
  local url asc_url iso asc tmpdir
  iso=$(choose_iso || true) || return 1
  asc_url=$($DIALOG --inputbox "Signature URL (.asc or CHECKSUMS.sig)" 10 70 3>&1 1>&2 2>&3) || return 1
  tmpdir=$(mktemp -d)
  asc="$tmpdir/$(basename "$asc_url")"
  curl -fsSL "$asc_url" -o "$asc" || { $DIALOG --msgbox "Failed to download signature" 8 50; rm -rf "$tmpdir"; return 1; }
  if GNUPGHOME=/var/lib/hypervisor/gnupg gpg --batch --verify "$asc" "$iso"; then
    touch "$iso.sha256.verified"
    $DIALOG --msgbox "GPG signature VERIFIED" 8 40
  else
    $DIALOG --msgbox "GPG verification FAILED" 8 40
  fi
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

# Scan helper: find ISO files under given paths (up to limited depth)
scan_paths_for_isos() {
  local found=()
  for base in "$@"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' f; do found+=("$f"); done < <(find "$base" -maxdepth 3 -type f -iname "*.iso" -print0 2>/dev/null || true)
  done
  printf '%s\n' "${found[@]}" | sort -u
}

scan_local_isos() {
  local defaults=(
    /run/media /media /mnt /home /var/tmp /tmp
  )
  mapfile -t files < <(scan_paths_for_isos "${defaults[@]}")
  if (( ${#files[@]} == 0 )); then
    $DIALOG --msgbox "No ISOs found under default paths." 8 50
    return 0
  fi
  # Build checklist
  local items=()
  for f in "${files[@]}"; do items+=("$f" "" off); done
  sel=$($DIALOG --checklist "Select ISOs to import into $ISOS_DIR" 22 80 12 "${items[@]}" 3>&1 1>&2 2>&3 || true)
  [[ -z "$sel" ]] && return 0
  for p in $sel; do
    p=${p%\"}; p=${p#\"}
    [[ -f "$p" ]] || continue
    cp -v "$p" "$ISOS_DIR/" || true
    store_sidecar_checksum "$ISOS_DIR/$(basename "$p")"
  done
  $DIALOG --msgbox "Imported selected ISOs." 8 40
}

mount_network_share_and_scan() {
  local typ mp target opts
  typ=$($DIALOG --menu "Share type" 12 50 2 nfs "NFS" cifs "SMB/CIFS" 3>&1 1>&2 2>&3 || echo "")
  [[ -z "$typ" ]] && return 0
  target=$($DIALOG --inputbox "Remote (nfs: server:/path, cifs: //server/share)" 10 70 3>&1 1>&2 2>&3) || return 0
  mp=$($DIALOG --inputbox "Mount point (will be created if missing)" 10 70 "/mnt/share" 3>&1 1>&2 2>&3) || return 0
  mkdir -p "$mp"
  if [[ "$typ" == nfs ]]; then
    opts=$($DIALOG --inputbox "Mount options (optional)" 10 70 "ro,vers=4" 3>&1 1>&2 2>&3 || echo "ro")
    if sudo mount -t nfs -o "$opts" "$target" "$mp"; then
      $DIALOG --msgbox "Mounted NFS at $mp" 8 40
      # Scan mount point
      mapfile -t files < <(scan_paths_for_isos "$mp")
    else
      $DIALOG --msgbox "Failed to mount NFS" 8 40; return 1
    fi
  else
    # CIFS
    local user pass
    user=$($DIALOG --inputbox "Username (optional)" 10 60 3>&1 1>&2 2>&3 || echo "")
    
    # Secure password input using temporary file with restrictive permissions
    local tmppass
    tmppass=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
    chmod 600 "$tmppass"
    $DIALOG --passwordbox "Password (optional)" 10 60 2>"$tmppass" || echo ""
    pass=$(cat "$tmppass" 2>/dev/null || echo "")
    shred -u "$tmppass" 2>/dev/null || rm -f "$tmppass"
    
    opts="ro,vers=3.0"
    [[ -n "$user" ]] && opts+="",username=$user
    [[ -n "$pass" ]] && opts+="",password=$pass
    if sudo mount -t cifs -o "$opts" "$target" "$mp"; then
      $DIALOG --msgbox "Mounted CIFS at $mp" 8 40
      mapfile -t files < <(scan_paths_for_isos "$mp")
    else
      $DIALOG --msgbox "Failed to mount CIFS" 8 40; return 1
    fi
  fi
  if (( ${#files[@]} == 0 )); then
    $DIALOG --msgbox "No ISOs found under $mp" 8 40
    return 0
  fi
  local items=()
  for f in "${files[@]}"; do items+=("$f" "" off); done
  sel=$($DIALOG --checklist "Select ISOs to import" 22 80 12 "${items[@]}" 3>&1 1>&2 2>&3 || true)
  [[ -z "$sel" ]] && return 0
  for p in $sel; do
    p=${p%\"}; p=${p#\"}
    [[ -f "$p" ]] || continue
    cp -v "$p" "$ISOS_DIR/" || true
    store_sidecar_checksum "$ISOS_DIR/$(basename "$p")"
  done
  $DIALOG --msgbox "Imported selected ISOs." 8 40
}


# Noninteractive CLI mode for automation
if [[ "${1:-}" == "--cli" ]]; then
  shift
  subcmd="${1:-}"
  case "$subcmd" in
    download)
      # Usage: iso_manager.sh --cli download --url <URL> [--checksum <SHA256>] [--preset <index|name>]
      shift || true
      url=""; checksum=""; preset=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --url) url="$2"; shift 2 ;;
          --checksum) checksum="$2"; shift 2 ;;
          --preset) preset="$2"; shift 2 ;;
          *) echo "Unknown option: $1" >&2; exit 2 ;;
        esac
      done
      if [[ -n "$preset" ]]; then
        # Allow lookup by index or name
        if [[ -f "$CONFIG_JSON" ]]; then
          mapfile -t names < <(jq -r '.iso_presets[]?.name' "$CONFIG_JSON")
          mapfile -t urls < <(jq -r '.iso_presets[]?.url' "$CONFIG_JSON")
          mapfile -t preset_checksum_urls < <(jq -r '.iso_presets[]? | (.checksum_urls // [.checksum_url]) | map(select(. != null and . != "")) | @sh' "$CONFIG_JSON")
          mapfile -t preset_signature_urls < <(jq -r '.iso_presets[]? | (.signature_urls // [.signature_url]) | map(select(. != null and . != "")) | @sh' "$CONFIG_JSON")
          mapfile -t preset_gpg_keys < <(jq -r '.iso_presets[]? | (.gpg_key_urls // [.gpg_key_url]) | map(select(. != null and . != "")) | @sh' "$CONFIG_JSON")
          idx=-1
          if [[ "$preset" =~ ^[0-9]+$ ]]; then idx="$preset"; else
            for i in "${!names[@]}"; do [[ "${names[$i]}" == "$preset" ]] && idx="$i" && break; done
          fi
          if (( idx >= 0 )) && [[ -n "${urls[$idx]:-}" ]]; then
            url="${urls[$idx]}"
            preset_checksum_list=$(eval echo ${preset_checksum_urls[$idx]:-})
            preset_signature_list=$(eval echo ${preset_signature_urls[$idx]:-})
            preset_gpg_key_list=$(eval echo ${preset_gpg_keys[$idx]:-})
          else
            echo "Invalid preset: $preset" >&2; exit 2
          fi
        else
          echo "Missing CONFIG_JSON: $CONFIG_JSON" >&2; exit 2
        fi
      fi
      # Try lists; pass first that works, handled inside download_iso_cli too
      if [[ -z "${checksum:-}" && -n "${preset_checksum_list:-}" ]]; then
        for preset_checksum_url in $preset_checksum_list; do
          if download_iso_cli "$url" "${checksum:-}" "$preset_checksum_url" "${preset_signature_list:-}" "${preset_gpg_key_list:-}"; then exit 0; fi
        done
        exit 1
      else
        download_iso_cli "$url" "${checksum:-}" "" "${preset_signature_list:-}" "${preset_gpg_key_list:-}"
      fi
      ;;
    *)
      echo "Usage: $0 --cli download --url <URL> [--checksum <SHA256>] [--preset <index|name>]" >&2
      exit 2
      ;;
  esac
  exit 0
fi

while true; do
  choice=$($DIALOG --menu "ISO Manager" 24 90 14 \
    1 "Download ISO (auto-checksum/signature/mirrors)" \
    2 "Validate ISO checksum" \
    3 "Import ISO from local path" \
    4 "Attach ISO to a VM profile" \
    5 "GPG: Import key" \
    6 "GPG: Verify ISO signature" \
    7 "List ISOs" \
    8 "Scan local storage for ISOs" \
    9 "Mount network share and scan" \
    10 "Help" \
    11 "Exit" \
    3>&1 1>&2 2>&3) || exit 0
  case "$choice" in
    1) download_iso ;;
    2) validate_iso ;;
    3) import_local_iso ;;
    4) attach_iso_to_profile ;;
    5) import_gpg_key ;;
    6) verify_gpg ;;
    7) list_isos | ${PAGER:-less} ;;
    8) scan_local_isos ;;
    9) mount_network_share_and_scan ;;
    10) $DIALOG --msgbox 'See documentation for help' 8 50 ;;
    11) exit 0 ;;
  esac
done
