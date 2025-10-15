# Common Issues and Solutions - Hyper-NixOS

## 🎯 **Purpose**
This document catalogs common issues encountered in Hyper-NixOS, their root causes, solutions, and prevention strategies. It serves as a reference for troubleshooting and avoiding known pitfalls.

## Table of Contents
- [Critical Issues](#critical-issues)
- [Installer Issues](#installer-issues)
- [Permission and Privilege Issues](#permission-and-privilege-issues)
- [Module and Configuration Issues](#module-and-configuration-issues)
- [CI/CD and Testing Issues](#cicd-and-testing-issues)
- [Hardware and Kernel Issues](#hardware-and-kernel-issues)
- [Service Configuration Issues](#service-configuration-issues)

## 🚨 **Critical Issues**

### Issue: "The option `services.auditd' does not exist"
**Symptoms**:
```
error: The option `services.auditd' does not exist. Definition values:
       - In `/nix/store/.../modules/security/credential-chain.nix':
           {
             _type = "if";
             condition = true;
             content = {
               enable = true;
```

**Root Cause**: The audit service module is not available in minimal NixOS configurations or when the audit module isn't imported. Security modules try to enable audit services unconditionally.

**Module Structure Issue**: In some cases, the module structure itself can cause evaluation issues even with proper conditional checks. Nested `lib.mkIf` conditions can cause NixOS to evaluate options that don't exist.

**Solutions**:

#### ✅ **Option 1: Import the audit module** (Recommended)
Add to your configuration imports:
```nix
{
  imports = [
    # ... other imports
    <nixpkgs/nixos/modules/security/audit.nix>
  ];
}
```

#### ✅ **Option 2: Fix module structure** (For module developers)
If you're developing modules, ensure proper conditional structure:
```nix
# WRONG - Nested conditionals can cause evaluation issues:
config = lib.mkIf cfg.enable (lib.mkMerge [
  { ... }
  (lib.mkIf (config.services ? auditd) { ... })
]);

# CORRECT - Flat structure with combined conditions:
config = lib.mkMerge [
  (lib.mkIf cfg.enable { ... })
  (lib.mkIf (cfg.enable && (config.services ? auditd)) {
    services.auditd = { enable = true; };
  })
];
```

#### ✅ **Option 3: Disable audit-dependent modules**
If you don't need audit functionality:
```nix
{
  hypervisor.security.credentialChain.enable = false;
  hypervisor.security.sudoProtection.enable = false;
  # ... disable other security modules that require audit
}
```

**Prevention**:
- Security modules now check for audit service availability before enabling
- Use `lib.mkIf (config.services ? auditd)` for conditional configuration
- Wrap audit configurations in `lib.mkMerge` for proper conditional evaluation

**Technical Details**:
The fix involves restructuring module configurations to use proper conditional checks:
```nix
config = lib.mkIf cfg.enable (lib.mkMerge [
  {
    # Main configuration
  }
  
  # Conditional audit configuration
  (lib.mkIf (config.services ? auditd) {
    services.auditd.enable = true;
  })
  
  (lib.mkIf (config.security ? audit) {
    security.audit = {
      enable = true;
      rules = [ /* audit rules */ ];
    };
  })
]);
```

**Other Services That May Cause Similar Issues**:
- `security.apparmor` - Not available in all configurations
- `services.fprintd` - Fingerprint daemon (biometrics.nix)
- `services.acpid` - ACPI daemon (gui/input.nix)
- `security.rtkit` - Real-time kit (gui-local.example.nix)
- `services.dbus` - D-Bus system (biometrics.nix)

**Note**: Most of these are in optional modules that aren't imported by default

## 🚨 **Critical Issues**

### Issue: "Neither the root account nor any wheel user has a password"
**Symptoms**:
```
error:
       Failed assertions:
       - Neither the root account nor any wheel user has a password or SSH authorized key.
       You must set one to prevent being locked out of your system.
```

**Root Cause**: NixOS requires at least one user with administrative access to have authentication credentials when `users.mutableUsers = false`.

**Solutions**:

#### ✅ **Option 1: Set a hashed password**
```nix
users.users.admin = {
  isNormalUser = true;
  extraGroups = [ "wheel" "libvirtd" "kvm" ];
  hashedPassword = "$6$rounds=100000$yourSaltHere$yourHashHere";
};
```

Generate a hashed password with:
```bash
mkpasswd -m sha-512
```

#### ✅ **Option 2: Add SSH public key**
```nix
users.users.admin = {
  isNormalUser = true;
  extraGroups = [ "wheel" "libvirtd" "kvm" ];
  openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EA... your-key-comment"
  ];
};
```

#### ✅ **Option 3: Use initial password (for setup only)**
```nix
users.users.admin = {
  isNormalUser = true;
  extraGroups = [ "wheel" "libvirtd" "kvm" ];
  initialPassword = "changeme";  # CHANGE IMMEDIATELY AFTER FIRST LOGIN
};
```

#### ✅ **Option 4: Enable mutable users (not recommended for production)**
```nix
users = {
  mutableUsers = true;  # Allows changing passwords after installation
  users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "kvm" ];
  };
};
```

#### ✅ **Option 5: Temporarily allow no password for first boot wizard (Hyper-NixOS)**
```nix
users = {
  mutableUsers = false;
  allowNoPasswordLogin = true;  # TEMPORARY - for first boot setup only
  
  users.admin = {
    isNormalUser = true;
    description = "System Administrator";
    extraGroups = [ "wheel" "libvirtd" "kvm" ];
    # Password will be set by first boot wizard
  };
};
```
**IMPORTANT**: This option should only be used with Hyper-NixOS's first boot wizard. After initial setup:
1. Set a proper password using the wizard or `passwd` command
2. Remove or set `allowNoPasswordLogin = false`
3. Rebuild your configuration

**Best Practices**:
1. For production systems, use hashed passwords or SSH keys
2. Never use `initialPassword` in production
3. If using `mutableUsers = true`, run `passwd admin` immediately after installation
4. Consider having multiple admin users for redundancy
5. For Hyper-NixOS, ensure both the admin user and hypervisor management user have credentials

**Example for Hyper-NixOS**:
```nix
users = {
  mutableUsers = false;
  
  # System administrator
  users.admin = {
    isNormalUser = true;
    description = "System Administrator";
    extraGroups = [ "wheel" "libvirtd" "kvm" ];
    hashedPassword = "$6$...";  # Generate with mkpasswd
    openssh.authorizedKeys.keys = [ "ssh-rsa ..." ];  # Optional redundancy
  };
  
  # Hypervisor management user (automatically created by hypervisor-base.nix)
  users.hypervisor = {
    hashedPassword = "$6$...";  # Or use initialPassword for first boot wizard
  };
};
```

**Prevention**:
- Always set authentication for at least one wheel group user
- Use the first boot wizard in Hyper-NixOS to set passwords interactively
- Consider using `configuration-complete.nix` as a template which includes proper user setup

### Issue: The option 'hypervisor.enable' does not exist
**Symptoms**:
```
error: The option `hypervisor.enable' does not exist. Definition values:
       - In `/nix/store/.../configuration-minimal.nix': true
```

**Root Cause**: The core options module that defines `hypervisor.enable` is not imported.

**Solution**:
1. Ensure `modules/core/options.nix` is imported in your configuration:
```nix
imports = [
  ./hardware-configuration.nix
  ./modules/core/options.nix  # Add this import
  ./modules/core/hypervisor-base.nix  # And this for base functionality
  # ... other imports
];
```

2. Make sure `hypervisor.enable = true;` is set in your configuration:
```nix
hypervisor.enable = true;
```

**Prevention**:
- Always import core option modules before using their options
- The modular architecture requires explicit imports
- Check that all required base modules are imported

## 📦 **Installer Issues**

### Issue: "BASH_SOURCE[0]: unbound variable" in install.sh
**Symptoms**:
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
bash: line 158: BASH_SOURCE[0]: unbound variable
```

**Root Cause**: When a bash script is piped from `curl` (stdin), `BASH_SOURCE[0]` is undefined. The script uses `set -u` (treat undefined variables as errors), causing the script to fail when trying to access `${BASH_SOURCE[0]}`.

**Technical Details**:
- When executed directly: `BASH_SOURCE[0]` contains the script path
- When piped from curl: `BASH_SOURCE[0]` is empty/undefined
- When sourced: `BASH_SOURCE[0]` != `$0`

**Solution**:
The script needs to handle all three cases:

```bash
# WRONG - Fails when piped from curl
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# CORRECT - Handles piped, executed, and sourced cases
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

**Pattern for Piped Scripts**:
When writing bash scripts meant to be piped from curl, always:

1. **Check for undefined variables with defaults**:
```bash
local script_dir="${BASH_SOURCE[0]:-}"
if [[ -n "$script_dir" ]]; then
    script_dir="$(cd "$(dirname "$script_dir")" && pwd)"
else
    script_dir="$(pwd)"
fi
```

2. **Use detection functions that work when piped**:
```bash
detect_mode() {
    # Can't use dirname "$0" when piped
    local script_dir="${BASH_SOURCE[0]:-}"
    if [[ -n "$script_dir" ]] && [[ -f "$(dirname "$script_dir")/scripts/installer.sh" ]]; then
        echo "local"
    else
        echo "remote"
    fi
}
```

3. **Run main conditionally**:
```bash
# Run if piped OR executed (but not if sourced)
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

**Prevention**:
- Always use `${BASH_SOURCE[0]:-}` with default empty string when `set -u` is enabled
- Test scripts both ways: `./script.sh` AND `cat script.sh | bash`
- Consider whether `set -u` is necessary for installer scripts
- Document that the script supports piped execution

**Related Issues**:
- Any script using `dirname "$0"` will fail when piped
- Functions like `readlink -f "$0"` also fail when piped
- Use `BASH_SOURCE` with proper defaults instead

**Comprehensive Fix**:
This pattern was found to affect 35+ scripts across the codebase. A comprehensive fix was applied to all affected scripts. See:
- `docs/dev/BASH_SOURCE_VULNERABILITY_FIX_2025-10-15.md` - Full analysis and fix details
- `scripts/lib/bash_source_safe.sh` - Safe utility functions library
- `scripts/tools/fix-bash-source-pattern.sh` - Audit and fix tool

**Scripts Fixed** (35 total):
- All installer and bootstrap scripts
- All wizard scripts (setup, configuration, etc.)
- VM management scripts (hv-migrate, hv-bootstrap, etc.)
- Library files (config_backup, dry_run, error_handling, etc.)
- Test scripts and CI validation
- Various utility scripts

All scripts now use the safe pattern: `${BASH_SOURCE[0]:-$0}` which works in all execution contexts.

### Issue: Duplicate Option Definitions
**Symptoms**:
```
error: attribute 'enabledFeatures' already defined at /nix/store/.../feature-manager.nix:104:5
       at /nix/store/.../feature-manager.nix:134:5
```

**Root Cause**: The same option is defined multiple times at the same level in a module.

**Solution**:
1. Remove duplicate option definitions
2. Keep only one definition with the most complete description
3. Ensure the option type and default values are consistent

**Example Fix**:
```nix
# Remove duplicate:
options.hypervisor.featureManager = {
  enabledFeatures = mkOption {  # First definition at line 104
    type = types.listOf types.str;
    default = [];
    description = "List of enabled features";
  };
  
  # ... other options ...
  
  enabledFeatures = mkOption {  # DUPLICATE at line 134 - REMOVE THIS
    type = types.listOf types.str;
    default = [];
    description = "List of enabled features";
  };
};
```

**Prevention**:
- Use editor search to check if an option name already exists before adding
- Keep options organized alphabetically or by category
- Run `nixos-rebuild dry-build` frequently during development

### Issue: mkOption 'check' Argument Error
**Symptoms**:
```
error: function 'mkOption' called with unexpected argument 'check'
       at /nix/store/.../lib/options.nix:67:5
```

**Root Cause**: The `check` argument is not valid for `mkOption`. NixOS uses type constructors for validation, not separate check functions.

**Solution**:
Use appropriate type constructors for validation:

```nix
# ❌ WRONG - Don't use check argument
userName = lib.mkOption {
  type = lib.types.str;
  default = "hypervisor";
  description = "Username for the management user account";
  check = name: builtins.match "^[a-z_][a-z0-9_-]*$" name != null;
};

# ✅ CORRECT - Use strMatching for regex validation
userName = lib.mkOption {
  type = lib.types.strMatching "^[a-z_][a-z0-9_-]*$";
  default = "hypervisor";
  description = "Username for the management user account (must follow Unix naming conventions)";
};
```

**Common Validation Patterns**:
```nix
# String matching regex
userName = lib.mkOption {
  type = lib.types.strMatching "^[a-z_][a-z0-9_-]*$";
};

# Integer ranges
port = lib.mkOption {
  type = lib.types.ints.between 1 65535;
};

# Positive integers
count = lib.mkOption {
  type = lib.types.ints.positive;
};

# Email validation
email = lib.mkOption {
  type = lib.types.strMatching "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$";
};

# Path validation
configPath = lib.mkOption {
  type = lib.types.path;
};

# Enum validation
logLevel = lib.mkOption {
  type = lib.types.enum [ "debug" "info" "warn" "error" ];
};
```

**Prevention**:
- Always use type constructors for validation
- Refer to NixOS manual section on types
- Common types with validation: `strMatching`, `ints.between`, `enum`, `path`
- Never add custom arguments to `mkOption`

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

### Issue: Undefined Variable 'elem' (or other lib functions)
**Symptoms**:
```
error: undefined variable 'elem'
       at /path/to/configuration.nix:XXX:XX:
```

**Root Cause**: Using library functions without the `lib.` prefix in files that don't have `with lib;` at the top.

**Solutions**:

#### ✅ **Fix #1: Add lib. prefix**
```nix
# ❌ WRONG (without `with lib;`)
prometheus = lib.mkIf (elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {

# ✅ CORRECT
prometheus = lib.mkIf (lib.elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {
```

#### ✅ **Fix #2: Use `with lib;` at the top**
```nix
{ config, lib, pkgs, ... }:

with lib;  # Add this line

{
  # Now you can use elem without lib. prefix
  prometheus = mkIf (elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {
```

**Common lib functions that need prefix**:
- `elem` - check if element is in list
- `mkIf` - conditional configuration
- `mkDefault` - set default value
- `mkForce` - force override value
- `mkOption` - define option
- `mkEnableOption` - define boolean enable option
- `optional` - return list with element if condition is true
- `optionals` - return list if condition is true
- `flatten` - flatten nested lists
- `mapAttrsToList` - map over attribute set

**Prevention**:
1. Always use `lib.` prefix for safety
2. If using `with lib;`, place it right after the function arguments
3. Be consistent within a file - either use `with lib;` or always prefix
4. When copying code between files, check if source has `with lib;`

**Recent Fix**:
- **(2025-10-14)**: Fixed undefined `elem` in `configuration-complete.nix` lines 168, 184, and 209 by adding `lib.` prefix.

### Issue: Python Code in Nix Multiline Strings
**Symptoms**:
```
error: syntax error, unexpected ')', expecting '}'
       at /path/to/module.nix:XXX:XX:
                          threat.get('target', ''),
                                                  ^
```

**Root Cause**: Single quotes in Python code conflict with Nix multiline string delimiters (`''`). In Nix, to include a literal single quote inside a multiline string, you must escape it by doubling it (`''`).

**Solutions**:

#### ✅ **Fix: Escape single quotes in embedded Python/scripts**
```nix
# ❌ WRONG - Unescaped single quotes in Nix multiline string
ExecStart = "${pkgs.python3}/bin/python3 ${pkgs.writeText "script.py" ''
  data = threat.get('target', '')
  items = playbook.get('actions', [])
''}";

# ✅ CORRECT - Single quotes escaped as ''
ExecStart = "${pkgs.python3}/bin/python3 ${pkgs.writeText "script.py" ''
  data = threat.get(''target'', '''')
  items = playbook.get(''actions'', [])
''}";
```

**Common patterns that need escaping**:
```nix
# Dictionary access
# ❌ WRONG:  data['key']
# ✅ CORRECT: data[''key'']

# String literals
# ❌ WRONG:  'string value'
# ✅ CORRECT: ''string value''

# Method calls with string arguments
# ❌ WRONG:  obj.get('key', 'default')
# ✅ CORRECT: obj.get(''key'', ''default'')

# Conditionals
# ❌ WRONG:  if 'key' in data:
# ✅ CORRECT: if ''key'' in data:
```

**Alternative approaches**:
1. **Use double quotes in Python** (when possible):
   ```nix
   data = threat.get("target", "")  # No escaping needed
   ```

2. **Store Python code in separate files**:
   ```nix
   ExecStart = "${pkgs.python3}/bin/python3 ${./script.py}";
   ```

3. **Use pkgs.writeScript with shebang**:
   ```nix
   myScript = pkgs.writeScript "myscript.py" ''
     #!${pkgs.python3}/bin/python3
     data = threat.get(''target'', '''')
   '';
   ```

**Prevention**:
1. Always escape single quotes in Nix multiline strings
2. Consider using double quotes in embedded Python code
3. For complex scripts, use separate files
4. Test build after adding embedded code

**Recent Fixes**:
- **(2025-10-14)**: Fixed Python single quotes in `modules/security/threat-response.nix` and `modules/security/behavioral-analysis.nix`. Applied systematic escaping to all `.get()` calls and dictionary keys.

### Issue: Bash Variables in Nix Multiline Strings
**Symptoms**:
```
error: undefined variable 'shadow_hash'
       at /nix/store/.../modules/security/credential-chain.nix:24:20:
           23|
           24|         echo -n "${shadow_hash}:${passwd_hash}:${machine_id}" | sha512sum | cut -d' ' -f1
              |                    ^
           25|     }
```

**Root Cause**: When using Nix multiline strings (`''...''`), Nix tries to interpolate `${...}` expressions during evaluation. Bash variables inside these strings must be escaped to prevent Nix from interpreting them.

**Solutions**:

#### ✅ **Fix: Escape bash variables by doubling the dollar sign**
```nix
# ❌ WRONG - Unescaped bash variables in Nix multiline string
credentialVerifier = pkgs.writeScriptBin "verify-credentials" ''
  #!${pkgs.bash}/bin/bash
  compute_system_hash() {
    local shadow_hash=$(sha512sum /etc/shadow | cut -d' ' -f1)
    echo -n "${shadow_hash}:${passwd_hash}" | sha512sum  # ERROR: Nix tries to interpolate
  }
'';

# ✅ CORRECT - Bash variables escaped with ''$
credentialVerifier = pkgs.writeScriptBin "verify-credentials" ''
  #!${pkgs.bash}/bin/bash
  compute_system_hash() {
    local shadow_hash=$(sha512sum /etc/shadow | cut -d' ' -f1)
    echo -n "''${shadow_hash}:''${passwd_hash}" | sha512sum  # Correctly escaped
  }
'';
```

#### ✅ **Common bash variables that need escaping**:
```nix
# Local variables
local var="value"
echo "''${var}"                    # Not echo "${var}"

# Environment variables
if [[ ''$EUID -ne 0 ]]; then      # Not if [[ $EUID -ne 0 ]]; then

# Script arguments
case "''${1:-default}" in          # Not case "${1:-default}" in

# Command substitution
echo "Result: ''$(command)"        # Not echo "Result: $(command)"

# Arrays and special variables
echo "''${array[@]}"               # Not echo "${array[@]}"
echo "''$@"                        # Not echo "$@"
```

#### ✅ **Variables that should NOT be escaped**:
```nix
# Nix package paths - these SHOULD be interpolated by Nix
ExecStart = "${pkgs.bash}/bin/bash"              # Correct - Nix interpolation
source "${pkgs.common}/lib/common.sh"            # Correct - Nix interpolation

# Nix variables
echo "${cfg.someOption}"                         # Correct - Nix config value
```

**Prevention**:
1. Remember: `''$` for bash variables, `$` for Nix variables
2. Test scripts by building the derivation
3. Use shellcheck on the generated scripts
4. Consider using separate script files for complex bash scripts

**History**:
- **(2025-10-15)**: Fixed bash variable escaping in `modules/security/credential-chain.nix`. All bash variables in multiline strings now properly escaped with `''$`.

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

### Issue: Undefined Variable Errors in Nix Modules
**Symptoms**:
```
error: undefined variable 'flatten'
error: undefined variable 'elem'
error: undefined variable 'concatStringsSep'
```

**Root Cause**: Nix library functions must be prefixed with `lib.` unless the file has `with lib;` at the top.

**Solutions**:

#### ✅ **Add lib. Prefix to All Library Functions**
```nix
# Wrong
flatten (map getTierFeatures currentTier.inherits)
elem "feature" enabledFeatures
concatStringsSep "\n" items

# Correct
lib.flatten (map getTierFeatures currentTier.inherits)
lib.elem "feature" enabledFeatures
lib.concatStringsSep "\n" items
```

#### ✅ **Common Functions That Need lib. Prefix**
```nix
lib.flatten        # Flatten nested lists
lib.elem          # Check if element is in list
lib.filter        # Filter list elements
lib.unique        # Remove duplicates from list
lib.foldl'        # Left fold (strict)
lib.mapAttrs      # Map over attribute set
lib.mapAttrsToList # Map attrs to list
lib.findFirst     # Find first matching element
lib.attrValues    # Get values from attribute set
lib.length        # Get list length
lib.concatStringsSep     # Join strings with separator
lib.concatMapStringsSep  # Map and join with separator
lib.optionalString       # Conditional string
```

#### ✅ **For Package References Use pkgs. Prefix**
```nix
# Wrong
writeScriptBin "script" ''
  #!${bash}/bin/bash
  ${jq}/bin/jq ...
''

# Correct
pkgs.writeScriptBin "script" ''
  #!${pkgs.bash}/bin/bash
  ${pkgs.jq}/bin/jq ...
''
```

**Prevention**:
- Always use `lib.` prefix for library functions
- Always use `pkgs.` prefix for packages
- Or use `with lib;` at the top of the module (but explicit prefixes are preferred)
- Test module syntax with `nixos-rebuild dry-build --show-trace`

### Issue: Missing Attribute Error - Module Dependencies
**Symptoms**:
```
error: attribute 'features' missing
       at /nix/store/.../modules/features/feature-manager.nix:9:14:
            8|   cfg = config.hypervisor.featureManager;
            9|   features = config.hypervisor.features;
```

**Root Cause**: A module is trying to access an option (`config.hypervisor.features`) that is defined in another module that hasn't been imported.

**Solutions**:

#### ✅ **Import All Required Modules**
If module A depends on options defined in module B, both must be imported:
```nix
imports = [
  ./modules/features/feature-categories.nix  # Defines hypervisor.features
  ./modules/features/feature-manager.nix     # Uses hypervisor.features
];
```

#### ✅ **Check Module Dependencies**
Common module dependencies in Hyper-NixOS:
- `feature-manager.nix` requires `feature-categories.nix`
- `tier-templates.nix` requires `feature-categories.nix`
- Many modules require `core/options.nix` for base options

#### ✅ **Verify Option Definitions**
To find where an option is defined:
```bash
# Search for option definition
grep -r "options\.hypervisor\.features\s*=" modules/

# Check if a module is imported
grep -h "feature-categories\.nix" configuration*.nix
```

**Prevention**:
- When creating modules that reference other options, document the dependencies
- Import modules in the correct order (dependencies first)
- Keep related options in the same module when possible
- Test configurations with `nixos-rebuild dry-build --show-trace`

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

### Issue: "attribute 'enable' missing" in NixOS modules
**Symptoms**:
```
error: attribute 'enable' missing
       at /nix/store/.../modules/features/feature-categories.nix:446:59:
          445|     # Generate security report
          446|     system.activationScripts.featureSecurityReport = mkIf cfg.enable ''
```

**Root Cause**: Trying to access an attribute that doesn't exist in the configuration. Common causes:
1. Using `cfg.enable` when `cfg` points to a configuration namespace without an `enable` option
2. Referencing attributes that don't exist in data structures
3. Assuming runtime state exists in static definitions

**Solutions**:

#### ✅ **Check if the attribute exists before using it**
```nix
# Bad - assumes cfg has enable attribute
system.activationScripts.myScript = mkIf cfg.enable ''
  echo "Running script"
'';

# Good - checks if the module is actually enabled
system.activationScripts.myScript = mkIf (config.myModule ? enable && config.myModule.enable) ''
  echo "Running script"
'';
```

#### ✅ **Use the correct configuration path**
```nix
# If cfg = config.hypervisor.features
# But enable is in config.hypervisor.featureManager.enable
# Then use:
mkIf config.hypervisor.featureManager.enable
```

#### ✅ **For feature checking, use the enabled features list**
```nix
# Bad - features don't have an 'enabled' attribute
optionalString feat.enabled "Feature is enabled"

# Good - check if feature is in the enabled list
optionalString (lib.elem featName config.hypervisor.featureManager.enabledFeatures) "Feature is enabled"
```

**Prevention**:
- Always verify configuration structure before accessing nested attributes
- Use `?` operator to check attribute existence: `config.module ? attribute`
- Remember that feature definitions are static; runtime state is tracked elsewhere
- Test modules with `nixos-rebuild dry-build --show-trace` to catch errors early

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

## 📂 **File Organization and IP Protection**

### Issue: IP-Protected Content in Public Release
**Symptoms**:
- AI documentation files in public-release folder
- Implementation reports visible in distribution
- Audit/test scripts included in public package

**Root Cause**: Incorrect file placement violating IP protection rules

**Solution**:
Move IP-protected content to appropriate locations:
```bash
# AI documentation → docs/dev/
mv public-release/docs/development/AI-*.md docs/dev/

# Implementation reports → docs/dev/implementation/
mkdir -p docs/dev/implementation
mv public-release/docs/implementation/*.md docs/dev/implementation/

# Audit/test scripts → scripts/audit/
mkdir -p scripts/audit
mv public-release/*-platform-*.sh scripts/audit/
```

**IP Protection Rules**:
- **Private (Never in public-release)**:
  - AI-*.md files
  - Implementation reports
  - Audit and test scripts
  - Development methodologies
  
- **Public (Safe for distribution)**:
  - User guides
  - Basic deployment scripts
  - Architecture overviews (without implementation details)

**Prevention**:
1. Always check IP classification before adding to public-release
2. Keep development docs in docs/dev/
3. Review public-release contents before distribution

**Recent Fix**:
- **(2025-10-14)**: Moved all IP-protected content from public-release to appropriate private locations

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

## 🧪 **CI/CD and Testing Issues**

### Issue: Unit Tests Failing in GitHub Actions CI
**Symptoms**:
```
Running: test_common... FAIL
✗ Some CI validation checks failed
Error: Process completed with exit code 1.
```

**Root Causes**:
1. Tests expect system paths that don't exist in CI (`/var/lib/hypervisor/`)
2. Missing dependencies (`jq`, `virsh`) in CI environment
3. Library files performing actions during sourcing
4. CI test runner overly aggressive in skipping tests

**Solutions**:

#### ✅ **Fix #1: Setup Test Environment Before Sourcing**
```bash
# ✅ CORRECT - Setup before source
TEST_TEMP_DIR=$(mktemp -d)
export HYPERVISOR_LOGS="$TEST_TEMP_DIR/logs"
export HYPERVISOR_STATE="$TEST_TEMP_DIR"
mkdir -p "$HYPERVISOR_LOGS"

source "$SCRIPTS_DIR/lib/common.sh"

# ❌ WRONG - Source then setup
source "$SCRIPTS_DIR/lib/common.sh"
export HYPERVISOR_LOGS="/tmp/logs"  # Too late!
```

#### ✅ **Fix #2: Filter Dependency Checks for CI**
```bash
# Remove require statements when testing
sed '/^require jq virsh$/d' "$SCRIPTS_DIR/lib/common.sh" > "$TEMP/common_ci.sh"
source "$TEMP/common_ci.sh"
```

#### ✅ **Fix #3: Install CI Dependencies**
```bash
# In test script
if [[ "${CI:-false}" == "true" ]]; then
    # Try to install jq
    if ! command -v jq >/dev/null && command -v apt-get >/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y jq
    fi
fi
```

#### ✅ **Fix #4: Create CI-Specific Test Files**
```bash
# tests/unit/test_common_ci.sh - CI-friendly version
# Avoids keywords that trigger test skipping
# Handles missing dependencies gracefully
```

**Prevention**:
- Design libraries with lazy initialization
- Don't perform actions during source/import
- Provide environment variable overrides
- Test in CI-like environment locally
- Document CI limitations in tests

### Issue: Tests Skipped When They Should Run
**Symptoms**:
```
Running: test_common... SKIP (requires libvirt)
```

**Root Cause**: Test runner greps for keywords to skip system-dependent tests

**Solution**:
```bash
# Avoid trigger words in test files
# Instead of: virsh list
# Use: VM_MANAGER list
# Or create separate CI test files
```

### Issue: "No such file or directory" in CI
**Symptoms**:
```
/workspace/scripts/lib/common.sh: line 66: /var/lib/hypervisor/logs/script.log: No such file or directory
```

**Root Cause**: Hardcoded paths in scripts

**Solution**:
```bash
# Use environment variables with defaults
LOG_FILE="${LOG_FILE:-${HYPERVISOR_LOGS}/script.log}"
HYPERVISOR_LOGS="${HYPERVISOR_LOGS:-/var/lib/hypervisor/logs}"
```

### Issue: PATH Override Breaking Tests
**Symptoms**:
- Mock commands not found
- Test setup ignored

**Root Cause**: Library overwrites PATH variable

**Solution**:
```bash
# Save and restore PATH in tests
ORIGINAL_PATH="$PATH"
source common.sh
export PATH="$TEST_BIN_DIR:$PATH"
```

### Issue: CI Environment Missing Tools
**Symptoms**:
```
shellcheck: command not found
jq: command not found
```

**Solution in GitHub Actions**:
```yaml
- name: Install dependencies
  run: |
    sudo apt-get update -qq
    sudo apt-get install -y shellcheck jq
```

**For Local CI Testing**:
```bash
# Simulate CI environment
export CI=true
export GITHUB_ACTIONS=true
./tests/run_all_tests.sh
```

### Best Practices for CI-Friendly Code

1. **Lazy Initialization**:
   ```bash
   # Good
   init_logs() {
       mkdir -p "$HYPERVISOR_LOGS"
   }
   
   # Bad  
   mkdir -p "$HYPERVISOR_LOGS"  # Runs on source
   ```

2. **Environment Detection**:
   ```bash
   if [[ "${CI:-false}" == "true" ]]; then
       # CI-specific behavior
   fi
   ```

3. **Configurable Paths**:
   ```bash
   : "${HYPERVISOR_ROOT:=/etc/hypervisor}"
   : "${HYPERVISOR_LOGS:=/var/lib/hypervisor/logs}"
   ```

4. **Graceful Degradation**:
   ```bash
   if command -v jq >/dev/null; then
       # Use jq
   else
       # Fallback method
   fi
   ```

### Issue: test_common_ci Still Failing After Initial Fixes (Update 2025-10-13)
**Symptoms**:
```
Running in CI mode - installing dependencies

TEST SUITE: common.sh library (CI)
[Test exits with code 1 without output]
```

**Root Causes**:
1. `common.sh` declares path variables as `readonly`, preventing test overrides
2. The `require` function calls `exit 1` directly, terminating the test script
3. Strict error handling (`set -e`) from sourced library affects test execution

**Solutions**:

#### ✅ **Fix #1: Remove Readonly Declarations in Test Environment**
```bash
# Convert readonly variables to regular ones
sed -i 's/^readonly HYPERVISOR_ROOT=/HYPERVISOR_ROOT=/g' "$TEST_TEMP_DIR/common_ci.sh"
sed -i 's/^readonly HYPERVISOR_STATE=/HYPERVISOR_STATE=/g' "$TEST_TEMP_DIR/common_ci.sh"
# ... repeat for all HYPERVISOR_* variables

# Then re-export test paths to override
export HYPERVISOR_ROOT="$TEST_TEMP_DIR"
```

#### ✅ **Fix #2: Use Subshells for Tests That May Exit**
```bash
# ✅ CORRECT - Subshell prevents script termination
(require nonexistent_command_xyz 2>/dev/null)
assert_failure "Should fail for missing commands"

# ❌ WRONG - Will exit the entire test script
require nonexistent_command_xyz 2>/dev/null
assert_failure "Should fail for missing commands"
```

#### ✅ **Fix #3: Disable Strict Error Handling for Tests**
```bash
# After sourcing common.sh which sets -e
set +e  # Disable exit on error for test execution
```

**Prevention**: Design libraries to be test-friendly with configurable behavior and avoid exit calls in utility functions.

### Issue: Nix Configuration Build Error - Undefined Variable
**Symptoms**:
```
error: undefined variable 'elem'
       at /nix/store/.../configuration.nix:323:28:
          322|     # System monitoring (if monitoring feature enabled)
          323|     prometheus = lib.mkIf (elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {
```

**Root Cause**: Missing `lib.` prefix for standard Nix library functions

**Solution**:

#### ✅ **Fix: Add lib. Prefix to Standard Functions**
```nix
# ❌ WRONG - elem is not in scope
prometheus = lib.mkIf (elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {
grafana = lib.mkIf (elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {

# ✅ CORRECT - Use lib.elem
prometheus = lib.mkIf (lib.elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {
grafana = lib.mkIf (lib.elem "monitoring" config.hypervisor.featureManager.enabledFeatures) {
```

**Common Functions Requiring lib. Prefix**:
- `elem`, `filter`, `map`, `any`, `all`
- `head`, `tail`, `length`, `unique`
- `concatStringsSep`, `optionalString`, `optional`
- `mkIf`, `mkDefault`, `mkForce`, `mkAfter`, `mkBefore`
- `types.*` (when defining options)

**Prevention**: Always use `lib.` prefix for standard library functions unless explicitly imported with `with lib;`

### Issue: Duplicate Attribute Definitions
**Symptoms**:
```
error: attribute 'users.users.hypervisor-vm' already defined at /nix/store/.../modules/security/privilege-separation.nix:72:5
       at /nix/store/.../modules/security/privilege-separation.nix:240:5:
```

**Root Cause**: The same attribute is defined multiple times in the configuration, which NixOS doesn't allow. Common scenarios:
1. Defining an attribute both inside and outside a `mkMerge` block
2. Multiple modules defining the same user/service/group
3. Incorrect module composition

**Solutions**:

#### ✅ **Fix: Consolidate into Single mkMerge Block**
```nix
# ❌ WRONG - Duplicate definitions
users.users = mkMerge (
  map (user: {
    ${user} = { extraGroups = [...]; };
  }) userList
);

# Later in the file...
users.users.hypervisor-vm = {  # This causes duplicate!
  isSystemUser = true;
  ...
};

# ✅ CORRECT - Single consolidated definition
users.users = mkMerge ([
  # Dynamic user configurations
  (mkMerge (
    map (user: {
      ${user} = { extraGroups = [...]; };
    }) userList
  ))
  
  # Static system user
  {
    hypervisor-vm = {
      isSystemUser = true;
      group = "hypervisor-users";
      description = "Hypervisor VM management service user";
      extraGroups = [ "libvirtd" "kvm" ];
    };
  }
]);
```

**Detection Commands**:
```bash
# Find duplicate user definitions
grep -h 'users\.users\.[a-zA-Z0-9-]* =' modules/**/*.nix | \
  sed 's/.*users\.users\.\([a-zA-Z0-9-]*\) =.*/\1/' | \
  sort | uniq -d

# Find duplicate service definitions
grep -h 'systemd\.services\.[a-zA-Z0-9-]* =' modules/**/*.nix | \
  sed 's/.*systemd\.services\.\([a-zA-Z0-9-]*\) =.*/\1/' | \
  sort | uniq -d

# Check for problematic mkMerge patterns
grep -B2 -A5 'users\.(users|groups) = mkMerge' modules/**/*.nix
```

**Prevention**:
1. Always use `mkMerge` when combining multiple attribute sets
2. Keep all definitions for the same attribute path in one place
3. Use `mkIf` for conditional definitions instead of multiple files
4. Run `nixos-rebuild dry-build` before applying changes
5. Document which module "owns" system users/services

**Related Documentation**:
- [CI GitHub Actions Guide](./dev/CI_GITHUB_ACTIONS_GUIDE.md)
- [CI Test Fixes 2025-10-13](./dev/CI_TEST_FIXES_2025-10-13.md)

## 👤 **User and Authentication Issues**

### Issue: Username contains capital letters or special characters
**Symptoms**:
- Warning during installation about non-standard username
- User works but some tools may have issues
- Username like "John.Doe" or "User123" 

**Root Cause**: 
While Linux and NixOS can handle various username formats, traditional Unix usernames should only contain lowercase letters, numbers, hyphens, and underscores, and must start with a letter or underscore.

**What Works**:
- ✅ Capital letters (e.g., "JohnDoe")
- ✅ Dots (e.g., "john.doe")
- ✅ Numbers (e.g., "user123" - but not as first character)
- ✅ Hyphens and underscores (e.g., "john-doe", "john_doe")

**What Doesn't Work**:
- ❌ Spaces (e.g., "John Doe")
- ❌ Starting with numbers (e.g., "123user")
- ❌ Special characters like @, #, $, etc.

**Solutions**:

#### ✅ **Option 1: Keep the username (Recommended for existing systems)**
The installer will preserve your existing username and it will work in NixOS. You may see warnings but the system will function correctly.

#### ✅ **Option 2: Create a standard Unix username**
For new installations, consider using a standard format:
- All lowercase
- No dots or special characters
- Example: "johndoe" instead of "John.Doe"

**How the Installer Handles It**:
1. Preserves usernames exactly as they exist on the host system
2. Properly escapes and quotes them in Nix configuration
3. Shows warnings for non-standard usernames but continues
4. The generated config uses quoted attribute names like `"John.Doe" = { ... }`

**Example Generated Configuration**:
```nix
users.users = {
  "John.Doe" = {
    isNormalUser = true;
    name = "John.Doe";  # Actual username preserved
    extraGroups = [ "wheel" "libvirtd" "kvm" ];
    hashedPassword = "...";
  };
};
```

**Prevention**:
- For new users, stick to traditional Unix naming: `[a-z_][a-z0-9_-]*`
- For existing users, the system handles it automatically
- Some older Unix tools may have issues with non-standard names

## 🔧 **Hardware and Kernel Issues**

### Issue: "kvm: already loaded vendor module 'kvm_amd'" or 'kvm_intel'
**Symptoms**:
- Warning message during `nixos-rebuild switch`
- System tries to load both Intel and AMD KVM modules
- One module reports it's already loaded

**Root Cause**: 
The hypervisor-base module loads both `kvm-intel` and `kvm-amd` kernel modules by default. The kernel will use the appropriate one for your CPU and report that the other vendor's module is already loaded when it tries to load both.

**Impact**: 
This is a **harmless warning**. The system works correctly - only the appropriate KVM module for your CPU is actually used.

**Solutions**:

#### ✅ **Option 1: Ignore the warning (Recommended)**
The warning is harmless and doesn't affect functionality. Both modules are loaded for compatibility across different hardware.

#### ✅ **Option 2: Override kernel modules for your specific CPU**
In your configuration:

```nix
# For AMD CPUs:
boot.kernelModules = lib.mkForce [ "kvm-amd" ];

# For Intel CPUs:
boot.kernelModules = lib.mkForce [ "kvm-intel" ];
```

**Prevention**:
- The default configuration loads both modules for maximum compatibility
- Using `lib.mkDefault` allows easy overriding in your local configuration
- The kernel automatically uses the correct module for your hardware

**Related Notes**:
- IOMMU parameters (`intel_iommu=on` and `amd_iommu=on`) are also included for both vendors
- The kernel ignores parameters for hardware it doesn't have
- This approach ensures the system works on any x86_64 hardware without modification

## 🔧 **Service Configuration Issues**

### Issue: "The option `services.auditd' does not exist"
**Symptoms**:
```
error: The option `services.auditd' does not exist. Definition values:
       - In `/nix/store/.../modules/security/credential-chain.nix':
           {
             _type = "if";
             condition = true;
             content = {
               enable = true;
```

**Root Cause**: 
This error can have two causes:
1. The security modules are trying to enable the audit daemon service (`services.auditd`), but this service might not be available in minimal NixOS configurations or when the audit module isn't imported.
2. **Incorrect module structure** where audit configuration is inside the main `lib.mkIf` block instead of being separate array elements in `lib.mkMerge`. This causes NixOS to evaluate the audit options even when they don't exist.

**Impact**: 
Build failure when using security modules on minimal NixOS installations.

**Solutions**:

#### ✅ **Option 1: Use the fixed modules (Recommended)**
The security modules have been updated with proper structure to conditionally enable audit services only when they're available:

```nix
# Security monitoring - only if audit is available
services.auditd = lib.mkIf (config.services ? auditd) {
  enable = true;
};

security.audit = lib.mkIf (config.security ? audit) {
  enable = true;
  rules = [ ... ];
};
```

#### ✅ **Option 2: Enable audit support in your configuration**
If you want audit logging, ensure the audit module is available:

```nix
# In your configuration.nix
{
  # Enable audit daemon
  security.auditd.enable = true;
  
  # Or import the audit module explicitly if needed
  imports = [
    # ... other imports
  ];
}
```

**Files Fixed**:
- `modules/security/credential-chain.nix`
- `modules/security/sudo-protection.nix`
- `modules/security/credential-security/time-window.nix`
- `modules/security/credential-security/anti-tampering.nix`
- `modules/security/strict.nix`
- `modules/security/base.nix`

#### ✅ **Option 3: Fix module structure issues**
If the conditionals are already present but the error persists, check the module structure:

```nix
# WRONG - conditionals nested inside array element:
config = lib.mkIf cfg.enable (lib.mkMerge [
  {
    # main config...
    }
    (lib.mkIf (config.services ? auditd) {  # This is inside the first element!
      services.auditd.enable = true;
    })
  ]);

# CORRECT - separate array elements:
config = lib.mkIf cfg.enable (lib.mkMerge [
  {
    # main config...
  }
  (lib.mkIf (config.services ? auditd) {  # This is a separate element
    services.auditd.enable = true;
  })
]);
```

**Prevention**:
- Always check if optional services exist before enabling them
- Use conditional expressions: `lib.mkIf (config.services ? serviceName)`
- Ensure each conditional block in `lib.mkMerge` is a separate array element
- Test modules with minimal NixOS configurations
- Document service dependencies in module descriptions

**Key Learning**:
1. Not all NixOS services are available in every configuration. Security modules should gracefully handle missing optional services to maintain compatibility with minimal installations.
2. Module structure matters - conditional blocks must be properly positioned in `lib.mkMerge` arrays to be evaluated correctly.