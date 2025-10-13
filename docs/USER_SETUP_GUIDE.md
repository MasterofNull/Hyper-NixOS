# User Setup Guide for Hyper-NixOS

This guide explains how to set up users with the appropriate privileges for Hyper-NixOS.

## Overview

Hyper-NixOS uses a privilege separation model where:
- **VM operations** do NOT require sudo
- **System operations** DO require sudo with clear acknowledgment

## User Categories

### 1. VM Users (Basic)
Can perform all basic VM operations without sudo:
- Start/stop/restart VMs
- View VM status and console
- Create snapshots
- Basic backups

### 2. VM Operators (Advanced)
Everything VM Users can do, plus:
- Create/delete storage volumes
- Manage VM templates
- Advanced backup operations

### 3. System Administrators
Everything above, plus:
- System configuration (with sudo)
- Network setup
- Security settings
- Service management

## Setting Up Users

### Step 1: Add User to System

Edit your `configuration.nix`:

```nix
users.users.alice = {
  isNormalUser = true;
  description = "Alice (VM User)";
  hashedPassword = "$6$..."; # Generate with: mkpasswd -m sha-512
};
```

### Step 2: Configure Privilege Level

In the same `configuration.nix`:

```nix
hypervisor.security.privileges = {
  enable = true;
  
  # Choose appropriate category for each user
  vmUsers = [ "alice" "bob" ];        # Basic VM operations
  vmOperators = [ "charlie" ];        # Advanced VM operations  
  systemAdmins = [ "admin" ];         # Full system access (with sudo)
};
```

### Step 3: Apply Configuration

```bash
sudo nixos-rebuild switch
```

### Step 4: User First Login

When users first login, they should verify their groups:

```bash
# Check group membership
groups

# Expected output for VM user:
# alice libvirtd kvm hypervisor-users

# Expected output for operator:
# charlie libvirtd kvm disk hypervisor-users hypervisor-operators

# Expected output for admin:
# admin wheel libvirtd kvm hypervisor-users hypervisor-operators hypervisor-admins
```

## Common Operations

### VM Users (No Sudo Required)

```bash
# Start a VM
vm-start my-vm

# Stop a VM
vm-stop my-vm

# List VMs
virsh list --all

# Connect to VM console
virsh console my-vm

# Create snapshot
virsh snapshot-create-as my-vm snapshot1

# View VM info
virsh dominfo my-vm
```

### System Administrators (Sudo Required)

```bash
# Configure network (requires sudo)
sudo system-config network setup-bridge br0

# Create storage pool (requires sudo)
sudo system-config storage create-pool default /var/lib/libvirt/images

# Update system (requires sudo)
sudo nixos-rebuild switch

# Manage services (requires sudo)
sudo systemctl restart libvirtd
```

## Troubleshooting

### "Permission Denied" for VM Operations

If users get permission denied for VM operations:

1. Check group membership:
   ```bash
   groups
   ```

2. Ensure user is in `libvirtd` and `kvm` groups:
   ```bash
   # If missing, admin can add:
   sudo usermod -aG libvirtd,kvm username
   ```

3. Logout and login again for group changes to take effect

4. Test libvirt access:
   ```bash
   virsh --connect qemu:///system list
   ```

### "Sudo Required" Messages

This is expected behavior for system operations. The message will show:
- What operation requires sudo
- Why it needs elevated privileges
- The exact command to run with sudo

Example:
```
═══════════════════════════════════════════════════════════════
  This operation requires administrator privileges
═══════════════════════════════════════════════════════════════

  Operation: system_config
  Script: system_config.sh

  Please run with sudo:
    sudo system_config.sh network setup-bridge br0

═══════════════════════════════════════════════════════════════
```

### Testing Privileges

Run the privilege test suite:

```bash
# As regular user (tests VM operations)
/etc/hypervisor/tests/test_privileges.sh

# With sudo (tests system operations)
sudo /etc/hypervisor/tests/test_privileges.sh
```

## Security Best Practices

1. **Principle of Least Privilege**: Only grant users the minimum access they need
2. **Regular Audits**: Review user permissions periodically
3. **Password Policies**: Enforce strong passwords for all users
4. **Sudo Logging**: All sudo operations are logged to audit trail
5. **Group Management**: Remove users from groups when access is no longer needed

## Quick Reference

| Operation | Sudo Required | Group Required |
|-----------|--------------|----------------|
| Start VM | No | libvirtd |
| Stop VM | No | libvirtd |
| Create VM | No | libvirtd |
| VM Console | No | libvirtd |
| Create Snapshot | No | libvirtd |
| View VM Status | No | libvirtd |
| Configure Network | Yes | wheel/hypervisor-admins |
| Create Storage Pool | Yes | wheel/hypervisor-admins |
| System Update | Yes | wheel |
| Modify Firewall | Yes | wheel/hypervisor-admins |

## Example User Configurations

### Development Team Member
```nix
users.users.developer = {
  isNormalUser = true;
  description = "Developer";
  extraGroups = [ ];  # Groups added automatically
};

hypervisor.security.privileges.vmUsers = [ "developer" ];
```

### Operations Engineer
```nix
users.users.ops = {
  isNormalUser = true;
  description = "Operations Engineer";
  extraGroups = [ ];  # Groups added automatically
};

hypervisor.security.privileges.vmOperators = [ "ops" ];
```

### System Administrator
```nix
users.users.sysadmin = {
  isNormalUser = true;
  description = "System Administrator";
  extraGroups = [ ];  # Groups added automatically
};

hypervisor.security.privileges.systemAdmins = [ "sysadmin" ];
```