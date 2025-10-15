# Credential Chain Security System

## Overview

Hyper-NixOS implements a secure credential chain that migrates user credentials from the host system while preventing unauthorized tampering and password resets.

## Architecture

```
Host System                    Hyper-NixOS Installation
    │                                    │
    ├─ User Credentials ─────────────>  ├─ Credential Import
    │  (username/password)              │  (with integrity check)
    │                                   │
    └─ Integrity Hash ──────────────>  ├─ Hash Verification
                                        │  (tamper detection)
                                        │
                                        └─ First Boot Decision
                                           ├─ Valid: Skip password setup
                                           └─ Tampered: Lock system
```

## Security Features

### 1. **Credential Migration**

The system can securely migrate credentials from the host:

```bash
# On host system before installation
sudo ./scripts/migrate-host-credentials.sh
```

This creates:
- Encrypted credential package with user info
- Cryptographic hash for integrity verification
- Metadata about source system

### 2. **Integrity Verification**

On every boot, the system verifies:
- Shadow file hasn't been modified
- Passwd file matches expected state
- Machine ID is consistent
- No unauthorized changes occurred

If tampering is detected:
- First-boot wizard is disabled
- Security alert is logged
- System enters lockdown mode

### 3. **Tamper Detection**

The system monitors for:
- Manual password changes outside approved methods
- Shadow/passwd file modifications
- Unauthorized user additions
- Group membership changes

### 4. **Secure Password Reset**

Only three approved methods for password reset:

#### Method 1: Secure Reset Tool
```bash
# From physical console only
sudo /etc/hypervisor/scripts/secure-password-reset.sh
```

Requires:
- Physical TTY access (no SSH)
- Administrator authentication
- Security challenge answers

#### Method 2: Recovery Mode
- Boot with 'recovery' kernel parameter
- Use recovery environment tools
- All actions logged

#### Method 3: Break-Glass Token
- Pre-generated daily token
- Based on machine ID
- Requires physical presence

## Workflow

### Initial Installation

1. **Host Preparation**:
   ```bash
   # Run on host system
   sudo ./scripts/migrate-host-credentials.sh
   ```

2. **Installation**:
   - Installer detects credential package
   - Imports user with existing password
   - Creates integrity hash

3. **First Boot**:
   - Detects migrated credentials
   - Skips password setup
   - Only configures system tier

### Normal Operation

1. **Boot Process**:
   - `credential-integrity-check.service` runs
   - Verifies no tampering occurred
   - Sets appropriate flags

2. **First-Boot Decision**:
   ```
   if (tamper_detected):
       → Lock system, alert admin
   elif (credentials_migrated):
       → Skip password setup
   elif (no_passwords_exist):
       → Run full first-boot
   else:
       → Normal boot
   ```

### Password Changes

1. **Legitimate Change**:
   - Use secure reset tool
   - Provides authentication
   - Updates integrity hash

2. **Unauthorized Change**:
   - Detected on next boot
   - Triggers tamper flag
   - Locks first-boot access

## Security Model

### Trust Chain

```
Physical Security (BIOS/UEFI)
         ↓
Boot Loader (Secure Boot)
         ↓
Kernel (Integrity checked)
         ↓
Credential Chain Module
         ↓
User Authentication
```

### Threat Mitigation

| Threat | Mitigation |
|--------|------------|
| Password reset via first-boot | Tamper detection prevents re-run |
| Manual shadow file edit | Integrity hash detects changes |
| Boot from USB to reset | Secure Boot + disk encryption |
| Social engineering | Physical presence + challenges |
| Credential package tampering | Cryptographic verification |

## Configuration

### Enable Credential Chain

```nix
# In configuration.nix
hypervisor.security.credentialChain = {
  enable = true;
  enforceIntegrity = true;
  triggerOnTamper = "both";  # lock and alert
};
```

### Security Options

- `enable`: Enable the credential chain system
- `enforceIntegrity`: Strict integrity checking
- `triggerOnTamper`: Actions on tamper detection
  - `"lock"`: Lock the system
  - `"alert"`: Send security alerts
  - `"both"`: Lock and alert

## Monitoring

### Check System Status

```bash
# Verify credential integrity
sudo verify-credentials check

# View tamper flag (if exists)
cat /var/lib/hypervisor/.tamper-detected

# Check security log
sudo journalctl -u credential-integrity-check
```

### Audit Events

All security events are logged:
```bash
# Credential changes
ausearch -k credential_changes

# Integrity checks
ausearch -k credential_integrity

# Security alerts
ausearch -k security_alert
```

## Emergency Procedures

### If Locked Out

1. **Check for tamper flag**:
   - Boot from live media
   - Mount system partition
   - Check `/var/lib/hypervisor/.tamper-detected`

2. **Verify legitimate lockout**:
   - Review security logs
   - Check for unauthorized access
   - Verify no actual tampering

3. **Reset if legitimate**:
   - Use secure reset tool
   - Document the incident
   - Update security procedures

### Break-Glass Token

Generate for emergency access:
```bash
# Generate daily token (run on different system)
echo -n "MACHINE_ID:$(date +%Y%m%d):hypervisor-reset" | sha256sum
```

Keep securely stored and update daily.

## Best Practices

### For Administrators

1. **Document credentials**:
   - Keep secure record of migrated users
   - Note source systems
   - Track password policies

2. **Monitor integrity**:
   ```bash
   # Daily check
   sudo verify-credentials check
   ```

3. **Prepare for emergencies**:
   - Generate break-glass tokens
   - Document reset procedures
   - Test recovery methods

### For Users

1. **Understand the system**:
   - Passwords migrate from old system
   - Changes require authorization
   - First boot is one-time only

2. **Report issues**:
   - Unexpected password prompts
   - Login failures
   - Security warnings

## Compliance

This system helps meet:
- **NIST 800-53**: Access control and audit
- **PCI DSS**: Password management
- **SOC 2**: Security monitoring
- **ISO 27001**: Access control

## Summary

The credential chain provides:
- ✅ Seamless credential migration
- ✅ Tamper detection and prevention
- ✅ Secure password reset procedures
- ✅ Comprehensive audit trail
- ✅ Emergency access methods
- ✅ Compliance with security standards

This creates a secure system where credentials are protected throughout the system lifecycle.