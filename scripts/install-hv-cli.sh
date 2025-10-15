#!/usr/bin/env bash
# Install Hyper-NixOS Unified CLI
# Makes 'hv' command available system-wide

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${1:-/usr/local/bin}"

echo -e "${BOLD}Installing Hyper-NixOS Unified CLI...${NC}\n"

# Check if running as root for system-wide install
if [ "$INSTALL_DIR" = "/usr/local/bin" ] && [ $EUID -ne 0 ]; then
    echo -e "${YELLOW}System-wide installation requires root privileges${NC}"
    echo "Run: sudo $0"
    echo "Or install to user directory: $0 ~/.local/bin"
    exit 1
fi

# Create install directory if needed
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Creating $INSTALL_DIR...${NC}"
    mkdir -p "$INSTALL_DIR"
fi

# Check if directory is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo -e "${YELLOW}⚠ Warning: $INSTALL_DIR is not in PATH${NC}"
    echo "Add to your shell profile:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
fi

# Install main CLI
echo -e "Installing ${BOLD}hv${NC} command..."
if [ -L "$INSTALL_DIR/hv" ]; then
    rm "$INSTALL_DIR/hv"
fi
ln -s "$SCRIPT_DIR/hv" "$INSTALL_DIR/hv"
echo -e "${GREEN}✓${NC} hv -> $INSTALL_DIR/hv"

# Install discovery tool
echo -e "Installing ${BOLD}hv-intelligent-defaults${NC} command..."
if [ -L "$INSTALL_DIR/hv-intelligent-defaults" ]; then
    rm "$INSTALL_DIR/hv-intelligent-defaults"
fi
ln -s "$SCRIPT_DIR/hv-intelligent-defaults" "$INSTALL_DIR/hv-intelligent-defaults"
echo -e "${GREEN}✓${NC} hv-intelligent-defaults -> $INSTALL_DIR/hv-intelligent-defaults"

# Verify installation
echo ""
echo -e "${BOLD}Verifying installation...${NC}"

if command -v hv &> /dev/null; then
    echo -e "${GREEN}✓${NC} hv command available"
    echo ""
    hv version
else
    echo -e "${RED}✗${NC} hv command not found in PATH"
    echo "You may need to restart your shell or add $INSTALL_DIR to PATH"
fi

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo -e "${BOLD}Quick start:${NC}"
echo -e "  ${GREEN}hv help${NC}              Show all commands"
echo -e "  ${GREEN}hv discover${NC}          See system detection"
echo -e "  ${GREEN}hv defaults-demo${NC}     Interactive demo"
echo -e "  ${GREEN}hv vm-create${NC}         Create VM with intelligent defaults"
echo ""
