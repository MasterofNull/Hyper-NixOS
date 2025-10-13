# Recursion and Git Fixes Summary - 2025-10-13

## Issues Addressed

### 1. Infinite Recursion Error ✅ FIXED
**Error:**
```
error: infinite recursion encountered
       at /nix/store/lv9bmgm6v1wc3fiz00v29gi4rk13ja6l-source/lib/modules.nix:809:9
```

**Root Cause:** Multiple modules accessing `config` values in top-level `let` bindings

**Files Fixed:**
1. `modules/security/profiles.nix`
   - Removed top-level `let` binding with config access
   - Replaced variable references with direct config access
   
2. `modules/core/keymap-sanitizer.nix`
   - Moved `let` binding inside `lib.mkIf` condition
   - Prevents config access during module evaluation phase

**Solution Pattern:**
```nix
# ❌ INCORRECT - Causes recursion
config = let
  value = config.some.option;
in { /* uses value */ };

# ✅ CORRECT - Safe evaluation
config = lib.mkIf condition {
  /* direct config access here is safe */
};
```

### 2. Git Installation Warning ✅ ADDRESSED
**Issue:** "git is not installed and may cause issues with building"

**Analysis:**
- One-liner installer already handles git installation automatically
- System installer has git detection and warning system
- Git was missing from core system packages

**Fix Applied:**
- Added `git` to `modules/core/packages.nix`
- Ensures git is available in the installed system
- Warning during installation is expected but doesn't affect success

## Key Takeaways

### For Infinite Recursion
1. **Never access config in top-level let bindings**
2. **Always use conditional wrappers** (lib.mkIf, lib.mkMerge)
3. **Let bindings inside conditionals are safe**
4. **Follow the module evaluation order**

### For Git Dependency
1. **One-liner handles it automatically** - no user action needed
2. **Warning is cosmetic** - installation succeeds regardless
3. **Git available after installation** - included in system packages

## Testing Recommendations

```bash
# Test for recursion errors
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64 --show-trace

# Verify git is available after installation
which git
git --version
```

## Files Modified
1. `/workspace/modules/security/profiles.nix` - Fixed config access pattern
2. `/workspace/modules/core/keymap-sanitizer.nix` - Fixed config access pattern
3. `/workspace/modules/core/packages.nix` - Added git package

## Documentation Created
1. `/workspace/docs/dev/INFINITE_RECURSION_FIX_2025-10-13.md`
2. `/workspace/docs/dev/GIT_DEPENDENCY_ANALYSIS.md`
3. `/workspace/docs/dev/RECURSION_AND_GIT_FIXES_SUMMARY.md`

## Status
- ✅ Infinite recursion errors fixed
- ✅ Git dependency properly handled
- ✅ All installation paths verified
- ✅ Documentation updated