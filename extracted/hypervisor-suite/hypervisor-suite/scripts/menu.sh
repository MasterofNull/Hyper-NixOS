#!/usr/bin/env bash
set -euo pipefail

ROOT="/etc/hypervisor"
STATE_DIR="/var/lib/hypervisor"
PROFILES_DIR="$ROOT/vm_profiles"
ISOS_DIR="$ROOT/isos"
SCRIPTS_DIR="$ROOT/scripts"
LAST_VM_FILE="$STATE_DIR/last_vm"

: "${DIALOG:=whiptail}"

require() {
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || {
      echo "Missing dependency: $bin" >&2
      exit 1
    }
  done
}

require "$DIALOG" jq curl virsh sha256sum

menu_main() {
  local choices=(
    1 "Start VM"
    2 "Quick-start last VM"
    3 "ISO manager (download/validate)"
    4 "Create VM from JSON (define/start)"
    5 "Edit VM profile"
    6 "Delete VM"
    7 "Exit"
  )
  $DIALOG --title "Hypervisor Menu" --menu "Choose an option" 20 78 10 "${choices[@]}" 3>&1 1>&2 2>&3
}

select_profile() {
  local profiles=()
  shopt -s nullglob
  for f in "$PROFILES_DIR"/*.json; do
    profiles+=("$(basename "$f")" "-")
  done
  shopt -u nullglob
  if (( ${#profiles[@]} == 0 )); then
    $DIALOG --msgbox "No VM profiles found in $PROFILES_DIR" 10 60
    return 1
  fi
  $DIALOG --title "Select VM" --menu "VM Profiles" 20 78 10 "${profiles[@]}" 3>&1 1>&2 2>&3
}

quick_start_last() {
  if [[ -f "$LAST_VM_FILE" ]]; then
    cat "$LAST_VM_FILE"
  else
    return 1
  fi
}

start_vm() {
  local profile_json="$1"
  echo "$(basename "$profile_json")" > "$LAST_VM_FILE"
  "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$profile_json" || {
    $DIALOG --msgbox "Failed to start VM." 8 50
    return 1
  }
}

iso_manager() {
  "$SCRIPTS_DIR/iso_manager.sh" "$ISOS_DIR"
}

edit_profile() {
  local file="$1"
  ${EDITOR:-nano} "$file"
}

delete_vm() {
  local profile_json="$1"
  local name
  name=$(jq -r .name "$profile_json")
  virsh destroy "$name" >/dev/null 2>&1 || true
  virsh undefine "$name" --remove-all-storage >/dev/null 2>&1 || true
}

while true; do
  choice=$(menu_main || true)
  case "$choice" in
    1)
      p=$(select_profile || true) || continue
      start_vm "$PROFILES_DIR/$p" || true
      ;;
    2)
      p=$(quick_start_last || true) || { $DIALOG --msgbox "No previous VM" 8 40; continue; }
      start_vm "$PROFILES_DIR/$p" || true
      ;;
    3)
      iso_manager || true
      ;;
    4)
      p=$(select_profile || true) || continue
      "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$PROFILES_DIR/$p" || true
      ;;
    5)
      p=$(select_profile || true) || continue
      edit_profile "$PROFILES_DIR/$p"
      ;;
    6)
      p=$(select_profile || true) || continue
      delete_vm "$PROFILES_DIR/$p"
      ;;
    7|*)
      exit 0
      ;;
  esac
done
