# Comprehensive Credential Security Guide

## Overview

This guide covers all available security features for protecting credentials during first boot and ongoing operations in Hyper-NixOS.

## Quick Start

### 1. Choose Your Security Profile

Add to your `configuration.nix`:

```nix
{
  hypervisor.security.credentialSecurity = {
    enable = true;
    profile = "enhanced";  # Options: "basic", "enhanced", "paranoid"
  };
}
```

### Security Profiles

#### Basic Profile
- ✅ Secure password input with memory locking
- ✅ Password complexity enforcement
- ✅ Time-limited first boot window
- ✅ Encrypted credential transfer
- 📝 **Best for**: Development environments, home labs

#### Enhanced Profile (Recommended)
- ✅ All basic features plus:
- ✅ Physical presence verification
- ✅ TPM2 encryption (when available)
- ✅ Encrypted credential storage
- ✅ Anti-tampering detection
- 📝 **Best for**: Production environments, small businesses

#### Paranoid Profile
- ✅ All enhanced features plus:
- ✅ Hardware authentication required (FIDO2/U2F)
- ✅ Split secret implementation
- ✅ Aggressive anti-tampering with auto-lockdown
- ✅ Strict time windows and business hours
- ✅ Weekly credential rotation
- 📝 **Best for**: High-security environments, compliance requirements

## Feature Details

### 1. Secure Credential Transfer

Instead of storing credentials in `/tmp`, we use encrypted, memory-only storage:

```nix
hypervisor.security.credentialTransfer = {
  enable = true;
  method = "auto";  # auto-detects TPM2, falls back to software
};
```

**How it works**:
- TPM2 sealing: Credentials sealed to boot state (PCRs 0,1,2,3,7)
- Software fallback: AES-256-GCM with ephemeral keys
- Automatic secure deletion after use

### 2. Memory-Locked Password Input

Prevents passwords from being swapped to disk:

```nix
hypervisor.security.memoryLockedInput = {
  enable = true;
  minLength = 12;
  requiredClasses = 3;  # upper, lower, digit, special
  checkDictionary = true;
  checkEntropy = true;
  hashRounds = 100000;
};
```

**Features**:
- Memory pages locked with `mlockall()`
- Automatic terminal echo disable
- Real-time strength feedback
- Dictionary attack prevention

### 3. Physical Presence Verification

Ensures first boot happens at the console:

```nix
hypervisor.security.physicalPresence = {
  enable = true;
  required = true;
  verificationMethod = "random-code";  # or "math-problem", "hardware-action"
  requireVisualChallenge = true;
  allowUSBKey = true;  # FIDO2 as alternative
};
```

**Verification methods**:
- Random code entry
- Visual pattern matching
- Reaction time test
- USB security key touch

### 4. Anti-Tampering Protection

Detects system compromise attempts:

```nix
hypervisor.security.antiTampering = {
  enable = true;
  warningThreshold = 30;   # Warning score
  criticalThreshold = 60;  # Lockdown score
  enableLockdown = true;   # Auto-lockdown on critical
  checkInterval = "5min";
};
```

**Checks performed**:
- Debugger detection
- Kernel module integrity
- Environment tampering (LD_PRELOAD)
- File integrity monitoring
- Process anomalies
- Network suspicious activity
- Boot security status

### 5. Time Window Enforcement

Limits when sensitive operations can occur:

```nix
hypervisor.security.timeWindow = {
  enable = true;
  firstBootWindow = 3600;    # 1 hour in seconds
  enforceBusinessHours = true;
  businessHoursStart = 8;    # 8 AM
  businessHoursEnd = 18;     # 6 PM
  allowWeekends = false;
};
```

**Features**:
- Installation time tracking
- Business hours enforcement
- Maintenance window support
- Grace period extensions (with auth)

### 6. Hardware Authentication

Support for physical security tokens:

```nix
hypervisor.security.hardwareAuth = {
  enable = true;
  fido2 = {
    enable = true;
    required = true;  # Mandatory for paranoid profile
  };
  tpm2 = {
    enable = true;
    pcrBanks = [ 0 1 2 3 7 ];
  };
  smartcard.enable = false;  # Optional
};
```

**Supported devices**:
- FIDO2/U2F keys (YubiKey, Solo, Titan)
- TPM2 chips (most modern laptops)
- Smart cards (CAC, PIV)

### 7. Encrypted Credential Storage

Secure storage for passwords and keys:

```nix
hypervisor.security.encryptedStorage = {
  enable = true;
  backend = "both";  # "vault", "systemd-creds", or "both"
  autoRotation = {
    enable = true;
    interval = "monthly";
  };
};
```

**Features**:
- SQLite vault with AES-256-GCM
- systemd-creds with TPM2 sealing
- Automatic expiration
- Audit logging
- Key rotation

### 8. Split Secret Implementation

Distribute admin password across multiple locations:

```nix
hypervisor.security.splitSecret = {
  enable = true;
  threshold = 2;  # Need 2 shares to reconstruct
  shares = 3;     # Generate 3 total shares
  autoSplit = true;
};
```

**Share storage locations**:
1. Boot partition
2. System partition  
3. QR code for printing
4. USB key (optional)
5. Network storage (encrypted)

## Usage Examples

### First Boot with Enhanced Security

1. **Boot the system** - Physical console required
2. **Security checks** run automatically:
   ```
   ✓ System integrity verified
   ✓ Time window valid (45 minutes remaining)
   ✓ Physical console detected: /dev/tty1
   ```

3. **Physical presence verification**:
   ```
   Challenge: ABC123
   Enter code: ABC123
   ✓ Physical presence verified
   ```

4. **Create admin with secure password**:
   ```
   Admin password: ************
   Confirm password: ************
   Strength: STRONG (Score: 85/100)
   ✓ Password validated
   ```

5. **Hardware auth setup** (if enabled):
   ```
   Found devices:
   ✓ FIDO2/U2F security key detected
   
   Please touch your security key when it blinks...
   ✓ Enrollment complete!
   ```

### Managing Credentials

```bash
# Store a credential securely
credential-vault store "database-admin" "dbadmin" "StrongP@ssw0rd!" "Production DB"

# Retrieve a credential
credential-vault get "database-admin"

# List all credentials
credential-vault list

# Rotate a password
credential-vault rotate "database-admin" "NewStr0ngP@ssw0rd!"

# View audit log
credential-vault audit
```

### Emergency Recovery

If locked out due to security measures:

1. **Boot into recovery mode** (single user)
2. **Reset anti-tampering**:
   ```bash
   anti-tamper-check reset
   ```
3. **Extend time window**:
   ```bash
   extend-time-window "Emergency recovery"
   ```
4. **Reconstruct split secret** (if enabled):
   ```bash
   split-secret reconstruct
   # Enter 2 of 3 shares when prompted
   ```

## Best Practices

### For Administrators

1. **Test your profile** in a VM before production
2. **Document share locations** for split secrets
3. **Keep backup authentication** methods:
   - Backup FIDO2 key
   - Recovery codes
   - Split secret shares
4. **Monitor security logs**:
   ```bash
   journalctl -u anti-tamper-check
   tail -f /var/log/hypervisor/tamper-detection.log
   ```

### For High Security

1. **Use paranoid profile** for sensitive environments
2. **Require multiple factors**:
   - Password + FIDO2 key
   - TPM2 + Physical presence
3. **Implement separation**:
   - Different admins hold different secret shares
   - Time-based access controls
4. **Regular rotation**:
   - Monthly password changes
   - Quarterly key rotation

### For Development

1. **Use basic profile** to avoid lockouts
2. **Disable time windows** during testing:
   ```nix
   hypervisor.security.timeWindow.enable = false;
   ```
3. **Keep logs verbose** for debugging

## Troubleshooting

### "Time window expired"
```bash
# Check installation time
stat -c %Y /etc/machine-id | xargs -I{} date -d @{}

# If legitimate, use recovery mode to extend
```

### "Physical presence verification failed"
- Ensure you're on a physical console (not SSH)
- Try Ctrl+Alt+F1 to switch to primary console
- Check if USB security key is properly inserted

### "Anti-tampering lockdown activated"
1. Boot into recovery mode
2. Check tampering log:
   ```bash
   cat /var/log/hypervisor/tamper-detection.log
   ```
3. Reset if false positive:
   ```bash
   anti-tamper-check reset
   ```

### "Cannot decrypt credentials"
- Check if TPM2 PCRs have changed (new kernel?)
- Verify systemd-creds keys:
  ```bash
  systemd-creds list
  ```
- Use backup decryption method

## Security Considerations

### Trade-offs

| Feature | Security Benefit | Usability Impact |
|---------|-----------------|------------------|
| Physical Presence | Prevents remote attacks | Requires console access |
| Time Windows | Limits attack window | May cause delays |
| Hardware Auth | Strong authentication | Requires hardware tokens |
| Split Secrets | No single point of failure | Complex recovery |
| Anti-Tampering | Detects compromises | May have false positives |

### Compliance

The paranoid profile helps meet:
- **NIST 800-63B** - Authentication requirements
- **PCI DSS 8.3** - Strong cryptography
- **HIPAA § 164.312** - Access controls
- **SOC 2 Type II** - Security controls

## Conclusion

Hyper-NixOS provides flexible credential security from basic to paranoid levels. Choose the profile that matches your security requirements and operational constraints. Remember: security is about layers - even the basic profile significantly improves credential protection over default configurations.