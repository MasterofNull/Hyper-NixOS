#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# VM Operations Functions
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# VM management functions for menu system
# Sudo Required: NO - All VM operations work without sudo
#

# Get VM list with optional filtering
get_vm_list() {
    local owner_filter="${1:-}"
    local entries=()
    
    shopt -s nullglob
    for f in "$USER_PROFILES_DIR"/*.json; do
        local name
        name=$(jq -r '.name // empty' "$f" 2>/dev/null || true)
        [[ -z "$name" ]] && name=$(basename "$f" .json)
        
        local owner
        owner=$(jq -r '.owner // empty' "$f" 2>/dev/null || true)
        
        # Apply owner filter if specified
        if [[ -n "$owner_filter" && "$owner" != "$owner_filter" ]]; then
            continue
        fi
        
        # Format entry
        if [[ -n "$owner" && "$owner" != "null" ]]; then
            entries+=("$f" "VM: $name (owner: $owner)")
        else
            entries+=("$f" "VM: $name")
        fi
    done
    shopt -u nullglob
    
    printf '%s\n' "${entries[@]}"
}

# Start a VM
start_vm() {
    local vm_profile="$1"
    local vm_name
    vm_name=$(basename "$vm_profile" .json)
    
    log_info "Starting VM: $vm_name"
    
    # Check if VM exists
    if ! virsh dominfo "$vm_name" &>/dev/null; then
        show_info "VM Not Found" "VM '$vm_name' does not exist. Creating from profile..."
        if ! "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$vm_profile"; then
            show_info "Error" "Failed to create VM from profile"
            return 1
        fi
    fi
    
    # Check if already running
    local state
    state=$(get_vm_state "$vm_name")
    if [[ "$state" == "running" ]]; then
        show_info "VM Running" "VM '$vm_name' is already running"
        return 0
    fi
    
    # Start the VM
    if virsh start "$vm_name"; then
        show_info "Success" "VM '$vm_name' started successfully"
        return 0
    else
        show_info "Error" "Failed to start VM '$vm_name'"
        return 1
    fi
}

# Stop a VM
stop_vm() {
    local vm_name="$1"
    local force="${2:-false}"
    
    log_info "Stopping VM: $vm_name (force=$force)"
    
    # Check state
    local state
    state=$(get_vm_state "$vm_name")
    if [[ "$state" != "running" ]]; then
        show_info "VM Not Running" "VM '$vm_name' is not running"
        return 0
    fi
    
    # Stop the VM
    if [[ "$force" == "true" ]]; then
        virsh destroy "$vm_name"
    else
        virsh shutdown "$vm_name"
    fi
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        show_info "Success" "VM '$vm_name' stop initiated"
        return 0
    else
        show_info "Error" "Failed to stop VM '$vm_name'"
        return 1
    fi
}

# Show VM console
show_vm_console() {
    local vm_name="$1"
    
    log_info "Connecting to VM console: $vm_name"
    
    # Check if running
    local state
    state=$(get_vm_state "$vm_name")
    if [[ "$state" != "running" ]]; then
        show_info "VM Not Running" "VM '$vm_name' must be running to access console"
        return 1
    fi
    
    clear_screen
    echo "Connecting to $vm_name console..."
    echo "Press Ctrl+] to exit console"
    echo ""
    sleep 2
    
    virsh console "$vm_name"
}

# Delete a VM
delete_vm() {
    local vm_name="$1"
    
    if ! show_yesno "Confirm Delete" "Are you sure you want to delete VM '$vm_name'?\n\nThis will remove the VM definition and all associated storage."; then
        return 0
    fi
    
    log_info "Deleting VM: $vm_name"
    
    # Stop if running
    local state
    state=$(get_vm_state "$vm_name")
    if [[ "$state" == "running" ]]; then
        virsh destroy "$vm_name"
    fi
    
    # Delete VM and storage
    if virsh undefine "$vm_name" --remove-all-storage; then
        # Remove profile
        rm -f "$USER_PROFILES_DIR/$vm_name.json"
        show_info "Success" "VM '$vm_name' deleted successfully"
        return 0
    else
        show_info "Error" "Failed to delete VM '$vm_name'"
        return 1
    fi
}

# Show VM info
show_vm_info() {
    local vm_name="$1"
    local info
    
    # Get VM info
    info=$(virsh dominfo "$vm_name" 2>&1)
    if [[ $? -ne 0 ]]; then
        show_info "Error" "Failed to get VM info:\n$info"
        return 1
    fi
    
    # Get additional details
    local vcpus memory state
    vcpus=$(virsh dominfo "$vm_name" | grep "CPU(s):" | awk '{print $2}')
    memory=$(virsh dominfo "$vm_name" | grep "Max memory:" | awk '{print $3,$4}')
    state=$(get_vm_state "$vm_name")
    
    # Get disk info
    local disks
    disks=$(virsh domblklist "$vm_name" --details | grep -E "disk.*file" | awk '{print $4}' | xargs -I{} du -h {} 2>/dev/null | awk '{print "  " $2 ": " $1}')
    
    # Format info
    local display_info="VM: $vm_name
State: $state
vCPUs: $vcpus
Memory: $memory

Disks:
$disks"
    
    show_info "VM Information" "$display_info" 20 70
}