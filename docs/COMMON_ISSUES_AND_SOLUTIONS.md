# Common Issues and Solutions - Hyper-NixOS

## 🎯 **Purpose**
This document catalogs common issues encountered in Hyper-NixOS, their root causes, solutions, and prevention strategies. It serves as a reference for troubleshooting and avoiding known pitfalls.

## Table of Contents
- [Critical Issues](#critical-issues)
- [Permission and Privilege Issues](#permission-and-privilege-issues)
- [Module and Configuration Issues](#module-and-configuration-issues)

## 🚨 **Critical Issues**

### Issue: Infinite Recursion Errors
**Symptoms**:
```
error: infinite recursion encountered
       at /nix/store/.../lib/modules.nix:809:9:
```

**Root Cause**: Circular dependencies in module evaluation, typically caused by:
1. Top-level `let` bindings accessing `config` values
2. Cross-module option dependencies
3. Improper module structure patterns

**Solutions**:

#### ✅ **Fix #1: Remove Top-Level Config Access (CRITICAL)**
```nix
# ❌ WRONG - Causes infinite recursion
let
  user = config.hypervisor.management.userName;
in {
  config = { /* ... */ };
}

# ✅ CORRECT - Access config inside config section
{
  config = let
    user = config.hypervisor.management.userName;
  in {
    # Configuration using user variable
  };
}
```

#### ✅ **Fix #2: Use Proper Conditional Wrappers**
```nix
# ❌ WRONG - Direct config access
{
  networking.firewall.allowedTCPPorts = [ config.hypervisor.web.port ];
}

# ✅ CORRECT - Wrapped in conditional
{
  config = lib.mkIf config.hypervisor.web.enable {
    networking.firewall.allowedTCPPorts = [ config.hypervisor.web.port ];
  };
}
```

#### ✅ **Fix #3: Move Let Bindings Inside Conditionals**
```nix
# ❌ WRONG - Top-level let accessing config (keymap-sanitizer.nix example)
{
  config = let
    key = (config.console.keyMap or "");
    invalid = builtins.elem key ["unset"];
  in lib.mkIf invalid {
    console.keyMap = lib.mkForce "us";
  };
}

# ✅ CORRECT - Let binding inside conditional
{
  config = lib.mkIf (let
    key = (config.console.keyMap or "");
  in builtins.elem key ["unset"]) {
    console.keyMap = lib.mkForce "us";
  };
}
```

#### ✅ **Fix #4: Eliminate Cross-Module Dependencies**
```nix
# ❌ WRONG - Option defined in different module
modules/web/dashboard.nix:
  config.something = config.hypervisor.monitoring.port;  # Defined elsewhere

# ✅ CORRECT - Options defined in same module
modules/web/dashboard.nix:
  options.hypervisor.web.port = { /* ... */ };
  config = lib.mkIf config.hypervisor.web.enable {
    networking.firewall.allowedTCPPorts = [ config.hypervisor.web.port ];
  };
```

**Prevention**:
- Always wrap module config in `lib.mkIf config.hypervisor.TOPIC.enable`
- Define options in the same module that uses them
- **NEVER access `config` in top-level `let` bindings** (most common cause)
- Use direct config access: `config.hypervisor.option` instead of `let var = config.hypervisor.option`
- Check ALL modules for this pattern - multiple files often have the same issue
- Test with `nixos-rebuild dry-build --show-trace`

**Recent Fixes**: 
- **(2025-10-13)**: Comprehensive fix applied to `configuration.nix`, `modules/core/directories.nix`, and `modules/security/profiles.nix`. See `docs/dev/INFINITE_RECURSION_FIX_2025-10-13.md` for details.
- **(2025-10-13 Update)**: Additional fix for `modules/core/keymap-sanitizer.nix` which had the same pattern. See `docs/dev/INFINITE_RECURSION_FIX_KEYMAP_2025-10-13.md` for details.

### Issue: Module Not Loading/Working
**Symptoms**:
- Module configuration not applied
- Services not starting
- Options not available

**Root Causes**:
1. Module not imported in `configuration.nix`
2. Module disabled (enable option set to false)
3. Conditional wrapper preventing evaluation
4. Option definition errors

**Solutions**:

#### ✅ **Check Import Status**
```bash
# Verify module is imported in configuration.nix
grep -r "modules/TOPIC/module.nix" configuration.nix
```

#### ✅ **Check Enable Status**
```nix
# Verify module is enabled
hypervisor.TOPIC.enable = true;  # Make sure this is set
```

#### ✅ **Verify Module Structure**
```nix
# Ensure proper module structure
{
  options.hypervisor.TOPIC = {
    enable = lib.mkEnableOption "Enable TOPIC";
    # Other options...
  };

  config = lib.mkIf config.hypervisor.TOPIC.enable {
    # Configuration here
  };
}
```

**Prevention**:
- Follow standardized module template
- Always include enable options for optional modules
- Test module enable/disable behavior
- Document module dependencies

### Issue: Git Not Available During Installation
**Symptoms**:
```
Git is not in PATH - some flake operations may fail
Consider installing git: nix-env -iA nixos.git
```

**Root Cause**: Nix flake operations require git for evaluation, but git may not be available in minimal installation environments.

**Solutions**:

#### ✅ **System-Level Git Installation**
Git is now included in core system packages (`modules/core/packages.nix`):
```nix
environment.systemPackages = with pkgs; [
  # System utilities
  git  # Required for flake operations and updates
  # ... other packages
];
```

#### ✅ **Flake-Level Git Provision**
The `flake.nix` provides git in installer apps:
```nix
apps.system-installer = {
  type = "app";
  program = lib.getExe (pkgs.writeShellScriptBin "hypervisor-system-installer" ''
    # Ensure git is in PATH for flake operations
    export PATH="${pkgs.git}/bin:$PATH"
    exec ${pkgs.bash}/bin/bash ${./scripts/system_installer.sh} "$@"
  '');
};
```

**Prevention**:
- Include git in core system packages for all NixOS configurations using flakes
- Provide git in PATH for any scripts that perform flake operations
- Test installation in minimal environments without git pre-installed

## ⚠️ **Common Warnings and Errors**

### Issue: Option Conflicts
**Symptoms**:
```
error: The option `services.something` is defined multiple times
```

**Root Cause**: Same option defined in multiple modules or files.

**Solutions**:
- Use `lib.mkMerge` for combining configurations
- Use `lib.mkForce` to override existing values
- Use `lib.mkDefault` for default values that can be overridden

```nix
# ✅ Merge multiple configurations
config = lib.mkMerge [
  (lib.mkIf condition1 { /* config 1 */ })
  (lib.mkIf condition2 { /* config 2 */ })
];

# ✅ Override existing value
services.something.enable = lib.mkForce true;

# ✅ Provide default that can be overridden
services.something.port = lib.mkDefault 8080;
```

### Issue: Type Errors
**Symptoms**:
```
error: A definition for option `...` is not of type `...`
```

**Root Cause**: Value doesn't match expected type.

**Solutions**:
- Check option type definition
- Convert values to correct type
- Use proper NixOS types

```nix
# ✅ Common type conversions
port = lib.mkOption {
  type = lib.types.port;  # Ensures valid port number
  default = 8080;
};

enable = lib.mkOption {
  type = lib.types.bool;  # Boolean values only
  default = false;
};

paths = lib.mkOption {
  type = lib.types.listOf lib.types.path;  # List of paths
  default = [];
};
```

### Issue: Service Failures
**Symptoms**:
- Services failing to start
- Permission denied errors
- Missing dependencies

**Common Causes & Solutions**:

#### ✅ **User/Group Issues**
```nix
# Ensure user exists before service starts
users.users.myuser = {
  isSystemUser = true;
  group = "mygroup";
};
users.groups.mygroup = {};

systemd.services.myservice = {
  serviceConfig.User = "myuser";
  # Service will start after user creation
};
```

#### ✅ **Directory Permissions**
```nix
# Create directories with proper permissions
systemd.tmpfiles.rules = [
  "d /var/lib/myapp 0755 myuser mygroup - -"
];
```

#### ✅ **Dependency Ordering**
```nix
systemd.services.myservice = {
  after = [ "network.target" "other-service.service" ];
  wants = [ "network.target" ];
  requires = [ "other-service.service" ];
};
```

## 🔧 **Performance Issues**

### Issue: Slow Build Times
**Symptoms**: `nixos-rebuild` takes very long time

**Causes & Solutions**:

#### ✅ **Unnecessary Evaluations**
```nix
# ❌ WRONG - Always evaluates expensive operation
config = {
  services.something = expensiveFunction config.other.value;
};

# ✅ CORRECT - Only evaluates when needed
config = lib.mkIf config.hypervisor.feature.enable {
  services.something = expensiveFunction config.other.value;
};
```

#### ✅ **Optimize Conditionals**
```nix
# ✅ Use early returns for expensive operations
config = lib.mkIf (!config.hypervisor.feature.enable) {};
# vs evaluating everything then discarding
```

### Issue: High Memory Usage
**Symptoms**: System running out of memory during builds

**Solutions**:
- Disable unnecessary modules during development
- Use `nix-collect-garbage` to clean up old builds
- Increase swap space for large builds

## 🛡️ **Security Issues**

### Issue: Permission Denied
**Symptoms**: Services can't access files/directories

**Solutions**:
```nix
# ✅ Proper service permissions
systemd.services.myservice = {
  serviceConfig = {
    User = "myuser";
    Group = "mygroup";
    ReadWritePaths = [ "/var/lib/myapp" ];
    ReadOnlyPaths = [ "/etc/myapp" ];
  };
};
```

### Issue: Firewall Blocking Services
**Symptoms**: Services not accessible from network

**Solutions**:
```nix
# ✅ Open required ports
networking.firewall = {
  allowedTCPPorts = [ 80 443 8080 ];
  allowedUDPPorts = [ 53 ];
};

# ✅ Interface-specific rules
networking.firewall.interfaces."lo".allowedTCPPorts = [ 8080 ];
```

## 🔍 **Debugging Techniques**

### Build Issues
```bash
# Get detailed error information
nixos-rebuild dry-build --show-trace

# Check specific module
nix-instantiate --eval --strict -E 'import ./modules/web/dashboard.nix'

# Verify configuration syntax
nix-instantiate --parse configuration.nix
```

### Runtime Issues
```bash
# Check service status
systemctl status myservice

# View service logs
journalctl -u myservice -f

# Check configuration files
nixos-option services.myservice
```

### Module Issues
```bash
# List all options for a module
nixos-option hypervisor.web

# Check option values
nixos-option hypervisor.web.enable
nixos-option hypervisor.web.port
```

## 📋 **Prevention Checklist**

### Before Making Changes
- [ ] Understand the current system behavior
- [ ] Read existing module code completely
- [ ] Check for similar patterns in other modules
- [ ] Plan the change to avoid circular dependencies

### Module Development
- [ ] Follow standardized module template
- [ ] Define options in same module as implementation
- [ ] Wrap config in `lib.mkIf` conditionals
- [ ] Test enable/disable behavior
- [ ] Document any special requirements

### Testing Changes
- [ ] Test with `nixos-rebuild dry-build --show-trace`
- [ ] Verify no infinite recursion errors
- [ ] Test module enable/disable functionality
- [ ] Check service startup and logs
- [ ] Validate configuration options work correctly

### Documentation
- [ ] Update relevant documentation
- [ ] Document any new patterns or decisions
- [ ] Add troubleshooting notes for complex features
- [ ] Update this guide with new issues discovered

## 🎯 **When to Seek Help**

### Complex Issues
- Infinite recursion that can't be resolved with standard fixes
- Performance problems affecting entire system
- Security vulnerabilities requiring immediate attention
- Breaking changes affecting multiple modules

### Before Seeking Help
1. **Gather Information**:
   - Full error messages with `--show-trace`
   - System configuration details
   - Steps to reproduce the issue
   - What was changed recently

2. **Try Standard Solutions**:
   - Check this troubleshooting guide
   - Review module patterns in working modules
   - Test with minimal configuration
   - Verify NixOS version compatibility

3. **Document the Issue**:
   - Clear description of problem
   - Expected vs actual behavior
   - Configuration snippets
   - Error messages and logs

Remember: Most issues have been encountered before. Check documentation, follow established patterns, and test thoroughly.

## 🔐 **Permission and Privilege Issues**

### Issue: "Permission Denied" for VM Operations
**Symptoms**:
```
error: Cannot access libvirt socket
Permission denied
```

**Root Cause**: User not in required groups for VM management

**Solution**:
```bash
# Add user to required groups
sudo usermod -aG libvirtd,kvm username

# Logout and login again for changes to take effect
```

**Prevention**:
- Configure users properly in `configuration.nix`:
  ```nix
  hypervisor.security.privileges = {
    enable = true;
    vmUsers = [ "username" ];
  };
  ```

### Issue: VM Operations Asking for Sudo Password
**Symptoms**:
```
[sudo] password for user:
```

**Root Cause**: Misconfigured polkit rules or user not in correct group

**Solution**:
1. Verify polkit rules are installed:
   ```bash
   ls /etc/polkit-1/rules.d/50-hypervisor*
   ```

2. Check user groups:
   ```bash
   groups
   # Should include: libvirtd kvm
   ```

3. Enable polkit rules in configuration:
   ```nix
   hypervisor.security.polkit = {
     enable = true;
     enableVMRules = true;
   };
   ```

### Issue: System Operations Not Working Without Sudo
**Symptoms**:
```
═══════════════════════════════════════════════════════════════
  This operation requires administrator privileges
═══════════════════════════════════════════════════════════════
```

**Expected Behavior**: This is correct! System operations SHOULD require sudo.

**Proper Usage**:
```bash
# Correct - system operations need sudo
sudo system-config network setup-bridge br0

# Incorrect - trying without sudo
system-config network setup-bridge br0  # Will fail with clear message
```

### Issue: Script Shows "Missing Required Group Membership"
**Symptoms**:
```
═══════════════════════════════════════════════════════════════
  Missing Required Group Membership
═══════════════════════════════════════════════════════════════

  Your user needs to be in these groups:
    • libvirtd
    • kvm
```

**Solution**:
1. Have an admin add you to groups:
   ```bash
   sudo usermod -aG libvirtd,kvm $USER
   ```

2. Logout and login again

3. Verify groups:
   ```bash
   groups
   ```

### Issue: "Operation not allowed in hardened mode"
**Symptoms**:
```
ERROR: Operation 'system_config' not allowed in hardened mode
```

**Root Cause**: System is in hardened security phase

**Solution**:
1. Check current phase:
   ```bash
   cat /etc/hypervisor/.phase* 2>/dev/null
   ```

2. If needed, transition to setup phase (requires sudo):
   ```bash
   sudo transition_phase.sh setup
   ```

3. Perform operation, then harden again:
   ```bash
   sudo transition_phase.sh harden
   ```

**Prevention**: Plan system changes during setup phase