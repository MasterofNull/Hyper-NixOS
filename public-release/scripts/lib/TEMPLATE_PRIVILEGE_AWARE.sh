#!/usr/bin/env bash
#
# Script: SCRIPT_NAME.sh
# Description: BRIEF_DESCRIPTION
# Sudo Required: YES/NO
# 
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#
# This script demonstrates proper privilege handling:
# - Basic VM operations: NO sudo required (libvirtd group)
# - System operations: SUDO required with clear indication
#

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# IMPORTANT: Set these based on your script's requirements
readonly REQUIRES_SUDO=false  # Set to true for system operations
readonly OPERATION_TYPE="vm_management"  # or "system_config", "network_config", etc.

# Start performance timer
script_timer_start

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME - $SCRIPT_VERSION

DESCRIPTION:
    DETAILED_DESCRIPTION

USAGE:
    $SCRIPT_NAME [OPTIONS] [ARGS...]

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -q, --quiet     Suppress non-error output
    -d, --debug     Enable debug mode

SUDO REQUIREMENT:
    $(if [[ "$REQUIRES_SUDO" == "true" ]]; then
        echo "YES - This script modifies system configuration"
    else
        echo "NO - Standard user in libvirtd group can run this"
    fi)

EXAMPLES:
    # Example 1
    $SCRIPT_NAME arg1 arg2

    # Example 2
    $SCRIPT_NAME --verbose

EOF
}

# Check privileges based on script requirements
check_privileges() {
    if [[ "$REQUIRES_SUDO" == "true" ]]; then
        # Script requires sudo
        if ! check_sudo_requirement; then
            # check_sudo_requirement will display the error message
            exit $EXIT_PERMISSION_DENIED
        fi
        
        # Additional checks for sudo operations
        check_phase_permission "$OPERATION_TYPE" || exit $EXIT_PERMISSION_DENIED
    else
        # Script doesn't require sudo - check group membership
        if ! check_vm_group_membership; then
            # check_vm_group_membership will display the error message
            exit $EXIT_PERMISSION_DENIED
        fi
    fi
    
    # Log who's running the script
    local actual_user=$(get_actual_user)
    log_info "Script started by user: $actual_user"
}

# Parse command line arguments
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
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                set -x
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_INVALID_ARGUMENT
                ;;
            *)
                # Positional arguments
                break
                ;;
        esac
    done
    
    # Store remaining arguments
    readonly ARGS=("$@")
}

# Main function for non-sudo operations
main_user_operation() {
    log_info "Performing user-level VM operation: $OPERATION_TYPE"
    
    # Example: List VMs (no sudo needed)
    if command -v virsh >/dev/null 2>&1; then
        virsh --connect qemu:///system list --all
    else
        log_error "virsh command not found"
        return $EXIT_MISSING_DEPENDENCY
    fi
    
    # Your user-level logic here
    log_success "Operation completed successfully"
}

# Main function for sudo operations
main_system_operation() {
    log_warn "Performing system-level operation: $OPERATION_TYPE"
    
    # Show what we're about to do
    cat <<EOF
═══════════════════════════════════════════════════════════════
  System Operation Details
═══════════════════════════════════════════════════════════════
  
  This operation will:
    • Modify system configuration
    • Update service settings
    • Change network configuration
  
  User: $(get_actual_user)
  Phase: $SECURITY_PHASE
  
═══════════════════════════════════════════════════════════════
EOF
    
    # Your system-level logic here
    log_success "System operation completed successfully"
}

# Main execution
main() {
    # Check privileges first
    check_privileges
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate environment
    validate_environment
    
    # Execute based on privilege level
    if [[ "$REQUIRES_SUDO" == "true" ]]; then
        main_system_operation
    else
        main_user_operation
    fi
    
    # Stop timer
    script_timer_end "$SCRIPT_NAME execution"
}

# Run main function
main "$@"