# Nix Infinite Recursion Fix Summary - Version 2

## Problem Identified

The infinite recursion error was caused by **duplicate option definitions** across multiple modules. Multiple modules were defining options under the same `hypervisor` namespace, which created conflicts and circular dependencies during Nix evaluation.

### Root Cause
- `modules/core/options.nix` defined basic `hypervisor.*` options
- `modules/network-settings/firewall.nix` defined `hypervisor.security.*` options
- `modules/network-settings/ssh.nix` defined `hypervisor.security.sshStrictMode`
- `modules/monitoring/prometheus.nix` defined `hypervisor.monitoring.*` options
- `modules/automation/backup.nix` defined `hypervisor.backup.*` options
- `modules/virtualization/performance.nix` defined `hypervisor.performance.*` options
- `modules/security/profiles.nix` defined `hypervisor.security.profile`

This created a situation where multiple modules were trying to define the same option namespace, causing Nix to get confused about which definition to use and leading to infinite recursion.

## Fixes Applied

### 1. Consolidated All Option Definitions
Moved all option definitions to `modules/core/options.nix` to create a single source of truth:

```nix
options.hypervisor = {
  # Management options
  management = { ... };
  
  # Menu options  
  menu = { ... };
  
  # First boot options
  firstBootWelcome = { ... };
  firstBootWizard = { ... };
  
  # GUI options
  gui = { ... };
  
  # Security options (consolidated)
  security = {
    profile = lib.mkOption { ... };
    strictFirewall = lib.mkEnableOption "...";
    migrationTcp = lib.mkEnableOption "...";
    sshStrictMode = lib.mkEnableOption "...";
  };
  
  # Monitoring options (consolidated)
  monitoring = {
    enablePrometheus = lib.mkEnableOption "...";
    enableGrafana = lib.mkEnableOption "...";
    enableAlertmanager = lib.mkEnableOption "...";
    prometheusPort = lib.mkOption { ... };
    grafanaPort = lib.mkOption { ... };
  };
  
  # Backup options (consolidated)
  backup = {
    enable = lib.mkEnableOption "...";
    schedule = lib.mkOption { ... };
    retention = lib.mkOption { ... };
    destination = lib.mkOption { ... };
    encrypt = lib.mkOption { ... };
    compression = lib.mkOption { ... };
  };
  
  # Performance options (consolidated)
  performance = {
    enableHugepages = lib.mkEnableOption "...";
    disableSMT = lib.mkEnableOption "...";
  };
};
```

### 2. Removed Duplicate Option Definitions
Removed all duplicate option definitions from:
- `modules/network-settings/firewall.nix`
- `modules/network-settings/ssh.nix`
- `modules/monitoring/prometheus.nix`
- `modules/automation/backup.nix`
- `modules/virtualization/performance.nix`
- `modules/security/profiles.nix`

### 3. Maintained Module Functionality
All modules still work exactly the same way - they just no longer define options, only use them. The configuration logic remains unchanged.

## Why This Fixes the Infinite Recursion

1. **Single Source of Truth**: All options are now defined in one place (`modules/core/options.nix`)
2. **No Conflicts**: No more competing definitions of the same option namespace
3. **Clear Dependencies**: The options module is imported first in `configuration.nix`, so all options are available when other modules try to use them
4. **Proper Evaluation Order**: Nix can now evaluate options in the correct order without circular dependencies

## Testing the Fix

To verify the fix resolves the infinite recursion error, run:

```bash
# Build the configuration
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64

# Or evaluate a specific attribute
nix eval --show-trace .#nixosConfigurations.hypervisor-x86_64.config.system.stateVersion
```

## Key Principles for Future Development

1. **Centralize Option Definitions**: Always define options in `modules/core/options.nix`
2. **One Namespace Per Module**: Each module should only define options under its own unique namespace
3. **Import Order Matters**: The options module must be imported before modules that use those options
4. **Use `lib.mkEnableOption` and `lib.mkOption`**: These are the correct functions for defining options

## Files Modified

- `modules/core/options.nix` - Added all consolidated option definitions
- `modules/network-settings/firewall.nix` - Removed duplicate option definitions
- `modules/network-settings/ssh.nix` - Removed duplicate option definitions  
- `modules/monitoring/prometheus.nix` - Removed duplicate option definitions
- `modules/automation/backup.nix` - Removed duplicate option definitions
- `modules/virtualization/performance.nix` - Removed duplicate option definitions
- `modules/security/profiles.nix` - Removed duplicate option definitions

The infinite recursion should now be resolved, and the configuration should build successfully.