#!/usr/bin/env bash
# Update references to configuration files after reorganization

set -euo pipefail

echo "Updating configuration file paths in scripts..."

# Update references to configuration.nix
find scripts -type f -name "*.sh" -o -name "*.py" | while read -r file; do
    # Skip the update scripts themselves
    if [[ "$file" == *"update-config-paths.sh"* ]] || [[ "$file" == *"update-nix-imports.sh"* ]]; then
        continue
    fi
    
    # Check if file contains references
    if grep -q "configuration\.nix\|hardware-configuration\.nix" "$file" 2>/dev/null; then
        echo "Updating: $file"
        
        # Update paths - be careful with context
        sed -i 's|/etc/nixos/configuration\.nix|/etc/nixos/configuration/configuration.nix|g' "$file"
        sed -i 's|"configuration\.nix"|"configuration/configuration.nix"|g' "$file"
        sed -i 's|'\''configuration\.nix'\''|'\''configuration/configuration.nix'\''|g' "$file"
        
        # Update hardware-configuration.nix references
        sed -i 's|/etc/nixos/hardware-configuration\.nix|/etc/nixos/configuration/core/hardware-configuration.nix|g' "$file"
        sed -i 's|"hardware-configuration\.nix"|"configuration/core/hardware-configuration.nix"|g' "$file"
        sed -i 's|'\''hardware-configuration\.nix'\''|'\''configuration/core/hardware-configuration.nix'\''|g' "$file"
        
        # Update variant references
        sed -i 's|configuration-minimal\.nix|configuration/variants/configuration-minimal.nix|g' "$file"
        sed -i 's|configuration-complete\.nix|configuration/variants/configuration-complete.nix|g' "$file"
        sed -i 's|configuration-enhanced\.nix|configuration/variants/configuration-enhanced.nix|g' "$file"
        sed -i 's|configuration-privilege-separation\.nix|configuration/variants/configuration-privilege-separation.nix|g' "$file"
    fi
done

echo "Configuration paths updated successfully!"