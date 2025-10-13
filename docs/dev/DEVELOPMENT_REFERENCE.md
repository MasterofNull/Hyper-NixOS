# Hyper-NixOS Development Reference
*For Human Developers and AI Assistants*

## Purpose
This document serves as the **single source of truth** for all Hyper-NixOS development. It is designed to be equally useful for:
- Human developers working on the project
- AI assistants helping with development
- Code reviewers and maintainers

## Quick Start for New Developers

### First Steps
1. Clone the repository
2. Read this document completely
3. Review `CRITICAL_REQUIREMENTS.md`
4. Run `hv dev setup` to configure your environment

### Key Commands
```bash
# Test your changes
nixos-rebuild test --show-trace

# Run validation
hv dev validate

# Check documentation sync
hv dev check-docs
```

## Architecture Overview

### Core Principles
1. **Security First**: Every feature must be evaluated for security impact
2. **No Sudo for VMs**: Regular users can manage VMs without elevation
3. **Modular Design**: Features can be enabled/disabled independently
4. **Risk Transparency**: Security implications clearly communicated
5. **User Adaptability**: System adapts to user experience level

### Module Structure
```
modules/
├── core/           # Essential system modules
├── features/       # Optional features with risk assessment
├── security/       # Security components
├── networking/     # Network configuration
└── virtualization/ # VM management
```

## Critical Patterns (MUST FOLLOW)

### ✅ NixOS Module Pattern
```nix
# ALWAYS use this structure
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.hypervisor.module.name;
in {
  options.hypervisor.module.name = {
    enable = mkEnableOption "description";
    # other options...
  };
  
  config = mkIf cfg.enable {
    # Implementation here
    # ONLY access config values inside mkIf
  };
}
```

### ❌ Anti-Pattern (CAUSES INFINITE RECURSION)
```nix
# NEVER do this
let
  value = config.some.option;  # ❌ Accessing config at top level
in {
  config = { /* ... */ };
}
```

### ✅ Script Pattern
```bash
#!/usr/bin/env bash
# Script: name.sh
# Sudo Required: YES/NO  # MUST specify
# Description: Brief description

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Metadata (REQUIRED)
readonly REQUIRES_SUDO=true/false
readonly OPERATION_TYPE="vm_management/system_config"

# Check privileges
if ! check_sudo_requirement; then
    exit $EXIT_PERMISSION_DENIED
fi
```

## Security Model

### Privilege Separation
- **VM Operations**: No sudo required (libvirtd group)
- **System Operations**: Explicit sudo with clear messaging
- **Enforcement**: Automatic via common.sh functions

### Risk Levels
1. `minimal` (🟢): No significant security impact
2. `low` (🔵): Minor security considerations  
3. `moderate` (🟡): Review recommended
4. `high` (🟠): Careful consideration required
5. `critical` (🔴): Only if absolutely necessary

### Two-Phase System
- **Setup Phase**: Permissive for initial configuration
- **Hardened Phase**: Restrictive for production use
- **Detection**: Check `/etc/hypervisor/.phase*` files

## Feature Development

### Adding a New Feature
1. Define in `modules/features/feature-categories.nix`
2. Specify risk level and impacts
3. List dependencies and conflicts
4. Create module in appropriate category
5. Update documentation
6. Add tests

### Feature Definition Template
```nix
myFeature = {
  name = "Feature Name";
  description = "What it does";
  risk = "minimal/low/moderate/high/critical";
  enabled = false;  # Default state
  impacts = [
    "Security impact 1"
    "Security impact 2"
  ];
  mitigations = [
    "How to reduce risk"
  ];
  requirements = [
    "What it needs to work"
  ];
};
```

## Common Tasks

### Update Documentation
```bash
# After any change
hv dev update-docs --component <name>

# Verify sync
hv dev check-docs
```

### Add a Script
1. Copy template: `cp scripts/lib/TEMPLATE.sh scripts/new-script.sh`
2. Update metadata (REQUIRES_SUDO, OPERATION_TYPE)
3. Implement functionality
4. Add to command dispatcher in `packages/hypervisor-cli.nix`
5. Document in `SCRIPT_PRIVILEGE_CLASSIFICATION.md`

### Debug Issues
```bash
# Module issues
nixos-rebuild test --show-trace

# Service issues
systemctl status hypervisor-*
journalctl -u hypervisor-* -f

# Script issues
bash -x script.sh  # Debug mode
```

## Testing Requirements

### Before Committing
- [ ] NixOS builds without errors
- [ ] Scripts pass validation
- [ ] Documentation updated
- [ ] Security review if needed
- [ ] Tests pass locally AND in CI

### Test Commands
```bash
# Run all tests
hv dev test

# Specific component
hv dev test --component security

# Validation only
hv dev validate

# Test in CI-like environment
export CI=true
./tests/run_all_tests.sh
```

### CI/CD Testing Guidelines

#### Writing CI-Friendly Tests
1. **Environment Setup BEFORE Sourcing**:
   ```bash
   # ✅ CORRECT
   export HYPERVISOR_LOGS="$TEST_DIR/logs"
   mkdir -p "$HYPERVISOR_LOGS"
   source common.sh
   
   # ❌ WRONG
   source common.sh
   export HYPERVISOR_LOGS="$TEST_DIR/logs"
   ```

2. **Handle Missing Dependencies**:
   ```bash
   if [[ "${CI:-false}" == "true" ]]; then
       # Mock or skip features requiring system tools
   fi
   ```

3. **Avoid Hardcoded Paths**:
   ```bash
   # Use environment variables
   : "${HYPERVISOR_ROOT:=/etc/hypervisor}"
   : "${LOG_FILE:=$HYPERVISOR_LOGS/script.log}"
   ```

4. **Don't Execute During Source**:
   ```bash
   # ✅ GOOD - Lazy initialization
   init_system() { mkdir -p "$HYPERVISOR_LOGS"; }
   
   # ❌ BAD - Runs immediately
   mkdir -p "$HYPERVISOR_LOGS"
   ```

#### CI Environment Limitations
- No systemd/libvirtd
- Limited filesystem access
- No sudo without explicit setup
- PATH may be overridden
- Missing system tools (jq, virsh, etc.)

#### Debugging CI Failures
1. Check GitHub Actions logs
2. Run locally with CI=true
3. Look for path/permission errors
4. Verify all dependencies mocked/installed

## Troubleshooting

### Infinite Recursion
- Check for config access in let bindings
- Ensure all config access is inside mkIf
- Review recent module changes

### Permission Denied
- Check user groups: `groups`
- Verify script REQUIRES_SUDO setting
- Check file permissions

### Build Failures
- Run with --show-trace
- Check syntax in modified files
- Verify all imports exist

## Communication

### Getting Help
- Check this document first
- Review existing patterns in codebase
- Ask in development chat
- File an issue with details

### Reporting Issues
Include:
- Error message with --show-trace
- Steps to reproduce
- System configuration
- What you expected vs what happened

## Maintenance Tasks

### Regular Updates
- Threat intelligence feeds (automated)
- Documentation review (monthly)
- Security audit (quarterly)
- Dependency updates (as needed)

### Release Process
1. Update version in all files
2. Generate changelog
3. Run full test suite
4. Update release notes
5. Tag and build

---

**Remember**: This document is the source of truth. Keep it updated with any new patterns or requirements discovered during development.