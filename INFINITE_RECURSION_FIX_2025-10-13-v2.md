# Infinite Recursion Fix - Web Dashboard Module

## Problem
The Nix evaluation was encountering an infinite recursion error at `/nix/store/.../lib/modules.nix:809:9` when trying to evaluate options. 

## Root Cause
The `modules/web/dashboard.nix` module was accessing `config.hypervisor.web.port` directly without proper conditional wrapping. This created a circular dependency during the Nix evaluation phase.

## Solution Applied

### 1. Added proper module structure to `modules/web/dashboard.nix`
- Wrapped all configuration in a `config = { ... }` block
- Made the configuration conditional with `lib.mkIf config.hypervisor.web.enable`

### 2. Added missing enable option to `modules/core/options.nix`
```nix
web = {
  enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable the web dashboard";
  };
  
  port = lib.mkOption {
    type = lib.types.port;
    default = 8080;
    description = "Port for the web dashboard";
  };
};
```

### 3. Fixed firewall configuration
- Removed `lib.mkAfter` from the port configuration to simplify evaluation
- The firewall rule now properly references the configured port

## Key Changes
1. **Module Structure**: Properly wrapped module content in `config = lib.mkIf condition { ... }`
2. **Enable Option**: Added standard enable option following NixOS module patterns
3. **Conditional Evaluation**: Ensures the module only evaluates when enabled

## Best Practices Applied
- ✅ Proper NixOS module structure with conditional evaluation
- ✅ Standard enable/disable pattern for optional features
- ✅ Avoiding circular dependencies in option evaluation
- ✅ Consistent with other modules in the codebase (monitoring, backup, etc.)

## Testing
The infinite recursion should now be resolved. The web dashboard will be enabled by default but can be disabled with:
```nix
hypervisor.web.enable = false;
```