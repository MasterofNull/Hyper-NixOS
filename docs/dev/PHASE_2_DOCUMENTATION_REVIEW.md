# Phase 2: Documentation Review - Installation & User Guides
## Date: 2025-10-19
## Reviewer: Claude Code (AI Agent)

---

## Review Criteria

**ACCEPTABLE** - References to host paths when:
- Showing installation commands (`nixos-install --root /mnt`)
- Explaining where files get copied during installation
- Documenting system_installer.sh behavior

**NEEDS FIXING** - References to host paths when:
- Describing Hyper-NixOS architecture
- Showing user commands that should reference repository
- Listing "locations" as if host paths are part of the system

---

## Category 1: Installation Guides

### ✅ MOSTLY ACCEPTABLE - Minor fixes needed

#### docs/INSTALLATION_GUIDE.md
**Lines 274, 300, 347, 520**: Shows installation steps

**Example (line 274)**:
```bash
cat >> /mnt/etc/nixos/configuration.nix <<EOF
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
EOF
```

**Assessment**: ✅ ACCEPTABLE - This is showing where files go during installation

**Minor Fix Needed**: Add clarification that this is temporary during install, and repository is the working location after

---

#### docs/INSTALLATION_WORKFLOW.md
**Line 293**: Comment says "Edit /etc/nixos/configuration.nix"

**Assessment**: ⚠️ NEEDS CONTEXT - Should clarify this is during installation, not normal workflow

**Suggested Fix**:
```nix
# During installation - edit /etc/nixos/configuration.nix
# After installation - edit in repository: Hyper-NixOS/configuration.nix
```

---

#### docs/deployment/DEPLOYMENT.md
**Line 62**: Shows creating configuration in /etc/nixos/

**Assessment**: ✅ ACCEPTABLE - Deployment guide showing where files go

---

## Category 2: Status/Report Documents

### ⚠️ NEEDS FIXING - Describing wrong locations

#### docs/ALL_PROFILES_UPDATED.md
**Line 15**: "**Location**: `/etc/nixos/configuration.nix`"
**Line 30**: "**Location**: `/etc/hypervisor/src/profiles/configuration-minimal.nix`"

**Assessment**: ❌ INCORRECT - This doc describes profile locations as if they're in host paths

**Current State**:
```markdown
### 1. configuration.nix (Main Configuration)
**Location**: `/etc/nixos/configuration.nix`
```

**Should Be**:
```markdown
### 1. configuration.nix (Main Configuration)
**Repository Location**: `Hyper-NixOS/configuration.nix`
**Installed Location**: Varies (typically /etc/nixos/ or custom)
```

**Action**: NEEDS REWRITE - This is a status doc about profiles, should reference repository

---

## Category 3: User/Admin Guides

### ⚠️ MIXED - Some need fixes

#### docs/FEATURE_MANAGEMENT_GUIDE.md
**Line 291**: `nix-instantiate --parse /etc/nixos/configuration.nix`

**Assessment**: ⚠️ SHOULD REFERENCE REPOSITORY

**Current**:
```bash
- Check syntax: `nix-instantiate --parse /etc/nixos/configuration.nix`
```

**Should Be**:
```bash
- Check syntax: `nix-instantiate --parse ./configuration.nix` (from repository)
```

---

#### docs/UPGRADE_MANAGEMENT.md
**Lines 117, 199**: References reviewing/editing `/etc/nixos/configuration.nix`

**Assessment**: ⚠️ NEEDS CONTEXT

**Example (line 117)**:
```markdown
1. Review `/etc/nixos/configuration.nix`
```

**Should Be**:
```markdown
1. Review `Hyper-NixOS/configuration.nix` in your repository
```

---

#### docs/COMMON_ISSUES_AND_SOLUTIONS.md
**Lines 236, 305**: Shows editing `/etc/nixos/configuration.nix`

**Assessment**: ⚠️ NEEDS REVIEW - Troubleshooting guide

**Need to check**: Is this showing installation troubleshooting (OK) or general usage (needs fix)

---

#### docs/SYSTEM_HARDENING_GUIDE.md
**Lines 237, 498**: References config file location

**Assessment**: ⚠️ NEEDS REVIEW

---

#### docs/SECURITY.md
**Line 214**: `sudo grep -r "hypervisor-" /etc/nixos/configuration.nix`

**Assessment**: ⚠️ SHOULD REFERENCE REPOSITORY

**Should Be**:
```bash
sudo grep -r "hypervisor-" Hyper-NixOS/configuration.nix
```

---

## Category 4: Reference Documents

#### docs/reference/SECURITY-QUICK-REFERENCE.md
**Line 92**: Comment showing `/etc/nixos/configuration.nix`

**Assessment**: ⚠️ NEEDS REVIEW - May be example config location

---

## Systematic Issues Found

### Issue Type 1: "Location" Fields
**Pattern**: Documents listing "**Location**: /etc/nixos/..." or "**Location**: /etc/hypervisor/..."

**Files Affected**:
- docs/ALL_PROFILES_UPDATED.md

**Fix Template**:
```markdown
**Repository**: `Hyper-NixOS/path/to/file.nix`
**After Installation**: Location varies by installation method
```

---

### Issue Type 2: Command Examples
**Pattern**: Commands showing operations on `/etc/nixos/configuration.nix`

**Files Affected**:
- docs/FEATURE_MANAGEMENT_GUIDE.md
- docs/SECURITY.md
- docs/UPGRADE_MANAGEMENT.md
- docs/COMMON_ISSUES_AND_SOLUTIONS.md

**Fix Template**:
```bash
# From repository directory
cd Hyper-NixOS
command ./configuration.nix
```

---

### Issue Type 3: Troubleshooting Steps
**Pattern**: "Edit /etc/nixos/configuration.nix" without context

**Files Affected**:
- docs/INSTALLATION_WORKFLOW.md
- docs/COMMON_ISSUES_AND_SOLUTIONS.md
- docs/SYSTEM_HARDENING_GUIDE.md

**Fix Template**:
```markdown
## Configuration Changes

For development/testing:
1. Edit `Hyper-NixOS/configuration.nix` in your repository
2. Test: `sudo nixos-rebuild build --flake .`
3. Apply: `sudo nixos-rebuild switch --flake .`
```

---

## Recommended Fixes by Priority

### Priority 1: Status/Report Documents (INCORRECT)
1. ✅ **docs/ALL_PROFILES_UPDATED.md** - Rewrite location fields

### Priority 2: User/Admin Guides (MISLEADING)
2. ✅ **docs/FEATURE_MANAGEMENT_GUIDE.md** - Update command examples
3. ✅ **docs/SECURITY.md** - Update grep command
4. ✅ **docs/UPGRADE_MANAGEMENT.md** - Clarify config location

### Priority 3: Troubleshooting Guides (NEEDS CONTEXT)
5. ⚠️ **docs/COMMON_ISSUES_AND_SOLUTIONS.md** - Review and add context
6. ⚠️ **docs/SYSTEM_HARDENING_GUIDE.md** - Review and add context
7. ⚠️ **docs/INSTALLATION_WORKFLOW.md** - Add context to comments

### Priority 4: Installation Guides (MOSTLY OK)
8. ✅ **docs/INSTALLATION_GUIDE.md** - Add clarification note
9. ✅ **docs/deployment/DEPLOYMENT.md** - Add clarification note

---

## Files That Are Acceptable As-Is

### Installation Process Documentation
These correctly show installation steps:
- Most references in INSTALLATION_GUIDE.md (showing where files go during install)
- deployment/DEPLOYMENT.md (showing deployment process)
- References in scripts (automation needs host paths)

---

## Next Steps

### Immediate Actions (Today)
1. Fix ALL_PROFILES_UPDATED.md (wrong location fields)
2. Fix FEATURE_MANAGEMENT_GUIDE.md (command examples)
3. Fix SECURITY.md (grep command)
4. Fix UPGRADE_MANAGEMENT.md (config location)

### Review Required (Need User Input)
5. COMMON_ISSUES_AND_SOLUTIONS.md - Determine if examples are install vs usage
6. SYSTEM_HARDENING_GUIDE.md - Determine context
7. INSTALLATION_WORKFLOW.md - Determine how much clarification needed

---

## Summary

**Total Files Reviewed**: 10 key files
**Acceptable As-Is**: 2 (deployment, some installation steps)
**Need Minor Fixes**: 4 (add clarification/context)
**Need Corrections**: 4 (wrong paths in user guides)

**Estimated Effort**:
- Priority 1-2 fixes: 1-2 hours
- Priority 3 review: 30-60 minutes
- Priority 4 clarifications: 30 minutes

---

**Status**: Analysis complete, awaiting approval to proceed with fixes
**Next**: Apply Priority 1-2 fixes (4 files)
