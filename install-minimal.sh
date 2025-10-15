#!/usr/bin/env bash
#
# Hyper-NixOS Quick Installer
# 
# This is a simple wrapper that downloads and runs the minimal installer
# Usage: curl -L https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install-minimal.sh | sudo bash
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Hyper-NixOS Quick Installer${NC}"
echo "This will download and run the minimal installation process."
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    echo "Try: curl -L [...] | sudo bash"
    exit 1
fi

# Check if NixOS
if [[ ! -f /etc/NIXOS ]]; then
    echo -e "${RED}Error: This installer requires NixOS${NC}"
    echo "Please install NixOS first: https://nixos.org"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "Downloading Hyper-NixOS..."

# Try to clone with git first
if command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/MasterofNull/Hyper-NixOS.git
    cd Hyper-NixOS
else
    # Fallback to downloading tarball
    echo "Git not found, downloading archive..."
    curl -L https://github.com/MasterofNull/Hyper-NixOS/archive/main.tar.gz | tar xz
    cd Hyper-NixOS-main
fi

# Run the installer
echo
echo "Starting installation..."
bash ./install.sh

# Cleanup
cd /
rm -rf "$TEMP_DIR"