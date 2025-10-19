#!/usr/bin/env bash
# Hyper-NixOS Channel Switcher
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Easy channel switching for NixOS updates

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLAKE_FILE="$REPO_ROOT/flake.nix"

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Hyper-NixOS Channel Switcher${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

show_current_channel() {
    echo -e "${BLUE}Current Channel:${NC}"
    grep "nixpkgs.url" "$FLAKE_FILE" | grep -v "^[[:space:]]*#" | sed 's/.*nixpkgs\///' | sed 's/".*$//' | sed 's/^/  /'
    echo ""
}

show_available_channels() {
    echo -e "${BLUE}Available Channels:${NC}"
    echo -e "  ${GREEN}1)${NC} nixos-unstable     ${YELLOW}(Bleeding edge, latest features)${NC}"
    echo -e "  ${GREEN}2)${NC} nixos-24.11        ${YELLOW}(Latest stable, recommended)${NC}"
    echo -e "  ${GREEN}3)${NC} nixos-24.05        ${YELLOW}(Previous stable, LTS support)${NC}"
    echo -e "  ${GREEN}4)${NC} Custom channel     ${YELLOW}(Advanced users)${NC}"
    echo ""
}

get_channel_url() {
    local channel=$1
    case "$channel" in
        unstable|1)
            echo "github:NixOS/nixpkgs/nixos-unstable"
            ;;
        24.11|2)
            echo "github:NixOS/nixpkgs/nixos-24.11"
            ;;
        24.05|3)
            echo "github:NixOS/nixpkgs/nixos-24.05"
            ;;
        *)
            echo "$channel"
            ;;
    esac
}

update_flake() {
    local new_channel=$1
    local channel_url
    channel_url=$(get_channel_url "$new_channel")

    echo -e "${YELLOW}Updating flake.nix to: $channel_url${NC}"

    # Backup current flake
    cp "$FLAKE_FILE" "$FLAKE_FILE.backup"

    # Update the nixpkgs.url line
    sed -i "s|nixpkgs.url = \"github:NixOS/nixpkgs/[^\"]*\";|nixpkgs.url = \"$channel_url\";|" "$FLAKE_FILE"

    echo -e "${GREEN}✓ Flake updated${NC}"
    echo ""
}

update_flake_lock() {
    echo -e "${YELLOW}Updating flake.lock...${NC}"

    cd "$REPO_ROOT"
    if nix flake update; then
        echo -e "${GREEN}✓ Flake lock updated${NC}"
    else
        echo -e "${RED}✗ Failed to update flake lock${NC}"
        echo -e "${YELLOW}Restoring backup...${NC}"
        mv "$FLAKE_FILE.backup" "$FLAKE_FILE"
        return 1
    fi
    echo ""
}

rebuild_system() {
    echo -e "${YELLOW}Would you like to rebuild the system now? (y/N)${NC}"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Rebuilding system with new channel...${NC}"
        echo -e "${YELLOW}This may take several minutes...${NC}"
        echo ""

        if sudo nixos-rebuild switch --flake "$REPO_ROOT"; then
            echo ""
            echo -e "${GREEN}✓ System successfully rebuilt with new channel!${NC}"
        else
            echo ""
            echo -e "${RED}✗ Rebuild failed${NC}"
            echo -e "${YELLOW}Your system is still on the old channel.${NC}"
            echo -e "${YELLOW}To rollback: sudo nixos-rebuild switch --rollback${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Skipping rebuild.${NC}"
        echo -e "${YELLOW}Run 'sudo nixos-rebuild switch' when ready.${NC}"
    fi
}

main() {
    print_header

    # Check if running with sudo (not recommended)
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}Warning: Don't run this script with sudo${NC}"
        echo -e "${YELLOW}Run as normal user; you'll be prompted for sudo when needed${NC}"
        exit 1
    fi

    show_current_channel
    show_available_channels

    echo -e "${BLUE}Select channel (1-4, or 'q' to quit):${NC} "
    read -r choice

    if [[ "$choice" == "q" ]] || [[ "$choice" == "Q" ]]; then
        echo "Exiting..."
        exit 0
    fi

    # Validate choice
    if [[ ! "$choice" =~ ^[1-4]$ ]] && [[ "$choice" != "unstable" ]] && [[ "$choice" != "24.11" ]] && [[ "$choice" != "24.05" ]]; then
        if [[ "$choice" == "4" ]]; then
            echo -e "${BLUE}Enter custom channel URL:${NC} "
            read -r custom_url
            choice="$custom_url"
        else
            echo -e "${RED}Invalid choice${NC}"
            exit 1
        fi
    fi

    update_flake "$choice" || exit 1
    update_flake_lock || exit 1
    rebuild_system || exit 1

    # Remove backup on success
    rm -f "$FLAKE_FILE.backup"

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Channel switch complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    print_header
    echo "Usage: $0 [CHANNEL]"
    echo ""
    echo "Switch NixOS channel for Hyper-NixOS"
    echo ""
    echo "Channels:"
    echo "  unstable, 1    - NixOS unstable (bleeding edge)"
    echo "  24.11, 2       - NixOS 24.11 (latest stable, recommended)"
    echo "  24.05, 3       - NixOS 24.05 (previous stable)"
    echo ""
    echo "Examples:"
    echo "  $0                # Interactive mode"
    echo "  $0 unstable       # Switch to unstable"
    echo "  $0 24.11          # Switch to 24.11 stable"
    echo ""
    echo "For advanced users:"
    echo "  Temporary override: nix build --override-input nixpkgs github:NixOS/nixpkgs/nixos-unstable"
    exit 0
fi

# Non-interactive mode
if [[ -n "${1:-}" ]]; then
    print_header
    show_current_channel
    update_flake "$1" || exit 1
    update_flake_lock || exit 1
    rebuild_system || exit 1
    rm -f "$FLAKE_FILE.backup"
else
    # Interactive mode
    main
fi
