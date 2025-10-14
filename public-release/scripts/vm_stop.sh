#!/usr/bin/env bash
#
# Stop Virtual Machine
# Sudo Required: NO
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#
# This script stops a VM without requiring sudo privileges.
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
readonly OPERATION_TYPE="vm_stop"

# Start performance timer
script_timer_start

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME - $SCRIPT_VERSION

DESCRIPTION:
    Stop a virtual machine without requiring sudo privileges.
    You must be a member of the libvirtd group.

USAGE:
    $SCRIPT_NAME [OPTIONS] <vm-name>

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -f, --force     Force stop (destroy) instead of graceful shutdown
    -t, --timeout   Shutdown timeout in seconds (default: 60)

SUDO REQUIREMENT:
    NO - Standard user in libvirtd group can run this

EXAMPLES:
    # Graceful shutdown
    $SCRIPT_NAME my-vm

    # Force stop
    $SCRIPT_NAME --force my-vm

    # Shutdown with custom timeout
    $SCRIPT_NAME --timeout 120 my-vm

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
    
    log_info "Stopping VM as user: $(get_actual_user)"
}

# Parse arguments
FORCE=false
VERBOSE=false
TIMEOUT=60
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
            -f|--force)
                FORCE=true
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
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

# Stop the VM
stop_vm() {
    local vm="$1"
    local state
    
    state=$(get_vm_state "$vm")
    
    case "$state" in
        "shut off")
            log_info "VM '$vm' is already stopped"
            return 0
            ;;
        "running"|"paused")
            if [[ "$FORCE" == "true" ]]; then
                log_warn "Force stopping VM '$vm'..."
                virsh --connect qemu:///system destroy "$vm"
            else
                log_info "Gracefully shutting down VM '$vm' (timeout: ${TIMEOUT}s)..."
                
                # Send shutdown signal
                virsh --connect qemu:///system shutdown "$vm"
                
                # Wait for shutdown
                local elapsed=0
                while [[ $elapsed -lt $TIMEOUT ]]; do
                    if [[ "$(get_vm_state "$vm")" == "shut off" ]]; then
                        log_success "VM '$vm' stopped successfully"
                        return 0
                    fi
                    
                    sleep 2
                    elapsed=$((elapsed + 2))
                    echo -n "."
                done
                
                echo
                log_warn "VM did not stop within timeout, force stopping..."
                virsh --connect qemu:///system destroy "$vm"
            fi
            ;;
        *)
            log_error "VM '$vm' is in unexpected state: $state"
            return 1
            ;;
    esac
    
    # Verify VM is stopped
    if [[ "$(get_vm_state "$vm")" == "shut off" ]]; then
        log_success "VM '$vm' stopped successfully"
        return 0
    else
        log_error "Failed to stop VM '$vm'"
        return 1
    fi
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
    
    # Stop the VM
    if ! stop_vm "$VM_NAME"; then
        exit $EXIT_GENERAL_ERROR
    fi
    
    # Show final status if verbose
    if [[ "$VERBOSE" == "true" ]]; then
        echo
        echo "VM Status:"
        virsh --connect qemu:///system dominfo "$VM_NAME" | grep "State:"
    fi
    
    # Stop timer
    script_timer_end "$SCRIPT_NAME execution"
}

# Run main function
main "$@"