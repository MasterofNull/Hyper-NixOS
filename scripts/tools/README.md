# Hyper-NixOS Development Tools

This directory contains tools to help with development and maintenance of the Hyper-NixOS system.

## Available Tools

### check-optional-services.sh
**Purpose**: Proactively checks for optional service configurations that might cause "option does not exist" errors.

**Usage**:
```bash
./scripts/tools/check-optional-services.sh
```

**What it checks**:
- Services that might not exist in minimal configurations (auditd, fprintd, rtkit, etc.)
- Proper use of conditional checks (`lib.mkIf`)
- Suggests fixes for any issues found

**When to use**:
- Before running `nixos-rebuild` to catch issues early
- After modifying security or service configurations
- When adding new modules that depend on optional services

### deploy-security-stack.sh
**Purpose**: Deploys the security monitoring stack.

**Usage**:
```bash
./scripts/tools/deploy-security-stack.sh
```

## Best Practices

1. **Run validation tools before building**: Use `check-optional-services.sh` to catch configuration issues before they cause build failures.

2. **Update tools when patterns change**: If you discover new patterns that cause issues, update the checking tools to catch them.

3. **Document tool usage**: When creating new tools, add them to this README with clear usage instructions.

## Common Patterns to Check

When developing, watch out for these patterns that can cause issues:

1. **Unconditional service enables**:
   ```nix
   # Bad:
   services.auditd.enable = true;
   
   # Good:
   (lib.mkIf (config.services ? auditd) {
     services.auditd.enable = true;
   })
   ```

2. **Missing module imports**:
   ```nix
   # If using audit features, ensure the module is imported:
   imports = [
     <nixpkgs/nixos/modules/security/audit.nix>
   ];
   ```

3. **Example files with optional services**:
   - Comment out optional services in example files
   - Or provide conditional configuration examples
   - Add clear notes about requirements