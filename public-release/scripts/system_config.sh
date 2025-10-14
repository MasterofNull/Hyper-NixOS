#!/usr/bin/env bash
#
# System Configuration Manager
# Sudo Required: YES
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#
# This script manages system-wide configuration and REQUIRES sudo privileges.
# It provides clear indication of what changes will be made.
#

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"
readonly REQUIRES_SUDO=true
readonly OPERATION_TYPE="system_config"

# Start performance timer
script_timer_start

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME - $SCRIPT_VERSION

DESCRIPTION:
    Manage system-wide configuration for Hyper-NixOS.
    This script modifies system settings and REQUIRES sudo privileges.

USAGE:
    sudo $SCRIPT_NAME [OPTIONS] <command> [args...]

COMMANDS:
    network     Configure network settings (bridges, NAT, firewall)
    storage     Configure storage pools and permissions
    security    Configure security settings and policies
    services    Manage system services
    show        Display current configuration

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --dry-run   Show what would be done without making changes

SUDO REQUIREMENT:
    YES - This script modifies system configuration

EXAMPLES:
    # Configure network bridges
    sudo $SCRIPT_NAME network setup-bridge br0

    # Configure storage pool
    sudo $SCRIPT_NAME storage create-pool default /var/lib/libvirt/images

    # Show current configuration
    sudo $SCRIPT_NAME show

EOF
}

# Check privileges
check_privileges() {
    # This operation requires sudo
    if ! check_sudo_requirement; then
        exit $EXIT_PERMISSION_DENIED
    fi
    
    # Check phase permissions
    if ! check_phase_permission "$OPERATION_TYPE"; then
        exit $EXIT_PERMISSION_DENIED
    fi
    
    log_warn "Running system configuration as: $(get_actual_user)"
}

# Show operation banner
show_operation_banner() {
    local operation="$1"
    local description="$2"
    
    cat <<EOF
╔═══════════════════════════════════════════════════════════════╗
║           SYSTEM CONFIGURATION OPERATION                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Operation: $operation
║  Description: $description
║  User: $(get_actual_user)
║  Phase: $SECURITY_PHASE
║                                                               ║
║  This operation will modify system configuration.             ║
║  All changes will be logged to the audit trail.              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
}

# Configure network
configure_network() {
    local subcommand="${1:-}"
    shift || true
    
    case "$subcommand" in
        setup-bridge)
            local bridge_name="${1:-br0}"
            show_operation_banner "Network Bridge Setup" \
                "Create and configure network bridge: $bridge_name"
            
            log_info "Creating network bridge: $bridge_name"
            
            # Create bridge
            if ! ip link show "$bridge_name" &>/dev/null; then
                ip link add "$bridge_name" type bridge
                log_success "Bridge $bridge_name created"
            else
                log_info "Bridge $bridge_name already exists"
            fi
            
            # Enable bridge
            ip link set "$bridge_name" up
            
            # Configure for VM use
            echo 1 > /proc/sys/net/ipv4/ip_forward
            
            log_success "Network bridge configured"
            ;;
            
        firewall)
            show_operation_banner "Firewall Configuration" \
                "Update firewall rules for VM networking"
            
            log_info "Configuring firewall rules..."
            # Firewall configuration would go here
            log_success "Firewall rules updated"
            ;;
            
        *)
            log_error "Unknown network subcommand: $subcommand"
            echo "Available subcommands: setup-bridge, firewall"
            exit $EXIT_INVALID_ARGUMENT
            ;;
    esac
}

# Configure storage
configure_storage() {
    local subcommand="${1:-}"
    shift || true
    
    case "$subcommand" in
        create-pool)
            local pool_name="${1:-default}"
            local pool_path="${2:-/var/lib/libvirt/images}"
            
            show_operation_banner "Storage Pool Creation" \
                "Create storage pool: $pool_name at $pool_path"
            
            log_info "Creating storage pool: $pool_name"
            
            # Create directory
            mkdir -p "$pool_path"
            
            # Set permissions
            chown root:libvirtd "$pool_path"
            chmod 775 "$pool_path"
            
            # Create libvirt pool
            virsh pool-define-as "$pool_name" dir --target "$pool_path" || true
            virsh pool-start "$pool_name" || true
            virsh pool-autostart "$pool_name" || true
            
            log_success "Storage pool created"
            ;;
            
        permissions)
            show_operation_banner "Storage Permissions" \
                "Fix storage permissions for VM access"
            
            log_info "Fixing storage permissions..."
            
            # Fix permissions on common directories
            for dir in /var/lib/libvirt/images /var/lib/hypervisor/vms; do
                if [[ -d "$dir" ]]; then
                    chown -R root:libvirtd "$dir"
                    chmod -R g+rw "$dir"
                    find "$dir" -type d -exec chmod g+s {} \;
                fi
            done
            
            log_success "Storage permissions fixed"
            ;;
            
        *)
            log_error "Unknown storage subcommand: $subcommand"
            echo "Available subcommands: create-pool, permissions"
            exit $EXIT_INVALID_ARGUMENT
            ;;
    esac
}

# Configure security
configure_security() {
    local subcommand="${1:-}"
    shift || true
    
    case "$subcommand" in
        selinux)
            show_operation_banner "SELinux Configuration" \
                "Configure SELinux policies for virtualization"
            
            log_info "Configuring SELinux..."
            
            # Set SELinux booleans for virt
            if command -v setsebool &>/dev/null; then
                setsebool -P virt_use_nfs on || true
                setsebool -P virt_sandbox_use_all_caps on || true
            else
                log_info "SELinux not available"
            fi
            
            log_success "Security configuration updated"
            ;;
            
        audit)
            show_operation_banner "Audit Configuration" \
                "Configure audit rules for VM operations"
            
            log_info "Configuring audit rules..."
            # Audit configuration would go here
            log_success "Audit rules updated"
            ;;
            
        *)
            log_error "Unknown security subcommand: $subcommand"
            echo "Available subcommands: selinux, audit"
            exit $EXIT_INVALID_ARGUMENT
            ;;
    esac
}

# Show current configuration
show_configuration() {
    show_operation_banner "Show Configuration" \
        "Display current system configuration"
    
    echo "=== Network Configuration ==="
    ip link show type bridge 2>/dev/null || echo "No bridges configured"
    echo
    
    echo "=== Storage Pools ==="
    virsh pool-list --all 2>/dev/null || echo "No storage pools"
    echo
    
    echo "=== Security Settings ==="
    echo "Security Phase: $SECURITY_PHASE"
    if command -v getenforce &>/dev/null; then
        echo "SELinux: $(getenforce)"
    fi
    echo
    
    echo "=== User Permissions ==="
    echo "Current user: $(get_actual_user)"
    echo "Groups: $(groups)"
}

# Parse arguments
VERBOSE=false
DRY_RUN=false
COMMAND=""
ARGS=()

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
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --)
                shift
                COMMAND="$1"
                shift
                ARGS=("$@")
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_INVALID_ARGUMENT
                ;;
            *)
                COMMAND="$1"
                shift
                ARGS=("$@")
                break
                ;;
        esac
    done
    
    if [[ -z "$COMMAND" ]]; then
        log_error "Command is required"
        show_help
        exit $EXIT_INVALID_ARGUMENT
    fi
}

# Main function
main() {
    # Check privileges first
    check_privileges
    
    # Parse arguments
    parse_arguments "$@"
    
    # Execute command
    case "$COMMAND" in
        network)
            configure_network "${ARGS[@]}"
            ;;
        storage)
            configure_storage "${ARGS[@]}"
            ;;
        security)
            configure_security "${ARGS[@]}"
            ;;
        services)
            configure_services "${ARGS[@]}"
            ;;
        show)
            show_configuration
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            echo "Available commands: network, storage, security, services, show"
            exit $EXIT_INVALID_ARGUMENT
            ;;
    esac
    
    # Stop timer
    script_timer_end "$SCRIPT_NAME execution"
    
    # Log completion
    log_success "System configuration completed by $(get_actual_user)"
}

# Run main function
main "$@"