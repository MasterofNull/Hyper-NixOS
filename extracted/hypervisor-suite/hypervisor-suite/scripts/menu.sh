#!/usr/bin/env bash
set -euo pipefail

ROOT="/etc/hypervisor"
STATE_DIR="/var/lib/hypervisor"
TEMPLATE_PROFILES_DIR="$ROOT/vm_profiles"   # read-only templates
USER_PROFILES_DIR="$STATE_DIR/vm_profiles"  # user-created profiles
ISOS_DIR="$STATE_DIR/isos"                  # stateful ISO library
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

mkdir -p "$USER_PROFILES_DIR" "$ISOS_DIR"

menu_main() {
  local choices=(
    1 "Start VM"
    2 "Quick-start last VM"
    3 "Create VM (wizard)"
    4 "ISO manager (download/validate/attach)"
    5 "Define/Start from JSON"
    6 "Edit VM profile"
    7 "Delete VM"
    8 "Exit"
  )
  $DIALOG --title "Hypervisor Menu" --menu "Choose an option" 20 78 10 "${choices[@]}" 3>&1 1>&2 2>&3
}

select_profile() {
  local entries=()
  shopt -s nullglob
  for f in "$USER_PROFILES_DIR"/*.json; do
    entries+=("$f" "user")
  done
  for f in "$TEMPLATE_PROFILES_DIR"/*.json; do
    entries+=("$f" "template")
  done
  shopt -u nullglob
  if (( ${#entries[@]} == 0 )); then
    $DIALOG --msgbox "No VM profiles found in\n$USER_PROFILES_DIR or $TEMPLATE_PROFILES_DIR" 10 70
    return 1
  fi
  $DIALOG --title "Select VM" --menu "VM Profiles" 22 90 12 "${entries[@]}" 3>&1 1>&2 2>&3
}

quick_start_last() {
  [[ -f "$LAST_VM_FILE" ]] && cat "$LAST_VM_FILE" || return 1
}

start_vm() {
  local profile_json="$1"
  echo "$profile_json" > "$LAST_VM_FILE"
  "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$profile_json" || {
    $DIALOG --msgbox "Failed to start VM." 8 50
    return 1
  }
}

iso_manager() {
  "$SCRIPTS_DIR/iso_manager.sh" "$ISOS_DIR" "$USER_PROFILES_DIR"
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

create_vm_wizard() {
  "$SCRIPTS_DIR/create_vm_wizard.sh" "$USER_PROFILES_DIR" "$ISOS_DIR"
}

autostart_countdown() {
  local seconds="${1:-5}"
  local vm
  vm=$(quick_start_last || true) || return 0
  for ((i=seconds;i>0;i--)); do
    $DIALOG --infobox "Autostarting last VM in ${i}s:\n${vm}\nPress any key to cancel." 10 60
    read -r -t 1 -n 1 _key && return 0
  done
  start_vm "$vm" || true
}

autostart_countdown 5

while true; do
  choice=$(menu_main || true)
  case "$choice" in
    1)
      p=$(select_profile || true) || continue
      start_vm "$p" || true
      ;;
    2)
      p=$(quick_start_last || true) || { $DIALOG --msgbox "No previous VM" 8 40; continue; }
      start_vm "$p" || true
      ;;
    3)
      create_vm_wizard || true
      ;;
    4)
      iso_manager || true
      ;;
    5)
      p=$(select_profile || true) || continue
      "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$p" || true
      ;;
    6)
      p=$(select_profile || true) || continue
      edit_profile "$p"
      ;;
    7)
      p=$(select_profile || true) || continue
      delete_vm "$p"
      ;;
    8|*)
      exit 0
      ;;
  esac
done
