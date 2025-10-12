# Security Model

Complete explanation of the security architecture for the Hyper-NixOS hypervisor system.

---

## Table of Contents

- [Overview](#overview)
- [Autologin Security](#autologin-security)
- [Sudo Privilege Model](#sudo-privilege-model)
- [Threat Model](#threat-model)
- [Attack Surface Analysis](#attack-surface-analysis)
- [Hardening Options](#hardening-options)
- [Best Practices](#best-practices)

---

## Overview

### Design Philosophy

**Goal:** Balance convenience (appliance-like VM management) with security (system protection)

**Approach:** **Least Privilege with Granular Permissions**

```
┌─────────────────────────────────────────┐
│  Physical/Console Access                │
│  ↓                                      │
│  Autologin (convenience)                │
│  ↓                                      │
│  Console Menu (non-privileged)          │
│  ↓                                      │
│  VM Operations ←── Passwordless sudo    │
│                    (virsh start/stop)   │
│  ↓                                      │
│  System Admin ←── Password REQUIRED     │
│                   (nixos-rebuild, etc.) │
└─────────────────────────────────────────┘
```

### Key Principles

1. ✅ **Autologin for convenience** - Boot directly to menu
2. ✅ **VM operations passwordless** - Start/stop VMs without friction  
3. ✅ **System operations require password** - Protect against unauthorized changes
4. ✅ **Physical access ≠ root access** - Attacker still needs password for damage
5. ✅ **Granular sudo rules** - Only specific commands allowed without password

---

## Autologin Security

### Why Autologin is Enabled

**Use Case:** Hypervisor as an appliance
- Boot → Menu → Select VM → Start VM (zero friction)
- No keyboard needed for normal operation
- Suitable for server room / home lab deployment

### Security Implications

**Physical Access Risks:**

| Without Autologin | With Autologin (Old Model) | With Autologin (New Model) |
|-------------------|---------------------------|---------------------------|
| ❌ No access | ❌ Instant root | ✅ Limited access |
| Need password | Passwordless sudo = root | Passwordless sudo = VMs only |
| Secure | **INSECURE** | **Secure** |

**What Autologin Provides:**
- ✅ Access to console menu
- ✅ Ability to start/stop VMs
- ✅ View VM status and logs
- ✅ Access to documentation

**What Autologin Does NOT Provide:**
- ❌ System reconfiguration (requires password)
- ❌ Installing software (requires password)
- ❌ Modifying firewall (requires password)
- ❌ Reading /etc/shadow (requires password)
- ❌ Changing other users (requires password)

### When to Disable Autologin

**Disable autologin if:**
- 🏢 Multi-user system (multiple people have physical access)
- 🔐 Compliance requirements mandate authentication
- 🚪 System in physically insecure location (public area)
- 📹 No physical security monitoring (cameras, locks)

**How to disable:**

Create `/var/lib/hypervisor/configuration/security-local.nix`:
```nix
{ config, lib, ... }:
{
  # Disable autologin - require manual login
  services.getty.autologinUser = lib.mkForce null;
}
```

Then rebuild: `sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"`

---

## Sudo Privilege Model

### Granular Permission System

**Old Model (INSECURE):**
```
User → sudo → ALL COMMANDS (NOPASSWD)
```
❌ **Problem:** Physical access = instant root access

**New Model (SECURE):**
```
User → sudo virsh start → ✅ Allowed (NOPASSWD)
User → sudo nixos-rebuild → ❌ Password required
User → sudo systemctl → ❌ Password required
User → sudo cat /etc/shadow → ❌ Password required
```

### Passwordless Commands (VM Operations)

These commands can be run without a password:

#### VM Control
- `virsh list` - List VMs
- `virsh start <vm>` - Start VM
- `virsh shutdown <vm>` - Graceful shutdown
- `virsh reboot <vm>` - Reboot VM
- `virsh destroy <vm>` - Force stop
- `virsh suspend <vm>` - Pause VM
- `virsh resume <vm>` - Resume VM

#### VM Information (Read-Only)
- `virsh dominfo <vm>` - VM details
- `virsh domstate <vm>` - VM state
- `virsh domuuid <vm>` - VM UUID
- `virsh domifaddr <vm>` - VM IP addresses
- `virsh console <vm>` - VM console access

#### VM Management
- `virsh define <xml>` - Define new VM
- `virsh undefine <vm>` - Remove VM definition

#### Snapshots
- `virsh snapshot-create-as` - Create snapshot
- `virsh snapshot-list` - List snapshots
- `virsh snapshot-revert` - Revert to snapshot
- `virsh snapshot-delete` - Delete snapshot

#### Network (Read-Only)
- `virsh net-list` - List networks
- `virsh net-info` - Network details
- `virsh net-dhcp-leases` - DHCP leases

### Password-Required Commands (System Administration)

These commands **require password authentication**:

#### System Configuration
- ❌ `nixos-rebuild` (system changes)
- ❌ `nix-env` (package installation)
- ❌ `nix-collect-garbage` (cleanup)

#### Service Management
- ❌ `systemctl start/stop/restart` (services)
- ❌ `systemctl enable/disable` (autostart)
- ❌ `systemctl daemon-reload` (reload configs)

#### Network Configuration
- ❌ `ip link` (interface changes)
- ❌ `systemctl restart systemd-networkd` (network restart)
- ❌ `iptables` (firewall changes)

#### File System
- ❌ `mount/umount` (mounting drives)
- ❌ Editing `/etc/*` (system configs)
- ❌ Editing `/var/*` (system state)

#### User Management
- ❌ `useradd/userdel` (user changes)
- ❌ `passwd` (password changes for others)
- ❌ `chown/chmod` on system files

---

## Threat Model

### Threats Addressed

| Threat | Mitigation | Effectiveness |
|--------|-----------|---------------|
| **Physical theft** | Password required for system changes | ✅ High |
| **Unauthorized console access** | Sudo password required | ✅ High |
| **Accidental damage** | Password prompt before destructive actions | ✅ High |
| **VM escape** | VMs run as non-root, AppArmor confined | ✅ High |
| **Network attacks** | Firewall enabled, SSH keys only | ✅ High |

### Threats NOT Addressed

| Threat | Why Not Addressed | Mitigation |
|--------|-------------------|------------|
| **Physical disk removal** | Can't prevent | ✅ Use LUKS encryption |
| **BIOS tampering** | Hardware-level | ✅ BIOS password, secure boot |
| **Memory dump (cold boot)** | Hardware attack | ✅ Encrypted RAM (if available) |
| **Shoulder surfing password** | Social engineering | ✅ Physical security |

### Attack Scenarios

#### Scenario 1: Stolen Laptop/Server

**Attacker capabilities:**
- ✅ Can boot to console menu (autologin)
- ✅ Can start/stop VMs
- ✅ Can view VM console
- ❌ **Cannot** reconfigure system (needs password)
- ❌ **Cannot** read SSH keys (needs password)
- ❌ **Cannot** extract secrets (needs password)
- ❌ **Cannot** install backdoors (needs password)

**Impact:** **LOW** - VMs can be accessed, but system remains protected

**Additional mitigation:**
- Enable disk encryption (LUKS)
- Store sensitive data in encrypted volumes
- Use VM disk encryption for critical workloads

#### Scenario 2: Unauthorized Console Access

**Attacker capabilities:**
- ✅ Can use the menu
- ✅ Can start VMs
- ❌ **Cannot** modify firewall
- ❌ **Cannot** install malware
- ❌ **Cannot** change passwords

**Impact:** **LOW** - Limited to VM operations only

#### Scenario 3: Compromised VM

**Attacker capabilities (inside VM):**
- ❌ **Cannot** escape to host (libvirt isolation + AppArmor)
- ❌ **Cannot** access other VMs (network isolation)
- ❌ **Cannot** access host filesystem (namespace isolation)

**Impact:** **VERY LOW** - VM escape is extremely difficult

---

## Attack Surface Analysis

### Entry Points

#### Console/Physical Access
- **Risk:** Medium (with new model), High (with old model)
- **Mitigation:** Passwordless sudo restricted to VM operations only
- **Monitoring:** Physical security, console logging

#### SSH (Remote Access)
- **Risk:** Low
- **Mitigation:** 
  - Password authentication disabled
  - Keys only
  - Root login disabled
  - Firewall enabled
- **Monitoring:** SSH logs, fail2ban (optional)

#### VM Guests → Host
- **Risk:** Low
- **Mitigation:**
  - VMs run as non-root (qemu user)
  - AppArmor profiles applied
  - Seccomp sandboxing enabled
  - Namespace isolation (mount, uts, ipc, pid, net)
- **Monitoring:** AppArmor logs, audit logs

#### Network Services
- **Risk:** Low (minimal exposed services)
- **Mitigation:**
  - Firewall enabled (default deny)
  - Only essential ports open (SSH, libvirt if needed)
  - No unnecessary services running
- **Monitoring:** Firewall logs, port scans

---

## Hardening Options

### Level 1: Default (Balanced)

**Current configuration:**
- ✅ Autologin enabled
- ✅ Sudo restricted to VM operations
- ✅ Password required for system changes
- ✅ Firewall enabled
- ✅ SSH keys only

**Suitable for:** Home lab, trusted environment

### Level 2: Enhanced Security

Add to `/var/lib/hypervisor/configuration/security-local.nix`:
```nix
{ config, lib, ... }:
{
  # Disable autologin - require manual login
  services.getty.autologinUser = lib.mkForce null;
  
  # Require password even for VM operations
  security.sudo.wheelNeedsPassword = true;
  security.sudo.extraRules = lib.mkForce [
    {
      users = [ config.users.users.hypervisor.name ];
      commands = [
        { command = "ALL"; }  # All commands require password
      ];
    }
  ];
  
  # Enable audit logging
  security.auditd.enable = true;
  security.audit.rules = [
    "-a always,exit -F arch=b64 -S execve"  # Log all command execution
  ];
}
```

**Suitable for:** Multi-user environment, compliance requirements

### Level 3: Maximum Security

Additional hardening:
```nix
{
  # All from Level 2, plus:
  
  # Disable SSH password fallback completely
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.ChallengeResponseAuthentication = false;
  
  # Restrict SSH to specific IPs
  services.openssh.settings.ListenAddress = [ "192.168.1.10" ];
  
  # Firewall: deny everything except SSH from specific subnet
  networking.firewall.extraCommands = ''
    iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j DROP
  '';
  
  # Enable disk encryption (requires setup during install)
  boot.initrd.luks.devices = {
    cryptroot = {
      device = "/dev/sda2";
      allowDiscards = true;
    };
  };
  
  # Require YubiKey for sudo (advanced)
  security.pam.services.sudo.u2fAuth = true;
}
```

**Suitable for:** Production environment, high-security requirements

---

## Best Practices

### General Security

1. ✅ **Keep system updated**
   ```bash
   sudo bash /etc/hypervisor/scripts/update_hypervisor.sh
   ```

2. ✅ **Use strong passwords**
   ```bash
   # At least 16 characters, mix of letters/numbers/symbols
   sudo passwd your-username
   ```

3. ✅ **Regular backups**
   ```bash
   sudo bash /etc/hypervisor/scripts/snapshots_backups.sh
   ```

4. ✅ **Monitor logs**
   ```bash
   sudo journalctl -f  # Real-time logs
   sudo journalctl -u systemd-networkd  # Network logs
   sudo journalctl -u libvirtd  # VM logs
   ```

### Physical Security

1. ✅ **Secure boot area** - Lock server room, cabinet locks
2. ✅ **Video surveillance** - Monitor physical access
3. ✅ **Asset tracking** - Serial numbers, inventory
4. ✅ **Disk encryption** - Protect data at rest

### Network Security

1. ✅ **Firewall rules** - Only open necessary ports
2. ✅ **Network segmentation** - Separate VM networks
3. ✅ **VPN access** - Don't expose SSH to internet
4. ✅ **Regular port scans** - Verify no unexpected services

### VM Security

1. ✅ **Isolate VMs** - Use separate bridges for different trust levels
2. ✅ **Update VM guests** - Keep guest OS patched
3. ✅ **VM firewalls** - Configure firewall inside each VM
4. ✅ **Snapshot before changes** - Easy rollback if compromised

---

## Security Comparison

### Hypervisor Systems Comparison

| Feature | Hyper-NixOS (This System) | Proxmox | ESXi Free | Hyper-V |
|---------|--------------------------|---------|-----------|---------|
| **Autologin** | ✅ Optional (secure) | ❌ No | ❌ No | ❌ No |
| **Granular sudo** | ✅ Yes (VM ops only) | ❌ Full sudo | N/A | N/A |
| **SSH keys only** | ✅ Default | ⚠️ Optional | ⚠️ Optional | ⚠️ Optional |
| **Firewall** | ✅ Enabled | ✅ Enabled | ✅ Enabled | ✅ Enabled |
| **AppArmor/SELinux** | ✅ AppArmor | ⚠️ Optional | ❌ No | ❌ No |
| **Hardened kernel** | ✅ Yes | ❌ No | ❌ No | N/A |
| **Non-root VMs** | ✅ Yes | ⚠️ Mixed | ✅ Yes | ✅ Yes |
| **Audit logging** | ✅ Enabled | ✅ Enabled | ✅ Enabled | ✅ Enabled |

---

## Summary

### Security Model Summary

✅ **What's Secure:**
- Autologin + restricted sudo = controlled convenience
- VM operations passwordless (usability)
- System operations password-required (security)
- Physical access ≠ root access (protection)

✅ **What's Protected:**
- System configuration (requires password)
- Sensitive files (/etc/shadow, SSH keys)
- Service management (systemctl)
- Package installation
- Network configuration

✅ **What's Convenient:**
- Boot directly to menu
- Start/stop VMs without password
- View VM status and logs
- Quick VM management

### The Balanced Approach

This security model provides:
1. 🎯 **Usability** - Appliance-like VM management
2. 🔒 **Security** - System remains protected  
3. ⚖️ **Balance** - Right level of friction in right places
4. 📊 **Auditability** - All sudo usage logged

**Philosophy:** Make the right thing easy, and the dangerous thing require thought (password prompt).

---

## Quick Reference

### Check Current Security Settings

```bash
# View sudo rules
sudo cat /etc/sudoers.d/*

# Test VM operation (should work without password)
sudo virsh list

# Test system operation (should ask for password)
sudo nixos-rebuild build --flake /etc/hypervisor

# View audit logs
sudo ausearch -ts recent

# Check autologin status
systemctl cat getty@tty1 | grep ExecStart
```

### Emergency: Disable Autologin Immediately

```bash
# Method 1: Systemd override
sudo systemctl edit getty@tty1
# Add: [Service]
#      ExecStart=
#      ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear - $TERM

# Method 2: NixOS config (requires rebuild)
# Edit security-local.nix as shown above
```
