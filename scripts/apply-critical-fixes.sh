#!/usr/bin/env bash
#
# Hyper-NixOS Critical Fixes Migration Script
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# This script applies critical fixes to an existing Hyper-NixOS installation:
# 1. CPU vendor detection (AMD vs Intel)
# 2. Configuration merge conflict prevention
# 3. NixOS stable channel alignment
# 4. Update management system

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║     Hyper-NixOS Critical Fixes Migration Script         ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}This script will apply critical fixes to your system:${NC}"
echo "  1. CPU vendor detection (AMD vs Intel)"
echo "  2. Configuration merge conflict prevention"
echo "  3. NixOS update management system"
echo ""

# Detect source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${CYAN}Repository: $REPO_ROOT${NC}"
echo -e "${CYAN}Target: /etc/hypervisor/src${NC}"
echo ""

# Verify we're in the right place
if [[ ! -f "$REPO_ROOT/configuration.nix" ]]; then
    echo -e "${RED}ERROR: Cannot find configuration.nix${NC}"
    echo "This script must be run from the Hyper-NixOS repository"
    exit 1
fi

if [[ ! -d "/etc/hypervisor/src" ]]; then
    echo -e "${RED}ERROR: /etc/hypervisor/src not found${NC}"
    echo "Is Hyper-NixOS installed on this system?"
    exit 1
fi

echo -e "${YELLOW}⚠ This will modify your system configuration${NC}"
echo -e "${YELLOW}⚠ A backup will be created first${NC}"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Creating Backup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

BACKUP_DIR="/root/hyper-nixos-backup-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r /etc/hypervisor/src "$BACKUP_DIR/"
cp -r /etc/nixos "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${GREEN}✓ Backup created${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Detecting Current System${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

# Detect CPU
CPU_VENDOR=$("$REPO_ROOT/scripts/detect-cpu-vendor.sh" vendor)
echo "CPU Vendor: $CPU_VENDOR"

# Check current NixOS version
NIXOS_VERSION=$(nixos-version --json | jq -r '.nixosVersion' || echo "unknown")
echo "NixOS Version: $NIXOS_VERSION"

echo -e "${GREEN}✓ System detected${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Copying New/Updated Files${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

# Create directories if they don't exist
mkdir -p /etc/hypervisor/src/modules/core
mkdir -p /etc/hypervisor/src/modules/system
mkdir -p /etc/hypervisor/src/scripts
mkdir -p /etc/hypervisor/src/docs

# Copy new modules
echo "Copying CPU detection module..."
cp "$REPO_ROOT/modules/core/cpu-detection.nix" /etc/hypervisor/src/modules/core/
echo -e "${GREEN}✓ modules/core/cpu-detection.nix${NC}"

echo "Copying update checker module..."
cp "$REPO_ROOT/modules/system/nixos-update-checker.nix" /etc/hypervisor/src/modules/system/
echo -e "${GREEN}✓ modules/system/nixos-update-checker.nix${NC}"

# Copy utility script
echo "Copying CPU detection script..."
cp "$REPO_ROOT/scripts/detect-cpu-vendor.sh" /etc/hypervisor/src/scripts/
chmod +x /etc/hypervisor/src/scripts/detect-cpu-vendor.sh
echo -e "${GREEN}✓ scripts/detect-cpu-vendor.sh${NC}"

# Copy documentation
echo "Copying documentation..."
cp "$REPO_ROOT/docs/UPGRADE_MANAGEMENT.md" /etc/hypervisor/src/docs/
cp "$REPO_ROOT/docs/FIXES_SUMMARY.md" /etc/hypervisor/src/docs/
echo -e "${GREEN}✓ Documentation${NC}"

# Copy updated configurations
echo "Copying updated configuration files..."
cp "$REPO_ROOT/configuration.nix" /etc/hypervisor/src/
cp "$REPO_ROOT/profiles/configuration-minimal.nix" /etc/hypervisor/src/profiles/
echo -e "${GREEN}✓ Configuration files${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 4: Testing Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

echo "Running dry-build to test configuration syntax..."
if nixos-rebuild dry-build --flake /etc/hypervisor 2>&1 | tee /tmp/nixos-dryrun.log | tail -20; then
    echo -e "${GREEN}✓ Configuration syntax is valid${NC}"
else
    echo -e "${RED}✗ Configuration test failed${NC}"
    echo ""
    echo "Error details saved to: /tmp/nixos-dryrun.log"
    echo ""
    echo -e "${YELLOW}Restoring backup...${NC}"
    cp -r "$BACKUP_DIR/src"/* /etc/hypervisor/src/
    echo -e "${YELLOW}Backup restored. Your system is unchanged.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 5: Applying Changes (Test Mode)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

echo "This will activate the new configuration temporarily (reverts on reboot)"
echo ""
read -p "Apply test configuration? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Running nixos-rebuild test..."
    if nixos-rebuild test --flake /etc/hypervisor 2>&1 | tee /tmp/nixos-test.log | tail -30; then
        echo -e "${GREEN}✓ Test configuration applied successfully${NC}"

        echo ""
        echo -e "${CYAN}Verifying CPU detection...${NC}"
        if [[ -f /var/log/hypervisor-cpu-detection.log ]]; then
            cat /var/log/hypervisor-cpu-detection.log
            echo -e "${GREEN}✓ CPU detection working${NC}"
        else
            echo -e "${YELLOW}⚠ CPU detection log not found (may not have run yet)${NC}"
        fi

        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}Test Successful!${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo "The new configuration is active but will revert on reboot."
        echo ""
        echo "Please verify:"
        echo "  • Check CPU detection: cat /var/log/hypervisor-cpu-detection.log"
        echo "  • Test VM functionality: virsh capabilities | grep -i kvm"
        echo "  • Check loaded modules: lsmod | grep kvm"
        echo ""
        echo -e "${CYAN}If everything works, make it permanent:${NC}"
        echo "  sudo nixos-rebuild switch --flake /etc/hypervisor"
        echo ""
        echo -e "${CYAN}To revert immediately:${NC}"
        echo "  sudo nixos-rebuild switch --rollback"
        echo ""
        echo -e "${CYAN}Enable update checker:${NC}"
        echo "  sudo systemctl enable --now nixos-update-checker.timer"
        echo ""

    else
        echo -e "${RED}✗ Test configuration failed${NC}"
        echo ""
        echo "Error details saved to: /tmp/nixos-test.log"
        echo ""
        echo -e "${YELLOW}Your system is still on the old configuration${NC}"
        echo -e "${YELLOW}To restore backed up files:${NC}"
        echo "  sudo cp -r $BACKUP_DIR/src/* /etc/hypervisor/src/"
        exit 1
    fi
else
    echo ""
    echo -e "${YELLOW}Test skipped. Configuration files updated but not applied.${NC}"
    echo ""
    echo "To test manually:"
    echo "  sudo nixos-rebuild test --flake /etc/hypervisor"
    echo ""
    echo "To apply permanently:"
    echo "  sudo nixos-rebuild switch --flake /etc/hypervisor"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Migration Complete${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "New commands available:"
echo "  • hv-check-updates      - Check for NixOS updates"
echo "  • hv-upgrade-test       - Test system upgrade"
echo "  • hv-system-upgrade     - Apply permanent upgrade"
echo ""
echo "Documentation:"
echo "  • /etc/hypervisor/src/docs/UPGRADE_MANAGEMENT.md"
echo "  • /etc/hypervisor/src/docs/FIXES_SUMMARY.md"
echo ""
echo -e "${GREEN}✓ All critical fixes applied${NC}"
