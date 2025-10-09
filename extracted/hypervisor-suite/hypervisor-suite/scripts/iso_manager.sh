#!/usr/bin/env bash
set -euo pipefail

ISOS_DIR="${1:-/etc/hypervisor/isos}"
: "${DIALOG:=whiptail}"

require() {
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing: $bin" >&2; exit 1; }
  done
}
require "$DIALOG" curl sha256sum

mkdir -p "$ISOS_DIR"

download_iso() {
  local url checksum filename tmp
  url=$($DIALOG --inputbox "ISO URL" 10 70 3>&1 1>&2 2>&3) || return 1
  checksum=$($DIALOG --inputbox "Expected SHA256 (optional)" 10 70 3>&1 1>&2 2>&3 || true)
  filename=$(basename "$url")
  tmp="$ISOS_DIR/.partial-$filename"
  curl -L -C - "$url" -o "$tmp"
  mv "$tmp" "$ISOS_DIR/$filename"
  if [[ -n "${checksum:-}" ]]; then
    echo "$checksum  $ISOS_DIR/$filename" | sha256sum -c - || {
      $DIALOG --msgbox "Checksum FAILED" 8 40
      return 1
    }
  fi
  $DIALOG --msgbox "Downloaded: $filename" 8 50
}

validate_iso() {
  local path checksum
  path=$($DIALOG --inputbox "Path to ISO" 10 70 "$ISOS_DIR/" 3>&1 1>&2 2>&3) || return 1
  checksum=$($DIALOG --inputbox "Expected SHA256" 10 70 3>&1 1>&2 2>&3) || return 1
  echo "$checksum  $path" | sha256sum -c - && $DIALOG --msgbox "Checksum OK" 8 30 || $DIALOG --msgbox "Checksum FAILED" 8 40
}

list_isos() {
  ls -1 "$ISOS_DIR"/*.iso 2>/dev/null || true
}

while true; do
  choice=$($DIALOG --menu "ISO Manager" 20 70 10 \
    1 "Download ISO (URL + optional SHA256)" \
    2 "Validate ISO checksum" \
    3 "List ISOs" \
    4 "Exit" 3>&1 1>&2 2>&3) || exit 0
  case "$choice" in
    1) download_iso ;;
    2) validate_iso ;;
    3) list_isos | ${PAGER:-less} ;;
    4) exit 0 ;;
  esac
done
