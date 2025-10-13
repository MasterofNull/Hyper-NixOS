# AI Assistant Context Guide - Hyper-NixOS

## 🎯 **Purpose**
This document provides essential context for future AI assistants working on the Hyper-NixOS system. It captures design philosophy, architectural decisions, historical context, and lessons learned to maintain system cohesion and prevent repeated mistakes.

## 🏗️ **System Architecture Philosophy**

### Core Design Principles
1. **Modular by Design** - Each module handles one specific topic/domain
2. **Topic Segregation** - Related options and configurations stay together
3. **Readable & Maintainable** - Small, focused files over monolithic configurations
4. **NixOS Best Practices** - Follow proper module patterns to prevent issues
5. **User Choice Respect** - Provide options, don't force decisions

### File Organization Philosophy
```
modules/
├── core/           ← Cross-cutting system options only
├── web/           ← Web dashboard functionality
├── monitoring/    ← Prometheus, Grafana, alerting
├── automation/    ← Backup, scheduling, maintenance
├── security/      ← Security profiles, hardening
├── network-settings/ ← Networking, firewall, SSH
└── virtualization/   ← VFIO, performance, VM management
```

**Key Rule**: Each module defines its own options. Options stay with their implementation.

## 🚨 **Critical Historical Issues & Solutions**

### Issue #1: Infinite Recursion (2025-10-13)
**Problem**: Circular dependencies causing `infinite recursion encountered` errors.

**Root Cause**: Top-level `let` bindings accessing `config` values before module evaluation.

**❌ Never Do This:**
```nix
let
  someValue = config.hypervisor.something;
in {
  config = { /* uses someValue */ };
}
```

**✅ Always Do This:**
```nix
{
  options.hypervisor.topic = { /* options here */ };
  
  config = lib.mkIf config.hypervisor.topic.enable {
    # All configuration wrapped in conditional
  };
}
```

**Lesson**: NixOS module evaluation happens in phases. Respect the evaluation order.

### Issue #2: Centralization Mistake (2025-10-13)
**Problem**: Attempted to solve circular dependencies by centralizing all options into one massive file.

**Why This Was Wrong**: Violated core principles of modularity, readability, and maintainability.

**Correct Solution**: Fix the module patterns, not the architecture. Keep options with their implementations.

**Lesson**: Don't sacrifice good architecture to solve technical issues. Fix the technical issues properly.

## 🎯 **Design Decisions & Rationale**

### Why Modular Architecture?
- **Maintainability**: Easy to find and modify related functionality
- **Readability**: Small files are easier to understand
- **Collaboration**: Multiple people can work on different modules
- **Testing**: Individual modules can be tested in isolation

### Why Options Co-location?
- **Context**: Options are documented near their usage
- **Discovery**: Easy to find what options are available
- **Maintenance**: Changes to functionality include option updates

### Why Conditional Wrappers?
- **Performance**: Disabled modules don't evaluate their configuration
- **Safety**: Prevents circular dependencies and evaluation issues
- **Clarity**: Makes enable/disable behavior explicit

## 🔧 **Common Patterns & Standards**

### Module Structure Template
```nix
{ config, lib, pkgs, ... }:
{
  # Options for this specific topic
  options.hypervisor.TOPIC = {
    enable = lib.mkEnableOption "Enable TOPIC functionality";
    
    # Topic-specific options here
    setting = lib.mkOption {
      type = lib.types.str;
      default = "value";
      description = "Description of setting";
    };
  };

  # Configuration wrapped in conditional
  config = lib.mkIf config.hypervisor.TOPIC.enable {
    # All configuration here
    
    # For multiple sub-features, use lib.mkMerge
    # config = lib.mkMerge [
    #   (lib.mkIf config.hypervisor.TOPIC.subFeature { ... })
    #   (lib.mkIf config.hypervisor.TOPIC.otherFeature { ... })
    # ];
  };
}
```

### Naming Conventions
- **Options**: `hypervisor.CATEGORY.setting`
- **Enable Options**: `hypervisor.CATEGORY.enable`
- **Files**: `modules/CATEGORY/descriptive-name.nix`
- **Categories**: web, monitoring, automation, security, virtualization, etc.

### Security Patterns
- **Profiles**: Use `hypervisor.security.profile` for different security levels
- **Conditionals**: Security features should be opt-in with clear descriptions
- **Hardening**: Default to secure, provide options to relax if needed

## 📚 **Key System Components**

### Core System (`modules/core/`)
- **Purpose**: Cross-cutting options used by multiple modules
- **Contains**: User management, boot settings, GUI options
- **Rule**: Only add options here if used by 3+ modules

### Security System (`modules/security/`)
- **Profiles**: "headless" (zero-trust) vs "management" (sudo access)
- **Philosophy**: Security by default, convenience by choice
- **Key Files**: profiles.nix, base.nix, kernel-hardening.nix

### Web Dashboard (`modules/web/`)
- **Purpose**: Lightweight VM management interface
- **Technology**: Flask + Python, systemd service
- **Security**: Runs as hypervisor-operator user, localhost-only by default

### Monitoring (`modules/monitoring/`)
- **Stack**: Prometheus + Grafana + Alertmanager
- **Philosophy**: Observability without overhead
- **Pattern**: Each component has its own enable option

## 🚫 **Anti-Patterns to Avoid**

### 1. Monolithic Option Files
```nix
# DON'T DO THIS
modules/core/options.nix:
  options.hypervisor = {
    web = { /* 50 lines */ };
    monitoring = { /* 100 lines */ };
    backup = { /* 75 lines */ };
    # ... 500+ lines total
  };
```

### 2. Cross-Module Dependencies
```nix
# DON'T DO THIS - Creates circular dependencies
modules/web/dashboard.nix:
  # Uses option defined in different module
  config.networking.firewall.allowedTCPPorts = [ config.hypervisor.monitoring.port ];
```

### 3. Top-Level Config Access
```nix
# DON'T DO THIS - Causes infinite recursion
let
  user = config.hypervisor.management.userName;
in {
  config = { /* ... */ };
}
```

### 4. Hardcoded Values
```nix
# DON'T DO THIS - Makes system inflexible
networking.firewall.allowedTCPPorts = [ 8080 ];  # Should be configurable
```

## 🎓 **Lessons Learned**

### Technical Lessons
1. **NixOS Evaluation Order Matters**: Respect module evaluation phases
2. **Conditionals Prevent Issues**: Always wrap config in `lib.mkIf`
3. **Options Belong With Implementation**: Don't separate them unnecessarily
4. **Test Early**: Small changes can have big impacts

### Architectural Lessons
1. **Modularity Scales**: Small modules are easier to maintain long-term
2. **Consistency Matters**: Standardized patterns reduce cognitive load
3. **Documentation Is Code**: Good docs prevent future mistakes
4. **User Choice Is Key**: Provide options, don't force decisions

### Process Lessons
1. **Understand Before Changing**: Learn the system before modifying it
2. **Fix Root Causes**: Don't work around problems, solve them
3. **Preserve Good Architecture**: Don't sacrifice design for quick fixes
4. **Test Thoroughly**: NixOS changes can have unexpected effects

## 🔍 **Debugging Guide**

### Infinite Recursion Errors
1. **Check for top-level config access** in `let` bindings
2. **Verify conditional wrappers** around all config sections
3. **Look for circular option dependencies** between modules
4. **Test with `nixos-rebuild dry-build --show-trace`**

### Module Not Working
1. **Check enable option** - is the module actually enabled?
2. **Verify option definitions** - are options properly defined?
3. **Check import order** - is the module imported in configuration.nix?
4. **Review conditionals** - are config sections properly wrapped?

### Performance Issues
1. **Check for unnecessary evaluations** - use conditionals properly
2. **Review option defaults** - expensive operations should be opt-in
3. **Monitor build times** - complex modules should be optional

## 🚀 **Future Development Guidelines**

### Adding New Modules
1. **Follow the template** - use standard module structure
2. **Define options locally** - keep options with implementation
3. **Use proper conditionals** - wrap config in `lib.mkIf`
4. **Test thoroughly** - verify no circular dependencies
5. **Document decisions** - update this guide with new patterns

### Modifying Existing Modules
1. **Understand current behavior** - read the module completely
2. **Preserve user options** - maintain backward compatibility
3. **Follow existing patterns** - stay consistent with module style
4. **Test edge cases** - verify enable/disable behavior works

### Major Changes
1. **Document the why** - explain rationale for changes
2. **Consider impact** - how does this affect other modules?
3. **Update documentation** - keep this guide current
4. **Plan migration** - help users adapt to changes

## 📖 **Reference Materials**

### Key Files to Understand
- `configuration.nix` - Main system configuration and imports
- `modules/core/options.nix` - Core cross-cutting options
- `modules/security/profiles.nix` - Security model implementation
- `docs/dev/SYSTEM_IMPROVEMENTS_2025-10-13.md` - Recent architectural fixes

### External Resources
- [NixOS Manual - Writing NixOS Modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [Nix Pills - NixOS Module System](https://nixos.org/guides/nix-pills/nixos.html)

## 🎯 **Success Metrics**

A well-maintained Hyper-NixOS system should have:
- ✅ No infinite recursion or circular dependency errors
- ✅ Modular, topic-segregated architecture
- ✅ Options co-located with their implementations
- ✅ Consistent patterns across all modules
- ✅ Clear enable/disable behavior for all features
- ✅ Good documentation and user guides

Remember: **The goal is a system that is powerful, secure, maintainable, and respects user choice.**