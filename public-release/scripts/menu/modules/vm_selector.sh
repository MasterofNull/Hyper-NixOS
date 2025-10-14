#!/usr/bin/env bash
#
# VM Boot Selector Module
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Boot selector functionality for menu system
#

# Show VM boot selector
show_vm_boot_selector() {
    local timeout="${1:-$BOOT_SELECTOR_TIMEOUT}"
    local exit_after="${2:-$BOOT_SELECTOR_EXIT_AFTER_START}"
    
    log_info "Showing VM boot selector (timeout: ${timeout}s)"
    
    # Get all VMs
    local vms=()
    while IFS= read -r vm; do
        [[ -n "$vm" ]] && vms+=("$vm")
    done < <(list_vms all)
    
    if [[ ${#vms[@]} -eq 0 ]]; then
        show_info "No VMs" "No VMs found to boot"
        return 1
    fi
    
    # Check for last booted VM
    local last_vm=""
    if [[ -f "$LAST_VM_FILE" ]]; then
        last_vm=$(cat "$LAST_VM_FILE" 2>/dev/null || true)
    fi
    
    # Build menu entries
    local entries=()
    local default_item=""
    for vm in "${vms[@]}"; do
        local state
        state=$(get_vm_state "$vm")
        local status=""
        [[ "$state" == "running" ]] && status=" [RUNNING]"
        
        entries+=("$vm" "Boot $vm$status")
        
        # Set default to last VM if it exists
        [[ "$vm" == "$last_vm" ]] && default_item="$vm"
    done
    
    # Add menu option
    entries+=("__MENU__" "← Return to Main Menu")
    
    # Show selector with timeout
    local selected
    if [[ -n "$default_item" ]]; then
        selected=$($DIALOG --title "VM Boot Selector" \
            --default-item "$default_item" \
            --timeout "$timeout" \
            --menu "Select a VM to boot (timeout in ${timeout}s):" \
            20 60 12 "${entries[@]}" 3>&1 1>&2 2>&3) || true
    else
        selected=$($DIALOG --title "VM Boot Selector" \
            --timeout "$timeout" \
            --menu "Select a VM to boot (timeout in ${timeout}s):" \
            20 60 12 "${entries[@]}" 3>&1 1>&2 2>&3) || true
    fi
    
    # Handle timeout - boot last VM
    if [[ -z "$selected" && -n "$last_vm" ]]; then
        selected="$last_vm"
        echo "Timeout - booting last VM: $selected"
    fi
    
    # Handle selection
    case "$selected" in
        ""|"__MENU__")
            return 0
            ;;
        *)
            # Boot the selected VM
            boot_vm "$selected"
            
            # Save as last VM
            echo "$selected" > "$LAST_VM_FILE"
            
            # Exit if configured
            if [[ "$exit_after" == "true" ]]; then
                clear_screen
                echo "VM '$selected' started. Exiting..."
                exit 0
            fi
            ;;
    esac
}

# Boot a VM with autostart handling
boot_vm() {
    local vm_name="$1"
    
    log_info "Booting VM: $vm_name"
    
    # Check if already running
    local state
    state=$(get_vm_state "$vm_name")
    if [[ "$state" == "running" ]]; then
        echo "VM '$vm_name' is already running"
        return 0
    fi
    
    # Check for autostart
    local profile="$USER_PROFILES_DIR/$vm_name.json"
    local autostart="false"
    if [[ -f "$profile" ]]; then
        autostart=$(jq -r '.autostart // false' "$profile" 2>/dev/null || echo "false")
    fi
    
    # Start the VM
    echo "Starting VM '$vm_name'..."
    if virsh start "$vm_name" 2>&1; then
        echo "VM '$vm_name' started successfully"
        
        # Show console if autostart
        if [[ "$autostart" == "true" ]]; then
            sleep 2
            echo "Connecting to console (autostart enabled)..."
            virsh console "$vm_name"
        fi
        
        return 0
    else
        echo "Failed to start VM '$vm_name'"
        return 1
    fi
}