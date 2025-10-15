# Sudo Security Measures in Hyper-NixOS

## Overview

Hyper-NixOS implements multiple layers of security to prevent unauthorized sudo password resets and protect administrative access.

## Security Layers

### 1. **First-Boot One-Time Execution**

The first-boot wizard can only run once:
- Creates `/var/lib/hypervisor/.first-boot-complete` flag
- Systemd service checks for this flag
- Cannot be re-run without removing the flag (which requires root)

### 2. **Sudo Configuration Lockdown**

After first boot, sudo configuration is locked:
```bash
# Files made immutable with chattr +i:
/etc/sudoers
/etc/sudoers.d/*
```

This prevents:
- Editing sudo rules
- Adding NOPASSWD entries
- Bypassing password requirements

### 3. **Physical Presence Requirements**

Password changes require physical console access:
- Must be on TTY1-TTY6 (not SSH)
- PAM module checks for physical presence
- Remote password resets are blocked

### 4. **Integrity Monitoring**

System monitors sudo configuration integrity:
```bash
# SHA256 hashes stored in:
/var/lib/hypervisor/.sudo-integrity

# Audit rules monitor:
- /etc/sudoers changes
- /etc/sudoers.d/ changes
- passwd command execution
- sudo command execution
```

### 5. **Break-Glass Procedures**

For legitimate password resets, three methods exist:

#### Method 1: Recovery Mode
```bash
# Add to kernel parameters at boot:
recovery

# Then use:
/etc/hypervisor/bin/sudo-password-reset
```

#### Method 2: Installation Media
1. Boot from Hyper-NixOS installation media
2. Mount the system
3. Chroot and reset passwords

#### Method 3: Break-Glass Token
- Requires pre-generated token based on machine ID
- Only works from physical console
- All attempts logged

### 6. **Sudo Security Configuration**

The sudo configuration enforces:
```sudoers
# No password-free sudo
Defaults    !authenticate  # DISABLED

# Short timeout
Defaults    timestamp_timeout=15

# Comprehensive logging
Defaults    log_input
Defaults    log_output
Defaults    logfile="/var/log/sudo.log"

# TTY requirement
Defaults    requiretty
Defaults    use_pty

# Password commands blocked via sudo
%wheel ALL=(ALL:ALL) ALL, !PASSWD_CMDS
```

### 7. **Audit Trail**

All security events are logged:
- Sudo attempts → `/var/log/sudo.log`
- PAM authentication → `journalctl -u systemd-logind`
- Audit events → `ausearch -k sudo_exec`
- Break-glass attempts → `journalctl -p warning`

## Attack Scenarios & Mitigations

### Scenario 1: Attacker Gains User Access
**Attack**: Try to re-run first-boot wizard
**Mitigation**: 
- First-boot flag prevents re-execution
- Sudo locked flag prevents changes
- Would need root to remove flags

### Scenario 2: Attacker Has Physical Access
**Attack**: Boot into single-user mode
**Mitigation**:
- Set BIOS/UEFI password
- Enable Secure Boot
- Encrypt root filesystem
- Physical security for servers

### Scenario 3: Attacker Tries Remote Reset
**Attack**: SSH in and attempt password change
**Mitigation**:
- PAM blocks non-TTY password changes
- Sudo configuration prevents passwd via sudo
- Physical presence required

### Scenario 4: Attacker Modifies Files
**Attack**: Try to edit /etc/sudoers
**Mitigation**:
- Files are immutable (chattr +i)
- Changes require root access
- Integrity monitoring detects changes

## Best Practices

### Initial Setup
1. Run first-boot wizard immediately after installation
2. Set strong, unique passwords for admin users
3. Document break-glass token securely
4. Test sudo access before lockdown

### Ongoing Security
1. Monitor audit logs regularly:
   ```bash
   # Check sudo usage
   aureport -x --summary
   
   # Check authentication failures
   journalctl -p warning -u systemd-logind
   ```

2. Regular security reviews:
   ```bash
   # Verify sudo configuration integrity
   sha256sum -c /var/lib/hypervisor/.sudo-integrity
   
   # Check for unauthorized changes
   ausearch -k sudoers_changes
   ```

3. Update procedures:
   - System updates don't modify sudo config
   - Configuration changes require recovery mode

### Emergency Access

If locked out:
1. **First Option**: Use break-glass token from physical console
2. **Second Option**: Boot into recovery mode
3. **Last Resort**: Boot from installation media

Always document the reason for emergency access in:
```bash
/var/log/hypervisor/emergency-access.log
```

## Configuration Example

```nix
# In configuration.nix
hypervisor.security.sudoProtection = {
  enable = true;                    # Enable all protections
  lockdownAfterBoot = true;        # Lock sudo config after first boot
  requirePhysicalPresence = true;   # Require console for changes
};
```

## Compliance

These measures help meet:
- **PCI DSS 8.2.1**: Strong password requirements
- **NIST 800-53 AC-6**: Least privilege
- **CIS Benchmark 5.3**: Sudo configuration
- **ISO 27001 A.9.4.3**: Password management

## Summary

The multi-layered approach ensures:
1. ✅ Initial passwords must be set during first boot
2. ✅ Sudo passwords cannot be reset without proper authorization
3. ✅ All password changes are logged and audited
4. ✅ Physical presence required for administrative changes
5. ✅ Break-glass procedures available for emergencies
6. ✅ Configuration integrity is monitored

This creates a secure system where administrative access is protected while maintaining usability for legitimate operations.