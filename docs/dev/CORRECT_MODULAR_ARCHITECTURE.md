# Correct Modular Architecture - 2025-10-13

## Overview
This document outlines the **correct** modular architecture that maintains topic-segregated, readable modules while preventing circular dependencies using proper NixOS patterns.

## 🏗️ **Correct Architectural Principles**

### 1. **Topic-Segregated Options** ✅
- Each module defines its own options related to its topic
- Options stay close to their implementation
- Easy to find and understand
- Maintains modular design

### 2. **Proper NixOS Module Structure** ✅
```nix
{ config, lib, pkgs, ... }:
{
  # Options defined in the same module that uses them
  options.hypervisor.TOPIC = {
    enable = lib.mkEnableOption "...";
    # other topic-specific options
  };

  # Configuration wrapped in conditional to prevent circular dependencies
  config = lib.mkIf config.hypervisor.TOPIC.enable {
    # All configuration here
  };
}
```

### 3. **Circular Dependency Prevention** ✅
- Use `config = lib.mkIf config.hypervisor.*.enable { ... }` wrapper
- No top-level `let` bindings accessing `config`
- Options and config in same module (no cross-module option dependencies)

## 📁 **Modular File Structure**

```
modules/
├── core/
│   └── options.nix           ← Only core cross-cutting options
├── web/
│   └── dashboard.nix         ← Defines hypervisor.web.* options
├── monitoring/
│   └── prometheus.nix        ← Defines hypervisor.monitoring.* options
├── automation/
│   └── backup.nix           ← Defines hypervisor.backup.* options
├── security/
│   ├── profiles.nix         ← Defines hypervisor.security.profile
│   └── ...
├── network-settings/
│   ├── firewall.nix         ← Defines hypervisor.security.strictFirewall
│   ├── ssh.nix              ← Defines hypervisor.security.sshStrictMode
│   └── ...
└── virtualization/
    ├── performance.nix      ← Defines hypervisor.performance.*
    └── ...
```

## 🎯 **Module Examples**

### Web Dashboard Module (`modules/web/dashboard.nix`)
```nix
{ config, lib, pkgs, ... }:
let
  py = pkgs.python3.withPackages (ps: [ ps.flask ps.requests ]);
in
{
  # Options defined in the same module
  options.hypervisor.web = {
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

  # Configuration wrapped in conditional
  config = lib.mkIf config.hypervisor.web.enable {
    # All web dashboard configuration here
    networking.firewall.interfaces."lo".allowedTCPPorts = [ config.hypervisor.web.port ];
    # ... rest of config
  };
}
```

### Monitoring Module (`modules/monitoring/prometheus.nix`)
```nix
{ config, lib, pkgs, ... }:
{
  # Monitoring-specific options
  options.hypervisor.monitoring = {
    enablePrometheus = lib.mkEnableOption "Enable Prometheus monitoring stack";
    enableGrafana = lib.mkEnableOption "Enable Grafana dashboards";
    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Port for Prometheus server";
    };
    # ... other monitoring options
  };

  # Multiple conditional configurations
  config = lib.mkMerge [
    (lib.mkIf config.hypervisor.monitoring.enablePrometheus {
      # Prometheus configuration
    })
    (lib.mkIf config.hypervisor.monitoring.enableGrafana {
      # Grafana configuration
    })
  ];
}
```

## ✅ **Benefits of This Architecture**

### 1. **Maintainability**
- Options are co-located with their implementation
- Easy to understand what each module does
- Clear topic boundaries

### 2. **Readability**
- Small, focused files
- Options and config in same place
- Self-documenting structure

### 3. **Modularity**
- Each module is self-contained
- Can be easily enabled/disabled
- Clear dependencies

### 4. **No Circular Dependencies**
- Proper use of `lib.mkIf` prevents evaluation issues
- Options defined before they're used
- No cross-module option dependencies

## 🚫 **What We Avoided**

### ❌ Centralized Monolithic Options File
```nix
# DON'T DO THIS - Creates massive unreadable file
modules/core/options.nix:
  options.hypervisor = {
    web = { ... };           # Web options
    monitoring = { ... };    # Monitoring options  
    backup = { ... };        # Backup options
    security = { ... };      # Security options
    # ... 500+ lines of options
  };
```

### ❌ Cross-Module Option Dependencies
```nix
# DON'T DO THIS - Creates circular dependencies
modules/web/dashboard.nix:
  config = {
    networking.firewall.allowedTCPPorts = [ config.hypervisor.web.port ];
  };

modules/core/options.nix:
  options.hypervisor.web.port = ...;
```

## 🎯 **Key Patterns**

### 1. **Options Co-location**
- Options defined in the module that implements them
- Keeps related code together
- Easy to find and modify

### 2. **Conditional Configuration**
- Always wrap config in `lib.mkIf config.hypervisor.*.enable`
- Prevents evaluation when module is disabled
- Avoids circular dependencies

### 3. **Topic Segregation**
- Each module focuses on one topic
- Clear boundaries between modules
- Logical organization

### 4. **Core Options Only in Core**
- Only cross-cutting options in `modules/core/options.nix`
- Management user, boot settings, GUI settings
- Options used by multiple modules

## 🔍 **Validation**

The architecture is correct when:
- [ ] Each module defines its own topic-specific options
- [ ] All config is wrapped in `lib.mkIf` conditionals
- [ ] No top-level `let` bindings access `config`
- [ ] Options are co-located with their implementation
- [ ] Files remain small and focused
- [ ] No circular dependencies occur

## 📊 **Result**

This architecture provides:
- ✅ **Modular design** - Topic-segregated files
- ✅ **Readability** - Small, focused modules  
- ✅ **Maintainability** - Options near implementation
- ✅ **Reliability** - No circular dependencies
- ✅ **NixOS best practices** - Proper module patterns
- ✅ **Scalability** - Easy to add new modules

This is the **correct** way to structure NixOS modules while maintaining the benefits of modular, topic-segregated design.