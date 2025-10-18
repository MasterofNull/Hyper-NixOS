**# System Hardening Guide - Hyper-NixOS

## Overview

Hyper-NixOS includes a comprehensive **system hardening wizard** that allows administrators to lock down the system after initial setup and configuration are complete. The hardening is **fully reversible** and comes with **4 distinct profiles** to match different security requirements.

**Key Features**:
- ✅ **Admin-only access** (requires sudo/root)
- ✅ **Multiple hardening profiles** (Development, Balanced, Strict, Paranoid)
- ✅ **Fully reversible** (un-harden anytime)
- ✅ **Automatic backups** before changes
- ✅ **State tracking** (know what's applied)
- ✅ **Integrates with privilege separation**

---

## The Hardening Wizard

### Location
`/home/hyperd/Documents/Hyper-NixOS/scripts/system-hardening-wizard.sh`

### Usage
```bash
# Must be run as root/sudo (admin only)
sudo /home/hyperd/Documents/Hyper-NixOS/scripts/system-hardening-wizard.sh
```

### When to Use

**Run hardening AFTER**:
1. ✅ System installation is complete
2. ✅ All VMs are created and tested
3. ✅ User accounts are set up
4. ✅ Network configuration is finalized
5. ✅ All features are tested and working

**DON'T run hardening**:
- ❌ During initial setup
- ❌ While actively developing/testing
- ❌ Before verifying everything works

---

## Hardening Profiles

### 1. Development Profile 🟢

**Use case**: Active development, testing, frequent changes

**What it does**:
- Relaxed file permissions (0755/0644)
- Debugging tools enabled
- Verbose logging
- `/etc/hypervisor` readable by wheel group
- `/var/lib/hypervisor` fully accessible

**File permissions**:
```
/etc/hypervisor/         → 0755 (rwxr-xr-x)
/etc/hypervisor/*.nix    → 0644 (rw-r--r--)
/etc/hypervisor/scripts/ → 0755 (rwxr-xr-x)
/var/lib/hypervisor/     → 0775 (rwxrwxr-x)
```

**Services**:
- Debug mode enabled (`HYPERVISOR_DEBUG=1`)
- All services running normally

**Best for**:
- Development workstations
- Test environments
- Lab setups
- Learning/experimentation

**Security level**: 🟢 Low (prioritizes usability)

---

### 2. Balanced Profile 🔵 **[RECOMMENDED]**

**Use case**: Daily use, production workstations, most users

**What it does**:
- Moderate file permissions (0750/0640)
- VM operations remain smooth
- System changes require authentication
- Secure areas locked down
- Basic firewall rules

**File permissions**:
```
/etc/hypervisor/                  → 0750 (rwxr-x---)
/etc/hypervisor/*.nix             → 0640 (rw-r-----)
/etc/hypervisor/flake.nix         → 0644 (rw-r--r--) [readable]
/etc/hypervisor/scripts/          → 0750 (rwxr-x---)
/var/lib/hypervisor/vms           → 2775 (rwxrwsr-x)
/var/lib/hypervisor/backups       → 2775 (rwxrwsr-x)
/var/lib/hypervisor/images        → 2770 (rwxrws---)
/var/lib/hypervisor/secure        → 0700 (rwx------)
/var/lib/hypervisor/system        → 0750 (rwxr-x---)
```

**Firewall**:
- SSH (port 22): ✅ Allowed
- VM consoles (5900-5920): ✅ Allowed
- Other ports: ❌ Blocked by default

**Services**:
- Normal operation
- VM operations work without sudo
- System changes need sudo

**Best for**:
- Production workstations
- Multi-user environments
- General use
- **This is the sweet spot for most users**

**Security level**: 🔵 Moderate (balanced security/usability)

---

### 3. Strict Profile 🟡

**Use case**: Production servers, sensitive environments

**What it does**:
- Strict file permissions (0750/0600)
- Comprehensive audit logging
- Hardened systemd services
- Admin group required for access
- Minimal attack surface

**File permissions**:
```
/etc/hypervisor/         → 0750 (rwxr-x---) root:hypervisor-admins
/etc/hypervisor/*.nix    → 0640 (rw-r-----) root:hypervisor-admins
/etc/hypervisor/scripts/ → 0700 (rwx------) root:root
/var/lib/hypervisor/     → 0770 (rwxrwx---)
/var/lib/hypervisor/secure → 0700 (rwx------) root:root
/var/lib/hypervisor/system → 0700 (rwx------) root:root
```

**Audit logging**:
- `/etc/hypervisor` → All writes audited
- `/var/lib/hypervisor/system` → All writes audited
- Logs to: `journalctl -t audit`

**Systemd hardening**:
```ini
[Service]
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true
```

**Best for**:
- Production servers
- Compliance requirements (SOC 2, HIPAA, etc.)
- Sensitive data handling
- Untrusted network environments

**Security level**: 🟡 High (security first, usability second)

---

### 4. Paranoid Profile 🔴

**Use case**: Maximum security, zero-trust environments

**What it does**:
- Extremely restrictive permissions (0700/0600)
- Everything requires explicit authorization
- Maximum audit logging
- Firewall denies all by default
- Non-essential services disabled

**File permissions**:
```
/etc/hypervisor/             → 0700 (rwx------) root:root
/etc/hypervisor/*            → 0600 (rw-------) root:root
/var/lib/hypervisor/         → 0700 (rwx------) root:root
/var/lib/hypervisor/vms      → 0750 (rwxr-x---) root:hypervisor-admins
```

**Audit logging**:
- **EVERYTHING** audited: `/etc`, `/var/lib/hypervisor`, sudo execution
- Logs to: `journalctl -t audit` (high volume!)

**Firewall**:
- Default policy: **DROP ALL**
- Explicitly allowed: SSH (port 22) only
- Everything else: ❌ Blocked

**Services disabled**:
- CUPS (printing)
- Bluetooth
- Avahi (mDNS)
- Any non-essential services

**Best for**:
- Military/government
- Financial services
- Classified data
- Air-gapped systems
- **Only use if you REALLY need this level of security**

**Security level**: 🔴 Maximum (significantly impacts usability)

**⚠️ WARNING**: This will break many workflows. Only use if required by policy!

---

## How It Works

### State Management

**State file**: `/var/lib/hypervisor/hardening-state.json`

Example:
```json
{
  "profile": "balanced",
  "timestamp": "2025-01-15T10:30:00-05:00",
  "applied_by": "admin",
  "hostname": "hyper-nixos",
  "version": "1.0.0"
}
```

### Automatic Backups

**Backup directory**: `/var/lib/hypervisor/hardening-backups/`

**What's backed up**:
- `/etc/hypervisor/` (entire directory)
- `/etc/nixos/configuration.nix`
- `/etc/nixos/` (entire directory)
- Current file permissions
- Systemd service list
- Iptables rules

**Backup naming**: `pre-hardening-YYYYMMDD-HHMMSS`

**Example**:
```
/var/lib/hypervisor/hardening-backups/
  ├── pre-hardening-20250115-103000/
  │   ├── hypervisor/
  │   ├── configuration.nix
  │   ├── permissions.txt
  │   ├── var-permissions.txt
  │   ├── services.txt
  │   └── iptables.rules
  └── pre-hardening-20250115-140000/
      └── ...
```

---

## Using the Wizard

### Interactive Walkthrough

**Step 1: Launch**
```bash
sudo /home/hyperd/Documents/Hyper-NixOS/scripts/system-hardening-wizard.sh
```

**Step 2: See current status**
```
Current Hardening Status:
  Status: No hardening applied
  System using default security settings
```

**Step 3: Select profile**
```
Select Hardening Profile:

  1) Development (minimal hardening, easy testing)
     • Relaxed permissions for development
     • Debugging tools enabled
     • Verbose logging

→ 2) Balanced (recommended for most users)
     • Reasonable security without breaking workflows
     • VM operations remain smooth
     • System changes require authentication

  3) Strict (production environments)
     • Enhanced access controls
     • Comprehensive audit logging
     • Minimal attack surface

  4) Paranoid (maximum security)
     • Extremely restrictive permissions
     • Everything requires explicit authorization
     • May impact usability

  5) Un-harden - Remove all hardening

  0) Exit without changes

Select profile (0-5): 2
```

**Step 4: Automatic backup**
```
Creating backup: pre-hardening-20250115-103000
✓ Backup created: /var/lib/hypervisor/hardening-backups/pre-hardening-20250115-103000
```

**Step 5: Apply hardening**
```
Applying: balanced

Applying Balanced Hardening Profile...
✓ Balanced hardening applied

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Hardening profile applied: balanced
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Backup saved to: /var/lib/hypervisor/hardening-backups/pre-hardening-20250115-103000
  State file: /var/lib/hypervisor/hardening-state.json

  Important Notes:
  • Test all VM operations to ensure they still work
  • Check that authorized users can access their VMs
  • Review audit logs: journalctl -t audit

  To reverse these changes, run this wizard again and select 'Un-harden'
```

---

## Un-hardening (Reverting)

### When to Un-harden

**Un-harden when**:
- Hardening is causing problems
- Need to make configuration changes
- Switching to development mode
- Troubleshooting issues

### How to Un-harden

**Step 1: Run wizard**
```bash
sudo /home/hyperd/Documents/Hyper-NixOS/scripts/system-hardening-wizard.sh
```

**Step 2: Select option 5**
```
Select profile (0-5): 5
```

**Step 3: Confirm**
```
This will remove all hardening and restore defaults.
Are you sure? (y/N): y
```

**Step 4: System restored**
```
Removing System Hardening...
⚠️  This will restore default permissions
✓ Hardening removed - system restored to defaults
```

**What happens**:
- File permissions reset to defaults (0755/0644)
- Audit rules cleared
- Firewall rules cleared
- Debug mode disabled
- State file removed

---

## Integration with Privilege Separation

The hardening wizard **works seamlessly** with privilege separation:

### Balanced + Privilege Separation (Recommended)

```nix
# Enable privilege separation
hypervisor.security.privileges = {
  enable = true;
  vmUsers = [ "alice" "bob" ];
  vmOperators = [ "alice" ];
  systemAdmins = [ "admin" ];
  allowPasswordlessVMOperations = true;
};
```

**Then harden with Balanced profile**:
- VM users can still manage VMs (no sudo)
- Operators can still do advanced operations (limited sudo)
- Admins need sudo for system changes
- **Plus**: File permissions are locked down
- **Plus**: Audit logging enabled
- **Plus**: Firewall protecting the system

### Directory Permissions with Privilege Separation

| Directory | Unhardened | Balanced | Strict | Owner:Group |
|-----------|------------|----------|--------|-------------|
| `/etc/hypervisor` | 0755 | 0750 | 0750 | root:wheel |
| `/var/lib/hypervisor/vms` | 0775 | 2775 | 0770 | root:hypervisor-users |
| `/var/lib/hypervisor/images` | 0775 | 2770 | 0770 | root:hypervisor-operators |
| `/var/lib/hypervisor/secure` | 0755 | 0700 | 0700 | root:root |
| `/var/lib/hypervisor/system` | 0755 | 0750 | 0700 | root:hypervisor-admins |

**The setgid bit (2XXX)** ensures new files inherit group ownership.

---

## Command Reference

### Check Current State
```bash
cat /var/lib/hypervisor/hardening-state.json | jq .
```

Output:
```json
{
  "profile": "balanced",
  "timestamp": "2025-01-15T10:30:00-05:00",
  "applied_by": "admin",
  "hostname": "hyper-nixos",
  "version": "1.0.0"
}
```

### List Backups
```bash
ls -lh /var/lib/hypervisor/hardening-backups/
```

### Restore from Backup
```bash
# List backups
ls /var/lib/hypervisor/hardening-backups/

# Copy back a specific backup
sudo cp -r /var/lib/hypervisor/hardening-backups/pre-hardening-YYYYMMDD-HHMMSS/hypervisor/* /etc/hypervisor/
```

### Check Audit Logs
```bash
# All audit events
sudo journalctl -t audit

# Hypervisor-specific
sudo journalctl -t audit | grep hypervisor

# Today's events
sudo journalctl -t audit --since today
```

### Check Firewall Rules
```bash
# NFT (modern)
sudo nft list ruleset

# Iptables (legacy)
sudo iptables -L -v -n
```

### Verify Permissions
```bash
# /etc/hypervisor
ls -lah /etc/hypervisor

# /var/lib/hypervisor
ls -lah /var/lib/hypervisor
find /var/lib/hypervisor -ls
```

---

## Troubleshooting

### Issue: "Permission denied" after hardening

**Cause**: User not in appropriate group

**Solution**:
```bash
# Check groups
groups your-username

# Verify privilege separation is enabled
grep "hypervisor.security.privileges.enable" /etc/nixos/configuration.nix

# If needed, add user to groups
sudo usermod -aG hypervisor-users,libvirtd,kvm your-username

# Logout and login for group changes to take effect
```

### Issue: Can't access VMs after hardening

**Cause**: Polkit rules not applied or user not in libvirtd group

**Solution**:
```bash
# Check polkit rules
ls /etc/polkit-1/rules.d/

# Check libvirt socket permissions
ls -l /var/run/libvirt/libvirt-sock

# Test virsh access
virsh list --all

# If fails, verify privilege separation configuration
```

### Issue: Hardening broke automation scripts

**Cause**: Scripts running as wrong user or missing permissions

**Solution 1: Use Development profile temporarily**
```bash
sudo /home/hyperd/Documents/Hyper-NixOS/scripts/system-hardening-wizard.sh
# Select: 1) Development
```

**Solution 2: Run scripts as proper user**
```bash
# Don't run as root if not needed
# Run as user in hypervisor-users group
```

**Solution 3: Grant specific permissions**
```bash
# For automation user
sudo usermod -aG hypervisor-operators automation-user
```

### Issue: Need to revert hardening

**Solution: Use un-harden**
```bash
sudo /home/hyperd/Documents/Hyper-NixOS/scripts/system-hardening-wizard.sh
# Select: 5) Un-harden
```

---

## Best Practices

### 1. Start with Balanced
- Don't jump straight to Paranoid
- Balanced works for 90% of use cases
- Test thoroughly before going stricter

### 2. Always Test After Hardening
```bash
# Test VM operations
virsh list --all
virt-manager
vm-start test-vm

# Test with regular user (not root)
su - regular-user
virsh list --all

# Check logs
journalctl -xe | tail -20
```

### 3. Keep Backups
- Wizard creates automatic backups
- Keep at least 3 recent backups
- Test backup restoration periodically

### 4. Document Your Choice
Create `/etc/hypervisor/HARDENING_PROFILE.txt`:
```
Hardening Profile: Balanced
Applied: 2025-01-15 10:30:00
By: admin
Reason: Production workstation setup
Notes: All VMs tested and working after hardening
```

### 5. Combine with Privilege Separation
- Enable privilege separation first
- Test that users can access VMs
- Then apply hardening
- Best of both worlds: usability + security

### 6. Use Strict or Paranoid Only When Required
- Compliance requirements (HIPAA, PCI-DSS, etc.)
- Sensitive data handling
- Untrusted network environments
- NOT for general desktop use

### 7. Monitor Audit Logs
```bash
# Set up regular audit log reviews
sudo journalctl -t audit --since "1 day ago" | less

# Or set up alerting (Strict/Paranoid profiles)
```

---

## Security Considerations

### What Hardening Protects Against

✅ **Unauthorized file access**
- Non-admin users can't read sensitive configs
- VM users limited to their areas
- Clear separation of concerns

✅ **Privilege escalation**
- Restrictive permissions prevent lateral movement
- Audit logging detects attempts
- Systemd service hardening limits compromise

✅ **Accidental damage**
- Permissions prevent mistakes
- Backups allow recovery
- State tracking shows what changed

✅ **Insider threats**
- Audit trail for accountability
- Least privilege principle enforced
- Admin actions logged

### What Hardening Does NOT Protect Against

❌ **Kernel exploits**
- Hardening is userspace-level
- Defense: Keep NixOS updated

❌ **VM escape attacks**
- Guest VM breaking out to host
- Defense: Keep QEMU/KVM updated

❌ **Physical access**
- Attacker with physical access has many options
- Defense: Disk encryption, BIOS password, locked server room

❌ **Compromised admin account**
- Admin has full access even with hardening
- Defense: Strong passwords, 2FA, key-based SSH

❌ **Social engineering**
- Tricking admin into running malicious commands
- Defense: User education, careful code review

---

## Comparison: Unhardened vs Hardened

| Feature | Unhardened | Balanced | Strict | Paranoid |
|---------|------------|----------|--------|----------|
| **File Permissions** | 0755/0644 | 0750/0640 | 0750/0600 | 0700/0600 |
| **VM Operations** | ✅ Easy | ✅ Easy | ✅ Easy | ⚠️ Admin only |
| **System Changes** | ⚠️ Easy | ✅ Sudo required | ✅ Sudo required | ✅ Sudo required |
| **Audit Logging** | ❌ None | ❌ None | ✅ Comprehensive | ✅ Maximum |
| **Firewall** | ⚠️ Permissive | ✅ Basic rules | ✅ Restrictive | ✅ Deny-all |
| **Debug Tools** | ✅ Enabled | ✅ Enabled | ⚠️ Limited | ❌ Disabled |
| **Service Hardening** | ❌ None | ❌ None | ✅ Enabled | ✅ Maximum |
| **Usability** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Security** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Recommended For** | Development | Production | Compliance | Classified |

---

## Conclusion

### Quick Decision Guide

**Choose Development if**:
- You're actively developing features
- You need to debug frequently
- System is in a test environment

**Choose Balanced if**: ⭐ **RECOMMENDED**
- You want good security without hassle
- System is used daily for work
- Multi-user workstation or server
- **This is the sweet spot**

**Choose Strict if**:
- Compliance requirements (SOC 2, HIPAA, etc.)
- Production server with sensitive data
- Untrusted network environment
- You understand the trade-offs

**Choose Paranoid if**:
- Military/government/classified data
- Zero-trust environment
- Policy absolutely requires it
- **Only if you MUST have maximum security**

### Summary

The system hardening wizard is a powerful tool for **locking down Hyper-NixOS after setup is complete**. It's:
- ✅ **Admin-only** (requires sudo)
- ✅ **Reversible** (un-harden anytime)
- ✅ **Flexible** (4 profiles for different needs)
- ✅ **Safe** (automatic backups)
- ✅ **Integrated** (works with privilege separation)

**Most users should use the Balanced profile** - it provides excellent security without interfering with normal VM operations.

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
