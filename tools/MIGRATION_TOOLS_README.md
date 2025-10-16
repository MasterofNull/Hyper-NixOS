# NixOS Migration Tools

**Purpose:** Automated detection and fixing of NixOS API changes across version upgrades.

**Created:** 2025-10-16  
**Motivation:** After encountering `services.auditd` → `security.auditd` migration, we built tools to prevent future manual migrations.

## Quick Start

### 1. Scan for Issues

```bash
# Scan for NixOS 24.05 compatibility
./tools/nixos-compat-scanner.sh

# Scan for specific version
./tools/nixos-compat-scanner.sh --target-version 24.11

# Output as JSON
./tools/nixos-compat-scanner.sh --format json > report.json
```

### 2. Fix Issues

```bash
# Interactive mode - review each change
./tools/nixos-migration-fix.sh --interactive

# Automatic mode - apply all fixes
./tools/nixos-migration-fix.sh --auto

# Dry run - see what would change
./tools/nixos-migration-fix.sh --dry-run
```

### 3. Verify

```bash
# Test the configuration
nixos-rebuild build

# If successful, apply
sudo nixos-rebuild switch
```

## Tools Overview

### nixos-compat-scanner.sh ✅

**Purpose:** Detect deprecated patterns and compatibility issues

**Features:**
- Scans `.nix` files for known API changes
- Configurable target NixOS version
- Text or JSON output
- Severity levels: ERROR, WARNING, INFO

**Output Example:**
```
═══════════════════════════════════════════════════════════
  NixOS Compatibility Scanner
  Target: NixOS 24.05
═══════════════════════════════════════════════════════════

[ERROR] modules/security/credential-chain.nix:263
  Issue: Deprecated pattern: services.auditd
  Fix: Replace 'services.auditd' with 'security.auditd'

[WARNING] modules/network/bridge.nix:45
  Issue: Deprecated option: networking.useDHCP
  Fix: Replace with per-interface useDHCP settings

═══════════════════════════════════════════════════════════
Summary:
  Errors:   1
  Warnings: 1
  Info:     0
═══════════════════════════════════════════════════════════
```

**Exit Codes:**
- `0` - No errors found
- `1` - Errors found (build may fail)

### nixos-migration-fix.sh 🔧

**Purpose:** Apply fixes for detected issues

**Modes:**
- **Interactive** (default) - Review each change before applying
- **Auto** - Apply all fixes automatically
- **Dry-run** - Show what would be fixed without making changes

**Features:**
- Automatic backups before modification
- Contextual diff preview
- Rollback capability
- Progress reporting
- Summary report generation

**Safety:**
- Creates timestamped backups in `backups/migration-YYYYMMDD-HHMMSS/`
- Shows diff context before each change
- Validates patterns before applying
- Generates rollback instructions

### Migration Rules Database 📋

**Location:** `tools/migration-rules/`

**Format:** TOML (human-readable, version-controlled)

**Current Rules:**
- `nixos-24.05.toml` - Rules for NixOS 24.05 migration

**Example Rule:**
```toml
[[migration]]
id = "auditd-namespace-change"
version_from = "23.11"
version_to = "24.05"
severity = "error"
category = "namespace-change"
description = "Audit daemon moved from services to security namespace"

[migration.pattern]
type = "option-path"
old = "services.auditd"
new = "security.auditd"
regex = 'services\.auditd'

[migration.fix]
type = "automatic"
replacements = [
    { search = "services.auditd", replace = "security.auditd" },
    { search = "services ? auditd", replace = "security ? auditd" },
]
confidence = "high"
```

## Use Cases

### Before NixOS Upgrade

```bash
# Check compatibility before upgrading
./tools/nixos-compat-scanner.sh --target-version 24.11

# Fix issues proactively
./tools/nixos-migration-fix.sh --interactive

# Verify
nixos-rebuild build
```

### After Encountering Build Errors

```bash
# Scan to identify issues
./tools/nixos-compat-scanner.sh

# Apply fixes
./tools/nixos-migration-fix.sh --auto

# Rebuild
nixos-rebuild build
```

### CI/CD Integration

```yaml
# .github/workflows/compatibility.yml
- name: Check NixOS Compatibility
  run: ./tools/nixos-compat-scanner.sh --format json > report.json
  
- name: Fail on Errors
  run: |
    if jq -e '.summary.errors > 0' report.json; then
      echo "Compatibility errors found!"
      exit 1
    fi
```

### Pre-commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit

./tools/nixos-compat-scanner.sh || {
    echo "Fix compatibility issues before committing"
    exit 1
}
```

## Detected Issues

### Currently Detected

1. **services.auditd → security.auditd** (NixOS 24.05)
   - Severity: ERROR
   - Auto-fixable: Yes
   - Confidence: High

2. **networking.useDHCP deprecation** (NixOS 24.05)
   - Severity: WARNING
   - Auto-fixable: No (requires per-interface config)
   - Manual instructions provided

3. **pythonPackages → python3Packages** (NixOS 24.05)
   - Severity: ERROR
   - Auto-fixable: Yes
   - Confidence: High

4. **lib.mkIf usage patterns** (Best Practice)
   - Severity: INFO
   - Auto-fixable: No
   - Suggestions provided

### Adding New Rules

```bash
# Edit the rules file
vim tools/migration-rules/nixos-24.11.toml

# Add your rule
[[migration]]
id = "your-rule-id"
version_to = "24.11"
severity = "error"
description = "Description of the change"

[migration.pattern]
regex = 'your\.pattern'
old = "old.option"
new = "new.option"

[migration.fix]
type = "automatic"  # or "manual" or "interactive"
replacements = [
    { search = "old", replace = "new" }
]
```

## Workflow Examples

### Example 1: Clean Migration

```bash
$ ./tools/nixos-compat-scanner.sh
═══════════════════════════════════════════════════════════
  NixOS Compatibility Scanner
  Target: NixOS 24.05
═══════════════════════════════════════════════════════════

[ERROR] modules/security/base.nix:66
  Issue: Deprecated pattern: services.auditd
  Fix: Replace 'services.auditd' with 'security.auditd'

═══════════════════════════════════════════════════════════
Summary: 1 error, 0 warnings, 0 info
═══════════════════════════════════════════════════════════

$ ./tools/nixos-migration-fix.sh --auto
═══════════════════════════════════════════════════════════
  NixOS Migration Fix Tool
  Mode: auto
═══════════════════════════════════════════════════════════

Fixing auditd namespace changes...

File: modules/security/base.nix
Fix: Update auditd namespace (services → security)
Change: services.auditd → security.auditd

[AUTO] Applying fix...
✓ Fix applied

═══════════════════════════════════════════════════════════
Summary:
  Fixed:   1
  Skipped: 0
  Failed:  0
═══════════════════════════════════════════════════════════

Report generated: MIGRATION_REPORT_2025-10-16.md

$ nixos-rebuild build
building the system configuration...
✓ Success!
```

### Example 2: Interactive Review

```bash
$ ./tools/nixos-migration-fix.sh --interactive

File: modules/security/credential-chain.nix
Fix: Update auditd namespace (services → security)
Change: services.auditd → security.auditd

Context:
261:     # Security monitoring - conditionally enable audit service if available
262:     (lib.mkIf (cfg.enable && config.services ? auditd) {
263:       services.auditd.enable = lib.mkDefault true;
264:     })
265:

Apply this fix? [y/N] y
  Backed up: modules/security/credential-chain.nix → backups/migration-20251016-143022/modules/security/credential-chain.nix
✓ Fix applied
```

### Example 3: Dry Run

```bash
$ ./tools/nixos-migration-fix.sh --dry-run

[DRY-RUN] Would apply fix
  File: modules/security/base.nix
  Change: services.auditd → security.auditd

[DRY-RUN] Would apply fix
  File: modules/security/strict.nix
  Change: services.auditd → security.auditd

Summary: Would fix 2 issues
```

## Rollback

If something goes wrong:

```bash
# Restore from backup
cp -r backups/migration-20251016-143022/* ./

# Or restore specific file
cp backups/migration-20251016-143022/modules/security/base.nix modules/security/

# Rebuild to verify
nixos-rebuild build
```

## Future Enhancements

### Phase 1 (Current)
- ✅ Basic scanner (Bash)
- ✅ Migration rules database (TOML)
- ✅ Auto-fix tool (Bash)
- ✅ Backup/rollback capability

### Phase 2 (Planned)
- [ ] Rust implementation for performance
- [ ] AST parsing for complex patterns
- [ ] Multi-threaded scanning
- [ ] Web dashboard for results

### Phase 3 (Future)
- [ ] CI/CD integration examples
- [ ] Multi-version testing framework
- [ ] Automated update monitoring
- [ ] Community rule contributions

## Contributing

### Adding Rules

1. Edit `tools/migration-rules/nixos-VERSION.toml`
2. Follow the existing rule format
3. Test with scanner and fixer
4. Submit PR with example

### Improving Tools

1. Check `docs/dev/NIXOS_MIGRATION_TOOLING_STRATEGY_2025-10-16.md` for roadmap
2. Create issue or PR
3. Update documentation
4. Add tests

## Documentation

- **Strategy:** `docs/dev/NIXOS_MIGRATION_TOOLING_STRATEGY_2025-10-16.md`
- **Version Strategy:** `docs/dev/NIXOS_VERSION_STRATEGY_2025-10-16.md`
- **Auditd Fix:** `docs/dev/AUDITD_NIXOS_24_05_FIX_2025-10-16.md`

## Support

For issues or questions:
1. Check documentation in `docs/dev/`
2. Run with `--help` flag
3. Review migration reports
4. Create GitHub issue

## License

MIT License - Same as Hyper-NixOS

---

**Note:** These tools are actively developed. Check `docs/dev/` for latest strategies and roadmaps.
