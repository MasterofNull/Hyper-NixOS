#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
IFS=$'\n\t'
umask 077

ROOT="/etc/hypervisor"
CONFIG_JSON="$ROOT/config.json"
STATE_DIR="/var/lib/hypervisor"
TEMPLATE_PROFILES_DIR="$ROOT/vm_profiles"   # read-only templates
USER_PROFILES_DIR="$STATE_DIR/vm_profiles"  # user-created profiles
ISOS_DIR="$STATE_DIR/isos"                  # stateful ISO library
SCRIPTS_DIR="$ROOT/scripts"
LAST_VM_FILE="$STATE_DIR/last_vm"

: "${DIALOG:=whiptail}"
export DIALOG
# Allow LOG_DIR override via environment; prefer /var/lib for write access under sandboxed service
LOG_DIR="${LOG_DIR:-}"
LOG_FILE=""
AUTOSTART_SECS=5
LOG_ENABLED=true
if [[ -f "$CONFIG_JSON" ]]; then
  AUTOSTART_SECS=$(jq -r '.features.autostart_timeout_sec // 5' "$CONFIG_JSON" 2>/dev/null || echo 5)
  LOG_ENABLED=$(jq -r '.logging.enabled // true' "$CONFIG_JSON" 2>/dev/null || echo true)
  if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR=$(jq -r '.logging.dir // "/var/lib/hypervisor/logs"' "$CONFIG_JSON" 2>/dev/null || echo "/var/lib/hypervisor/logs")
  fi
fi
[[ -z "$LOG_DIR" ]] && LOG_DIR="/var/lib/hypervisor/logs"
LOG_FILE="$LOG_DIR/menu.log"
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

menu_vm_main() {
  local entries=()
  shopt -s nullglob
  for f in "$USER_PROFILES_DIR"/*.json; do
    local name
    name=$(jq -r '.name // empty' "$f" 2>/dev/null || true)
    [[ -z "$name" ]] && name=$(basename "$f")
    entries+=("$f" "VM: $name")
  done
  shopt -u nullglob
  entries+=("__GNOME__" "Start GNOME management session (fallback GUI)")
  entries+=("__MORE__" "More Options (setup, ISO, VFIO, tools)")
  entries+=("__UPDATE__" "Update Hypervisor (pin to latest)")
  entries+=("__TOGGLE_MENU_ON" "Enable menu at boot")
  entries+=("__TOGGLE_MENU_OFF" "Disable menu at boot")
  entries+=("__RUN_WIZARD__" "Run first-boot setup wizard now")
  entries+=("__TOGGLE_WIZARD_ON" "Enable first-boot wizard at boot")
  entries+=("__TOGGLE_WIZARD_OFF" "Disable first-boot wizard at boot")
  entries+=("__EXIT__" "Exit")
  $DIALOG --title "Hypervisor - VMs" --menu "Select a VM to start, or choose an action" 22 90 14 "${entries[@]}" 3>&1 1>&2 2>&3
}

menu_more() {
  local choices=(
    0 "Setup wizard (recommended)"
    1 "Create VM (wizard)"
    2 "ISO manager (download/validate/attach)"
    3 "Hardware detect & VFIO suggestions"
    4 "VFIO configure (bind & Nix)"
    5 "Define/Start from JSON"
    6 "Edit VM profile"
    7 "Delete VM"
    8 "Bridge helper"
    9 "Snapshots & backups"
    10 "Docs & Help"
    11 "Preflight check"
    12 "SSH setup (for migration)"
    13 "Live migration"
    14 "Detect & adjust (devices/security)"
    15 "Quick-start last VM"
    16 "Back"
  )
  $DIALOG --title "Hypervisor - More Options" --menu "Choose an option" 22 90 14 "${choices[@]}" 3>&1 1>&2 2>&3
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
  "$SCRIPTS_DIR/iso_manager.sh" "$ISOS_DIR" "$USER_PROFILES_DIR" || true
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

autostart_countdown

while true; do
  choice=$(menu_vm_main || true)
  case "$choice" in
    "__GNOME__")
      if systemctl is-enabled gdm.service >/dev/null 2>&1; then
        $DIALOG --msgbox "Starting GNOME (graphical target for this session)." 10 70
        sudo systemctl start gdm.service || $DIALOG --msgbox "Failed to start GDM" 8 50
        sudo systemctl isolate graphical.target || true
      else
        $DIALOG --yesno "GDM is not enabled. Enable and start GNOME now?" 10 70 && {
          sudo systemctl enable gdm.service || true
          sudo systemctl start gdm.service || $DIALOG --msgbox "Failed to start GDM" 8 50
          sudo systemctl isolate graphical.target || true
        }
      fi
      ;;
    "__MORE__")
      while true; do
        mchoice=$(menu_more || true)
        case "$mchoice" in
          0) "$SCRIPTS_DIR/setup_wizard.sh" || true;;
          1) create_vm_wizard || true;;
          2) iso_manager || true;;
          3) "$SCRIPTS_DIR/hardware_detect.sh" | ${PAGER:-less};;
          4) "$SCRIPTS_DIR/vfio_workflow.sh" || true;;
          5) p=$(select_profile || true) || continue; "$SCRIPTS_DIR/validate_profile.sh" "$p" || true; "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$p" || true;;
          6) p=$(select_profile || true) || continue; edit_profile "$p";;
          7) p=$(select_profile || true) || continue; delete_vm "$p";;
          8) "$SCRIPTS_DIR/bridge_helper.sh" || true;;
          9) "$SCRIPTS_DIR/snapshots_backups.sh" || true;;
          10) "$SCRIPTS_DIR/docs_viewer.sh" || true;;
          11) "$SCRIPTS_DIR/preflight_check.sh" || true;;
          12) "$SCRIPTS_DIR/ssh_setup.sh" || true;;
          13) "$SCRIPTS_DIR/migrate_vm.sh" || true;;
          14) "$SCRIPTS_DIR/detect_and_adjust.sh" || true;;
          15) p=$(quick_start_last || true) || { $DIALOG --msgbox "No previous VM" 8 40; continue; }; start_vm "$p" || true;;
          16|*) break;;
        esac
      done
      ;;
    "__UPDATE__")
      if sudo bash /etc/hypervisor/scripts/update_hypervisor.sh; then
        $DIALOG --msgbox "Hypervisor pinned to latest and system rebuilt." 10 70
      else
        $DIALOG --msgbox "Update failed. See logs." 8 50
      fi
      ;;
    "__TOGGLE_MENU_ON")
      sudo bash /etc/hypervisor/scripts/toggle_boot_features.sh menu on && $DIALOG --msgbox "Menu will start at boot." 8 40 || $DIALOG --msgbox "Failed to toggle." 8 40
      ;;
    "__TOGGLE_MENU_OFF")
      sudo bash /etc/hypervisor/scripts/toggle_boot_features.sh menu off && $DIALOG --msgbox "Menu disabled at boot." 8 40 || $DIALOG --msgbox "Failed to toggle." 8 40
      ;;
    "__RUN_WIZARD__")
      sudo ${SHELL:-/bin/bash} -lc '/etc/hypervisor/scripts/setup_wizard.sh' || true
      ;;
    "__TOGGLE_WIZARD_ON")
      sudo bash /etc/hypervisor/scripts/toggle_boot_features.sh wizard on && $DIALOG --msgbox "First-boot wizard enabled." 8 50 || $DIALOG --msgbox "Failed to toggle." 8 50
      ;;
    "__TOGGLE_WIZARD_OFF")
      sudo bash /etc/hypervisor/scripts/toggle_boot_features.sh wizard off && $DIALOG --msgbox "First-boot wizard disabled." 8 50 || $DIALOG --msgbox "Failed to toggle." 8 50
      ;;
    "__EXIT__"|*)
      # If the selection is a file path to a VM profile, start it then return to menu
      if [[ -n "$choice" && -f "$choice" ]]; then
        start_vm "$choice" || true
      fi
      # Return to main loop; let user explicitly exit via TTY
      ;;
  esac
done
