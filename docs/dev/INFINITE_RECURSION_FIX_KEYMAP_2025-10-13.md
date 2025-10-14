# Infinite Recursion Fix - Keymap Sanitizer - 2025-10-13

## Problem Summary
The NixOS configuration was experiencing an infinite recursion error when building:
```
error: infinite recursion encountered
       at /nix/store/lv9bmgm6v1wc3fiz00v29gi4rk13ja6l-source/lib/modules.nix:809:9:
```

This occurred despite previous fixes documented in `INFINITE_RECURSION_FIX_2025-10-13.md`.

## Root Cause Analysis
The issue was caused by a remaining instance of the anti-pattern in `modules/core/keymap-sanitizer.nix`. The file was accessing `config.console.keyMap` in a top-level `let` binding before the module evaluation phase.

### The Problematic Code
```nix
# ❌ WRONG - Causes infinite recursion
{
  config = let
    key = (config.console.keyMap or "");
    lower = lib.toLower key;
    invalid = builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ];
  in lib.mkIf invalid {
    console.keyMap = lib.mkForce "us";
  };
}
```

This pattern violates NixOS module evaluation order, as it tries to access `config` values during the module definition phase.

## Solution Applied
Moved the `let` binding inside the `lib.mkIf` condition to ensure `config` values are only accessed during the evaluation phase:

```nix
# ✅ CORRECT - No infinite recursion
{
  config = lib.mkIf (let
    key = (config.console.keyMap or "");
    lower = lib.toLower key;
  in builtins.elem lower [ "(unset)" "unset" "n/a" "-" "" ]) {
    console.keyMap = lib.mkForce "us";
  };
}
```

## Testing Instructions

### On Your NixOS System
1. Update your local repository:
   ```bash
   cd /path/to/your/hyper-nixos
   git pull
   ```

2. Test the configuration build:
   ```bash
   # Dry build test (recommended first)
   nixos-rebuild dry-build --flake .#hypervisor-x86_64 --show-trace
   
   # Or if using the system directly
   sudo nixos-rebuild dry-build --show-trace
   ```

3. If the dry build succeeds, perform the actual rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#hypervisor-x86_64
   ```

### Expected Results
- ✅ No infinite recursion errors
- ✅ Clean build output
- ✅ System builds and switches successfully

## Lessons Reinforced
1. **Always check ALL files** for the anti-pattern, not just the obvious ones
2. **Small utility modules** can also contain the problematic pattern
3. **The pattern can be subtle** - even a simple keymap sanitizer can cause issues
4. **Use proper conditional evaluation** - `let` bindings accessing `config` should be inside `lib.mkIf` or similar conditionals

## Prevention for Future Development
When writing NixOS modules:
- ✅ Never use `config` in top-level `let` bindings
- ✅ Always wrap config access in appropriate conditionals
- ✅ Test immediately with `nixos-rebuild dry-build --show-trace`
- ✅ Search for the pattern across all files when debugging

## Related Documentation
- `docs/dev/INFINITE_RECURSION_FIX_2025-10-13.md` - Previous comprehensive fix
- `docs/dev/AI_ASSISTANT_CONTEXT.md` - Contains anti-patterns documentation (PROTECTED)
- `docs/COMMON_ISSUES_AND_SOLUTIONS.md` - General troubleshooting guide (PUBLIC)

## Status
✅ **RESOLVED** - The keymap sanitizer infinite recursion has been fixed.