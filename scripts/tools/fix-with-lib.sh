#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Simple script to fix 'with lib;' anti-pattern in NixOS modules
#

set -euo pipefail

# Process each .nix file
find modules -name "*.nix" -type f | while read -r file; do
    # Skip if doesn't contain 'with lib;'
    if ! grep -q "with lib;" "$file"; then
        continue
    fi
    
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "${file}.backup"
    
    # Simple replacement: with lib; -> let inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types; in
    sed -i 's/^with lib;$/let\n  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;\nin/' "$file"
    
    echo "  ✓ Fixed 'with lib;' pattern"
done

echo "Done! Backups created with .backup extension"