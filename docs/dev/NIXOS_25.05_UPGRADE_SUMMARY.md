# NixOS 25.05 Upgrade Summary

## Overview

**Date**: 2025-10-19
**Agent**: Claude Code
**Change**: Upgraded Hyper-NixOS from NixOS 24.11 to NixOS 25.05

## What Was Changed

### 1. Core System Files

#### flake.nix & flake.lock
- **Updated**: `nixpkgs.url` now points to `nixos-25.05` channel
- **Updated**: `flake.lock` updated to NixOS 25.05 package versions
- **Status**: Latest stable NixOS release (May 2025)

### 2. Documentation Updates

#### Critical Documentation Files
- [x] `docs/dev/PROJECT_DEVELOPMENT_HISTORY.md` - Added 25.05 upgrade entry at top
- [x] `docs/dev/CLAUDE.md` - Updated "built on NixOS 25.05"
- [x] `docs/dev/AI_ASSISTANT_CONTEXT.md` - Updated base OS version to 25.05
- [x] `README.md` - Updated badge to show NixOS 25.05
- [x] `docs/UPGRADE_GUIDE.md` - Already correctly referenced 25.05 as latest
- [x] `docs/COMMON_ISSUES_AND_SOLUTIONS.md` - Updated version compatibility table

#### Version References Updated
- "NixOS 24.11" → "NixOS 25.05" where referring to current version
- "NixOS 24.05+" → "NixOS 25.05" in system requirements
- Badge in README.md updated to `NixOS-25.05-blue`

### 3. Code Comments

#### Module Comments Updated
- [x] `modules/core/boot.nix` - Updated hardware.graphics comment
- [x] `modules/hardware/platform-detection.nix` - Updated graphics API comment
- [x] `modules/hardware/desktop.nix` - Updated graphics support comment

**Comment Pattern**: "NixOS 24.11+" → "NixOS 24.11+ / 25.05"

### 4. system.stateVersion Updated (Fresh Install)

#### Updated to 25.05
- **Changed**: All `system.stateVersion = "24.05"` → `"25.05"`
- **Reason**: This is a FRESH system that hasn't been built yet
- **Correct for**: New installations (not upgrades of existing systems)
- **Files Updated**:
  - configuration.nix
  - All 4 profile files (minimal, minimal-recovery, privilege-separation, complete)
  - examples/production-config.nix
  - scripts/first-boot-wizard.sh (generated configs)
- **Note**: On existing/already-installed systems, stateVersion should NOT be changed

#### Historical Documentation
- Version-specific compatibility guides (24.05 vs 24.11) kept for reference
- Migration tool files (tools/nixos-updater/) kept for backward compatibility
- Deprecation lists (deprecations-24.05.txt, deprecations-24.11.txt) preserved

## API Compatibility

### NixOS 25.05 Uses Modern API
NixOS 25.05 continues to use the modern API introduced in 24.11:

| Old (24.05) | Modern (24.11+ / 25.05) | Status |
|-------------|-------------------------|---------|
| `hardware.opengl` | `hardware.graphics` | ✅ Using modern |
| `hardware.opengl.driSupport` | `hardware.graphics.enable` | ✅ Using modern |
| `hardware.opengl.driSupport32Bit` | `hardware.graphics.enable32Bit` | ✅ Using modern |

**Verification**: All module code already uses `hardware.graphics` (modern API).

## Files Modified

### Configuration Files (7 files)
1. `configuration.nix` - stateVersion updated
2. `profiles/configuration-minimal.nix` - stateVersion updated
3. `profiles/configuration-minimal-recovery.nix` - stateVersion updated
4. `profiles/configuration-privilege-separation.nix` - stateVersion updated
5. `profiles/configuration-complete.nix` - stateVersion updated
6. `examples/production-config.nix` - stateVersion updated
7. `scripts/first-boot-wizard.sh` - Generated config stateVersion

### Documentation (9 files)
1. `docs/dev/PROJECT_DEVELOPMENT_HISTORY.md`
2. `docs/dev/CLAUDE.md`
3. `docs/dev/AI_ASSISTANT_CONTEXT.md`
4. `docs/COMMON_ISSUES_AND_SOLUTIONS.md`
5. `docs/FIXES_SUMMARY.md`
6. `docs/UPGRADE_MANAGEMENT.md`
7. `docs/CHANGELOG_ENTRY.md`
8. `README.md`
9. `docs/dev/NIXOS_25.05_UPGRADE_SUMMARY.md` (this file - NEW)

### Code/Modules (3 files)
1. `modules/core/boot.nix`
2. `modules/hardware/platform-detection.nix`
3. `modules/hardware/desktop.nix`

### System Files (2 files)
1. `flake.nix` (already updated in previous commit)
2. `flake.lock` (already updated in previous commit)

## Verification Steps

### Verify Current Version
```bash
# Check flake.nix
grep "nixpkgs.url" flake.nix
# Should show: nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

# Check NixOS version (after rebuild)
nixos-version
# Should show: 25.05.xxxxx
```

### Verify System Build
```bash
# Build test (doesn't activate)
sudo nixos-rebuild build --flake .

# If successful, apply
sudo nixos-rebuild switch --flake .
```

### Verify Documentation
```bash
# Check that docs reference correct version
grep -r "NixOS 25.05" docs/dev/CLAUDE.md
grep -r "25.05" README.md

# Verify no stale 24.11 references in current version docs
# (Should only appear in historical/compatibility sections)
```

## Benefits of 25.05 Upgrade

### Security
- Latest security patches and fixes
- Updated kernel with recent CVE fixes
- Modern security features and improvements

### Features
- Latest package versions in nixpkgs
- Improved NixOS modules and options
- Better hardware support

### Alignment with Design Ethos
- **Pillar 1 (Ease of Use)**: Latest stable = better compatibility
- **Pillar 2 (Security)**: Current security patches
- **Pillar 3 (Learning)**: Up-to-date documentation matches system

## Channel Flexibility

Users can still switch channels as needed:

```bash
# Stay on 25.05 (recommended)
./scripts/switch-channel.sh 25.05

# Use unstable (bleeding edge)
./scripts/switch-channel.sh unstable

# Downgrade to 24.11 if needed
./scripts/switch-channel.sh 24.11

# Legacy 24.05 support
./scripts/switch-channel.sh 24.05
```

See `docs/UPGRADE_GUIDE.md` for complete channel management instructions.

## Testing Checklist

After upgrade, verify:

- [ ] System builds successfully
- [ ] All services start correctly
- [ ] LibVirt/QEMU work properly
- [ ] VMs start and run
- [ ] Networking functions
- [ ] Security modules load
- [ ] No errors in journal: `journalctl -p err -b`
- [ ] Documentation references are accurate

## Rollback Procedure

If issues arise:

```bash
# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or switch channel back
./scripts/switch-channel.sh 24.11
nix flake update
sudo nixos-rebuild switch --flake .
```

## Lessons Learned

### Importance of Version Tracking
This upgrade highlighted the importance of:
1. **Comprehensive documentation updates** across all files
2. **Systematic search and replace** to catch all references
3. **Preserving historical information** (compatibility guides)
4. **Understanding stateVersion** semantics (don't change it!)

### Documentation Synchronization
Following the CRITICAL_REQUIREMENTS.md protocol:
1. ✅ Updated PROJECT_DEVELOPMENT_HISTORY.md FIRST
2. ✅ Updated AI_ASSISTANT_CONTEXT.md with new version
3. ✅ Updated all user-facing documentation
4. ✅ Verified code comments match reality
5. ✅ Created this summary document

## Next Steps

1. **Test System**: Rebuild and verify all functionality
2. **Monitor**: Watch for any version-specific issues
3. **Document**: Add any 25.05-specific patterns to AI docs
4. **Update**: Keep flake.lock updated with `nix flake update`

## References

- NixOS 25.05 Release Notes: https://nixos.org/manual/nixos/stable/release-notes.html#sec-release-25.05
- Hyper-NixOS Upgrade Guide: `docs/UPGRADE_GUIDE.md`
- Channel Switcher: `scripts/switch-channel.sh`
- Design Ethos: `docs/dev/DESIGN_ETHOS.md`

---

**Status**: ✅ Complete
**Documented by**: Claude Code
**Date**: 2025-10-19
