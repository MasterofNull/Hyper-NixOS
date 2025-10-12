# Infinite Recursion Fix - 2025-10-12

## Problem
The NixOS configuration was experiencing infinite recursion errors when building:
```
error: infinite recursion encountered
at /nix/store/lv9bmgm6v1wc3fiz00v29gi4rk13ja6l-source/lib/modules.nix:809:9:
```

## Root Cause
In `configuration/configuration.nix`, there was a circular dependency in the evaluation of `services.xserver.enable`:

1. Line 7 read `config.services.xserver.enable` and stored it in `baseSystemHasGui`
2. Line 10 used `baseSystemHasGui` to compute `enableGuiAtBoot`
3. Line 243 set `services.xserver.enable` based on `enableGuiAtBoot`

This created a circular reference:
- `config.services.xserver.enable` → `baseSystemHasGui` → `enableGuiAtBoot` → `config.services.xserver.enable` → ...

## Solution
Removed the circular reference by:

1. **Removed** the `baseSystemHasGui` variable that read from `config.services.xserver.enable`
2. **Simplified** `enableGuiAtBoot` to only check for explicit user preference:
   ```nix
   enableGuiAtBoot = if hasHypervisorGuiPreference then hypervisorGuiRequested else false;
   ```
3. **Updated** line 244 to only use `enableGuiAtBoot`:
   ```nix
   services.xserver.enable = lib.mkDefault enableGuiAtBoot;
   ```

## Changes Made
- **File**: `configuration/configuration.nix`
- **Lines Modified**: 7-11, 244
- **Behavior Change**: The X server will now only be enabled if explicitly requested via `hypervisor.gui.enableAtBoot`, rather than trying to preserve existing X server settings (which caused the circular dependency)

## Impact
- ✅ Fixes infinite recursion error
- ✅ Simplifies configuration logic
- ⚠️ Users who relied on X server being auto-detected from previous configuration may need to explicitly set `hypervisor.gui.enableAtBoot = true;` in their local config

## Testing
To verify the fix works:
```bash
# Check for syntax errors and infinite recursion
nix build .#nixosConfigurations.hypervisor-x86_64.config.system.build.toplevel

# Or with nixos-rebuild
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64
```

## Related Issues
This fix builds upon previous infinite recursion fixes in PR #76 which addressed:
- Firewall port conflicts (lib.mkAfter)
- Duplicate user definitions
- Duplicate systemd service definitions
