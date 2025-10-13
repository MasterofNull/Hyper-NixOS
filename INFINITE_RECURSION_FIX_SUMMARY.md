# Nix Infinite Recursion Fix Summary

## Problem Identified

The infinite recursion error was caused by two issues in your NixOS configuration:

1. **Incorrect use of `lib.mkIf` in `modules/security/profiles.nix`** (line 186):
   - The code was using `users.users = lib.mkIf (mgmtUser == "hypervisor") { ... }`
   - This is incorrect because `users.users` expects an attribute set, not a conditional
   - This created a circular dependency when evaluating the user configuration

2. **Missing option definitions**:
   - The configuration was referencing `hypervisor.management.userName` and other options that were never defined
   - This caused evaluation errors when trying to access these non-existent options

## Fixes Applied

### 1. Fixed the user definition in `modules/security/profiles.nix`:
```nix
# Changed from:
users.users = lib.mkIf (mgmtUser == "hypervisor") {
  hypervisor = { ... };
};

# To:
users.users = lib.optionalAttrs (mgmtUser == "hypervisor") {
  hypervisor = { ... };
};
```

### 2. Created `modules/core/options.nix` to define missing options:
- Defined `hypervisor.management.userName` (default: "hypervisor")
- Defined `hypervisor.menu.enableAtBoot` (default: true)
- Defined `hypervisor.firstBootWelcome.enableAtBoot` (default: true)
- Defined `hypervisor.firstBootWizard.enableAtBoot` (default: false)
- Defined `hypervisor.gui.enableAtBoot` (default: false)

### 3. Added the new options module to `configuration.nix`:
- Imported `./modules/core/options.nix` at the beginning of the core system configuration section

## Testing the Fix

To verify the fix resolves the infinite recursion error, run:

```bash
# Build the configuration
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64

# Or evaluate a specific attribute
nix eval --show-trace .#nixosConfigurations.hypervisor-x86_64.config.system.stateVersion
```

If the error persists, use `--show-trace` to get more details about where the recursion is occurring.

## Additional Notes

- The `lib.optionalAttrs` function is the correct way to conditionally add attributes to an attribute set
- Always define options before using them with `lib.attrByPath` or similar functions
- Consider using `lib.mkDefault` for option values that can be overridden rather than hard-coding them in multiple places