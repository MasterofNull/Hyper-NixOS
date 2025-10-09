#!/usr/bin/env bash
set -euo pipefail

ROOT="/etc/hypervisor"
CONFIG_JSON="$ROOT/config.json"
STATE_DIR="/var/lib/hypervisor"
TEMPLATE_PROFILES_DIR="$ROOT/vm_profiles"   # read-only templates
USER_PROFILES_DIR="$STATE_DIR/vm_profiles"  # user-created profiles
ISOS_DIR="$STATE_DIR/isos"                  # stateful ISO library
SCRIPTS_DIR="$ROOT/scripts"
LAST_VM_FILE="$STATE_DIR/last_vm"

: "${DIALOG:=whiptail}"
LOG_DIR="/var/log/hypervisor"
LOG_FILE="$LOG_DIR/menu.log"
AUTOSTART_SECS=5
LOG_ENABLED=true
if [[ -f "$CONFIG_JSON" ]]; then
  AUTOSTART_SECS=$(jq -r '.features.autostart_timeout_sec // 5' "$CONFIG_JSON" 2>/dev/null || echo 5)
  LOG_ENABLED=$(jq -r '.logging.enabled // true' "$CONFIG_JSON" 2>/dev/null || echo true)
  LOG_DIR=$(jq -r '.logging.dir // "/var/log/hypervisor"' "$CONFIG_JSON" 2>/dev/null || echo "/var/log/hypervisor")
  LOG_FILE="$LOG_DIR/menu.log"
fi
mkdir -p "$LOG_DIR"
log() { $LOG_ENABLED && printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG_FILE" || true; }

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
    0 "Setup wizard (recommended)"
    1 "Start VM"
    2 "Quick-start last VM"
    3 "Create VM (wizard)"
    4 "ISO manager (download/validate/attach)"
    5 "Hardware detect & VFIO suggestions"
    6 "VFIO configure (bind & Nix)"
    7 "Define/Start from JSON"
    8 "Edit VM profile"
    9 "Delete VM"
    10 "Bridge helper"
    11 "Snapshots & backups"
    12 "Docs & Help"
    13 "Exit"
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
  local seconds="${1:-$AUTOSTART_SECS}"
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
    0)
      "$SCRIPTS_DIR/setup_wizard.sh" || true
      ;;
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
      "$SCRIPTS_DIR/hardware_detect.sh" | ${PAGER:-less}
      ;;
    6)
      "$SCRIPTS_DIR/vfio_workflow.sh" || true
      ;;
    7)
      p=$(select_profile || true) || continue
      "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$p" || true
      ;;
    8)
      p=$(select_profile || true) || continue
      edit_profile "$p"
      ;;
    9)
      p=$(select_profile || true) || continue
      delete_vm "$p"
      ;;
    10)
      "$SCRIPTS_DIR/bridge_helper.sh" || true
      ;;
    11)
      "$SCRIPTS_DIR/snapshots_backups.sh" || true
      ;;
    12)
      "$SCRIPTS_DIR/docs_viewer.sh" || true
      ;;
    13|*)
      exit 0
      ;;
  esac
done
