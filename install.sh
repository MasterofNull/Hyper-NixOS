#!/usr/bin/env bash
# Hyper-NixOS Universal Installer
# Copyright (C) 2024-2025 MasterofNull
# 
# This script works in two modes:
# 1. Local mode: Run from cloned repository
# 2. Remote mode: Piped from curl for quick installation
#
# Usage:
#   Local:  git clone <repo> && cd Hyper-NixOS && sudo ./install.sh
#   Remote: curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}==>${NC} $*"; }
print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_error() { echo -e "${RED}✗${NC} $*"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $*"; }

# Detect if we're running from a cloned repo or piped from curl
detect_mode() {
    if [[ -f "$(dirname "$0")/scripts/system_installer.sh" ]]; then
        echo "local"
    else
        echo "remote"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This installer must be run as root"
        echo "Please run: sudo $0 $*"
        exit 1
    fi
}

# Ensure git is available
ensure_git() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi
    
    print_status "Git not found, installing..."
    
    # Try to install git using nix
    if command -v nix >/dev/null 2>&1; then
        nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git 2>/dev/null || {
            print_warning "Could not install git via nix profile"
            # Try adding to PATH if already installed
            [[ -d ~/.nix-profile/bin ]] && export PATH="$HOME/.nix-profile/bin:$PATH"
            [[ -d /run/current-system/sw/bin ]] && export PATH="/run/current-system/sw/bin:$PATH"
        }
    fi
    
    # Check again
    if ! command -v git >/dev/null 2>&1; then
        print_error "Git is required but could not be installed automatically"
        echo "Please install git manually: nix-env -iA nixos.git"
        exit 1
    fi
    
    print_success "Git installed successfully"
}

# Remote mode: Clone repo and run installer
remote_install() {
    print_status "Starting Hyper-NixOS remote installation..."
    
    # Ensure git is available
    ensure_git
    
    # Create temporary directory
    local tmpdir
    tmpdir=$(mktemp -d -t hyper-nixos-install.XXXXXX)
    trap 'rm -rf "$tmpdir"' EXIT
    
    print_status "Cloning Hyper-NixOS repository..."
    
    # Clone the repository
    local repo_url="https://github.com/MasterofNull/Hyper-NixOS.git"
    if ! git clone "$repo_url" "$tmpdir/hyper-nixos" 2>/dev/null; then
        print_error "Failed to clone repository from $repo_url"
        exit 1
    fi
    
    print_success "Repository cloned successfully"
    
    cd "$tmpdir/hyper-nixos"
    
    # Run the system installer with optimal defaults
    print_status "Running Hyper-NixOS installer..."
    
    export NIX_CONFIG="experimental-features = nix-command flakes"
    
    exec bash ./scripts/system_installer.sh \
        --fast \
        --hostname "$(hostname -s)" \
        --action switch \
        --source "$tmpdir/hyper-nixos" \
        "$@"
}

# Local mode: Run installer from current directory
local_install() {
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    
    print_status "Starting Hyper-NixOS local installation..."
    print_status "Installation directory: $script_dir"
    
    # Verify we have the installer script
    if [[ ! -f "$script_dir/scripts/system_installer.sh" ]]; then
        print_error "Cannot find system_installer.sh"
        print_error "Please ensure you're running this from the Hyper-NixOS repository root"
        exit 1
    fi
    
    # Run the installer
    export NIX_CONFIG="experimental-features = nix-command flakes"
    
    exec bash "$script_dir/scripts/system_installer.sh" \
        --source "$script_dir" \
        "$@"
}

# Main execution
main() {
    # Check for root privileges
    check_root "$@"
    
    # Detect mode and run appropriate installer
    local mode
    mode=$(detect_mode)
    
    case "$mode" in
        local)
            local_install "$@"
            ;;
        remote)
            remote_install "$@"
            ;;
        *)
            print_error "Could not determine installation mode"
            exit 1
            ;;
    esac
}

# Handle being piped from curl
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
