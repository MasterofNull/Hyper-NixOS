#!/usr/bin/env bash
#
# Hyper-NixOS Main Menu
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Boot-time console menu for VM management, ISO downloads, system tools.
# Runs with restricted permissions for security (polkit-based access control).
#
# Repository: https://github.com/MasterofNull/Hyper-NixOS
#

# Source common library for shared functions and security
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}

# Initialize logging for this script
init_logging "menu"

# Script-specific configuration
readonly ROOT="/etc/hypervisor"
readonly TEMPLATE_PROFILES_DIR="$ROOT/vm_profiles"
readonly USER_PROFILES_DIR="$HYPERVISOR_PROFILES"
readonly ISOS_DIR="$HYPERVISOR_ISOS"
readonly SCRIPTS_DIR="$HYPERVISOR_SCRIPTS"
readonly LAST_VM_FILE="$HYPERVISOR_STATE/last_vm"
readonly OWNER_FILTER_FILE="$HYPERVISOR_STATE/owner_filter"
readonly BRANDING="$HYPERVISOR_BRANDING"

# Load menu-specific configuration
AUTOSTART_SECS=$(json_get "$HYPERVISOR_CONFIG" ".features.autostart_timeout_sec" "5")
BOOT_SELECTOR_ENABLE=$(json_get "$HYPERVISOR_CONFIG" ".features.boot_selector_enable" "false")
BOOT_SELECTOR_TIMEOUT=$(json_get "$HYPERVISOR_CONFIG" ".features.boot_selector_timeout_sec" "8")
BOOT_SELECTOR_EXIT_AFTER_START=$(json_get "$HYPERVISOR_CONFIG" ".features.boot_selector_exit_after_start" "true")

# Load owner filter if available
if [[ -z "${OWNER_FILTER:-}" && -f "$OWNER_FILTER_FILE" ]]; then
  OWNER_FILTER=$(cat "$OWNER_FILTER_FILE" 2>/dev/null || true)
  export OWNER_FILTER
fi

# Additional dependencies for menu
require curl sha256sum

# Ensure required directories exist
mkdir -p "$USER_PROFILES_DIR" "$ISOS_DIR"

log_info "Menu started"

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
  entries+=("__VM_SELECTOR__" "← Back to VM Boot Selector")
  entries+=("" "")
  entries+=("__VM_OPS__" "VM Operations →")
  entries+=("__SYS_CONFIG__" "System Configuration → [sudo]")
  entries+=("__ADMIN__" "🔧 Admin Management Environment → (full access)")
  entries+=("" "")
  local donate_enabled
  donate_enabled=$(json_get "$HYPERVISOR_CONFIG" ".donate.enable" "true")
  if [[ "$donate_enabled" == "true" || "$donate_enabled" == "True" ]]; then
    entries+=("__DONATE__" "❤ Support development (donate)")
  fi
  entries+=("" "")
  if [[ -n "$owner_filter" ]]; then
    entries+=("__CLEAR_OWNER_FILTER__" "Show all owners (clear filter)")
  else
    entries+=("__SET_OWNER_FILTER__" "Filter by owner…")
  fi
  entries+=("" "")
  entries+=("__DESKTOP__" "Start GUI Desktop session [sudo]")
  entries+=("__EXIT__" "Exit")
  $DIALOG --title "$BRANDING - Main Menu" --menu "Select a VM to start, or choose an action" 22 90 14 "${entries[@]}" 3>&1 1>&2 2>&3
}

menu_vm_operations() {
  local choices=(
    0 "🚀 Install VMs - Complete guided workflow (RECOMMENDED)"
    1 "Create VM wizard"
    2 "Edit VM profile"
    3 "Delete VM"
    4 "Define/Start VM from JSON"
    5 "Validate VM profile"
    "" ""
    10 "ISO manager (download/verify ISOs)"
    11 "Cloud image manager (cloud-init images)"
    "" ""
    20 "Snapshots & backups"
    21 "Clone/Template manager"
    22 "Resource optimizer"
    23 "Bulk operations (manage multiple VMs)"
    "" ""
    30 "Metrics & Health diagnostics"
    31 "Health checks"
    32 "View logs"
    33 "VM Dashboard (real-time status)"
    "" ""
    40 "Hardware detect & VFIO suggestions"
    41 "SPICE/VNC launcher"
    42 "Guest agent actions"
    "" ""
    99 "← Back to Main Menu"
  )
  $DIALOG --title "$BRANDING - VM Operations" --menu "VM setup and management (no sudo required)" 24 80 16 "${choices[@]}" 3>&1 1>&2 2>&3
}

menu_system_config() {
  local choices=(
    1 "Network foundation setup [sudo]"
    2 "Bridge helper [sudo]"
    3 "Network helper (firewall & DHCP) [sudo]"
    4 "Zone manager (bridges & base rules) [sudo]"
    5 "SSH setup (for migration) [sudo]"
    "" ""
    10 "VFIO configure (bind & Nix) [sudo]"
    11 "Per-VM firewall (inbound rules) [sudo]"
    "" ""
    20 "Update Hypervisor (pin latest) [sudo]"
    21 "Security audit [sudo]"
    22 "Preflight check [sudo]"
    23 "System diagnostics [sudo]"
    24 "Detect & adjust (devices/security) [sudo]"
    "" ""
    30 "Docs & Help"
    31 "Interactive Tutorial"
    32 "Help & Learning Center"
    33 "Guided System Testing"
    34 "Guided Metrics Viewer"
    35 "Guided Backup Verification"
    "" ""
    99 "← Back to Main Menu"
  )
  $DIALOG --title "$BRANDING - System Configuration" --menu "System-level configuration (requires sudo)" 24 80 16 "${choices[@]}" 3>&1 1>&2 2>&3
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
  $DIALOG --title "$BRANDING - Select VM" --menu "VM Profiles" 22 90 12 "${entries[@]}" 3>&1 1>&2 2>&3
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

launch_console() {
  local domain="$1"
  
  # Check if VM is running
  if ! virsh domstate "$domain" 2>/dev/null | grep -q "running"; then
    $DIALOG --yesno "VM '$domain' is not running.\n\nStart it now?" 10 50
    if [[ $? -eq 0 ]]; then
      virsh start "$domain" 2>&1 | grep -v "^$" || true
      sleep 3
    else
      return 1
    fi
  fi
  
  # Get display URI
  local uri
  uri=$(virsh domdisplay "$domain" 2>/dev/null || echo "")
  
  if [[ -z "$uri" ]]; then
    $DIALOG --msgbox "Error: No display available for VM '$domain'\n\nEnsure VM has graphics enabled in profile." 10 60
    return 1
  fi
  
  # Check if remote-viewer is available
  if ! command -v remote-viewer >/dev/null 2>&1; then
    $DIALOG --msgbox "Error: remote-viewer not found\n\nInstall with:\n  nix-env -iA nixpkgs.virt-viewer" 10 60
    return 1
  fi
  
  # Launch viewer in background
  log "Launching console for $domain (URI: $uri)"
  nohup remote-viewer "$uri" >/dev/null 2>&1 &
  
  $DIALOG --msgbox "Console viewer launched for '$domain'\n\nURI: $uri" 10 60
}

vm_action_menu() {
  local profile_json="$1"
  local name
  name=$(jq -r '.name // empty' "$profile_json" 2>/dev/null || basename "$profile_json" .json)
  
  while true; do
    # Check VM state
    local state="unknown"
    if command -v virsh >/dev/null 2>&1; then
      state=$(virsh domstate "$name" 2>/dev/null || echo "undefined")
    fi
    
    local action
    action=$($DIALOG --title "VM: $name" --menu "Status: $state\nChoose action:" 18 70 9 \
      "1" "Start/Resume VM" \
      "2" "Launch Console (SPICE/VNC)" \
      "3" "View VM Status" \
      "4" "Edit Profile" \
      "5" "Stop VM" \
      "6" "Force Stop VM" \
      "7" "Delete VM" \
      "8" "Clone VM" \
      "9" "Back to Main Menu" \
      3>&1 1>&2 2>&3 || echo "9")
    
    case "$action" in
      1)
        start_vm "$profile_json" || true
        ;;
      2)
        launch_console "$name" || true
        ;;
      3)
        local info
        info=$(virsh dominfo "$name" 2>&1 || echo "VM not defined")
        $DIALOG --title "VM Status: $name" --msgbox "$info" 20 70
        ;;
      4)
        edit_profile "$profile_json"
        ;;
      5)
        if virsh shutdown "$name" 2>&1; then
          $DIALOG --msgbox "Shutdown signal sent to '$name'" 8 50
        else
          $DIALOG --msgbox "Failed to shutdown '$name'" 8 50
        fi
        ;;
      6)
        if virsh destroy "$name" 2>&1; then
          $DIALOG --msgbox "VM '$name' force stopped" 8 50
        else
          $DIALOG --msgbox "Failed to stop '$name'" 8 50
        fi
        ;;
      7)
        if $DIALOG --yesno "Delete VM '$name'?\n\nThis will:\n- Stop the VM\n- Remove from libvirt\n- Delete storage\n- Keep profile: $profile_json\n\nContinue?" 14 60; then
          delete_vm "$profile_json"
          $DIALOG --msgbox "VM '$name' deleted" 8 50
          break
        fi
        ;;
      8)
        local new_name
        new_name=$($DIALOG --inputbox "New VM name:" 10 60 "${name}-clone" 3>&1 1>&2 2>&3 || echo "")
        if [[ -n "$new_name" ]]; then
          local new_profile="$USER_PROFILES_DIR/${new_name}.json"
          if [[ -f "$new_profile" ]]; then
            $DIALOG --msgbox "Profile already exists: $new_profile" 8 60
          else
            jq --arg newname "$new_name" '.name = $newname' "$profile_json" > "$new_profile"
            $DIALOG --msgbox "Cloned to: $new_profile\n\nNote: Disk will be created on first start" 10 60
          fi
        fi
        ;;
      9|*)
        break
        ;;
    esac
  done
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
  choice=$($DIALOG --title "$BRANDING - Boot Selector" \
    --menu "Select a VM to start (timeout ${BOOT_SELECTOR_TIMEOUT}s). Default: ${default_base}" \
    22 90 14 "${entries[@]}" --timeout "$BOOT_SELECTOR_TIMEOUT" 3>&1 1>&2 2>&3 || true)

  if [[ -z "$choice" ]]; then
    # Timed out or canceled: start autostart set by priority
    local delay_ms sleep_secs
    delay_ms=$(jq -r '.features.boot_autostart_delay_ms // 1500' "$HYPERVISOR_CONFIG" 2>/dev/null || echo 1500)
    local autolist prio path group groups_order delay_group_ms last_group=""
    delay_group_ms=$(jq -r '.features.boot_autostart_delay_between_groups_ms // 2500' "$HYPERVISOR_CONFIG" 2>/dev/null || echo 2500)
    mapfile -t groups_order < <(jq -r '.features.boot_autostart_groups_order[]? // empty' "$HYPERVISOR_CONFIG" 2>/dev/null || true)
    autolist=$(for f in "$USER_PROFILES_DIR"/*.json; do [[ -f "$f" ]] || continue; a=$(jq -r '.autostart // false' "$f" 2>/dev/null || echo false); [[ "$a" == true || "$a" == True ]] || continue; p=$(jq -r '.autostart_priority // 50' "$f" 2>/dev/null || echo 50); g=$(jq -r '.autostart_group // ""' "$f" 2>/dev/null || echo ""); printf '%s\t%03d\t%s\n' "$g" "$p" "$f"; done | sort -t $'\t' -k1,1 -k2,2n)
    if (( ${#groups_order[@]} )); then
      # reorder autolist by groups_order
      tmp=""
      for g in "${groups_order[@]}"; do
        tmp+=$(printf '%s\n' "$autolist" | awk -F '\t' -v gg="$g" '$1==gg')$'\n'
      done
      tmp+=$(printf '%s\n' "$autolist" | awk -F '\t' 'BEGIN{OFS="\t"} NR==FNR{a[$0];next} !($1 in a){print $0}' <(printf '%s\n' "${groups_order[@]}") -)
      autolist="$tmp"
    fi
    while IFS=$'\t' read -r group prio path; do
      [[ -z "$path" || ! -f "$path" ]] && continue
      if [[ -n "$last_group" && "$group" != "$last_group" ]]; then
        sleep_secs=$(awk -v ms="$delay_group_ms" 'BEGIN{printf("%0.3f", ms/1000)}')
        sleep "$sleep_secs"
      fi
      start_vm "$path" || true
      sleep_secs=$(awk -v ms="$delay_ms" 'BEGIN{printf("%0.3f", ms/1000)}')
      sleep "$sleep_secs"
      last_group="$group"
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
    "__VM_SELECTOR__")
      # Re-enter the built-in boot selector
      boot_vm_selector || true
      ;;
    "__ADMIN__")
      exec "$SCRIPTS_DIR/admin_menu.sh"
      ;;
    "__DONATE__")
      "$SCRIPTS_DIR/donate.sh" || true
      ;;
    "__DESKTOP__")
      if systemctl is-enabled display-manager.service >/dev/null 2>&1; then
        $DIALOG --msgbox "Starting GUI Desktop (graphical target for this session)." 10 70
        sudo systemctl start display-manager.service || $DIALOG --msgbox "Failed to start Display Manager" 8 50
        sudo systemctl isolate graphical.target || true
      else
        $DIALOG --yesno "Display Manager is not enabled. Start GUI Desktop for this session?" 10 70 && {
          sudo systemctl start display-manager.service || $DIALOG --msgbox "Failed to start Display Manager" 8 50
          sudo systemctl isolate graphical.target || true
        }
      fi
      ;;
    "__MORE__")
      while true; do
        mchoice=$(menu_more || true)
        case "$mchoice" in
          0) "$SCRIPTS_DIR/install_vm_workflow.sh" || true;;
          1) create_vm_wizard || true;;
          2) iso_manager || true;;
          3) "$SCRIPTS_DIR/image_manager.sh" || true;;
          4) "$SCRIPTS_DIR/hardware_detect.sh" | ${PAGER:-less};;
          5) "$SCRIPTS_DIR/vfio_workflow.sh" || true;;
          6) p=$(select_profile || true) || continue; "$SCRIPTS_DIR/validate_profile.sh" "$p" || true; "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$p" || true;;
          7) p=$(select_profile || true) || continue; edit_profile "$p";;
          8) p=$(select_profile || true) || continue; delete_vm "$p";;
          9) "$SCRIPTS_DIR/bridge_helper.sh" || true;;
          10) "$SCRIPTS_DIR/network_helper.sh" || true;;
          11) "$SCRIPTS_DIR/zone_manager.sh" || true;;
          12) "$SCRIPTS_DIR/snapshots_backups.sh" || true;;
          13) "$SCRIPTS_DIR/per_vm_firewall.sh" || true;;
          14) "$SCRIPTS_DIR/spice_vnc_launcher.sh" || true;;
          15) "$SCRIPTS_DIR/guest_agent_actions.sh" || true;;
          16) "$SCRIPTS_DIR/template_clone_manager.sh" || true;;
          17) "$SCRIPTS_DIR/metrics_health.sh" || true;;
          18) "$SCRIPTS_DIR/enhanced_health_checks.sh" || true;;
          19) "$SCRIPTS_DIR/vm_resource_optimizer.sh" || true;;
          20) "$SCRIPTS_DIR/docs_viewer.sh" || true;;
          21) "$SCRIPTS_DIR/health_checks.sh" || true;;
          22) "$SCRIPTS_DIR/preflight_check.sh" || true;;
          23) "$SCRIPTS_DIR/ssh_setup.sh" || true;;
          24) "$SCRIPTS_DIR/migrate_vm.sh" || true;;
          25) "$SCRIPTS_DIR/detect_and_adjust.sh" || true;;
          26) p=$(quick_start_last || true) || { $DIALOG --msgbox "No previous VM" 8 40; continue; }; start_vm "$p" || true;;
          27) "$SCRIPTS_DIR/diagnose.sh" | ${PAGER:-less};;
          28) "$SCRIPTS_DIR/vm_dashboard.sh" || true;;
          29) "$SCRIPTS_DIR/bulk_operations.sh" || true;;
          30) "$SCRIPTS_DIR/help_assistant.sh" || true;;
          31) "$SCRIPTS_DIR/interactive_tutorial.sh" || true;;
          32) "$SCRIPTS_DIR/guided_system_test.sh" || true;;
          33) "$SCRIPTS_DIR/guided_metrics_viewer.sh" || true;;
          34) "$SCRIPTS_DIR/guided_backup_verification.sh" || true;;
          35|*) break;;
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
    "__EXIT__"|*)
      # If the selection is a file path to a VM profile, show action menu
      if [[ -n "$choice" && -f "$choice" ]]; then
        vm_action_menu "$choice" || true
      fi
      # Return to main loop; let user explicitly exit via TTY
      ;;
  esac
done
