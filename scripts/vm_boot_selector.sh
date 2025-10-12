#!/usr/bin/env bash
#
# VM Boot Selector - Shows VM list on boot with auto-select
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"
STATE_DIR="/var/lib/hypervisor"
USER_PROFILES_DIR="$STATE_DIR/vm_profiles"
LAST_VM_FILE="$STATE_DIR/last_vm"
CONFIG_JSON="/etc/hypervisor/config.json"
SCRIPTS_DIR="/etc/hypervisor/scripts"

# Default timeout for auto-selection
TIMEOUT_SECS=8

# Load timeout from config
if [[ -f "$CONFIG_JSON" ]]; then
  TIMEOUT_SECS=$(jq -r '.features.boot_selector_timeout_sec // 8' "$CONFIG_JSON" 2>/dev/null || echo 8)
fi

# Get list of VMs
get_vms() {
  local entries=()
  shopt -s nullglob
  for f in "$USER_PROFILES_DIR"/*.json; do
    local name
    name=$(jq -r '.name // empty' "$f" 2>/dev/null || true)
    [[ -z "$name" ]] && name=$(basename "$f" .json)
    entries+=("$f" "$name")
  done
  shopt -u nullglob
  printf '%s\n' "${entries[@]}"
}

# Get last selected VM
get_last_vm() {
  if [[ -f "$LAST_VM_FILE" ]]; then
    cat "$LAST_VM_FILE" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Save last selected VM
save_last_vm() {
  echo "$1" > "$LAST_VM_FILE"
}

# Main boot selector
main() {
  # Get VM list
  local vm_entries
  mapfile -t vm_entries < <(get_vms)
  
  # If no VMs, go directly to main menu
  if (( ${#vm_entries[@]} == 0 )); then
    exec "$SCRIPTS_DIR/menu.sh"
    exit 0
  fi
  
  # Build menu entries
  local menu_items=()
  local default_item=""
  local last_vm
  last_vm=$(get_last_vm)
  
  # Add VMs to menu
  for (( i=0; i<${#vm_entries[@]}; i+=2 )); do
    local vm_path="${vm_entries[i]}"
    local vm_name="${vm_entries[i+1]}"
    menu_items+=("$vm_path" "$vm_name")
    
    # Set default to last used VM
    if [[ "$vm_path" == "$last_vm" ]]; then
      default_item="$vm_path"
    fi
  done
  
  # If no default set, use first VM
  if [[ -z "$default_item" ]] && (( ${#menu_items[@]} > 0 )); then
    default_item="${menu_items[0]}"
  fi
  
  # Add "More Options" entry
  menu_items+=("__MORE__" "More Options (Setup, Tools, Configuration)")
  
  # Show menu with timeout
  local selection
  if [[ -n "$default_item" ]]; then
    selection=$($DIALOG --title "VM Boot Selector" \
      --menu "Select VM to start (auto-starts in ${TIMEOUT_SECS}s)

Last selected: $(basename "$default_item" .json)

VMs:" \
      22 76 14 \
      --default-item "$default_item" \
      --timeout "$TIMEOUT_SECS" \
      "${menu_items[@]}" 3>&1 1>&2 2>&3) || {
      # Timeout or cancel - use default if available
      if [[ -n "$default_item" && "$default_item" != "__MORE__" ]]; then
        selection="$default_item"
      else
        # If no default or default is More Options, go to main menu
        exec "$SCRIPTS_DIR/menu.sh"
        exit 0
      fi
    }
  else
    # No default, show menu without auto-select
    selection=$($DIALOG --title "VM Boot Selector" \
      --menu "Select VM to start

VMs:" \
      20 76 12 \
      "${menu_items[@]}" 3>&1 1>&2 2>&3) || {
      # Cancel - go to main menu
      exec "$SCRIPTS_DIR/menu.sh"
      exit 0
    }
  fi
  
  # Handle selection
  if [[ "$selection" == "__MORE__" ]]; then
    # Go to main menu
    exec "$SCRIPTS_DIR/menu.sh"
    exit 0
  else
    # Start selected VM
    save_last_vm "$selection"
    
    # Show starting message
    $DIALOG --infobox "Starting VM: $(jq -r '.name // empty' "$selection" 2>/dev/null)..." 6 60
    
    # Start the VM
    exec "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$selection"
  fi
}

main "$@"
