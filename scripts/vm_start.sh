#!/usr/bin/env bash
#
# Start Virtual Machine
# Sudo Required: NO
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#
# This script starts a VM without requiring sudo privileges.
# User must be in the libvirtd group.
#

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"
readonly REQUIRES_SUDO=false
readonly OPERATION_TYPE="vm_start"

# Start performance timer
script_timer_start

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME - $SCRIPT_VERSION

DESCRIPTION:
    Start a virtual machine without requiring sudo privileges.
    You must be a member of the libvirtd group.

USAGE:
    $SCRIPT_NAME [OPTIONS] <vm-name>

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -c, --console   Attach to console after starting
    -w, --wait      Wait for VM to fully boot

SUDO REQUIREMENT:
    NO - Standard user in libvirtd group can run this

EXAMPLES:
    # Start a VM
    $SCRIPT_NAME my-vm

    # Start and attach to console
    $SCRIPT_NAME --console my-vm

    # Start with verbose output
    $SCRIPT_NAME --verbose my-vm

EOF
}

# Check privileges
check_privileges() {
    # This operation doesn't require sudo
    if ! check_vm_group_membership; then
        exit $EXIT_PERMISSION_DENIED
    fi
    
    # Check phase permissions
    if ! check_phase_permission "$OPERATION_TYPE"; then
        exit $EXIT_PERMISSION_DENIED
    fi
    
    log_info "Starting VM as user: $(get_actual_user)"
}

# Parse arguments
CONSOLE=false
WAIT=false
VERBOSE=false
VM_NAME=""

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit $EXIT_SUCCESS
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--console)
                CONSOLE=true
                shift
                ;;
            -w|--wait)
                WAIT=true
                shift
                ;;
            --)
                shift
                VM_NAME="$1"
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_INVALID_ARGUMENT
                ;;
            *)
                VM_NAME="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$VM_NAME" ]]; then
        log_error "VM name is required"
        show_help
        exit $EXIT_INVALID_ARGUMENT
    fi
}

# Check if VM exists
check_vm_exists() {
    local vm="$1"
    
    if ! virsh --connect qemu:///system dominfo "$vm" &>/dev/null; then
        log_error "VM '$vm' does not exist"
        echo "Available VMs:"
        virsh --connect qemu:///system list --all --name | sed 's/^/  /'
        return 1
    fi
    
    return 0
}

# Get VM state
get_vm_state() {
    local vm="$1"
    virsh --connect qemu:///system domstate "$vm" 2>/dev/null || echo "unknown"
}

# Start the VM
start_vm() {
    local vm="$1"
    local state
    
    state=$(get_vm_state "$vm")
    
    case "$state" in
        "running")
            log_info "VM '$vm' is already running"
            return 0
            ;;
        "paused")
            log_info "VM '$vm' is paused, resuming..."
            virsh --connect qemu:///system resume "$vm"
            ;;
        "shut off"|"crashed")
            log_info "Starting VM '$vm'..."
            virsh --connect qemu:///system start "$vm"
            ;;
        *)
            log_error "VM '$vm' is in unexpected state: $state"
            return 1
            ;;
    esac
    
    if [[ "$?" -eq 0 ]]; then
        log_success "VM '$vm' started successfully"
        
        # Show VM info
        if [[ "$VERBOSE" == "true" ]]; then
            echo
            echo "VM Information:"
            virsh --connect qemu:///system dominfo "$vm"
        fi
        
        return 0
    else
        log_error "Failed to start VM '$vm'"
        return 1
    fi
}

# Wait for VM to boot
wait_for_boot() {
    local vm="$1"
    local timeout=60
    local elapsed=0
    
    log_info "Waiting for VM to boot (max ${timeout}s)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        # Check if VM has an IP address (indicates it's booted)
        if virsh --connect qemu:///system domifaddr "$vm" 2>/dev/null | grep -q "ipv4"; then
            log_success "VM appears to be fully booted"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "Network interfaces:"
                virsh --connect qemu:///system domifaddr "$vm"
            fi
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
    done
    
    echo
    log_warn "Timeout waiting for VM to fully boot"
    return 0  # Don't fail, VM might still be booting
}

# Attach to console
attach_console() {
    local vm="$1"
    
    echo
    echo "Attaching to VM console..."
    echo "Press Ctrl+] to exit console"
    echo
    
    virsh --connect qemu:///system console "$vm"
}

# Main function
main() {
    # Check privileges first
    check_privileges
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate VM exists
    if ! check_vm_exists "$VM_NAME"; then
        exit $EXIT_GENERAL_ERROR
    fi
    
    # Start the VM
    if ! start_vm "$VM_NAME"; then
        exit $EXIT_GENERAL_ERROR
    fi
    
    # Wait for boot if requested
    if [[ "$WAIT" == "true" ]]; then
        wait_for_boot "$VM_NAME"
    fi
    
    # Attach to console if requested
    if [[ "$CONSOLE" == "true" ]]; then
        attach_console "$VM_NAME"
    fi
    
    # Show connection info
    echo
    echo "To connect to this VM:"
    echo "  Console: virsh --connect qemu:///system console $VM_NAME"
    echo "  Display: virt-viewer --connect qemu:///system $VM_NAME"
    
    # Stop timer
    script_timer_end "$SCRIPT_NAME execution"
}

# Run main function
main "$@"