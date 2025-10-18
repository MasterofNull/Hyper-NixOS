#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: brand-all-wizards.sh
# Purpose: Add branding to all wizard scripts
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add branding to a wizard file
brand_wizard() {
    local file="$1"
    local filename=$(basename "$file")

    echo "Processing: $filename"

    # Check if already has branding source
    if grep -q "source.*branding.sh" "$file" 2>/dev/null; then
        echo "  ✓ Already sources branding.sh"
    else
        echo "  + Adding branding.sh source"

        # Find the line after common.sh or ui.sh source, or after set -e line
        local insert_line=$(grep -n "source.*common.sh\|source.*ui.sh\|^set -" "$file" | tail -1 | cut -d: -f1)

        if [ -n "$insert_line" ]; then
            # Insert after that line
            sed -i "${insert_line}a\\
\\
# Source branding library\\
BRANDING_LIB=\"\${SCRIPT_DIR}/lib/branding.sh\"\\
if [ -f \"\${BRANDING_LIB}\" ]; then\\
    # shellcheck source=lib/branding.sh\\
    source \"\${BRANDING_LIB}\"\\
fi" "$file"
        fi
    fi

    # Check if shows banner
    if grep -q "show_banner\|print_header" "$file" 2>/dev/null; then
        # Check if it's using our branding banner
        if grep -q "show_banner_large\|show_banner_compact" "$file" 2>/dev/null; then
            echo "  ✓ Already shows branding banner"
        else
            echo "  ! Has custom banner (manual review needed)"
        fi
    else
        echo "  + Adding banner call to main function"

        # Find the main function or first function after sourcing
        local main_func=$(grep -n "^main()\|^show_.*menu\|^print_header" "$file" | head -1 | cut -d: -f1)

        if [ -n "$main_func" ]; then
            # Add show_banner_large call at the start of the function
            sed -i "${main_func}a\\
    # Show branding\\
    if type show_banner_large &>/dev/null; then\\
        clear\\
        show_banner_large\\
    fi\\
" "$file"
        fi
    fi

    echo ""
}

echo "╔════════════════════════════════════════════════════════╗"
echo "║         Hyper-NixOS Wizard Branding Tool              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "This tool will add branding to all wizard scripts."
echo ""

# Find all wizard files
WIZARDS=(
    "$SCRIPT_DIR/backup-configuration-wizard.sh"
    "$SCRIPT_DIR/comprehensive-setup-wizard.sh"
    "$SCRIPT_DIR/create-vm-wizard.sh"
    "$SCRIPT_DIR/feature-manager-wizard.sh"
    "$SCRIPT_DIR/feature-manager-wizard-v2.sh"
    "$SCRIPT_DIR/first-boot-wizard.sh"
    "$SCRIPT_DIR/monitoring-configuration-wizard.sh"
    "$SCRIPT_DIR/network-configuration-wizard.sh"
    "$SCRIPT_DIR/security-configuration-wizard.sh"
    "$SCRIPT_DIR/setup-wizard.sh"
    "$SCRIPT_DIR/storage-configuration-wizard.sh"
    "$SCRIPT_DIR/system-setup-wizard.sh"
)

# Setup wizards
for wizard in "$SCRIPT_DIR"/setup/*wizard*.sh; do
    [ -f "$wizard" ] && WIZARDS+=("$wizard")
done

echo "Found ${#WIZARDS[@]} wizard scripts to process"
echo ""

for wizard in "${WIZARDS[@]}"; do
    if [ -f "$wizard" ]; then
        brand_wizard "$wizard"
    fi
done

echo "✓ All wizards have been branded!"
echo ""
echo "Please test the wizards to ensure they work correctly:"
echo "  hv first-boot"
echo "  hv vm-create"
echo "  hv security-config"
echo ""
