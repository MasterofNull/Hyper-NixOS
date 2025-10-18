# Hibernation & Authentication Management

## Overview

Hyper-NixOS provides **intelligent hibernation and authentication** that prevents user lockouts while maintaining security. The system is context-aware and adapts to:

- Headless VMs (no password prompts)
- Desktop environments (secure screen locking)
- Laptops with power management
- Servers without user interaction
- Embedded systems and SBCs

## The Problem

**Traditional NixOS hibernation issues**:

1. **User Lockouts**: System requires password on resume, but users have no passwords set
2. **Headless Systems**: Can't enter password on resume (no display/keyboard)
3. **VM Environments**: Password prompts don't make sense for automated VMs
4. **Inconsistent Behavior**: Desktop vs headless have different needs

## The Solution

Hyper-NixOS implements **context-aware authentication**:

```
IF (headless system OR no users have passwords):
    → Allow resume without password
ELSE IF (desktop system AND users have passwords):
    → Require password on resume
ELSE:
    → Intelligent fallback based on configuration
```

## Features

### 1. Automatic Swap Detection

The system automatically:
- Detects all swap devices and files
- Selects the largest swap for hibernation
- Configures `boot.resumeDevice` automatically
- Verifies swap is large enough (≥ RAM size)

### 2. Context-Aware Authentication

**Headless Systems** (VMs, servers without GUI):
- ✅ Resume without password prompt
- ✅ Auto-login for single-user systems
- ✅ No screen locking
- ✅ Prevents lockouts

**Desktop Systems** (with GUI):
- ✅ Lock screen on suspend/resume
- ✅ Require password if users have passwords
- ✅ Secure authentication
- ✅ Optional auto-login for testing

### 3. Lockout Prevention

Active measures to prevent lockouts:
- Detect users without passwords
- Disable password requirements for those users
- Warn administrators about configuration issues
- Provide auto-login fallback
- Allow emergency access

### 4. Power Management

Intelligent power states:
- **Suspend-to-RAM** (sleep) - Fast resume, requires power
- **Hibernate** (suspend-to-disk) - Slow resume, no power needed
- **Hybrid Sleep** - Both RAM and disk
- **Suspend-then-Hibernate** - Sleep first, then hibernate after timeout

## Configuration

### Basic Configuration

```nix
# In configuration.nix
hypervisor.hibernation = {
  enable = true;                    # Enable hibernation support (default: true)
  autoDetectSwap = true;            # Auto-detect swap device (default: true)
  requirePassword = "auto";         # Password requirement (default: "auto")
  allowHeadlessResume = true;       # Allow headless resume (default: true)
  suspendToRamEnabled = true;       # Enable suspend-to-RAM (default: true)
  preventUserLockout = true;        # Prevent lockouts (default: true)
};
```

### Password Requirement Options

```nix
hypervisor.hibernation.requirePassword = "auto";  # Recommended
```

Options:
- **`"auto"`** (default) - Require password only if users have passwords set
- **`"always"`** - Always require password (may lock out users!)
- **`"never"`** - Never require password (security risk on desktops!)
- **`"desktop-only"`** - Require password only on systems with GUI

### Examples

#### Example 1: Headless VM

```nix
# Headless VM with no passwords
hypervisor.hibernation = {
  enable = true;
  requirePassword = "auto";         # Detects no passwords → no prompt
  allowHeadlessResume = true;       # Allows resume without interaction
  preventUserLockout = true;        # Active lockout prevention
};
```

**Result**: Resume works without any user interaction.

#### Example 2: Desktop Laptop

```nix
# Laptop with desktop environment and passwords
hypervisor.hibernation = {
  enable = true;
  requirePassword = "auto";         # Detects passwords → requires password
  suspendToRamEnabled = true;       # Enable sleep mode
};
```

**Result**: Lock screen appears on resume, requires password.

#### Example 3: Server

```nix
# Server with no GUI but admin passwords
hypervisor.hibernation = {
  enable = true;
  requirePassword = "never";        # Override for automated resume
  allowHeadlessResume = true;
};
```

**Result**: Resume works automatically even though passwords exist.

## Commands

### Check Hibernation Status

```bash
hv-hibernation-status
```

Output:
```
=== Hyper-NixOS Hibernation Status ===

Desktop Environment: No (headless)
Users with Passwords: 0
Password Required on Resume: No

Suspend-to-RAM: Enabled
Hibernation: Enabled
Auto Swap Detection: Enabled

Lockout Prevention: Enabled

⚠ WARNING: No users have passwords set!

To prevent lockouts:
1. Set passwords: sudo passwd <username>
2. Or keep preventUserLockout = true (current setting)

Headless systems without passwords will auto-resume without prompts.
```

### Test Suspend

```bash
# Test suspend for 10 seconds (requires root)
sudo hv-test-suspend
```

### Manual Hibernation

```bash
# Hibernate immediately
sudo systemctl hibernate

# Suspend to RAM (sleep)
sudo systemctl suspend

# Hybrid sleep
sudo systemctl hybrid-sleep

# Suspend then hibernate after timeout
sudo systemctl suspend-then-hibernate
```

### Check Swap

```bash
# View swap devices
swapon --show

# Check swap size vs RAM
free -h
```

## Swap Configuration

### Automatic Detection

By default, swap is auto-detected:

```nix
hypervisor.hibernation.autoDetectSwap = true;  # default
```

The system:
1. Finds all active swap devices
2. Selects the largest one
3. Sets `boot.resumeDevice` automatically
4. Verifies size is sufficient (≥ RAM)

### Manual Swap Configuration

If auto-detection fails:

```nix
# Disable auto-detection
hypervisor.hibernation.autoDetectSwap = false;

# Manually specify resume device
boot.resumeDevice = "/dev/disk/by-uuid/YOUR-SWAP-UUID";

# Or by device path
boot.resumeDevice = "/dev/sda2";
```

### Creating Swap

If you don't have swap:

```bash
# Create swap file (8GB example)
sudo dd if=/dev/zero of=/swapfile bs=1M count=8192
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent in configuration.nix
```

```nix
swapDevices = [ { device = "/swapfile"; } ];
```

### Swap Size Recommendations

For hibernation, swap must be ≥ RAM size:

| RAM Size | Recommended Swap |
|----------|------------------|
| 4GB      | 4GB minimum      |
| 8GB      | 8GB minimum      |
| 16GB     | 16GB minimum     |
| 32GB+    | Equal to RAM     |

For laptops, add extra for suspend-then-hibernate:
- RAM + 2GB for safety

## User Password Management

### Checking Passwords

```bash
# Check if a user has a password
sudo passwd -S username

# Output:
# username P ...  = password set
# username NP ... = no password
```

### Setting Passwords

```bash
# Set password for user
sudo passwd username

# In configuration.nix (declarative)
users.users.username = {
  hashedPassword = "...";  # Generate with: mkpasswd -m sha-512
};
```

### Auto-Login (Testing Only)

```nix
# Enable auto-login for single user (be careful!)
services.getty.autologinUser = "username";

# Or for display manager
services.xserver.displayManager.autoLogin = {
  enable = true;
  user = "username";
};
```

**⚠ Warning**: Auto-login bypasses all authentication!

## Power Management

### Laptop Power Modes

On laptops, the system automatically:

1. **Lid Closed** → Suspend to RAM
2. **Battery Low** → Hibernate
3. **Suspend > 30min** → Automatically hibernate (saves battery)

Configure timeout:

```nix
systemd.sleep.extraConfig = ''
  HibernateDelaySec=30min  # Hibernate after 30min of suspend
'';
```

### Desktop Power Modes

On desktops:

1. **Sleep** → Suspend to RAM (if supported)
2. **Shutdown** → Normal shutdown
3. **Hibernate** → Manual only (usually)

### Server Power Modes

Servers typically:

1. **Run 24/7** → No automatic suspend
2. **Manual Hibernate** → For maintenance windows
3. **UPS Integration** → Hibernate on power loss

## Troubleshooting

### Issue: Resume Hangs at Password Prompt

**Cause**: System requires password but user has none set

**Solution**:
```nix
hypervisor.hibernation = {
  requirePassword = "never";
  preventUserLockout = true;
};
```

Or set a password:
```bash
sudo passwd your-username
```

### Issue: Can't Hibernate (No Swap)

**Cause**: No swap configured or swap too small

**Check**:
```bash
swapon --show
free -h
```

**Solution**: Create swap file or partition (see above)

### Issue: Resume Fails

**Causes**:
1. Wrong resume device
2. Swap device changed
3. initrd doesn't have resume support

**Check**:
```bash
# Check resume device setting
cat /sys/power/resume

# Check kernel parameters
cat /proc/cmdline | grep resume

# Test swap
sudo swapoff -a
sudo swapon -a
```

**Solution**:
```nix
# Rebuild with verbose logging
sudo nixos-rebuild switch --show-trace

# Check logs
journalctl -b | grep -i resume
```

### Issue: Screen Stays Locked After Resume

**Cause**: Lock screen requires password but you can't remember it

**Solution 1**: Reset password from TTY
```bash
# Press Ctrl+Alt+F2 to switch to TTY
# Login as root
passwd your-username
```

**Solution 2**: Disable lock screen
```nix
hypervisor.hibernation.requirePassword = "never";
```

### Issue: Headless System Won't Resume

**Cause**: System waiting for password input on invisible console

**Solution**:
```nix
hypervisor.hibernation = {
  allowHeadlessResume = true;
  requirePassword = "never";
};
```

## Security Considerations

### Headless Systems

**Risk**: No password on resume = anyone with physical access can use system

**Mitigation**:
- Encrypt root filesystem (LUKS)
- Physical security (locked server room)
- Network-level authentication
- Disable hibernation entirely for high-security

### Desktop Systems

**Risk**: Unlocked desktop after resume

**Mitigation**:
- Always set user passwords
- Enable screen locking
- Use `requirePassword = "auto"` or `"always"`
- Consider full-disk encryption

### VM Environments

**Risk**: VMs don't need passwords, but host might

**Solution**:
- Host: Strong passwords + encryption
- VMs: Passwordless + auto-resume
- Separate configs for host and VMs

## Best Practices

### 1. Use Auto Mode

```nix
hypervisor.hibernation.requirePassword = "auto";
```

This intelligently handles all scenarios.

### 2. Set Passwords for Interactive Systems

Any system with a keyboard/display should have passwords:

```bash
sudo passwd admin
```

### 3. Encrypt Sensitive Systems

Hibernation writes RAM to disk. For sensitive data:

```nix
# Enable LUKS encryption
boot.initrd.luks.devices."root" = {
  device = "/dev/disk/by-uuid/...";
  preLVM = true;
};
```

### 4. Test Before Production

```bash
# Test suspend/resume cycle
sudo systemctl suspend
# Wait, then press power button

# Test hibernation
sudo systemctl hibernate
# Power off, power on, should resume
```

### 5. Monitor Logs

```bash
# Check for resume errors
journalctl -b -1 | grep -i resume

# Check power management
journalctl -u systemd-suspend
journalctl -u systemd-hibernate
```

## Integration with Other Modules

### Works With

- **universal-hardware-detection.nix** - Detects swap devices
- **laptop.nix** - Battery-aware power management
- **security modules** - Respects password policies
- **GUI modules** - Integrates with display managers

### Provides

- Context-aware authentication
- Automatic swap configuration
- Lockout prevention
- Power management scripts

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
