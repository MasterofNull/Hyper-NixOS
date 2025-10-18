# Privilege Separation in Hyper-NixOS - Complete Guide

## Executive Summary

**Privilege separation is a security feature that separates VM operations from system administration**, allowing users to manage virtual machines **without sudo** while requiring explicit authentication for system-level changes.

**Current Status**: The privilege separation module is **imported by some profiles** but **NOT enabled by default**. You're correct that this should likely be a core feature across all profiles.

---

## What is Privilege Separation?

### The Core Concept

Traditional hypervisor setups have two problems:

**Problem 1: Everything needs sudo**
```bash
sudo virsh start my-vm     # Why do I need sudo for this?
sudo virsh console my-vm   # Or this?
sudo virsh shutdown my-vm  # Or this?
```

**Problem 2: OR everything is passwordless**
```bash
# No password for anything - dangerous!
nixos-rebuild switch       # This SHOULD require confirmation
systemctl restart critical-service  # This too!
```

**Hyper-NixOS Privilege Separation Solution**:
```bash
# VM operations - NO sudo needed
virsh start my-vm          # ✓ Works immediately
virt-manager               # ✓ Opens and manages VMs
vm-start my-gaming-rig     # ✓ Custom scripts work too

# System operations - sudo REQUIRED
sudo nixos-rebuild switch  # ✓ Requires password & confirmation
sudo systemctl restart libvirtd  # ✓ Protected
sudo hypervisor-config     # ✓ Explicit acknowledgment
```

---

## How It Works

### Three-Tier User Model

#### **Tier 1: VM Users** (`vmUsers`)
**Who**: Regular users who need to manage VMs
**What they can do WITHOUT sudo**:
- Start/stop/restart VMs
- Connect to VM consoles
- View VM status
- Basic VM monitoring
- Access VM backups

**What they CANNOT do**:
- Change system configuration
- Modify storage pools
- Create new network bridges
- Install packages

**Example users**: Developers, QA testers, regular workstation users

#### **Tier 2: VM Operators** (`vmOperators`)
**Who**: Power users who need advanced VM operations
**What they can do WITHOUT sudo** (in addition to Tier 1):
- Create/delete VMs
- Manage VM storage
- Take VM snapshots
- Modify VM templates
- Resize VM disks
- Configure VM networks (within defined ranges)

**What they still CANNOT do**:
- Change hypervisor system configuration
- Modify NixOS system
- Install system packages
- Change firewall rules

**Example users**: DevOps engineers, VM administrators, lab managers

#### **Tier 3: System Admins** (`systemAdmins`)
**Who**: Full system administrators
**What they can do WITH sudo**:
- Everything from Tier 1 & 2
- Run `nixos-rebuild` to change system
- Modify system services
- Install/remove packages
- Configure networking at host level
- Security policy changes

**Example users**: Infrastructure admins, security engineers

---

## Technical Implementation

### User Groups Created

| Group | GID | Members | Purpose |
|-------|-----|---------|---------|
| `hypervisor-users` | 2000 | All VM users + operators + admins | Basic VM access |
| `hypervisor-operators` | 2001 | Operators + admins | Advanced VM operations |
| `hypervisor-admins` | 2002 | Admins only | System administration |
| `libvirtd` | (system) | All tiers | libvirt socket access |
| `kvm` | (system) | All tiers | KVM device access |
| `wheel` | (system) | Admins only | sudo access |

### Automatic Group Assignment

When you configure:
```nix
hypervisor.security.privileges = {
  enable = true;
  vmUsers = [ "alice" "bob" ];
  vmOperators = [ "alice" ];
  systemAdmins = [ "admin" ];
};
```

**Alice** gets automatically added to:
- `hypervisor-users` (VM user)
- `hypervisor-operators` (VM operator)
- `hypervisor-admins` (system admin)
- `libvirtd` (VM access)
- `kvm` (virtualization)
- `wheel` (sudo)

**Bob** gets:
- `hypervisor-users`
- `libvirtd`
- `kvm`

**Admin** gets:
- All groups including `wheel` for sudo

### Directory Permissions

| Directory | Owner | Group | Perms | Who Can Access |
|-----------|-------|-------|-------|----------------|
| `/var/lib/hypervisor/vms` | root | hypervisor-users | 2775 | All VM users |
| `/var/lib/hypervisor/backups` | root | hypervisor-users | 2775 | All VM users |
| `/var/lib/hypervisor/snapshots` | root | hypervisor-users | 2775 | All VM users |
| `/var/lib/hypervisor/logs` | root | hypervisor-users | 2775 | All VM users |
| `/var/lib/hypervisor/images` | root | hypervisor-operators | 2775 | Operators+ |
| `/var/lib/hypervisor/templates` | root | hypervisor-operators | 2775 | Operators+ |
| `/etc/hypervisor` | root | hypervisor-admins | 0750 | Admins only |
| `/var/lib/hypervisor/system` | root | hypervisor-admins | 0750 | Admins only |
| `/var/lib/hypervisor/secure` | root | root | 0700 | Root only |

### Polkit Rules (Passwordless VM Operations)

The module creates polkit rules that allow VM operations without passwords:

```javascript
// VM management without password
polkit.addRule(function(action, subject) {
    if ((action.id == "org.libvirt.unix.manage" ||
         action.id == "org.libvirt.unix.monitor") &&
        subject.isInGroup("hypervisor-users")) {
        return polkit.Result.YES;  // No password needed
    }
});

// System operations still need password
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.systemd1.manage") == 0 &&
        !subject.isInGroup("hypervisor-admins")) {
        return polkit.Result.AUTH_ADMIN;  // Password required
    }
});
```

### Sudo Configuration

**VM Operators** get NOPASSWD for specific storage operations:
```bash
# No password needed
sudo mkdir -p /var/lib/libvirt/images/new-vm
sudo chown :libvirtd /var/lib/libvirt/images/my-vm
sudo resize2fs /var/lib/libvirt/images/my-vm-disk.img
```

**System Admins** need password for everything:
```bash
# Password REQUIRED
sudo nixos-rebuild switch
sudo systemctl restart hypervisor-*
sudo hypervisor-config
```

---

## Which Profiles Currently Use It?

### ✅ Currently Importing

1. **configuration.nix** (main config)
   - Imports: Yes (line 62)
   - Enabled: **No** (must explicitly enable)

2. **profiles/configuration-complete.nix**
   - Imports: Yes (line 42)
   - Enabled: **No** (must explicitly enable)

3. **profiles/configuration-privilege-separation.nix**
   - Imports: Yes (line 32)
   - Enabled: **YES** (lines 49-58)
   - **This profile demonstrates full privilege separation**

### ❌ Currently NOT Importing

4. **profiles/configuration-minimal.nix**
   - Missing import
   - **Should add**: Yes (basic security)

5. **profiles/configuration-enhanced.nix**
   - Missing import
   - **Should add**: Yes (enhanced security profile should have this)

6. **profiles/configuration-minimal-recovery.nix**
   - Missing import
   - **Maybe**: Recovery mode might intentionally avoid restrictions

---

## Should ALL Profiles Include This?

### My Recommendation: **YES, but with nuance**

### ✅ Profiles That SHOULD Include Privilege Separation

**1. configuration.nix** (already imports, should enable by default)
```nix
hypervisor.security.privileges = {
  enable = lib.mkDefault true;  # Enable by default
  allowPasswordlessVMOperations = lib.mkDefault true;
};
```

**2. configuration-complete.nix** (already imports, should enable)
- Full-featured setup should include proper security

**3. configuration-enhanced.nix** (MISSING - should add)
- Enhanced security profile absolutely needs this

**4. configuration-minimal.nix** (MISSING - should add)
- Even minimal installs benefit from VM/system separation

**5. configuration-privilege-separation.nix** (already enabled)
- This is the reference implementation

### ⚠️ Profiles That Should Make It OPTIONAL

**6. configuration-minimal-recovery.nix**
- Recovery mode might need emergency root access
- Should import but leave disabled by default
- Can be enabled if needed: `hypervisor.security.privileges.enable = true;`

---

## Configuration Examples

### Example 1: Single-User Workstation (Default for Most Users)

```nix
hypervisor.security.privileges = {
  enable = true;
  vmUsers = [ "john" ];  # Your username
  vmOperators = [ "john" ];  # Also advanced operations
  systemAdmins = [ "john" ];  # Full system control
  allowPasswordlessVMOperations = true;
};
```

**Result**:
- John can manage VMs without sudo
- John needs sudo for `nixos-rebuild` and system changes
- Clear separation between "playing with VMs" vs "changing the system"

### Example 2: Multi-User Lab Environment

```nix
hypervisor.security.privileges = {
  enable = true;

  # Students can use VMs
  vmUsers = [ "alice" "bob" "charlie" "david" ];

  # Lab assistants can manage VMs
  vmOperators = [ "alice" "lab-assistant" ];

  # Only admins can change system
  systemAdmins = [ "professor" "admin" ];

  allowPasswordlessVMOperations = true;
};
```

**Result**:
- 4 students can start/stop/use VMs (no sudo)
- Alice & lab assistant can create/delete VMs (no sudo)
- Only professor and admin can run `nixos-rebuild` (with sudo)

### Example 3: Production Server (Strict Separation)

```nix
hypervisor.security.privileges = {
  enable = true;
  vmUsers = [ "app-user1" "app-user2" ];
  vmOperators = [ "devops-team" ];
  systemAdmins = [ "sysadmin" ];

  # Even VM operations require acknowledgment in production
  allowPasswordlessVMOperations = false;
};

# Also enable audit logging
security.audit.enable = true;
```

**Result**:
- App users can view VMs, need password to start/stop
- DevOps can manage VMs with password
- Sysadmin has full control
- Everything audited

---

## Benefits of Privilege Separation

### Security Benefits

1. **Principle of Least Privilege**
   - Users only get permissions they actually need
   - Reduces attack surface

2. **Explicit System Changes**
   - `sudo` password requirement makes users think before system changes
   - "Am I sure I want to do this?"

3. **Audit Trail**
   - All sudo operations logged
   - VM operations tracked separately
   - Clear accountability

4. **Malware Protection**
   - User-level malware can't silently modify system
   - Needs sudo password for system-level persistence

### Usability Benefits

1. **No Sudo for Common Operations**
   - VM users don't need sudo password every 2 minutes
   - Smooth workflow for VM management

2. **Clear Mental Model**
   - VM stuff = normal operations
   - System stuff = important changes (need sudo)

3. **Multi-User Friendly**
   - Can safely give VM access to multiple users
   - Don't need to give everyone sudo

4. **Scripts Don't Need Sudo**
   - Automation scripts for VM management work seamlessly
   - No password prompts breaking automated workflows

---

## Comparison with Other Hypervisors

### VMware ESXi
- Role-based access control (RBAC)
- Similar concept: VM admins ≠ host admins
- **Hyper-NixOS equivalent**: Privilege separation module

### Proxmox VE
- Users, groups, and permissions
- VM operations separate from system operations
- **Hyper-NixOS equivalent**: Exactly what privilege-separation.nix does

### Traditional Linux/KVM
- Either everything needs sudo, or everything is passwordless
- Usually requires manual polkit rule configuration
- **Hyper-NixOS advantage**: Automatic, declarative, well-organized

---

## Migration Guide

### Adding Privilege Separation to Existing Profile

If you want to add privilege separation to a profile that doesn't have it:

**Step 1**: Add the import
```nix
imports = [
  # ... other imports ...
  ../modules/security/privilege-separation.nix
];
```

**Step 2**: Configure it
```nix
hypervisor.security.privileges = {
  enable = true;
  vmUsers = [ "your-username" ];
  vmOperators = [ "your-username" ];
  systemAdmins = [ "your-username" ];
  allowPasswordlessVMOperations = true;
};
```

**Step 3**: Rebuild
```bash
sudo nixos-rebuild switch
```

**Step 4**: Logout and login (for group membership to take effect)

**Step 5**: Test
```bash
# Should work without sudo:
virsh list --all
virt-manager

# Should require sudo:
sudo nixos-rebuild switch
```

---

## Recommended Changes to Hyper-NixOS

### Proposal: Make Privilege Separation Standard

**Goal**: Include privilege separation in all non-recovery profiles

**Changes Needed**:

1. **Add import to missing profiles**:
   - `profiles/configuration-minimal.nix`
   - `profiles/configuration-enhanced.nix`

2. **Enable by default with sane defaults**:
   ```nix
   hypervisor.security.privileges = {
     enable = lib.mkDefault true;

     # Single-user by default (user must customize for multi-user)
     vmUsers = lib.mkDefault [];
     vmOperators = lib.mkDefault [];
     systemAdmins = lib.mkDefault [];

     allowPasswordlessVMOperations = lib.mkDefault true;
   };
   ```

3. **Wizard integration**:
   - Setup wizard should ask about privilege separation
   - Offer templates: single-user, multi-user, production

4. **Documentation updates**:
   - README should mention privilege model
   - Installation guide should explain user tiers
   - Security documentation should detail polkit rules

---

## Security Considerations

### Attack Scenarios Prevented

**Scenario 1: Compromised VM User Account**
- Attacker gains access to VM user's account
- Can manage VMs but **cannot** modify system
- Cannot install backdoors in NixOS configuration
- Cannot create new system users
- Damage limited to VM operations

**Scenario 2: Malicious Script**
- User runs a malicious script
- Script can manipulate VMs but **cannot** modify system
- Cannot change firewall rules
- Cannot install system packages
- Requires user to manually `sudo` for system changes

**Scenario 3: Accidental Damage**
- User accidentally runs destructive command
- If it's a VM operation: affects VMs only
- If it's a system operation: sudo password prompt prevents accident

### Attack Scenarios NOT Prevented

⚠️ **Important Limitations**:

1. **VM escape attacks**
   - If attacker escapes from VM to host, they may gain VM user privileges
   - Still cannot modify system without sudo password
   - Defense: Keep QEMU/KVM updated

2. **Privilege escalation exploits**
   - If Linux kernel vulnerability exists
   - Attacker might escalate from VM user to root
   - Defense: Keep NixOS updated, use security modules (AppArmor/SELinux)

3. **Social engineering**
   - If user can be tricked into running `sudo malicious-command`
   - Privilege separation cannot help
   - Defense: User education

---

## Troubleshooting

### Issue: "Permission denied" when starting VM

**Check group membership**:
```bash
groups
# Should include: libvirtd kvm hypervisor-users
```

**If missing, add yourself**:
```nix
# In configuration.nix
hypervisor.security.privileges = {
  enable = true;
  vmUsers = [ "your-username" ];  # Add your username here
};
```

**Rebuild and re-login**:
```bash
sudo nixos-rebuild switch
# Then logout and login again
```

### Issue: Sudo still required for VM operations

**Check polkit rules**:
```bash
# Should show passwordless VM operations
cat /etc/polkit-1/rules.d/*hypervisor*.rules
```

**Verify configuration**:
```nix
hypervisor.security.privileges = {
  allowPasswordlessVMOperations = true;  # Make sure this is true
};
```

### Issue: Can't run nixos-rebuild even as admin

**Check wheel group**:
```bash
groups
# Admins should have: wheel
```

**Verify you're in systemAdmins list**:
```nix
hypervisor.security.privileges = {
  systemAdmins = [ "your-username" ];  # Make sure you're here
};
```

---

## Conclusion

### Summary

**Privilege separation is a critical security feature** that should be included in most Hyper-NixOS profiles. It provides:

✅ **Better security** through least privilege
✅ **Better usability** for VM operations
✅ **Clear separation** between VM work and system changes
✅ **Multi-user support** out of the box

### Current State

- ✅ Module exists and works well
- ⚠️ Only imported by 3 out of 6 profiles
- ❌ Not enabled by default even where imported

### Recommendation

**Add privilege-separation.nix to ALL profiles except recovery**, with:
- Enabled by default: `enable = lib.mkDefault true;`
- Sane single-user defaults
- Clear documentation for multi-user setups
- Wizard integration for easy configuration

Your assumption is **correct**: This feature should be foundational to Hyper-NixOS, not just an optional profile.

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
