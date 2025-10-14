# Privilege Separation Model for Hyper-NixOS

## Overview

Hyper-NixOS implements a clear privilege separation model:
- **Basic VM operations**: No sudo required (run as regular user in libvirtd group)
- **System operations**: Require sudo with clear acknowledgment

## Privilege Categories

### 1. No Sudo Required (Regular User Operations)

These operations work for any user in the `libvirtd` and `kvm` groups:

#### VM Management
- `vm_start` - Start a VM
- `vm_stop` - Stop/shutdown a VM  
- `vm_restart` - Restart a VM
- `vm_pause` - Pause a VM
- `vm_resume` - Resume a VM
- `vm_status` - Check VM status
- `vm_console` - Connect to VM console
- `vm_list` - List VMs

#### VM Monitoring
- `vm_info` - Get VM information
- `vm_metrics` - View VM metrics
- `vm_logs` - View VM logs
- `resource_usage` - Check resource usage

#### Snapshots & Backups (User's VMs)
- `snapshot_create` - Create VM snapshot
- `snapshot_list` - List snapshots
- `snapshot_revert` - Revert to snapshot
- `backup_create` - Backup a VM
- `backup_list` - List backups

### 2. Sudo Required (System Operations)

These operations require sudo and show clear warnings:

#### System Configuration
- `system_installer.sh` - Install Hyper-NixOS
- `hardware_detect.sh` - Detect and configure hardware
- `foundational_networking_setup.sh` - Configure network bridges
- `toggle_boot_features.sh` - Modify boot configuration
- `transition_phase.sh` - Change security phase

#### Security Operations  
- `harden_permissions.sh` - Apply security hardening
- `relax_permissions.sh` - Relax permissions (setup mode)
- `security_audit.sh` - Run security audit
- `update_hypervisor.sh` - System updates

#### Storage & Network Management
- `storage_pool_create` - Create storage pools
- `network_bridge_create` - Create network bridges
- `firewall_config` - Modify firewall rules

#### User Management
- `user_create` - Create system users
- `group_modify` - Modify group membership

## Implementation

### 1. Script Template with Privilege Check

```bash
#!/usr/bin/env bash
#
# Script Name - Description
# Sudo Required: YES/NO
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/privilege_check.sh"

# Script metadata
SCRIPT_NAME="$(basename "$0")"
REQUIRES_SUDO=false  # Set to true for system operations
OPERATION_TYPE="vm_management"  # or "system_config"

# Check privileges
check_privileges() {
    if [[ "$REQUIRES_SUDO" == "true" ]]; then
        if [[ $EUID -ne 0 ]]; then
            echo "═══════════════════════════════════════════════════════════════"
            echo "  This operation requires administrator privileges"
            echo "═══════════════════════════════════════════════════════════════"
            echo
            echo "  Operation: $OPERATION_TYPE"
            echo "  Script: $SCRIPT_NAME"
            echo
            echo "  This script will:"
            describe_sudo_operations
            echo
            echo "  Please run with sudo:"
            echo "    sudo $0 $*"
            echo
            echo "═══════════════════════════════════════════════════════════════"
            exit $EXIT_PERMISSION_DENIED
        fi
        
        # Log sudo usage
        log_warn "Running with sudo: $SCRIPT_NAME (user: ${SUDO_USER:-root})"
    else
        # Check for required groups
        check_user_groups
    fi
}

# Describe what sudo operations will do
describe_sudo_operations() {
    case "$OPERATION_TYPE" in
        system_config)
            echo "    • Modify system configuration files"
            echo "    • Change system services"
            echo "    • Update network settings"
            ;;
        storage_management)
            echo "    • Create/modify storage pools"
            echo "    • Change disk permissions"
            echo "    • Mount/unmount filesystems"
            ;;
        security_config)
            echo "    • Modify security policies"
            echo "    • Change file permissions"
            echo "    • Update firewall rules"
            ;;
    esac
}

# Check user is in required groups
check_user_groups() {
    local required_groups=("libvirtd" "kvm")
    local missing_groups=()
    
    for group in "${required_groups[@]}"; do
        if ! groups | grep -q "\b$group\b"; then
            missing_groups+=("$group")
        fi
    done
    
    if [[ ${#missing_groups[@]} -gt 0 ]]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Missing Required Group Membership"
        echo "═══════════════════════════════════════════════════════════════"
        echo
        echo "  Your user needs to be in these groups:"
        for group in "${missing_groups[@]}"; do
            echo "    • $group"
        done
        echo
        echo "  To add yourself to these groups, run:"
        echo "    sudo usermod -aG ${missing_groups[*]} $USER"
        echo
        echo "  Then logout and login again for changes to take effect."
        echo
        echo "═══════════════════════════════════════════════════════════════"
        exit $EXIT_PERMISSION_DENIED
    fi
}

# Initialize privilege check
check_privileges

# Main script logic
main() {
    # Your script logic here
    echo "Running $OPERATION_TYPE operations..."
}

main "$@"
```

### 2. Privilege Check Library

```bash
# scripts/lib/privilege_check.sh
#!/usr/bin/env bash

# Privilege checking functions for Hyper-NixOS scripts

# Operation categories that don't require sudo
NO_SUDO_OPERATIONS=(
    # VM Management
    "vm_start" "vm_stop" "vm_restart" "vm_pause" "vm_resume"
    "vm_status" "vm_console" "vm_list" "vm_info"
    
    # Monitoring
    "vm_metrics" "vm_logs" "resource_usage" "health_check"
    
    # User-level operations
    "snapshot_create" "snapshot_list" "snapshot_revert"
    "backup_create" "backup_list" "backup_restore"
    
    # Read-only operations
    "config_view" "log_view" "status_view"
)

# Check if operation requires sudo
operation_requires_sudo() {
    local operation="$1"
    
    # Check if in no-sudo list
    for no_sudo_op in "${NO_SUDO_OPERATIONS[@]}"; do
        if [[ "$operation" == "$no_sudo_op" ]]; then
            return 1  # Does not require sudo
        fi
    done
    
    return 0  # Requires sudo
}

# Pretty print sudo requirement
print_sudo_requirement() {
    local script_name="$1"
    local requires_sudo="$2"
    
    if [[ "$requires_sudo" == "true" ]]; then
        echo -e "${RED}[SUDO REQUIRED]${NC} $script_name"
    else
        echo -e "${GREEN}[USER MODE]${NC} $script_name"
    fi
}

# Check effective permissions
check_effective_permissions() {
    local required_perms="$1"
    
    case "$required_perms" in
        "vm_management")
            # Check libvirt socket access
            if [[ ! -w /var/run/libvirt/libvirt-sock ]]; then
                return 1
            fi
            ;;
        "storage_read")
            # Check read access to VM storage
            if [[ ! -r /var/lib/libvirt/images ]]; then
                return 1
            fi
            ;;
        "storage_write")
            # Check write access to VM storage
            if [[ ! -w /var/lib/libvirt/images ]]; then
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Sudo preservation wrapper
# Preserves environment variables when using sudo
sudo_preserve() {
    local vars_to_preserve=(
        "HYPERVISOR_CONFIG"
        "SECURITY_PHASE"
        "USER"
        "HOME"
    )
    
    local sudo_cmd="sudo"
    for var in "${vars_to_preserve[@]}"; do
        if [[ -n "${!var}" ]]; then
            sudo_cmd="$sudo_cmd $var='${!var}'"
        fi
    done
    
    eval "$sudo_cmd $@"
}

# Generate sudo warning for interactive scripts
show_sudo_warning() {
    local operation="$1"
    local description="$2"
    
    cat <<EOF
╔═══════════════════════════════════════════════════════════════╗
║              ADMINISTRATOR PRIVILEGES REQUIRED                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Operation: $operation                                        ║
║  Description: $description                                    ║
║                                                               ║
║  This operation requires sudo because it will:                ║
║    • Modify system configuration                              ║
║    • Change system-wide settings                              ║
║    • Access restricted resources                              ║
║                                                               ║
║  You will be prompted for your password.                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Press Enter to continue or Ctrl+C to cancel...
EOF
    read -r
}

# Check if running under sudo
is_running_as_sudo() {
    [[ $EUID -eq 0 ]] || [[ -n "$SUDO_USER" ]]
}

# Get actual user (even when running under sudo)
get_actual_user() {
    if [[ -n "$SUDO_USER" ]]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

# Export functions
export -f operation_requires_sudo
export -f print_sudo_requirement
export -f check_effective_permissions
export -f sudo_preserve
export -f show_sudo_warning
export -f is_running_as_sudo
export -f get_actual_user
```

### 3. Updated Menu System

```bash
# scripts/menu/menu.sh - Updated with privilege awareness

show_main_menu() {
    local entries=()
    
    # VM operations (no sudo required)
    entries+=("" "")
    entries+=("__HEADER_VM__" "═══ VM Operations (No Sudo Required) ═══")
    
    # Show VMs with management options
    for vm in $(list_user_vms); do
        entries+=("vm:$vm" "▸ $vm")
    done
    
    entries+=("__VM_CREATE__" "✚ Create New VM")
    entries+=("__VM_DASHBOARD__" "📊 VM Dashboard")
    
    # System operations (sudo required)
    entries+=("" "")
    entries+=("__HEADER_SYSTEM__" "═══ System Operations (Sudo Required) ═══")
    entries+=("__SYS_CONFIG__" "🔧 System Configuration [SUDO]")
    entries+=("__NETWORK_CONFIG__" "🌐 Network Setup [SUDO]")
    entries+=("__SECURITY_CONFIG__" "🔒 Security Settings [SUDO]")
    entries+=("__UPDATE_SYSTEM__" "🔄 Update Hypervisor [SUDO]")
    
    # User operations
    entries+=("" "")
    entries+=("__HEADER_USER__" "═══ User Operations ═══")
    entries+=("__BACKUP_MANAGE__" "💾 Backup Management")
    entries+=("__SNAPSHOT_MANAGE__" "📸 Snapshot Management")
    entries+=("__HELP__" "❓ Help & Documentation")
    entries+=("__EXIT__" "🚪 Exit")
    
    # Show menu with current user info
    local current_user=$(get_actual_user)
    local sudo_status=""
    if is_running_as_sudo; then
        sudo_status=" (SUDO MODE)"
    fi
    
    show_menu "$BRANDING - Main Menu | User: $current_user$sudo_status" \
        "Select an operation:" \
        "${entries[@]}"
}

# Handle menu selection with privilege check
handle_menu_selection() {
    local selection="$1"
    
    case "$selection" in
        vm:*)
            # VM operations - no sudo needed
            local vm_name="${selection#vm:}"
            show_vm_menu "$vm_name"
            ;;
            
        __VM_CREATE__|__VM_DASHBOARD__|__BACKUP_MANAGE__|__SNAPSHOT_MANAGE__)
            # User operations - no sudo needed
            handle_user_operation "$selection"
            ;;
            
        __SYS_CONFIG__|__NETWORK_CONFIG__|__SECURITY_CONFIG__|__UPDATE_SYSTEM__)
            # System operations - require sudo
            handle_system_operation "$selection"
            ;;
    esac
}

# Handle system operations that require sudo
handle_system_operation() {
    local operation="$1"
    
    # Check if already running as sudo
    if ! is_running_as_sudo; then
        case "$operation" in
            __SYS_CONFIG__)
                show_sudo_requirement "System Configuration" \
                    "Configure system-wide settings, users, and services"
                exec sudo "$0" --system-config
                ;;
            __NETWORK_CONFIG__)
                show_sudo_requirement "Network Configuration" \
                    "Setup network bridges, VLANs, and firewall rules"
                exec sudo "$SCRIPTS_DIR/foundational_networking_setup.sh"
                ;;
            __SECURITY_CONFIG__)
                show_sudo_requirement "Security Configuration" \
                    "Modify security policies and system hardening"
                exec sudo "$SCRIPTS_DIR/security_config.sh"
                ;;
            __UPDATE_SYSTEM__)
                show_sudo_requirement "System Update" \
                    "Update Hyper-NixOS system packages and configuration"
                exec sudo "$SCRIPTS_DIR/update_hypervisor.sh"
                ;;
        esac
    else
        # Already sudo, proceed with operation
        case "$operation" in
            __SYS_CONFIG__)
                show_system_config_menu
                ;;
            # ... handle other operations
        esac
    fi
}

# Show sudo requirement dialog
show_sudo_requirement() {
    local title="$1"
    local description="$2"
    
    clear
    cat <<EOF
╔═══════════════════════════════════════════════════════════════╗
║           ADMINISTRATOR PRIVILEGES REQUIRED                   ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Operation: $title                                            ║
║                                                               ║
║  This operation requires administrator privileges to:         ║
║    $description                                               ║
║                                                               ║
║  You will now be prompted for your sudo password.            ║
║                                                               ║
║  Note: Basic VM operations do NOT require sudo.              ║
║  Only system configuration changes need elevated privileges.  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Press Enter to continue or Ctrl+C to cancel...
EOF
    read -r
}
```

### 4. Polkit Rules for GUI Applications

For systems with PolicyKit, we can allow VM operations without password prompts:

```xml
<!-- /etc/polkit-1/rules.d/50-hypervisor-vm-management.rules -->
polkit.addRule(function(action, subject) {
    // Allow users in libvirtd group to manage VMs without password
    if (action.id.indexOf("org.libvirt.unix.manage") == 0 &&
        subject.isInGroup("libvirtd")) {
        return polkit.Result.YES;
    }
});

polkit.addRule(function(action, subject) {
    // Allow VM monitoring without password
    if (action.id.indexOf("org.libvirt.unix.monitor") == 0 &&
        subject.isInGroup("libvirtd")) {
        return polkit.Result.YES;
    }
});

polkit.addRule(function(action, subject) {
    // System operations still require authentication
    if (action.id.indexOf("org.hypervisor.system") == 0) {
        return polkit.Result.AUTH_ADMIN;
    }
});
```

### 5. Group-Based Access Control

```nix
# modules/security/group-access.nix
{ config, lib, pkgs, ... }:

{
  # User groups for different access levels
  users.groups = {
    # Basic VM management - no sudo needed
    hypervisor-users = {
      gid = 2000;
      members = config.hypervisor.users.vmUsers;
    };
    
    # Advanced VM operations - no sudo needed
    hypervisor-operators = {
      gid = 2001;
      members = config.hypervisor.users.vmOperators;
    };
    
    # System administrators - sudo required
    hypervisor-admins = {
      gid = 2002;
      members = config.hypervisor.users.systemAdmins;
    };
  };
  
  # Add VM users to required system groups
  users.users = lib.mapAttrs (name: user: {
    extraGroups = [ "libvirtd" "kvm" ] ++ 
      lib.optional (lib.elem name config.hypervisor.users.vmOperators) "disk" ++
      lib.optional (lib.elem name config.hypervisor.users.systemAdmins) "wheel";
  }) config.users.users;
  
  # Sudo rules - only for system operations
  security.sudo.extraRules = [
    {
      # VM users - no sudo access
      groups = [ "hypervisor-users" ];
      commands = [ ];  # No sudo commands
    }
    {
      # VM operators - limited sudo for storage operations
      groups = [ "hypervisor-operators" ];
      commands = [
        {
          command = "${pkgs.coreutils}/bin/mkdir -p /var/lib/libvirt/images/*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.coreutils}/bin/chown :libvirtd /var/lib/libvirt/images/*";
          options = [ "NOPASSWD" ];
        }
      ];
    }
    {
      # System admins - full sudo with password
      groups = [ "hypervisor-admins" "wheel" ];
      commands = [ { command = "ALL"; } ];
    }
  ];
  
  # File permissions for different groups
  systemd.tmpfiles.rules = [
    # VM management areas - accessible to all VM users
    "d /var/lib/hypervisor/vms 2775 root hypervisor-users - -"
    "d /var/lib/hypervisor/backups 2775 root hypervisor-users - -"
    "d /var/lib/hypervisor/snapshots 2775 root hypervisor-users - -"
    
    # System areas - restricted to admins
    "d /etc/hypervisor 0750 root hypervisor-admins - -"
    "d /var/lib/hypervisor/system 0750 root hypervisor-admins - -"
  ];
}
```

## Script Classification

### No Sudo Required ✓
```
menu.sh                    # Main menu (VM operations only)
vm_dashboard.sh           # View VM status
create_vm_wizard.sh       # Create VMs (user's storage)
vm_start.sh              # Start VMs
vm_stop.sh               # Stop VMs
vm_console.sh            # Access VM console
snapshots_backups.sh     # User's VM snapshots
resource_reporter.sh     # View resource usage
health_checks.sh         # Check VM health
iso_manager.sh           # Download ISOs (user directory)
spice_vnc_launcher.sh    # Connect to VM display
```

### Sudo Required ⚠️
```
system_installer.sh      # Install system [SUDO]
hardware_detect.sh       # Detect hardware [SUDO]
foundational_networking_setup.sh  # Setup bridges [SUDO]
update_hypervisor.sh     # System updates [SUDO]
security_audit.sh        # Security audit [SUDO]
harden_permissions.sh    # Apply hardening [SUDO]
toggle_boot_features.sh  # Boot config [SUDO]
zone_manager.sh          # Network zones [SUDO]
per_vm_firewall.sh       # Firewall rules [SUDO]
vfio_workflow.sh         # VFIO setup [SUDO]
```

## Best Practices

1. **Clear Indication**: Scripts requiring sudo should clearly indicate this in:
   - Script header comments
   - Help text
   - Error messages
   - Menu entries with [SUDO] tag

2. **Graceful Handling**: When sudo is required:
   - Check if already running as root
   - Provide clear explanation why sudo is needed
   - Show what operations will be performed
   - Offer to re-run with sudo automatically

3. **Minimal Privilege**: Operations should use the least privilege necessary:
   - VM operations: regular user in libvirtd group
   - Storage creation: operator group with specific sudo rules
   - System config: full sudo with password

4. **Audit Trail**: All sudo operations should be logged with:
   - Who ran the command (actual user)
   - What operation was performed
   - When it was executed
   - Result of the operation

This model ensures that day-to-day VM management is convenient and doesn't require constant sudo password entry, while system-level changes maintain appropriate security controls.