#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Properly merge let blocks after fixing 'with lib;'
#

set -euo pipefail

find modules -name "*.nix" -type f | while read -r file; do
    # Skip if doesn't have the problematic pattern
    if ! grep -q "^  inherit (lib)" "$file"; then
        continue
    fi
    
    # Check if has the double let issue
    if grep -A2 "^in$" "$file" | grep -q "^let$"; then
        echo "Merging let blocks in: $file"
        
        # Use perl for more complex replacement
        perl -i -0pe 's/let\n  inherit \(lib\) [^;]+;\nin\n\nlet\n/let\n  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;\n/g' "$file"
    fi
done

echo "Done merging let blocks"