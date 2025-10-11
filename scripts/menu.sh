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
OWNER_FILTER_FILE="$STATE_DIR/owner_filter"

: "${DIALOG:=whiptail}"
export DIALOG
# Allow LOG_DIR override via environment; prefer /var/lib for write access under sandboxed service
LOG_DIR="${LOG_DIR:-}"
LOG_FILE=""
AUTOSTART_SECS=5
LOG_ENABLED=true
BOOT_SELECTOR_ENABLE=false
BOOT_SELECTOR_TIMEOUT=8
BOOT_SELECTOR_EXIT_AFTER_START=true
if [[ -f "$CONFIG_JSON" ]]; then
  AUTOSTART_SECS=$(jq -r '.features.autostart_timeout_sec // 5' "$CONFIG_JSON" 2>/dev/null || echo 5)
  LOG_ENABLED=$(jq -r '.logging.enabled // true' "$CONFIG_JSON" 2>/dev/null || echo true)
  if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR=$(jq -r '.logging.dir // "/var/lib/hypervisor/logs"' "$CONFIG_JSON" 2>/dev/null || echo "/var/lib/hypervisor/logs")
  fi
  BOOT_SELECTOR_ENABLE=$(jq -r '.features.boot_selector_enable // false' "$CONFIG_JSON" 2>/dev/null || echo false)
  BOOT_SELECTOR_TIMEOUT=$(jq -r '.features.boot_selector_timeout_sec // 8' "$CONFIG_JSON" 2>/dev/null || echo 8)
  BOOT_SELECTOR_EXIT_AFTER_START=$(jq -r '.features.boot_selector_exit_after_start // true' "$CONFIG_JSON" 2>/dev/null || echo true)
fi
if [[ -z "${OWNER_FILTER:-}" && -f "$OWNER_FILTER_FILE" ]]; then
  OWNER_FILTER=$(cat "$OWNER_FILTER_FILE" 2>/dev/null || true)
  export OWNER_FILTER
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
  local owner_filter="${OWNER_FILTER:-}"
  shopt -s nullglob
  for f in "$USER_PROFILES_DIR"/*.json; do
    local name
    name=$(jq -r '.name // empty' "$f" 2>/dev/null || true)
    [[ -z "$name" ]] && name=$(basename "$f")
    local owner
    owner=$(jq -r '.owner // empty' "$f" 2>/dev/null || true)
    if [[ -n "$owner_filter" && "$owner" != "$owner_filter" ]]; then
      continue
    fi
    if [[ -n "$owner" && "$owner" != "null" ]]; then
      entries+=("$f" "VM: $name (owner: $owner)")
    else
      entries+=("$f" "VM: $name")
    fi
  done
  shopt -u nullglob
  entries+=("__GNOME__" "Start GNOME management session (fallback GUI)")
  entries+=("__MORE__" "More Options (setup, ISO, VFIO, tools)")
  entries+=("__UPDATE__" "Update Hypervisor (pin to latest)")
  if [[ -n "$owner_filter" ]]; then
    entries+=("__CLEAR_OWNER_FILTER__" "Show all owners (clear filter)")
  else
    entries+=("__SET_OWNER_FILTER__" "Filter by owner…")
  fi
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
    2 "VM setup workflow (guided end-to-end)"
    3 "ISO manager (download/validate/attach)"
    4 "Cloud image manager (cloud-init images)"
    5 "Hardware detect & VFIO suggestions"
    6 "VFIO configure (bind & Nix)"
    7 "Define/Start from JSON"
    8 "Edit VM profile"
    9 "Delete VM"
    10 "Bridge helper"
    11 "Zone manager (bridges & base rules)"
    12 "Snapshots & backups"
    13 "Docs & Help"
    14 "Preflight check"
    15 "SSH setup (for migration)"
    16 "Live migration"
    17 "Detect & adjust (devices/security)"
    18 "Quick-start last VM"
    19 "Back"
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

# Boot-time VM selector with timeout, similar to a bootloader menu
boot_vm_selector() {
  # Build menu entries from user profiles and include a maintenance option
  local entries=("__MAINTENANCE__" "Maintenance (skip autostart)" "__SELECT_MULTI__" "Select multiple VMs…")
  shopt -s nullglob
  local first=""; local default_profile=""; local last=""; local f
  [[ -f "$LAST_VM_FILE" ]] && last=$(cat "$LAST_VM_FILE" 2>/dev/null || true)
  for f in "$USER_PROFILES_DIR"/*.json; do
    local name; name=$(jq -r '.name // empty' "$f" 2>/dev/null || true)
    [[ -z "$name" ]] && name=$(basename "$f")
    entries+=("$f" "VM: $name")
    [[ -z "$first" ]] && first="$f"
  done
  shopt -u nullglob
  (( ${#entries[@]} <= 2 )) && return 0  # no VMs present

  # Determine default profile: prefer last, else first
  if [[ -n "$last" && -f "$last" ]]; then default_profile="$last"; else default_profile="$first"; fi

  # Show one-shot menu with timeout; on timeout, autostart default_profile
  local choice default_base
  default_base=$(basename -- "$default_profile")
  choice=$($DIALOG --title "Hypervisor - Select VM to Boot" \
    --menu "Select a VM to start (timeout ${BOOT_SELECTOR_TIMEOUT}s). Default: ${default_base}" \
    22 90 14 "${entries[@]}" --timeout "$BOOT_SELECTOR_TIMEOUT" 3>&1 1>&2 2>&3 || true)

  if [[ -z "$choice" ]]; then
    # Timed out or canceled: start autostart set by priority
    local delay_ms sleep_secs
    delay_ms=$(jq -r '.features.boot_autostart_delay_ms // 1500' "$CONFIG_JSON" 2>/dev/null || echo 1500)
    local autolist prio path
    autolist=$(for f in "$USER_PROFILES_DIR"/*.json; do [[ -f "$f" ]] || continue; a=$(jq -r '.autostart // false' "$f" 2>/dev/null || echo false); [[ "$a" == true || "$a" == True ]] || continue; p=$(jq -r '.autostart_priority // 50' "$f" 2>/dev/null || echo 50); printf '%03d\t%s\n' "$p" "$f"; done | sort -n)
    while IFS=$'\t' read -r prio path; do
      [[ -z "$path" || ! -f "$path" ]] && continue
      start_vm "$path" || true
      sleep_secs=$(awk -v ms="$delay_ms" 'BEGIN{printf("%0.3f", ms/1000)}')
      sleep "$sleep_secs"
    done <<< "$autolist"
    $BOOT_SELECTOR_EXIT_AFTER_START && exit 0 || return 0
  fi

  if [[ "$choice" == "__SELECT_MULTI__" ]]; then
    # Build checklist
    local items=()
    for f in "$USER_PROFILES_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      local name; name=$(jq -r '.name // empty' "$f" 2>/dev/null || basename "$f")
      local on; on=$(jq -r '.autostart // false' "$f" 2>/dev/null || echo false)
      items+=("$f" "$name" $( [[ "$on" == true || "$on" == True ]] && echo on || echo off ))
    done
    sel=$($DIALOG --checklist "Select VMs to start" 22 90 14 "${items[@]}" 3>&1 1>&2 2>&3 || true)
    if [[ -n "$sel" ]]; then
      # whiptail returns space-separated quoted paths
      for p in $sel; do
        # strip quotes
        p=${p%\"}; p=${p#\"}
        [[ -f "$p" ]] && start_vm "$p" || true
      done
      $BOOT_SELECTOR_EXIT_AFTER_START && exit 0 || return 0
    fi
    return 0
  fi

  if [[ "$choice" == "__MAINTENANCE__" ]]; then
    # Stay in maintenance (no autostart); fall through to main menu
    return 0
  fi

  if [[ -f "$choice" ]]; then
    start_vm "$choice" || true
    $BOOT_SELECTOR_EXIT_AFTER_START && exit 0 || return 0
  fi
}

if [[ "$BOOT_SELECTOR_ENABLE" == "true" || "$BOOT_SELECTOR_ENABLE" == "True" ]]; then
  boot_vm_selector || true
else
  autostart_countdown
fi

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
          2) "$SCRIPTS_DIR/vm_setup_workflow.sh" || true;;
          3) iso_manager || true;;
          4) "$SCRIPTS_DIR/image_manager.sh" || true;;
          5) "$SCRIPTS_DIR/hardware_detect.sh" | ${PAGER:-less};;
          6) "$SCRIPTS_DIR/vfio_workflow.sh" || true;;
          7) p=$(select_profile || true) || continue; "$SCRIPTS_DIR/validate_profile.sh" "$p" || true; "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$p" || true;;
          8) p=$(select_profile || true) || continue; edit_profile "$p";;
          9) p=$(select_profile || true) || continue; delete_vm "$p";;
          10) "$SCRIPTS_DIR/bridge_helper.sh" || true;;
          11) "$SCRIPTS_DIR/zone_manager.sh" || true;;
          12) "$SCRIPTS_DIR/snapshots_backups.sh" || true;;
          13) "$SCRIPTS_DIR/docs_viewer.sh" || true;;
          14) "$SCRIPTS_DIR/preflight_check.sh" || true;;
          15) "$SCRIPTS_DIR/ssh_setup.sh" || true;;
          16) "$SCRIPTS_DIR/migrate_vm.sh" || true;;
          17) "$SCRIPTS_DIR/detect_and_adjust.sh" || true;;
          18) p=$(quick_start_last || true) || { $DIALOG --msgbox "No previous VM" 8 40; continue; }; start_vm "$p" || true;;
          19|*) break;;
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
    "__SET_OWNER_FILTER__")
      OWNER_FILTER=$($DIALOG --inputbox "Owner to show" 10 60 3>&1 1>&2 2>&3 || echo "")
      export OWNER_FILTER
      if [[ -n "$OWNER_FILTER" ]]; then echo "$OWNER_FILTER" > "$OWNER_FILTER_FILE"; fi
      ;;
    "__CLEAR_OWNER_FILTER__")
      unset OWNER_FILTER
      rm -f "$OWNER_FILTER_FILE"
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
