#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: add-branding-headers.sh
# Purpose: Add standardized branding headers to all project files
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

set -euo pipefail

# Standard bash script header
BASH_HEADER='#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: FILENAME
# Purpose: DESCRIPTION
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################
'

# Nix module header
NIX_HEADER='################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: FILENAME
# Purpose: DESCRIPTION
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################
'

# Check if file has proper header
has_proper_header() {
    local file="$1"
    grep -q "Hyper-NixOS - Next-Generation Virtualization Platform" "$file" 2>/dev/null
}

# Add header to bash script
add_bash_header() {
    local file="$1"
    local filename=$(basename "$file")
    local description="${2:-Hyper-NixOS script}"

    if has_proper_header "$file"; then
        echo "✓ $file already has proper header"
        return 0
    fi

    # Create temp file with header
    local temp=$(mktemp)

    # Get shebang line if exists
    local shebang=$(head -n 1 "$file" | grep '^#!' || echo "#!/usr/bin/env bash")

    # Write header
    echo "$shebang" > "$temp"
    echo "################################################################################" >> "$temp"
    echo "# Hyper-NixOS - Next-Generation Virtualization Platform" >> "$temp"
    echo "# https://github.com/MasterofNull/Hyper-NixOS" >> "$temp"
    echo "#" >> "$temp"
    echo "# Script: $filename" >> "$temp"
    echo "# Purpose: $description" >> "$temp"
    echo "#" >> "$temp"
    echo "# Copyright © 2024-2025 MasterofNull" >> "$temp"
    echo "# Licensed under the MIT License" >> "$temp"
    echo "#" >> "$temp"
    echo "# Author: MasterofNull" >> "$temp"
    echo "################################################################################" >> "$temp"
    echo "" >> "$temp"

    # Append original content (skip shebang if present)
    if head -n 1 "$file" | grep -q '^#!'; then
        tail -n +2 "$file" >> "$temp"
    else
        cat "$file" >> "$temp"
    fi

    # Replace original
    mv "$temp" "$file"
    chmod +x "$file"

    echo "✓ Added header to $file"
}

# Add header to nix file
add_nix_header() {
    local file="$1"
    local filename=$(basename "$file")
    local description="${2:-Hyper-NixOS module}"

    if has_proper_header "$file"; then
        echo "✓ $file already has proper header"
        return 0
    fi

    # Create temp file with header
    local temp=$(mktemp)

    echo "################################################################################" > "$temp"
    echo "# Hyper-NixOS - Next-Generation Virtualization Platform" >> "$temp"
    echo "# https://github.com/MasterofNull/Hyper-NixOS" >> "$temp"
    echo "#" >> "$temp"
    echo "# Module: $filename" >> "$temp"
    echo "# Purpose: $description" >> "$temp"
    echo "#" >> "$temp"
    echo "# Copyright © 2024-2025 MasterofNull" >> "$temp"
    echo "# Licensed under the MIT License" >> "$temp"
    echo "#" >> "$temp"
    echo "# Author: MasterofNull" >> "$temp"
    echo "################################################################################" >> "$temp"
    echo "" >> "$temp"

    # Append original content
    cat "$file" >> "$temp"

    # Replace original
    mv "$temp" "$file"

    echo "✓ Added header to $file"
}

echo "Adding branding headers to Hyper-NixOS project files..."
echo "This script will update files that don't have proper headers."
echo ""

# Count files
total_bash=$(find /home/hyperd/Documents/Hyper-NixOS/scripts -type f -name "*.sh" | wc -l)
total_nix=$(find /home/hyperd/Documents/Hyper-NixOS/modules -type f -name "*.nix" | wc -l)

echo "Found:"
echo "  - $total_bash bash scripts"
echo "  - $total_nix nix modules"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Process bash scripts
echo "Processing bash scripts..."
find /home/hyperd/Documents/Hyper-NixOS/scripts -type f -name "*.sh" | while read -r file; do
    add_bash_header "$file" "Hyper-NixOS script"
done

# Process nix modules
echo ""
echo "Processing nix modules..."
find /home/hyperd/Documents/Hyper-NixOS/modules -type f -name "*.nix" | while read -r file; do
    add_nix_header "$file" "NixOS module for Hyper-NixOS"
done

echo ""
echo "Done! All files have been branded."
