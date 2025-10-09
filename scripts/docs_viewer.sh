#!/usr/bin/env bash
set -euo pipefail
: "${DIALOG:=whiptail}"

DOCS_DIR="/etc/hypervisor/docs"

require() { for b in $DIALOG; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

if [[ ! -d "$DOCS_DIR" ]]; then
  $DIALOG --msgbox "No docs directory at $DOCS_DIR" 8 50
  exit 0
fi

choose_doc() {
  local entries=()
  shopt -s nullglob
  for f in "$DOCS_DIR"/*; do
    [[ -f "$f" ]] || continue
    entries+=("$f" " ")
  done
  shopt -u nullglob
  if (( ${#entries[@]} == 0 )); then
    $DIALOG --msgbox "No documentation files found" 8 50
    return 1
  fi
  $DIALOG --menu "Select a document" 20 80 12 "${entries[@]}" 3>&1 1>&2 2>&3
}

while true; do
  doc=$(choose_doc || true) || exit 0
  [[ -z "${doc:-}" ]] && exit 0
  $DIALOG --title "$(basename "$doc")" --textbox "$doc" 25 100
  # Ask to view another
  $DIALOG --yesno "View another document?" 8 40 || exit 0
done
