# Configuration Migration Guide

Complete guide to using the NixOS configuration migrator for safe, automated config transformations.

## 🎯 What is Configuration Migration?

Migration automatically transforms your NixOS configuration for:
- **Version upgrades** (24.05 → 24.11) with breaking changes
- **Channel to flakes** conversion
- **Deprecated option** replacement
- **Modernization** of old configs
- **Testing** changes before production

## 🚀 Quick Start

### Interactive Wizard (Easiest)
```bash
nixos-updater migrate-wizard

# Guides you through:
# 1. Select source config
# 2. Choose target path
# 3. Select migration type
# 4. Review and apply
```

### CLI Usage
```bash
# Clone and test
nixos-updater migrate /etc/nixos /tmp/test-config

# Apply preset migration
nixos-updater migrate /etc/nixos /tmp/upgraded upgrade-nixos-version:24.11

# Switch to migrated config
nixos-updater switch-config /tmp/upgraded
```

## 📋 Complete Workflow Example

### Scenario: Upgrade from 24.05 to 24.11

```bash
# Step 1: Clone current config
nixos-updater migrate /etc/nixos /tmp/nixos-24.11-test \
    deprecated-options:24.11 \
    upgrade-nixos-version:24.11

# Output:
# === Incremental Migration ===
# Source: /etc/nixos
# Target: /tmp/nixos-24.11-test
#
# === Migration Step 1: deprecated-options:24.11 ===
# → Applying rule: deprecated-options
#   → Fixing deprecated options for 24.11
#     → Replacing: services.auditd → security.auditd
#   ✓ Rule applied
#   → Validating configuration...
#   ✓ Syntax valid
#   → Testing build...
#   ✓ Build successful
#
# === Migration Step 2: upgrade-nixos-version:24.11 ===
# → Applying rule: upgrade-nixos-version
#   → Migrating to NixOS 24.11
#     ✓ Updated flake.nix
#   ✓ Rule applied
#   → Validating configuration...
#   ✓ Syntax valid
#   → Testing build...
#   ✓ Build successful
#
# === Migration Complete ===
# ✓ All rules applied successfully

# Step 2: Review changes
diff -ru /etc/nixos /tmp/nixos-24.11-test

# Step 3: Test build (without activating)
cd /tmp/nixos-24.11-test
nixos-rebuild build --flake ".#$(hostname -s)"

# Step 4: If successful, switch
sudo nixos-updater switch-config /tmp/nixos-24.11-test

# Step 5: Verify
systemctl --failed
nixos-updater profiles

# If problems, rollback
nixos-updater rollback
```

## 🔧 Migration Rules

### Available Rules

**1. upgrade-nixos-version:VERSION**
```bash
nixos-updater migrate /etc/nixos /tmp/new upgrade-nixos-version:24.11

# Updates:
# - Flake nixpkgs input to nixos-24.11
# - Applies version-specific breaking changes
# - Updates deprecated options
```

**2. channels-to-flake**
```bash
nixos-updater migrate /etc/nixos /tmp/flake channels-to-flake

# Creates:
# - flake.nix with current channel
# - Wraps existing configuration.nix
# - Adds flake compatibility layer
```

**3. deprecated-options:VERSION**
```bash
nixos-updater migrate /etc/nixos /tmp/fixed deprecated-options:24.11

# Fixes:
# - services.auditd → security.auditd
# - Removed options (comments them out)
# - Renamed options
# - Module path changes
```

**4. modernize-syntax**
```bash
nixos-updater migrate /etc/nixos /tmp/modern modernize-syntax

# Updates:
# - with pkgs; → explicit imports
# - Old Nix syntax → modern syntax
# - Adds comments for best practices
```

**5. fix-imports**
```bash
nixos-updater migrate /etc/nixos /tmp/fixed fix-imports

# Fixes:
# - Relative import paths
# - Missing imported files
# - Circular imports
```

**6. add-flake-compat**
```bash
nixos-updater migrate /etc/nixos /tmp/compat add-flake-compat

# Adds:
# - default.nix for backward compatibility
# - Allows using flake config with nix-build
```

### Combining Rules (Incremental)

```bash
# Apply multiple rules in sequence
nixos-updater migrate /etc/nixos /tmp/complete \
    fix-imports \
    modernize-syntax \
    deprecated-options:24.11 \
    upgrade-nixos-version:24.11

# Each rule:
# 1. Is applied
# 2. Syntax validated
# 3. Build tested
# 4. Checkpoint created (for rollback)
```

## 🎨 Migration Presets

### Preset 1: Upgrade to 24.11
```bash
# Use library function
source /usr/local/lib/nixos-updater/lib/nixos-config-migrator.sh

migrate_preset_upgrade_2411 /etc/nixos /tmp/nixos-24.11

# Applies:
# 1. deprecated-options:24.11
# 2. upgrade-nixos-version:24.11
# 3. modernize-syntax
# 4. fix-imports
```

### Preset 2: Convert to Flakes
```bash
migrate_preset_to_flakes /etc/nixos /tmp/nixos-flake

# Applies:
# 1. channels-to-flake
# 2. add-flake-compat
# 3. modernize-syntax
# 4. fix-imports
```

### Preset 3: Full Modernization
```bash
migrate_preset_full_modernize /etc/nixos /tmp/nixos-modern

# Applies:
# 1. fix-imports
# 2. modernize-syntax
# 3. deprecated-options:current
# 4. update-service-names
```

## 🔁 Incremental Loop Mechanism

### How It Works

Each migration step:
1. **Creates checkpoint** (full config backup)
2. **Applies rule** (automated transformation)
3. **Validates syntax** (catches errors immediately)
4. **Tests build** (ensures buildability)
5. **Commits or rolls back** (automatic recovery)

### Example: Step-by-Step Migration

```bash
# Start with current config
source /usr/local/lib/nixos-updater/lib/nixos-config-migrator.sh

# Clone
nixos_clone_config /etc/nixos /tmp/migration "24.11 upgrade test"

# Apply rules one by one with validation
cd /tmp/migration

# Rule 1: Fix deprecated options
apply_migration_rule . deprecated-options 24.11
validate_nix_syntax .
# ✓ Valid, continue

# Rule 2: Update version
apply_migration_rule . upgrade-nixos-version 24.11
validate_nix_syntax .
# ✓ Valid, continue

# Rule 3: Modernize
apply_migration_rule . modernize-syntax
validate_nix_syntax .
# ✓ Valid, continue

# All rules applied successfully!
```

### Automatic Recovery

If any step fails:
```bash
# === Migration Step 2: upgrade-nixos-version:24.11 ===
# → Applying rule: upgrade-nixos-version
#   ✓ Rule applied
#   → Validating configuration...
#   ✗ Syntax invalid after rule application
#   → Restoring from checkpoint...
# ✗ Migration failed at step 2

# Config automatically restored to last valid state!
```

## 🛡️ Safe Switching

### Test Before Switching

```bash
# 1. Migrate to temporary location
nixos-updater migrate /etc/nixos /tmp/test-upgrade \
    upgrade-nixos-version:24.11

# 2. Test build
cd /tmp/test-upgrade
nixos-rebuild build --flake ".#$(hostname -s)"

# 3. Compare with current
nixos-updater compare /etc/nixos /tmp/test-upgrade

# 4. If satisfied, switch
switch_to_migrated_config /tmp/test-upgrade

# 5. Verify
systemctl is-system-running
nixos-updater profiles

# 6. If problems, rollback
nixos-updater rollback
```

### With Backup

```bash
# Automatic backup before switching
switch_to_migrated_config /tmp/upgraded true

# Backup created at: /var/backups/nixos-pre-migration-20251016-120000
# If anything goes wrong:
# sudo cp -r /var/backups/nixos-pre-migration-*/* /etc/nixos/
# sudo nixos-rebuild switch
```

## 🎯 Real-World Use Cases

### Use Case 1: Test New NixOS Release

```bash
#!/usr/bin/env bash
# test-new-release.sh

# Create test environment
nixos-updater migrate /etc/nixos /tmp/nixos-24.11-test \
    deprecated-options:24.11 \
    upgrade-nixos-version:24.11

# Build test system
cd /tmp/nixos-24.11-test
nixos-rebuild build --flake ".#test-system"

# If build succeeds, you know your config is compatible!
echo "✓ Configuration compatible with 24.11"
echo "Safe to upgrade production when ready"
```

### Use Case 2: Multi-Stage Migration

```bash
#!/usr/bin/env bash
# staged-migration.sh

# Stage 1: Clone and fix syntax
nixos_clone_config /etc/nixos /tmp/stage1
apply_migration_rule /tmp/stage1 fix-imports
apply_migration_rule /tmp/stage1 modernize-syntax

# Stage 2: Update deprecated options
nixos_clone_config /tmp/stage1 /tmp/stage2
apply_migration_rule /tmp/stage2 deprecated-options 24.11

# Stage 3: Upgrade version
nixos_clone_config /tmp/stage2 /tmp/stage3
apply_migration_rule /tmp/stage3 upgrade-nixos-version 24.11

# Each stage tested and validated independently
# Can stop at any stage if issues found
```

### Use Case 3: Production Migration Pipeline

```bash
#!/usr/bin/env bash
# production-migration.sh

set -euo pipefail

SOURCE="/etc/nixos"
TEST_TARGET="/tmp/production-migration-test"
STAGING_SERVER="staging.example.com"
PROD_SERVERS=("prod01" "prod02" "prod03")

# 1. Create and test migration locally
echo "=== Phase 1: Local Testing ==="
nixos-updater migrate "$SOURCE" "$TEST_TARGET" \
    deprecated-options:24.11 \
    upgrade-nixos-version:24.11

cd "$TEST_TARGET"
nixos-rebuild build --flake ".#test" || exit 1
echo "✓ Local build successful"

# 2. Deploy to staging
echo "=== Phase 2: Staging Deployment ==="
scp -r "$TEST_TARGET" "$STAGING_SERVER:/tmp/migration"
ssh "$STAGING_SERVER" "sudo nixos-updater switch-config /tmp/migration"

# Wait and verify
sleep 300
if ssh "$STAGING_SERVER" "systemctl is-system-running"; then
    echo "✓ Staging deployment successful"
else
    echo "✗ Staging failed"
    ssh "$STAGING_SERVER" "sudo nixos-updater rollback"
    exit 1
fi

# 3. Deploy to production (one at a time)
echo "=== Phase 3: Production Deployment ==="
for server in "${PROD_SERVERS[@]}"; do
    echo "Deploying to $server..."
    
    scp -r "$TEST_TARGET" "$server:/tmp/migration"
    ssh "$server" "sudo nixos-updater switch-config /tmp/migration"
    
    sleep 60
    
    if ! ssh "$server" "systemctl is-system-running"; then
        echo "✗ $server failed, halting rollout"
        ssh "$server" "sudo nixos-updater rollback"
        exit 1
    fi
    
    echo "✓ $server deployed successfully"
done

echo "✓ Production migration complete across all servers"
```

### Use Case 4: Custom Migration Rules

```bash
#!/usr/bin/env bash
# custom-migration.sh

# Define custom migration function
my_custom_migration() {
    local config_path=$1
    
    echo "Applying custom changes..."
    
    # Replace custom company settings
    find "$config_path" -name "*.nix" -exec \
        sed -i 's/company\.oldService/company.newService/g' {} \;
    
    # Add new required imports
    if ! grep -q "custom-module.nix" "$config_path/configuration.nix"; then
        sed -i '/imports = \[/a \    ./custom-module.nix' "$config_path/configuration.nix"
    fi
    
    echo "✓ Custom migration applied"
}

# Apply standard + custom migration
nixos_clone_config /etc/nixos /tmp/custom-migration
my_custom_migration /tmp/custom-migration
nixos_validate_config /tmp/custom-migration
```

## 🔍 Comparison Before Migration

### Compare Configurations
```bash
# Before migrating, see what will change
nixos-updater compare /etc/nixos /tmp/test-config

# Output:
# === Configuration Comparison ===
# Config 1: /etc/nixos
# Config 2: /tmp/test-config
#
# --- File Differences ---
# Files /etc/nixos/flake.nix and /tmp/test-config/flake.nix differ
#
# --- Nix Expression Diff ---
# - nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
# + nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
```

### Preview Changes
```bash
# See what packages will change
nixos_diff_before_update /tmp/test-config

# Output:
# === Update Diff Preview ===
# Config: /tmp/test-config
# Type: flake
#
# --- Flake Input Changes ---
# • Updated 'nixpkgs': ...24.05 → ...24.11
#
# --- System Build Diff ---
# these 42 paths will be updated:
#   systemd-254.1 → 254.6
#   linux-6.5.7 → 6.6.3
# these 5 paths will be added:
#   new-package-1.0
```

## 🎯 Migration Strategies

### Strategy 1: Parallel Testing
```bash
# Keep production running, test migration separately

# 1. Clone to test location
nixos-updater migrate /etc/nixos /home/admin/nixos-test \
    upgrade-nixos-version:24.11

# 2. Test extensively
cd /home/admin/nixos-test
nixos-rebuild build --flake ".#$(hostname -s)"

# 3. Only switch when confident
# Don't rush - test thoroughly!

# 4. When ready
sudo nixos-updater switch-config /home/admin/nixos-test
```

### Strategy 2: Incremental Production
```bash
# Apply changes incrementally, test each change

# Change 1: Fix deprecated options only
nixos-updater migrate /etc/nixos /tmp/step1 deprecated-options:24.11
switch_to_migrated_config /tmp/step1
# → Test production for 24 hours

# Change 2: Modernize syntax
nixos-updater migrate /etc/nixos /tmp/step2 modernize-syntax
switch_to_migrated_config /tmp/step2
# → Test production for 24 hours

# Change 3: Upgrade version
nixos-updater migrate /etc/nixos /tmp/step3 upgrade-nixos-version:24.11
switch_to_migrated_config /tmp/step3
# → Monitor production
```

### Strategy 3: Canary Deployment
```bash
# Test on small subset before full rollout

CANARY_SERVER="canary01"
PROD_SERVERS=("prod01" "prod02" "prod03" "prod04" "prod05")

# 1. Migrate configuration
nixos-updater migrate /etc/nixos /tmp/migration \
    deprecated-options:24.11 \
    upgrade-nixos-version:24.11

# 2. Deploy to canary
scp -r /tmp/migration "$CANARY_SERVER:/tmp/"
ssh "$CANARY_SERVER" "sudo nixos-updater switch-config /tmp/migration"

# 3. Monitor canary for 24-48 hours
sleep 172800  # 48 hours

# 4. Check canary health
if ssh "$CANARY_SERVER" "systemctl is-system-running"; then
    echo "✓ Canary healthy, proceeding with rollout"
    
    # 5. Deploy to production
    for server in "${PROD_SERVERS[@]}"; do
        scp -r /tmp/migration "$server:/tmp/"
        ssh "$server" "sudo nixos-updater switch-config /tmp/migration"
        sleep 300  # 5 minutes between servers
    done
else
    echo "✗ Canary unhealthy, aborting rollout"
    ssh "$CANARY_SERVER" "sudo nixos-updater rollback"
    exit 1
fi
```

## 📝 Creating Custom Migration Rules

### Define Your Own Transformation

```bash
#!/usr/bin/env bash
# /usr/local/share/nixos-updater/custom-rules/my-company-migration.sh

migrate_company_custom() {
    local config_path=$1
    
    echo "Applying company-specific migration..."
    
    # Replace old internal services
    find "$config_path" -name "*.nix" -exec \
        sed -i 's/services\.oldInternalTool/services.newInternalTool/g' {} \;
    
    # Update custom module imports
    find "$config_path" -name "*.nix" -exec \
        sed -i 's|company/old-modules|company/new-modules|g' {} \;
    
    # Add new required options
    local config_file="$config_path/configuration.nix"
    if ! grep -q "company.newFeature.enable" "$config_file"; then
        sed -i '/services = {/a \  company.newFeature.enable = true;' "$config_file"
    fi
    
    echo "✓ Company migration complete"
}

# Register rule
export -f migrate_company_custom
```

### Use Custom Rule

```bash
# Source custom rules
source /usr/local/share/nixos-updater/custom-rules/my-company-migration.sh

# Apply in migration
nixos_clone_config /etc/nixos /tmp/company-migration
migrate_company_custom /tmp/company-migration
nixos_validate_config /tmp/company-migration
```

## 🧪 Testing Migrations

### Test Framework

```bash
#!/usr/bin/env bash
# test-migration.sh

test_migration_suite() {
    local test_name=$1
    local source=$2
    local rules=$3
    
    echo "=== Testing: $test_name ==="
    
    local test_target="/tmp/migration-test-$$"
    
    # Apply migration
    if nixos-updater migrate "$source" "$test_target" $rules; then
        echo "  ✓ Migration succeeded"
    else
        echo "  ✗ Migration failed"
        return 1
    fi
    
    # Validate
    if nixos_validate_config "$test_target"; then
        echo "  ✓ Validation passed"
    else
        echo "  ✗ Validation failed"
        return 1
    fi
    
    # Try to build
    if test_config_build "$test_target"; then
        echo "  ✓ Build test passed"
    else
        echo "  ✗ Build test failed"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_target"
    
    echo "  ✓ $test_name: ALL TESTS PASSED"
    return 0
}

# Run test suite
test_migration_suite "Upgrade to 24.11" /etc/nixos "upgrade-nixos-version:24.11"
test_migration_suite "Convert to flakes" /etc/nixos "channels-to-flake"
test_migration_suite "Fix deprecated" /etc/nixos "deprecated-options:24.11"
```

## 🚨 Rollback and Recovery

### If Migration Fails

```bash
# Migration automatically creates checkpoints
# If a step fails, it automatically restores

# Manual rollback during migration:
# 1. Config automatically restored to last checkpoint
# 2. Target directory contains partially migrated config
# 3. Review what failed in logs

# After switching to migrated config:
# If system doesn't boot or has issues
nixos-updater rollback
```

### Complete Recovery Process

```bash
# Worst case: system won't boot after migration

# 1. Boot from previous generation (grub menu)
# 2. Log in
# 3. Check what happened
journalctl -xb

# 4. Restore backup
sudo cp -r /var/backups/nixos-pre-migration-*/* /etc/nixos/

# 5. Rebuild
sudo nixos-rebuild switch

# 6. Investigate what went wrong
diff -ru /var/backups/nixos-pre-migration-*/ /tmp/failed-migration/
```

## 📊 Advanced Migration Patterns

### Pattern 1: Conditional Migration

```bash
#!/usr/bin/env bash
# Migrate only if needed

current_version=$(nixos_get_version)

if [[ "$current_version" == "24.05" ]]; then
    echo "Upgrading from 24.05 to 24.11..."
    nixos-updater migrate /etc/nixos /tmp/upgrade \
        deprecated-options:24.11 \
        upgrade-nixos-version:24.11
    
    # Test and switch
    if nixos_validate_config /tmp/upgrade; then
        switch_to_migrated_config /tmp/upgrade
    fi
else
    echo "Already on $current_version, no migration needed"
fi
```

### Pattern 2: Phased Migration

```bash
#!/usr/bin/env bash
# Multi-phase migration with breaks for testing

# Phase 1: Non-breaking changes
nixos-updater migrate /etc/nixos /tmp/phase1 \
    fix-imports \
    modernize-syntax

switch_to_migrated_config /tmp/phase1
echo "Phase 1 complete. Test for 24 hours, then continue with Phase 2"
exit 0

# [24 hours later, run phase 2]

# Phase 2: Deprecated options
nixos-updater migrate /etc/nixos /tmp/phase2 \
    deprecated-options:24.11

switch_to_migrated_config /tmp/phase2
echo "Phase 2 complete. Test for 24 hours, then continue with Phase 3"
exit 0

# [24 hours later, run phase 3]

# Phase 3: Version upgrade
nixos-updater migrate /etc/nixos /tmp/phase3 \
    upgrade-nixos-version:24.11

switch_to_migrated_config /tmp/phase3
echo "Phase 3 complete. Migration finished!"
```

### Pattern 3: Parallel Environment Testing

```bash
#!/usr/bin/env bash
# Test migration in parallel with production

# Production stays on 24.05
# Test environment runs 24.11

# Create migrated config
nixos-updater migrate /etc/nixos /home/admin/nixos-24.11 \
    deprecated-options:24.11 \
    upgrade-nixos-version:24.11

# Deploy to test VM
scp -r /home/admin/nixos-24.11 test-vm:/tmp/
ssh test-vm "sudo nixos-updater switch-config /tmp/nixos-24.11"

# Run full application test suite against test VM
run_test_suite test-vm

# If successful, migrate production
if [[ $? -eq 0 ]]; then
    for prod in prod{01..10}; do
        scp -r /home/admin/nixos-24.11 $prod:/tmp/
        ssh $prod "sudo nixos-updater switch-config /tmp/nixos-24.11"
    done
fi
```

## 🎓 Best Practices

### 1. Always Test Before Production
```bash
# NEVER migrate production directly
# ALWAYS test in temporary location first

nixos-updater migrate /etc/nixos /tmp/test ...
# Test thoroughly
# Only then apply to production
```

### 2. Use Incremental Rules
```bash
# Don't try to do everything at once
# Apply rules one by one, test each

# Good:
nixos-updater migrate /etc/nixos /tmp/step1 deprecated-options:24.11
# Test step1
nixos-updater migrate /tmp/step1 /tmp/step2 upgrade-nixos-version:24.11
# Test step2

# Risky:
nixos-updater migrate /etc/nixos /tmp/all \
    fix-imports modernize-syntax deprecated-options:24.11 \
    upgrade-nixos-version:24.11 update-service-names
# Too many changes at once - harder to debug
```

### 3. Keep Backups
```bash
# Always backup before major migrations
tar -czf /backup/nixos-$(date +%Y%m%d).tar.gz /etc/nixos

# Use tool's automatic backup
switch_to_migrated_config /tmp/migrated true  # true = auto backup
```

### 4. Document Your Migrations
```bash
# Keep a log of migrations
cat >> /var/log/nixos-migrations.log << EOF
$(date): Migrated to 24.11
  Source: /etc/nixos
  Target: /tmp/nixos-24.11
  Rules: deprecated-options, upgrade-version
  Result: Success
  Generation: $(nixos_get_current_generation)
EOF
```

## 📞 Troubleshooting

### Migration Step Fails
```bash
# Check which rule failed
# → Review logs
cat /var/log/nixos-updater/updater-*.log

# → Try rule manually
apply_migration_rule /tmp/test deprecated-options 24.11

# → Check syntax
validate_nix_syntax /tmp/test
```

### Build Test Fails
```bash
# Get detailed error
cd /tmp/migrated-config
nixos-rebuild build --flake ".#$(hostname -s)" --show-trace

# Common issues:
# - Missing imports: Add missing files
# - Type errors: Fix option types
# - Deprecated options: Check deprecation list
```

### Switch Fails
```bash
# System won't boot with migrated config

# 1. Reboot and select previous generation from GRUB
# 2. Log in
# 3. Review what went wrong
# 4. Fix or restore backup
# 5. Try again
```

---

## 🎉 Summary

The migrator provides:
- ✅ **Safe cloning** of configurations
- ✅ **Automated transformations** via rules
- ✅ **Incremental application** with validation
- ✅ **Checkpoint/rollback** at each step
- ✅ **Multiple presets** for common migrations
- ✅ **Custom rules** for specific needs
- ✅ **Comparison tools** to preview changes
- ✅ **Safe switching** with automatic backup

**This makes complex migrations safe, automated, and repeatable!**
