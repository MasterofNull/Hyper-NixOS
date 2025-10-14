# Script Privilege Classification

This document categorizes all Hyper-NixOS scripts by their privilege requirements.

## 🟢 No Sudo Required (VM Operations)

These scripts work for any user in the `libvirtd` and `kvm` groups:

### VM Management
- `menu.sh` - Main menu interface (VM operations only)
- `vm_dashboard.sh` - View VM status and metrics
- `create_vm_wizard.sh` - Create new VMs (uses user's storage)
- `vm_start.sh` - Start virtual machines
- `vm_stop.sh` - Stop/shutdown VMs
- `vm_restart.sh` - Restart VMs
- `vm_pause.sh` - Pause running VMs
- `vm_resume.sh` - Resume paused VMs
- `vm_console.sh` - Connect to VM console
- `vm_list.sh` - List available VMs
- `spice_vnc_launcher.sh` - Connect to VM display

### VM Monitoring & Info
- `resource_reporter.sh` - View VM resource usage
- `health_checks.sh` - Check VM health status
- `vm_info.sh` - Display VM information
- `performance_monitor.sh` - Monitor VM performance

### Snapshots & Backups (User's VMs)
- `snapshots_backups.sh` - Manage VM snapshots
- `snapshot_create.sh` - Create VM snapshots
- `snapshot_list.sh` - List snapshots
- `snapshot_revert.sh` - Revert to snapshot
- `backup_create.sh` - Backup VMs
- `backup_list.sh` - List backups
- `backup_restore.sh` - Restore from backup

### User Operations
- `iso_manager.sh` - Download ISOs (to user directory)
- `template_manager.sh` - Manage VM templates
- `donate.sh` - Show donation information
- `help.sh` - Display help information

## 🔴 Sudo Required (System Operations)

These scripts require administrator privileges and show clear warnings:

### System Installation & Setup
- `system_installer.sh` - Install Hyper-NixOS [SUDO]
- `hardware_detect.sh` - Detect and configure hardware [SUDO]
- `foundational_networking_setup.sh` - Configure network bridges [SUDO]
- `initial_setup.sh` - Initial system configuration [SUDO]

### System Configuration
- `toggle_boot_features.sh` - Modify boot configuration [SUDO]
- `update_hypervisor.sh` - System updates [SUDO]
- `system_config.sh` - System-wide configuration [SUDO]
- `kernel_tuning.sh` - Kernel parameter tuning [SUDO]

### Security Operations
- `security_audit.sh` - Run security audit [SUDO]
- `harden_permissions.sh` - Apply security hardening [SUDO]
- `relax_permissions.sh` - Relax permissions (setup mode) [SUDO]
- `transition_phase.sh` - Change security phase [SUDO]
- `selinux_config.sh` - Configure SELinux [SUDO]

### Network Management
- `zone_manager.sh` - Manage network zones [SUDO]
- `per_vm_firewall.sh` - Configure VM firewall rules [SUDO]
- `bridge_setup.sh` - Create network bridges [SUDO]
- `vlan_config.sh` - Configure VLANs [SUDO]
- `nat_setup.sh` - Configure NAT [SUDO]

### Storage Management
- `storage_pool_create.sh` - Create storage pools [SUDO]
- `storage_pool_delete.sh` - Delete storage pools [SUDO]
- `disk_resize.sh` - Resize disk images [SUDO]
- `lvm_setup.sh` - Configure LVM [SUDO]

### Advanced Features
- `vfio_workflow.sh` - VFIO/GPU passthrough setup [SUDO]
- `cpu_pinning.sh` - Configure CPU pinning [SUDO]
- `hugepages_setup.sh` - Configure hugepages [SUDO]
- `numa_config.sh` - NUMA configuration [SUDO]

### Service Management
- `service_manager.sh` - Manage system services [SUDO]
- `systemd_unit_create.sh` - Create systemd units [SUDO]
- `enable_features.sh` - Enable system features [SUDO]

## 📋 Privilege Check Implementation

### For Non-Sudo Scripts

```bash
#!/usr/bin/env bash
# Sudo Required: NO

# Script metadata
readonly REQUIRES_SUDO=false
readonly OPERATION_TYPE="vm_management"

# Check privileges (group membership only)
if ! check_vm_group_membership; then
    exit $EXIT_PERMISSION_DENIED
fi
```

### For Sudo Scripts

```bash
#!/usr/bin/env bash
# Sudo Required: YES

# Script metadata
readonly REQUIRES_SUDO=true
readonly OPERATION_TYPE="system_config"

# Check sudo requirement
if ! check_sudo_requirement; then
    exit $EXIT_PERMISSION_DENIED
fi

# Check phase permissions
check_phase_permission "$OPERATION_TYPE" || exit $EXIT_PERMISSION_DENIED
```

## 🎯 Best Practices

1. **Clear Indication**: Every script should indicate sudo requirement in:
   - Header comments: `# Sudo Required: YES/NO`
   - Help text
   - Error messages
   - Menu entries with `[SUDO]` tag

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

## 🔒 Security Phase Considerations

Scripts should also respect the two-phase security model:

### Setup Phase (Permissive)
- Both sudo and non-sudo operations allowed
- Warnings shown for operations that will be restricted later

### Hardened Phase (Restrictive)
- Only essential operations allowed
- System modifications blocked
- Clear error messages explaining phase restrictions