# First Boot Security Model

## Overview

Hyper-NixOS uses a secure first-boot configuration system that allows initial setup without pre-configured passwords while maintaining security through multiple protection layers.

## Security Protections

### 1. **First Boot Detection**

The wizard includes multiple checks to ensure it only runs on truly unconfigured systems:

```bash
# Check 1: First boot flag
if [[ -f "/var/lib/hypervisor/.first-boot-complete" ]]; then
    # System already configured - EXIT
fi

# Check 2: Custom user configuration
if [[ -f "/etc/nixos/modules/users-local.nix" ]]; then
    # Installer already configured users - EXIT
fi

# Check 3: Existing passwords
if [[ $USERS_WITH_PASSWORDS -gt 0 ]]; then
    # Warn and require explicit confirmation
fi
```

### 2. **Systemd Service Conditions**

The service won't start if:
- First boot flag exists (`ConditionPathExists = "!/var/lib/hypervisor/.first-boot-complete"`)
- Custom user config exists (`ConditionPathExists = "!/etc/nixos/modules/users-local.nix"`)

### 3. **One-Time Execution**

Once run successfully:
- Creates `/var/lib/hypervisor/.first-boot-complete` flag
- Disables `hypervisor.firstBoot.autoStart` in configuration
- Service won't run again even after reboot

### 4. **TTY-Only Execution**

- Requires physical or console access (TTY)
- Cannot be run over SSH or remote connections
- Prevents remote exploitation

## Configuration Flow

```
System Boot
    ↓
Check Conditions:
- No first-boot flag?
- No users-local.nix?
- allowNoPasswordLogin = true?
    ↓ All Yes
Start First Boot Wizard
    ↓
Security Checks:
- Already configured? → EXIT
- Passwords exist? → WARN
    ↓
Set Admin Passwords
    ↓
Configure System Tier
    ↓
Create Completion Flag
    ↓
Normal Operation
```

## Security Considerations

### Why This is Safe

1. **Physical Access Required**: TTY-only prevents remote attacks
2. **Multiple Guards**: Several checks prevent re-execution
3. **Explicit Flag**: `allowNoPasswordLogin` must be explicitly set
4. **Limited Window**: Only works on first boot
5. **Audit Trail**: All actions logged to systemd journal

### Potential Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Someone boots unconfigured system | Physical security, BIOS passwords |
| Flag file deleted | Wizard checks for existing passwords |
| Service re-enabled | Multiple condition checks |
| Remote exploitation | TTY-only requirement |

## Best Practices

### For Deployment

1. **Pre-configure when possible**: Use installer with users-local.nix
2. **Physical security**: Secure server rooms during initial setup
3. **Quick configuration**: Run setup immediately after installation
4. **Remove after setup**: Consider removing `allowNoPasswordLogin` after configuration

### For Production

```nix
# After first boot, consider updating configuration:
users = {
  mutableUsers = false;
  # allowNoPasswordLogin = true;  # Comment out or remove
};
```

## Manual Override

If you need to reconfigure the system tier later:

```bash
# Safe reconfiguration tool
sudo /etc/hypervisor/bin/reconfigure-tier
```

This tool:
- Requires sudo authentication
- Prompts for confirmation
- Doesn't bypass password requirements

## Comparison with Alternatives

| Method | Security | Convenience | Use Case |
|--------|----------|-------------|----------|
| Pre-set password in config | Low (visible in git) | High | Development only |
| Cloud-init | Medium | High | Cloud deployments |
| Manual post-install | High | Low | High-security environments |
| **First-boot wizard** | **High** | **High** | **Recommended** |

## Audit Logging

All first-boot activities are logged:

```bash
# View first-boot logs
journalctl -u hypervisor-first-boot

# Check if first-boot was completed
ls -la /var/lib/hypervisor/.first-boot-complete
```

## Summary

The first-boot security model provides a balance between:
- **Security**: Multiple protection layers prevent misuse
- **Usability**: No need to pre-configure passwords
- **Flexibility**: Works with various deployment methods

This approach aligns with Hyper-NixOS's two-phase security model: permissive during setup, hardened for production.