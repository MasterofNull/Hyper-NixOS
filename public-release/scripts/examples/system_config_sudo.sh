#!/usr/bin/env bash
#
# Example: System Configuration with sudo
# Sudo Required: YES
#
# This script demonstrates system operations that require sudo
# with clear indication and user acknowledgment.
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/exit_codes.sh"

# Script metadata
readonly REQUIRES_SUDO=true
readonly OPERATION_TYPE="system_config"

# Check sudo requirement
if ! check_sudo_requirement; then
    exit $EXIT_PERMISSION_DENIED
fi

# Check phase permissions
check_phase_permission "$OPERATION_TYPE" || exit $EXIT_PERMISSION_DENIED

# Main function
main() {
    local action="${1:-}"
    
    if [[ -z "$action" ]]; then
        echo "Usage: sudo $0 <action>"
        echo
        echo "Actions:"
        echo "  network   - Configure network settings"
        echo "  storage   - Configure storage pools"
        echo "  security  - Configure security settings"
        echo
        echo "This script REQUIRES sudo for system configuration."
        exit $EXIT_INVALID_ARGUMENT
    fi
    
    # Show what we're doing
    cat <<EOF
╔═══════════════════════════════════════════════════════════════╗
║           SYSTEM CONFIGURATION OPERATION                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Action: $action                                              ║
║  User: $(get_actual_user)                                     ║
║  Phase: $SECURITY_PHASE                                       ║
║                                                               ║
║  This operation will modify system configuration.             ║
║  All changes will be logged to the audit trail.              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
    
    # Log the operation
    log_warn "System configuration operation: $action by user $(get_actual_user)"
    
    case "$action" in
        network)
            configure_network
            ;;
        storage)
            configure_storage
            ;;
        security)
            configure_security
            ;;
        *)
            log_error "Unknown action: $action"
            exit $EXIT_INVALID_ARGUMENT
            ;;
    esac
    
    log_success "System configuration completed"
}

# Example configuration functions
configure_network() {
    echo "Configuring network settings..."
    echo "  • Checking network bridges"
    echo "  • Updating firewall rules"
    echo "  • Applying NAT configuration"
    # Actual implementation would go here
}

configure_storage() {
    echo "Configuring storage pools..."
    echo "  • Creating storage directories"
    echo "  • Setting permissions"
    echo "  • Configuring quotas"
    # Actual implementation would go here
}

configure_security() {
    echo "Configuring security settings..."
    echo "  • Updating SELinux policies"
    echo "  • Setting file permissions"
    echo "  • Configuring audit rules"
    # Actual implementation would go here
}

main "$@"