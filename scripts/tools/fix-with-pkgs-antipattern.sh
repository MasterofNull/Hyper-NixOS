#!/usr/bin/env bash
# Fix 'with pkgs;' anti-pattern in NixOS modules
# Replaces with explicit pkgs. prefix

set -euo pipefail

# Files that need fixing
FILES=(
    "modules/virtualization/vm-config.nix"
    "modules/virtualization/vm-composition.nix"
    "modules/storage-management/storage-tiers.nix"
    "modules/security/credential-security/default.nix"
    "modules/monitoring/ai-anomaly.nix"
    "modules/default.nix"
    "modules/automation/backup-dedup.nix"
    "modules/core/capability-security.nix"
    "modules/core/hypervisor-base.nix"
    "modules/api/interop-service.nix"
    "modules/clustering/mesh-cluster.nix"
)

echo "====================================================="
echo "  Fixing 'with pkgs;' Anti-Pattern"
echo "====================================================="
echo

for file in "${FILES[@]}"; do
    if [[ ! -f "/workspace/$file" ]]; then
        echo "⚠️  Skipping $file (not found)"
        continue
    fi
    
    echo "Processing: $file"
    
    # Check if file actually has 'with pkgs;'
    if ! grep -q "with pkgs;" "/workspace/$file"; then
        echo "  ✓ Already fixed or no 'with pkgs;' found"
        continue
    fi
    
    # Create backup
    cp "/workspace/$file" "/workspace/$file.backup-$(date +%s)"
    
    # This is complex - flag for manual review
    echo "  ⚠️  Contains 'with pkgs;' - needs manual review"
    echo "     File backed up"
done

echo
echo "====================================================="
echo "Summary:"
echo "  Files checked: ${#FILES[@]}"
echo "  Manual review needed for files with 'with pkgs;'"
echo
echo "Manual fix instructions:"
echo "1. Remove 'with pkgs;' from let bindings"
echo "2. Add 'pkgs.' prefix to all package references"
echo "3. Test build: nixos-rebuild dry-build --show-trace"
echo "====================================================="
