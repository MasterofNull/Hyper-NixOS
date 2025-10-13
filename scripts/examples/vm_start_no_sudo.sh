#!/usr/bin/env bash
#
# Example: Start VM without sudo
# Sudo Required: NO
#
# This script demonstrates VM operations that don't require sudo
# when the user is in the libvirtd group.
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/exit_codes.sh"

# Script metadata
readonly REQUIRES_SUDO=false
readonly OPERATION_TYPE="vm_start"

# Check privileges (will verify group membership)
if ! check_vm_group_membership; then
    exit $EXIT_PERMISSION_DENIED
fi

# Main function
main() {
    local vm_name="${1:-}"
    
    if [[ -z "$vm_name" ]]; then
        echo "Usage: $0 <vm-name>"
        echo
        echo "This script starts a VM without requiring sudo."
        echo "You must be in the 'libvirtd' group."
        exit $EXIT_INVALID_ARGUMENT
    fi
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Starting VM: $vm_name"
    echo "  User: $(get_actual_user)"
    echo "  Sudo: NOT REQUIRED ✓"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    # Start the VM (no sudo needed!)
    if virsh --connect qemu:///system start "$vm_name"; then
        log_success "VM '$vm_name' started successfully"
        
        # Show VM info
        echo
        echo "VM Status:"
        virsh --connect qemu:///system dominfo "$vm_name"
        
        # Get console info
        echo
        echo "To connect to console:"
        echo "  virsh --connect qemu:///system console $vm_name"
        echo
        echo "To connect via SPICE/VNC:"
        echo "  virt-viewer --connect qemu:///system $vm_name"
        
    else
        log_error "Failed to start VM '$vm_name'"
        exit $EXIT_GENERAL_ERROR
    fi
}

main "$@"