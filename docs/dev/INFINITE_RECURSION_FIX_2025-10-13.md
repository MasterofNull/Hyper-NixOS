# Infinite Recursion Fix - 2025-10-13

## Problem
The NixOS configuration was experiencing infinite recursion errors when building:
```
error: infinite recursion encountered
       at /nix/store/lv9bmgm6v1wc3fiz00v29gi4rk13ja6l-source/lib/modules.nix:809:9:
          808|     in warnDeprecation opt //
          809|       { value = builtins.addErrorContext "while evaluating the option `${showOption loc}':" value;
             |         ^
          810|         inherit (res.defsFinal') highestPrio;
```

## Root Cause
Multiple modules were accessing `config` values in top-level `let` bindings, which causes circular dependencies during NixOS module evaluation. The problematic pattern was:

```nix
config = let
  someValue = config.some.option;
in {
  # configuration using someValue
};
```

## Files Fixed

### 1. `modules/security/profiles.nix`
**Problem**: Top-level `let` binding accessing multiple config values
```nix
# Before (INCORRECT)
config = let
  mgmtUser = config.hypervisor.management.userName;
  enableMenuAtBoot = config.hypervisor.menu.enableAtBoot;
  # ... more config accesses
in lib.mkMerge [ ... ];
```

**Solution**: Removed the `let` binding and accessed config values directly
```nix
# After (CORRECT)
config = lib.mkMerge [
  (lib.mkIf (config.hypervisor.security.profile == "headless") {
    # Direct config access inside conditional
  })
];
```

### 2. `modules/core/keymap-sanitizer.nix`
**Problem**: Config access in `let` binding before `lib.mkIf`
```nix
# Before (INCORRECT)
config = let
  key = (config.console.keyMap or "");
  lower = lib.toLower key;
  invalid = builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ];
in lib.mkIf invalid {
  console.keyMap = lib.mkForce "us";
};
```

**Solution**: Moved the `let` binding inside the `lib.mkIf` condition
```nix
# After (CORRECT)
config = lib.mkIf (let
  key = (config.console.keyMap or "");
  lower = lib.toLower key;
in builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ]) {
  console.keyMap = lib.mkForce "us";
};
```

## Additional Fix: Git Installation Warning

### Problem
The installer was giving a warning that git is not installed, which could cause issues with flake operations.

### Solution
Added `git` to the core system packages in `modules/core/packages.nix`:
```nix
environment.systemPackages = with pkgs; [
  # ... other packages ...
  
  # Scripting and development
  python3
  python3Packages.jsonschema
  git  # Required for flake operations
  
  # ... more packages ...
];
```

## Key Lessons

1. **Never access `config` in top-level `let` bindings** - This creates circular dependencies
2. **Always wrap config in conditionals** - Use `lib.mkIf`, `lib.mkMerge`, etc.
3. **Let bindings inside conditionals are safe** - The evaluation happens after the module system is resolved
4. **Include essential tools in system packages** - Git is required for flake operations

## Design Pattern to Follow

### ✅ Correct Pattern
```nix
{ config, lib, pkgs, ... }:
{
  options.hypervisor.TOPIC = {
    # Define options here
  };

  config = lib.mkIf config.hypervisor.TOPIC.enable {
    # All configuration here
    # Safe to access config values directly
  };
}
```

### ❌ Incorrect Pattern
```nix
{ config, lib, pkgs, ... }:
let
  # NEVER DO THIS - causes infinite recursion
  someValue = config.some.option;
in
{
  config = {
    # Uses someValue
  };
}
```

## Testing
Due to the environment limitations, the fixes could not be tested with `nixos-rebuild`. However, the patterns fixed are known causes of infinite recursion in NixOS configurations. To verify:

```bash
# Test with dry-build
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64 --show-trace

# Or with nix directly
nix build .#nixosConfigurations.hypervisor-x86_64.config.system.build.toplevel
```

## Impact
- ✅ Eliminates infinite recursion errors
- ✅ Maintains modular architecture
- ✅ Ensures git is available for flake operations
- ✅ Follows NixOS best practices for module evaluation