#!/usr/bin/env bash
# Fix 'with lib;' and 'with pkgs;' anti-patterns in NixOS modules
# Converts to explicit lib. and pkgs. prefixes

set -euo pipefail

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_status() { echo -e "${YELLOW}→${NC} $*"; }

# Modules to fix (from audit)
MODULES=(
    "modules/security/vulnerability-scanning.nix"
    "modules/security/ids-ips.nix"
    "modules/storage-management/storage-tiers.nix"
    "modules/virtualization/vm-config.nix"
    "modules/virtualization/vm-composition.nix"
    "modules/features/container-support.nix"
    "modules/features/database-tools.nix"
    "modules/features/dev-tools.nix"
    "modules/security/credential-security/default.nix"
    "modules/clustering/mesh-cluster.nix"
    "modules/automation/ci-cd.nix"
    "modules/automation/kubernetes-tools.nix"
    "modules/network-settings/vpn-server.nix"
    "modules/automation/backup-dedup.nix"
    "modules/core/capability-security.nix"
    "modules/monitoring/ai-anomaly.nix"
)

cd "$(dirname "$0")/../.."

echo "Fixing anti-patterns in ${#MODULES[@]} modules..."
echo

for module in "${MODULES[@]}"; do
    if [[ ! -f "$module" ]]; then
        echo "Warning: $module not found, skipping"
        continue
    fi
    
    print_status "Processing $module"
    
    # Create backup
    cp "$module" "$module.bak"
    
    # Fix: environment.systemPackages = with pkgs; [...] 
    # to: environment.systemPackages = [...]  (pkgs. already prefixed in list)
    sed -i 's/= with pkgs; \[/= [/' "$module"
    
    # Fix: with lib; at top level (rare, but check)
    sed -i '/^with lib;$/d' "$module"
    sed -i '/^with pkgs;$/d' "$module"
    
    # Validate syntax
    if nix-instantiate --parse "$module" >/dev/null 2>&1; then
        print_success "Fixed and validated: $module"
        rm "$module.bak"
    else
        echo "Error: Syntax validation failed, restoring backup"
        mv "$module.bak" "$module"
        exit 1
    fi
done

echo
echo "All modules fixed successfully!"
echo "Run: nixos-rebuild dry-build --show-trace"
