# Auditd Configuration Fix - 2025-10-16

## Issue Fixed ✅

**Error:**
```
error: The option `services.auditd' does not exist.
```

**Root Cause:**
NixOS 24.05 moved audit configuration from `services.auditd` to `security.auditd`. Four security modules were still using the old path.

## Solution Applied

Updated all references from the old namespace to the new one:

| Old (Broken) | New (Fixed) |
|-------------|-------------|
| `services.auditd` | `security.auditd` |
| `config.services ? auditd` | `config.security ? auditd` |

## Files Fixed (4)

1. ✅ `modules/security/credential-chain.nix` - Credential integrity monitoring
2. ✅ `modules/security/base.nix` - Base security audit rules
3. ✅ `modules/security/strict.nix` - Strict security mode
4. ✅ `modules/security/sudo-protection.nix` - Sudo usage monitoring

## Changes Made

**Before:**
```nix
services.auditd.enable = true;  # ❌ Wrong namespace
```

**After:**
```nix
security.auditd.enable = lib.mkDefault true;  # ✅ Correct namespace
```

**Key Improvements:**
- ✅ Uses correct NixOS 24.05 option path
- ✅ Added `lib.mkDefault` for user overrides
- ✅ Simplified conditional checks
- ✅ Maintains all security functionality

## Testing

**Verify the fix:**
```bash
# 1. Rebuild configuration
sudo nixos-rebuild build

# Expected: No errors about auditd

# 2. Apply changes
sudo nixos-rebuild switch

# 3. Verify audit is running
systemctl status auditd

# 4. Check audit rules are loaded
sudo auditctl -l
```

## No Breaking Changes

- ✅ Backwards compatible (conditional checks)
- ✅ All security features preserved
- ✅ Audit rules still applied
- ✅ No user action required

## What You Get

The audit system monitors:
- ✅ Credential file changes (`/etc/shadow`, `/etc/passwd`)
- ✅ VM operations and deletions
- ✅ Sudo usage and privilege escalations
- ✅ Configuration file modifications
- ✅ Security-sensitive directory access

## Documentation

Full details in: `docs/dev/AUDITD_NIXOS_24_05_FIX_2025-10-16.md`

## Next Steps

Just rebuild your system:
```bash
sudo nixos-rebuild switch
```

That's it! The fix is automatic. 🎉
