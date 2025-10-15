#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Setup script for Hyper-NixOS Feature Management System
# This script integrates the feature manager into the system
#

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly WIZARD_SCRIPT="$SCRIPT_DIR/feature-manager-wizard.sh"
readonly FIRST_BOOT_SCRIPT="$SCRIPT_DIR/first-boot-wizard.sh"

echo -e "${BLUE}Hyper-NixOS Feature Management Setup${NC}\n"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}Running as root${NC}"
else
    echo -e "${YELLOW}Running as user. Will use sudo for system changes.${NC}"
fi

# Create necessary directories
echo -e "\n${BLUE}Creating directories...${NC}"
sudo mkdir -p /etc/hypervisor/{bin,features,templates,backups}
sudo mkdir -p /var/lib/hypervisor/{cache,state}

# Install feature manager wizard
echo -e "\n${BLUE}Installing feature manager...${NC}"
sudo cp "$WIZARD_SCRIPT" /etc/hypervisor/bin/feature-manager
sudo chmod +x /etc/hypervisor/bin/feature-manager

# Create convenience symlinks
echo -e "\n${BLUE}Creating convenience commands...${NC}"
sudo ln -sf /etc/hypervisor/bin/feature-manager /usr/local/bin/hv-features 2>/dev/null || true

# Install tier templates module
echo -e "\n${BLUE}Installing tier templates...${NC}"
if [[ -f "$PROJECT_ROOT/modules/features/tier-templates.nix" ]]; then
    echo "Tier templates module already in place"
else
    echo -e "${RED}Warning: tier-templates.nix not found in modules${NC}"
fi

# Create feature database
echo -e "\n${BLUE}Creating feature database...${NC}"
cat > /tmp/features-database.json << 'EOF'
{
  "version": "1.0",
  "features": {
    "core": {
      "category": "core",
      "description": "Essential system components and CLI tools",
      "ram": 512,
      "dependencies": [],
      "conflicts": []
    },
    "libvirt": {
      "category": "virtualization",
      "description": "VM management with QEMU/KVM",
      "ram": 256,
      "dependencies": ["core"],
      "conflicts": []
    },
    "monitoring": {
      "category": "monitoring",
      "description": "Prometheus + Grafana monitoring stack",
      "ram": 1024,
      "dependencies": ["core"],
      "conflicts": []
    },
    "ai-security": {
      "category": "security",
      "description": "AI/ML threat detection and response",
      "ram": 4096,
      "dependencies": ["monitoring", "security-base"],
      "conflicts": []
    },
    "desktop-kde": {
      "category": "desktop",
      "description": "KDE Plasma desktop environment",
      "ram": 2048,
      "dependencies": ["core"],
      "conflicts": ["desktop-gnome", "desktop-xfce"]
    },
    "desktop-gnome": {
      "category": "desktop",
      "description": "GNOME desktop environment",
      "ram": 2048,
      "dependencies": ["core"],
      "conflicts": ["desktop-kde", "desktop-xfce"]
    },
    "clustering": {
      "category": "enterprise",
      "description": "High availability clustering support",
      "ram": 8192,
      "dependencies": ["monitoring", "networking-advanced"],
      "conflicts": []
    }
  }
}
EOF
sudo mv /tmp/features-database.json /etc/hypervisor/features/features-database.json

# Create helper scripts
echo -e "\n${BLUE}Creating helper scripts...${NC}"

# Quick template application
cat > /tmp/hv-apply-template << 'EOF'
#!/usr/bin/env bash
# Quick template application

template="${1:-standard}"
echo "Applying $template template..."

cat > /tmp/template-config.json << EOT
{
  "tier": "$template",
  "features": []
}
EOT

/etc/hypervisor/bin/feature-manager --import /tmp/template-config.json --non-interactive --apply
rm -f /tmp/template-config.json
EOF
sudo mv /tmp/hv-apply-template /etc/hypervisor/bin/
sudo chmod +x /etc/hypervisor/bin/hv-apply-template

# Feature information tool
cat > /tmp/hv-feature << 'EOF'
#!/usr/bin/env bash
# Feature information and management tool

case "$1" in
    list)
        if [[ "$2" == "--enabled" ]]; then
            grep -oP 'enabledFeatures\s*=\s*\[\s*\K[^\]]+' /etc/nixos/hypervisor-features.nix 2>/dev/null | tr -d '[]"' | tr ',' '\n'
        else
            jq -r '.features | keys[]' /etc/hypervisor/features/features-database.json 2>/dev/null
        fi
        ;;
    info)
        feature="$2"
        jq ".features.\"$feature\" // \"Feature not found\"" /etc/hypervisor/features/features-database.json
        ;;
    deps)
        feature="$2"
        jq -r ".features.\"$feature\".dependencies[]? // empty" /etc/hypervisor/features/features-database.json
        ;;
    check-resources)
        total=0
        for feature in $(hv-feature list --enabled); do
            ram=$(jq -r ".features.\"$feature\".ram // 0" /etc/hypervisor/features/features-database.json)
            total=$((total + ram))
        done
        echo "Total RAM required: ${total}MB"
        echo "System RAM: $(free -m | awk '/^Mem:/ {print $2}')MB"
        ;;
    resource-report)
        echo "Feature Resource Usage Report"
        echo "============================"
        for feature in $(hv-feature list --enabled); do
            ram=$(jq -r ".features.\"$feature\".ram // 0" /etc/hypervisor/features/features-database.json)
            printf "%-30s %6d MB\n" "$feature:" "$ram"
        done
        ;;
    *)
        echo "Usage: hv-feature {list|info|deps|check-resources|resource-report} [args]"
        exit 1
        ;;
esac
EOF
sudo mv /tmp/hv-feature /etc/hypervisor/bin/
sudo chmod +x /etc/hypervisor/bin/hv-feature

# Integration with first-boot wizard
echo -e "\n${BLUE}Updating first-boot integration...${NC}"
if [[ -f "$FIRST_BOOT_SCRIPT" ]]; then
    # Add option to run feature manager from first-boot menu
    if ! grep -q "feature-manager" "$FIRST_BOOT_SCRIPT"; then
        echo -e "${YELLOW}Note: First-boot wizard can launch feature manager${NC}"
    fi
fi

# Create systemd service for feature management
echo -e "\n${BLUE}Creating systemd service...${NC}"
cat > /tmp/hypervisor-feature-manager.service << 'EOF'
[Unit]
Description=Hyper-NixOS Feature Manager
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/true
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo mv /tmp/hypervisor-feature-manager.service /etc/systemd/system/

# Create desktop entry for GUI environments
echo -e "\n${BLUE}Creating desktop entry...${NC}"
cat > /tmp/hypervisor-features.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Hyper-NixOS Feature Manager
Comment=Manage system features and configuration
Icon=applications-system
Exec=konsole -e /etc/hypervisor/bin/feature-manager
Terminal=false
Categories=System;Settings;
Keywords=features;configuration;system;hypervisor;
EOF
sudo mkdir -p /usr/share/applications
sudo mv /tmp/hypervisor-features.desktop /usr/share/applications/

# Update module imports
echo -e "\n${BLUE}Checking module configuration...${NC}"
CONFIG_FILE="/etc/nixos/configuration.nix"
if [[ -f "$CONFIG_FILE" ]]; then
    # Check if tier-templates module is imported
    if ! grep -q "tier-templates.nix" "$CONFIG_FILE"; then
        echo -e "${YELLOW}Note: Add the following to your configuration.nix imports:${NC}"
        echo "  ./modules/features/tier-templates.nix"
    fi
fi

# Create example custom template
echo -e "\n${BLUE}Creating example custom template...${NC}"
cat > /tmp/custom-templates-example.nix << 'EOF'
# Example custom templates for Hyper-NixOS
# Copy to /etc/nixos/custom-templates.nix and modify as needed

{ config, lib, pkgs, ... }:

{
  hypervisor.tierTemplates.customTemplates = {
    # Example: Minimal web server
    webserver = {
      description = "Minimal web server configuration";
      baseTemplate = "standard";
      addFeatures = [ "web-dashboard" "ssl-termination" "container-support" ];
      removeFeatures = [ "desktop-kde" "desktop-gnome" ];
    };
    
    # Example: Development workstation with specific tools
    dev-rust = {
      description = "Rust development environment";
      baseTemplate = "developer";
      addFeatures = [ "rust-dev" "cargo-tools" "rustup" ];
      removeFeatures = [ ];
    };
    
    # Example: High-security configuration
    paranoid = {
      description = "Maximum security configuration";
      features = [
        "core" "security-base" "ssh-hardening" "firewall"
        "audit-logging" "ai-security" "compliance"
        "vulnerability-scanning" "ids-ips" "network-isolation"
        "storage-encryption" "monitoring" "alerting"
      ];
    };
  };
}
EOF
sudo cp /tmp/custom-templates-example.nix /etc/nixos/custom-templates-example.nix

# Final summary
echo -e "\n${GREEN}✅ Feature Management System Setup Complete!${NC}\n"

echo "Available commands:"
echo "  • ${BLUE}feature-manager${NC} - Launch the interactive feature management wizard"
echo "  • ${BLUE}hv-features${NC} - Quick access to feature manager"
echo "  • ${BLUE}hv-feature${NC} - Command-line feature information tool"
echo "  • ${BLUE}hv-template${NC} - Template management commands"
echo "  • ${BLUE}hv-apply-template${NC} - Quick template application"

echo -e "\nConfiguration files:"
echo "  • /etc/nixos/hypervisor-features.nix - Current feature configuration"
echo "  • /etc/nixos/custom-templates.nix - Custom template definitions"
echo "  • /etc/hypervisor/features/ - Feature database and configs"

echo -e "\nNext steps:"
echo "1. Run '${BLUE}feature-manager${NC}' to customize your system"
echo "2. Or use '${BLUE}hv-apply-template <tier>${NC}' for quick setup"
echo "3. View the feature catalog at ${BLUE}/docs/FEATURE_CATALOG.md${NC}"
echo "4. Read the guide at ${BLUE}/docs/FEATURE_MANAGEMENT_GUIDE.md${NC}"

echo -e "\n${YELLOW}Note: Changes require 'nixos-rebuild switch' to take effect${NC}"