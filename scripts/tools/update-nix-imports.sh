#!/usr/bin/env bash
# Update NixOS configuration imports after file structure reorganization

set -euo pipefail

# Function to update imports in a file
update_imports() {
    local file="$1"
    echo "Updating imports in: $file"
    
    # Update hardware-configuration.nix path
    sed -i 's|./hardware-configuration.nix|./core/hardware-configuration.nix|g' "$file"
    
    # Update module paths to use ../modules/
    sed -i 's|./modules/|../modules/|g' "$file"
    
    # Update references to other configuration variants
    sed -i 's|./configuration-|./variants/configuration-|g' "$file"
    
    # Special case for files in variants/ that need to go up two levels
    if [[ "$file" == configuration/variants/* ]]; then
        sed -i 's|./core/hardware-configuration.nix|../core/hardware-configuration.nix|g' "$file"
        sed -i 's|../modules/|../../modules/|g' "$file"
    fi
}

# Update main configuration
update_imports "configuration/configuration.nix"

# Update all variant configurations
for variant in configuration/variants/*.nix; do
    if [ -f "$variant" ]; then
        update_imports "$variant"
    fi
done

echo "Import paths updated successfully!"