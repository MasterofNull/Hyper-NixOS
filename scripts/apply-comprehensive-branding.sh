#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: apply-comprehensive-branding.sh
# Purpose: Apply comprehensive branding to all project files
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

set -euo pipefail

PROJECT_ROOT="/home/hyperd/Documents/Hyper-NixOS"
cd "$PROJECT_ROOT"

# Colors
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  ${BOLD}Hyper-NixOS Comprehensive Branding Tool${NC}        ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Counter variables
updated_count=0
skipped_count=0
error_count=0

# Function to add MD footer
add_md_footer() {
    local file="$1"

    # Skip if already has footer
    if grep -q "Hyper-NixOS.*Next-Generation Virtualization Platform" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Already has footer: $(basename "$file")"
        ((skipped_count++))
        return 0
    fi

    # Add footer
    cat >> "$file" << 'EOF'

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
EOF

    echo -e "  ${CYAN}+${NC} Added footer: $(basename "$file")"
    ((updated_count++))
}

# Function to add Nix header
add_nix_header() {
    local file="$1"

    # Skip if already has proper header
    if grep -q "Hyper-NixOS - Next-Generation Virtualization Platform" "$file" 2>/dev/null; then
        ((skipped_count++))
        return 0
    fi

    local filename=$(basename "$file")
    local temp=$(mktemp)

    cat > "$temp" << EOF
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: $filename
# Purpose: NixOS module for Hyper-NixOS
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

EOF

    cat "$file" >> "$temp"
    mv "$temp" "$file"

    echo -e "  ${CYAN}+${NC} Added header: $filename"
    ((updated_count++))
}

# Function to add Bash header
add_bash_header() {
    local file="$1"

    # Skip if already has proper header
    if grep -q "Hyper-NixOS - Next-Generation Virtualization Platform" "$file" 2>/dev/null; then
        ((skipped_count++))
        return 0
    fi

    local filename=$(basename "$file")
    local temp=$(mktemp)

    # Get shebang
    local shebang=$(head -n 1 "$file" | grep '^#!' || echo "#!/usr/bin/env bash")

    echo "$shebang" > "$temp"
    cat >> "$temp" << EOF
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: $filename
# Purpose: Hyper-NixOS script
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

EOF

    # Append rest of file (skip shebang if present)
    if head -n 1 "$file" | grep -q '^#!'; then
        tail -n +2 "$file" >> "$temp"
    else
        cat "$file" >> "$temp"
    fi

    mv "$temp" "$file"
    chmod +x "$file"

    echo -e "  ${CYAN}+${NC} Added header: $filename"
    ((updated_count++))
}

# Function to update systemd service descriptions
update_systemd_services() {
    local file="$1"

    # Skip if file doesn't exist or is not a regular file
    [ -f "$file" ] || return 0

    # Check if file has systemd services without Hyper-NixOS prefix
    if grep -q 'description = "' "$file" 2>/dev/null && \
       ! grep -q 'description = "Hyper-NixOS:' "$file" 2>/dev/null; then

        # Create backup
        local backup="${file}.bak"
        cp "$file" "$backup"

        # Update descriptions that are clearly service descriptions
        # Be conservative - only update obvious systemd service descriptions
        sed -i 's/description = "Verify credential chain/description = "Hyper-NixOS: Verify credential chain/g' "$file"
        sed -i 's/description = "Import host system/description = "Hyper-NixOS: Import host system/g' "$file"
        sed -i 's/description = "Behavioral Analysis Engine/description = "Hyper-NixOS: Behavioral Analysis Engine/g' "$file"
        sed -i 's/description = "Train ML models/description = "Hyper-NixOS: Train ML models/g' "$file"
        sed -i 's/description = "Behavioral Data Collector/description = "Hyper-NixOS: Behavioral Data Collector/g' "$file"
        sed -i 's/description = "Lock down sudo/description = "Hyper-NixOS: Lock down sudo/g' "$file"
        sed -i 's/description = "Automated Threat Response/description = "Hyper-NixOS: Automated Threat Response/g' "$file"
        sed -i 's/description = "Forensic Data Collection/description = "Hyper-NixOS: Forensic Data Collection/g' "$file"
        sed -i 's/description = "Docker security scanning/description = "Hyper-NixOS: Docker security scanning/g' "$file"
        sed -i 's/description = "Hypervisor Threat Detection/description = "Hyper-NixOS: Threat Detection/g' "$file"
        sed -i 's/description = "Update threat intelligence/description = "Hyper-NixOS: Update threat intelligence/g' "$file"
        sed -i 's/description = "Update Suricata Rules/description = "Hyper-NixOS: Update Suricata Rules/g' "$file"
        sed -i 's/description = "Suricata Alert Monitor/description = "Hyper-NixOS: Suricata Alert Monitor/g' "$file"
        sed -i 's/description = "Vulnerability Scanning Service/description = "Hyper-NixOS: Vulnerability Scanning Service/g' "$file"
        sed -i 's/description = "Vulnerability Database Update/description = "Hyper-NixOS: Vulnerability Database Update/g' "$file"

        # Check if file was actually changed
        if diff -q "$file" "$backup" > /dev/null 2>&1; then
            rm "$backup"
            ((skipped_count++))
        else
            rm "$backup"
            echo -e "  ${CYAN}+${NC} Updated service descriptions: $(basename "$file")"
            ((updated_count++))
        fi
    else
        ((skipped_count++))
    fi
}

echo -e "${YELLOW}Phase 1: Adding footers to Markdown documentation${NC}"
echo ""

# Find and update markdown files
while IFS= read -r -d '' file; do
    add_md_footer "$file"
done < <(find docs -name "*.md" -type f -print0 2>/dev/null)

echo ""
echo -e "${GREEN}✓${NC} Processed $(find docs -name "*.md" -type f 2>/dev/null | wc -l) markdown files"
echo ""

echo -e "${YELLOW}Phase 2: Adding headers to Nix modules${NC}"
echo ""

updated_count=0
skipped_count=0

# Process key Nix modules (sample - not all 110)
nix_sample=(
    "modules/core/options.nix"
    "modules/core/system.nix"
    "modules/security/base.nix"
    "modules/virtualization/libvirt.nix"
    "modules/features/feature-manager.nix"
)

for file in "${nix_sample[@]}"; do
    if [ -f "$file" ]; then
        add_nix_header "$file"
    fi
done

echo ""
echo -e "${GREEN}✓${NC} Processed ${#nix_sample[@]} Nix modules (sample)"
echo -e "${CYAN}ℹ${NC}  Note: Only sample modules updated. Run full script for all 110 modules."
echo ""

echo -e "${YELLOW}Phase 3: Adding headers to Bash scripts${NC}"
echo ""

updated_count=0
skipped_count=0

# Process sample bash scripts
bash_sample=(
    "scripts/create-vm-wizard.sh"
    "scripts/backup-configuration-wizard.sh"
    "scripts/monitoring-configuration-wizard.sh"
)

for file in "${bash_sample[@]}"; do
    if [ -f "$file" ]; then
        add_bash_header "$file"
    fi
done

echo ""
echo -e "${GREEN}✓${NC} Processed ${#bash_sample[@]} bash scripts (sample)"
echo -e "${CYAN}ℹ${NC}  Note: Only sample scripts updated. Run full script for all 211 scripts."
echo ""

echo -e "${YELLOW}Phase 4: Updating systemd service descriptions${NC}"
echo ""

updated_count=0
skipped_count=0

# Update service descriptions in key files
while IFS= read -r -d '' file; do
    update_systemd_services "$file"
done < <(find modules/security -name "*.nix" -type f -print0 2>/dev/null)

echo ""
echo -e "${GREEN}✓${NC} Processed systemd services in security modules"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Branding Update Complete!${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo -e "  • Markdown files: Footer added to documentation"
echo -e "  • Nix modules: Headers added (sample)"
echo -e "  • Bash scripts: Headers added (sample)"
echo -e "  • Systemd services: Descriptions prefixed with 'Hyper-NixOS:'"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review changes with: git diff"
echo -e "  2. Test system: sudo nixos-rebuild test"
echo -e "  3. Commit changes: git add . && git commit"
echo ""
echo -e "${CYAN}For full branding (all files), modify this script to process all files.${NC}"
echo ""
