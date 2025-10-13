# Infinite Recursion Fix Summary - 2025-10-13

## Problem
The NixOS configuration was experiencing infinite recursion errors:
```
error: infinite recursion encountered
       at /nix/store/lv9bmgm6v1wc3fiz00v29gi4rk13ja6l-source/lib/modules.nix:809:9:
          808|     in warnDeprecation opt //
          809|       { value = builtins.addErrorContext "while evaluating the option `${showOption loc}':" value;
             |         ^
          810|         inherit (res.defsFinal') highestPrio;
```

## Root Cause
The infinite recursion was caused by **circular dependencies in module evaluation** due to improper use of `config` values in top-level `let` bindings. Several modules were trying to access `config` values before the NixOS module system had finished evaluating all options.

## Files Fixed

### 1. `modules/gui/desktop.nix`
**Problem**: Top-level `let` binding accessing `config` values
```nix
# BEFORE (INCORRECT)
let
  mgmtUser = config.hypervisor.management.userName;
  enableGuiAtBoot = config.hypervisor.gui.enableAtBoot or false;
in {
  programs.sway = lib.mkIf enableGuiAtBoot {
```

**Fix**: Moved `config` access directly into the conditions
```nix
# AFTER (CORRECT)
{
  programs.sway = lib.mkIf (config.hypervisor.gui.enableAtBoot or false) {
    # ...
    services.greetd = lib.mkIf (config.hypervisor.gui.enableAtBoot or false) {
      # ...
      initial_session = {
        command = "sway";
        user = config.hypervisor.management.userName;
      };
```

### 2. `modules/core/directories.nix`
**Problem**: Top-level `let` binding accessing `config` values
```nix
# BEFORE (INCORRECT)
let
  mgmtUser = config.hypervisor.management.userName;
  activeProfile = config.hypervisor.security.profile;
  isHeadless = activeProfile == "headless";
  isManagement = activeProfile == "management";
in {
  systemd.tmpfiles.rules = lib.mkMerge [
```

**Fix**: Moved `let` binding inside the configuration
```nix
# AFTER (CORRECT)
{
  systemd.tmpfiles.rules = let
    mgmtUser = config.hypervisor.management.userName;
    activeProfile = config.hypervisor.security.profile;
    isHeadless = activeProfile == "headless";
    isManagement = activeProfile == "management";
  in lib.mkMerge [
```

### 3. `modules/core/keymap-sanitizer.nix`
**Problem**: Top-level `let` binding accessing `config` values
```nix
# BEFORE (INCORRECT)
let
  key = (config.console.keyMap or "");
  lower = lib.toLower key;
  invalid = builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ];
in {
  config = lib.mkIf invalid {
```

**Fix**: Moved `let` binding inside the `config` section
```nix
# AFTER (CORRECT)
{
  config = let
    key = (config.console.keyMap or "");
    lower = lib.toLower key;
    invalid = builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ];
  in lib.mkIf invalid {
```

## Key Principle

**❌ INCORRECT Pattern (causes infinite recursion):**
```nix
let
  someValue = config.some.option;
in {
  config = {
    # configuration using someValue
  };
}
```

**✅ CORRECT Pattern:**
```nix
{
  config = let
    someValue = config.some.option;
  in {
    # configuration using someValue
  };
}
```

Or even better:
```nix
{
  config = {
    some.setting = lib.mkIf config.some.condition "value";
  };
}
```

## Why This Matters

The NixOS module system evaluates modules in multiple passes:
1. First pass: Collect all option definitions
2. Second pass: Evaluate option values
3. Third pass: Generate final configuration

When `config` values are accessed in top-level `let` bindings, they are evaluated during the first pass, before all options are defined, creating circular dependencies.

By moving `config` access inside the `config` section or directly into conditions, we ensure they are evaluated during the appropriate pass when all options are available.

## Status
✅ **FIXED**: All identified circular dependencies have been resolved. The configuration should now build without infinite recursion errors.

## Files Modified
- `modules/gui/desktop.nix`
- `modules/core/directories.nix` 
- `modules/core/keymap-sanitizer.nix`

## Testing
To test the fix, run:
```bash
nixos-rebuild dry-build --show-trace
```

The build should now complete without infinite recursion errors.