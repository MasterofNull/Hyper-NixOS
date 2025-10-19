# Documentation Corrections Needed - Architecture References
## Date: 2025-10-19
## Issue: Incorrect references to /etc/nixos/ and /etc/hypervisor/ as architecture

---

## Background

**CORRECT ARCHITECTURE**:
- Entry Point: `Hyper-NixOS/flake.nix`
- Main Config: `Hyper-NixOS/configuration.nix` (imports all modules)
- Modules: `Hyper-NixOS/modules/**/*.nix`

**HOST SYSTEM FILES** (NOT part of Hyper-NixOS architecture):
- `/etc/nixos/` - Host system location
- `/etc/hypervisor/` - Host placeholder for compare/merge only
- These are referenced by automation scripts for installation purposes ONLY

**RULE**:
- ✅ Automation scripts CAN reference host paths for installation
- ✅ Installation guides CAN mention where files get copied
- ❌ Architecture documentation SHOULD NOT describe host paths as part of Hyper-NixOS

---

## CRITICAL - Files Incorrectly Describing Architecture

### 1. docs/dev/AI_ASSISTANT_CONTEXT.md
**Line 80**:
```markdown
`/etc/nixos/configuration.nix` imports all modules and defines:
```

**SHOULD BE**:
```markdown
`Hyper-NixOS/configuration.nix` imports all modules and defines:
```

**Context**: This is in "Configuration Structure" section describing the architecture

---

### 2. BUILD_INSTRUCTIONS.md
**ENTIRE FILE IS INCORRECT** - Created by AI with wrong understanding

**Current State**: Describes `/etc/hypervisor/` and `/etc/nixos/` as system architecture

**Should Describe**:
- How to build from `Hyper-NixOS/` repository
- Standard build command: `sudo nixos-rebuild switch --flake /path/to/Hyper-NixOS`
- Development workflow within repository

**Action**: Complete rewrite needed

---

### 3. docs/dev/CONFIGURATION_MODIFICATION_PROCESS.md
**Line 11**:
```markdown
1. **`/etc/nixos/configuration.nix`**
```

**Multiple lines** (76, 119, 120, 222, 318): References `/etc/nixos/configuration.nix` in examples

**Assessment**: Need to review - these may be installation examples (acceptable) or architecture descriptions (incorrect)

**Action**: Review with user

---

### 4. docs/dev/SYSTEM_AUDIT_2025-10-19.md
**Lines 100, 247**: Mentions `/etc/nixos/configuration.nix` as main config

**Context**: This is the audit report I just created - also has incorrect understanding

**Action**: Update or remove (created today with wrong info)

---

## MEDIUM PRIORITY - Files That May Need Review

### Installation/Deployment Guides (May be acceptable)

These reference `/etc/nixos/configuration.nix` but might be showing installation steps:

1. **docs/INSTALLATION_GUIDE.md** (lines 274, 300, 347, 520)
2. **docs/dev/INSTALLATION_GUIDE.md** (multiple references)
3. **docs/deployment/DEPLOYMENT.md** (line 62)
4. **docs/INSTALLATION_WORKFLOW.md** (line 293)
5. **docs/ALL_PROFILES_UPDATED.md** (lines 15, 242)

**Action**: Review each to determine if they're:
- ✅ Showing installation steps (acceptable)
- ❌ Describing architecture (needs correction)

---

### User/Admin Guides

1. **docs/FEATURE_MANAGEMENT_GUIDE.md** (line 291)
   - Shows syntax check command: `nix-instantiate --parse /etc/nixos/configuration.nix`
   - **Assessment**: May need update to show repo path

2. **docs/UPGRADE_MANAGEMENT.md** (lines 117, 199)
   - References reviewing/editing `/etc/nixos/configuration.nix`
   - **Assessment**: Should reference repo instead

3. **docs/COMMON_ISSUES_AND_SOLUTIONS.md** (lines 236, 305)
   - Shows editing `/etc/nixos/configuration.nix`
   - **Assessment**: Need review

4. **docs/SYSTEM_HARDENING_GUIDE.md** (lines 237, 498)
   - References config file location
   - **Assessment**: Need review

5. **docs/SECURITY.md** (line 214)
   - Shows grep command on `/etc/nixos/configuration.nix`
   - **Assessment**: Should use repo path

---

## Files Referencing /etc/hypervisor/

**Total**: 78 files reference `/etc/hypervisor/`

**Categories**:
1. **Scripts** (automation) - These are CORRECT (need host paths)
2. **Installation docs** - May be CORRECT (showing where files go)
3. **Architecture docs** - INCORRECT (should not describe as architecture)

**Action Required**: Need systematic review of each file

**Sample files to check**:
- docs/dev/CHANGELOG.md
- docs/FIXES_SUMMARY.md
- docs/reference/SCRIPT_REFERENCE.md
- docs/guides/CENTRAL_WIZARD_GUIDE.md
- docs/user-guides/*.md

---

## Recommended Approach

### Phase 1: Fix Critical Architecture Docs (Today)
1. ✅ AI_ASSISTANT_CONTEXT.md - Fix line 80
2. ✅ BUILD_INSTRUCTIONS.md - Complete rewrite
3. ✅ SYSTEM_AUDIT_2025-10-19.md - Update or remove

### Phase 2: Review Installation Guides (This Week)
1. Determine which references are installation steps (OK) vs architecture (fix)
2. Update user-facing guides to reference repo instead of host paths
3. Ensure consistency

### Phase 3: Systematic Review (Next Week)
1. Review all 78 files referencing /etc/hypervisor/
2. Categorize: scripts (OK) vs docs (may need fix)
3. Update as needed

---

## Questions for User

1. **BUILD_INSTRUCTIONS.md**: Should this file be completely rewritten, or removed?

2. **Installation guides**: When showing examples, is it acceptable to reference `/etc/nixos/configuration.nix` as "the installed location" while making clear the repo is the source?

3. **User guides**: Should commands show:
   - Repository path: `nix-instantiate --parse Hyper-NixOS/configuration.nix`
   - Or relative: `nix-instantiate --parse ./configuration.nix` (assuming in repo)

4. **Priority**: Should we fix all critical docs first, or do one complete review of all files?

---

## Correct Examples

### Architecture Description (CORRECT)
```markdown
## Hyper-NixOS Architecture

**Entry Point**: `Hyper-NixOS/flake.nix`
- Defines nixosConfigurations (hypervisor-x86_64, hypervisor-aarch64)
- Each configuration imports `./configuration.nix`

**Main Configuration**: `Hyper-NixOS/configuration.nix`
- Imports `./hardware-configuration.nix` (placeholder in repo)
- Imports all modules from `./modules/`
- Defines system settings

**Build Command**:
```bash
cd Hyper-NixOS
sudo nixos-rebuild switch --flake .
```
```

### Installation Instructions (ACCEPTABLE)
```markdown
## Installation

During installation, files are copied to host system:

```bash
# System installer copies repository
sudo rsync -av Hyper-NixOS/ /install-location/

# Hardware config auto-generated
nixos-generate-config --root /mnt
```

After installation, build from the installed location.
```

---

**Status**: Awaiting user guidance on correction approach
**Priority**: Critical (P0) - Architecture documentation must be accurate
**Estimated Effort**:
- Phase 1: 2-3 hours
- Phase 2: 4-6 hours
- Phase 3: 6-8 hours
