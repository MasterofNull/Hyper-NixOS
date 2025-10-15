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

# Trap for cleanup on error
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo
        print_error "Installation failed with exit code: $exit_code"
        if [[ -n "${tmpdir:-}" && -d "${tmpdir:-}" ]]; then
            echo "Cleaning up temporary files..."
            rm -rf "$tmpdir"
        fi
    fi
    exit $exit_code
}
trap cleanup_on_error EXIT INT TERM

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Progress indicators
print_status() { echo -e "${BLUE}==>${NC} $*"; }
print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_error() { echo -e "${RED}✗${NC} $*" >&2; }
print_warning() { echo -e "${YELLOW}⚠${NC} $*" >&2; }
print_info() { echo -e "${CYAN}ℹ${NC} $*"; }

# Detect if we're running from a cloned repo or piped from curl
detect_mode() {
    # When piped from curl, $0 is "bash", so dirname won't work
    local script_dir="${BASH_SOURCE[0]:-}"
    if [[ -n "$script_dir" ]] && [[ -f "$(dirname "$script_dir")/scripts/system_installer.sh" ]]; then
        echo "local"
    else
        echo "remote"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        report_error "This installer must be run as root" \
                     "Run: sudo $0 $*"
        exit 1
    fi
}

# Simple spinner for operations
spinner_pid=""
start_spinner() {
    local message="$1"
    if [[ -t 1 ]]; then
        (
            local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            local i=0
            while true; do
                printf "\r${CYAN}%s${NC} %s" "${spin:$i:1}" "$message"
                i=$(( (i + 1) % 10 ))
                sleep 0.1
            done
        ) &
        spinner_pid=$!
    else
        print_status "$message"
    fi
}

stop_spinner() {
    local status="${1:-success}"
    local message="${2:-}"
    
    if [[ -n "$spinner_pid" ]]; then
        kill "$spinner_pid" 2>/dev/null || true
        wait "$spinner_pid" 2>/dev/null || true
        spinner_pid=""
        printf "\r\033[K"  # Clear line
    fi
    
    if [[ -n "$message" ]]; then
        case "$status" in
            success) print_success "$message" ;;
            error)   print_error "$message" ;;
            warning) print_warning "$message" ;;
            *)       print_info "$message" ;;
        esac
    fi
}

# Helper functions
print_line() {
    local char="${1:-═}"
    local width="${2:-70}"
    printf '%b' "$BLUE"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf '%b\n' "$NC"
}

center_text() {
    local text="$1"
    local width="${2:-70}"
    local padding=$(( (width - ${#text}) / 2 ))
    printf '%*s%s\n' $padding '' "$text"
}

# Error reporting with context
report_error() {
    local message="$1"
    local suggestion="${2:-}"
    local error_log="${3:-}"
    
    echo >&2
    printf '%b╔══════════════════════════════════════════════════════════════╗%b\n' "$RED" "$NC" >&2
    printf '%b║                         ERROR                                ║%b\n' "$RED" "$NC" >&2
    printf '%b╠══════════════════════════════════════════════════════════════╣%b\n' "$RED" "$NC" >&2
    printf '%b║%b %-60s %b║%b\n' "$RED" "$NC" "$message" "$RED" "$NC" >&2
    
    if [[ -n "$suggestion" ]]; then
        printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
        printf '%b║%b %bSuggestion:%b %-48s %b║%b\n' "$RED" "$NC" "$YELLOW" "$NC" "$suggestion" "$RED" "$NC" >&2
    fi
    
    if [[ -n "$error_log" && -f "$error_log" ]]; then
        printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
        printf '%b║%b Recent error output:                                       %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
        while IFS= read -r line; do
            printf '%b║%b %-60s %b║%b\n' "$RED" "$NC" "${line:0:60}" "$RED" "$NC" >&2
        done < <(tail -n 5 "$error_log")
    fi
    
    printf '%b╚══════════════════════════════════════════════════════════════╝%b\n' "$RED" "$NC" >&2
    echo >&2
}

# Ensure git is available
ensure_git() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi
    
    start_spinner "Installing git..."
    
    # Try to install git using nix
    local install_output
    if command -v nix >/dev/null 2>&1; then
        install_output=$(nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git 2>&1) || {
            stop_spinner warning "Could not install git via nix profile"
            # Try adding to PATH if already installed
            [[ -d ~/.nix-profile/bin ]] && export PATH="$HOME/.nix-profile/bin:$PATH"
            [[ -d /run/current-system/sw/bin ]] && export PATH="/run/current-system/sw/bin:$PATH"
        }
    fi
    
    # Check again
    if ! command -v git >/dev/null 2>&1; then
        stop_spinner error "Git installation failed"
        print_error "Git is required but could not be installed automatically"
        echo "Please install git manually: nix-env -iA nixos.git"
        if [[ -n "${install_output:-}" ]]; then
            echo
            echo "Error output:"
            echo "$install_output" | tail -n 10
        fi
        exit 1
    fi
    
    stop_spinner success "Git installed successfully"
}

# Remote mode: Clone repo and run installer
remote_install() {
    echo
    print_line "=" 70
    center_text "Hyper-NixOS Remote Installation"
    print_line "=" 70
    echo
    
    print_status "Starting remote installation..."
    
    # Ensure git is available
    ensure_git
    
    # Create temporary directory
    local tmpdir
    tmpdir=$(mktemp -d -t hyper-nixos-install.XXXXXX)
    trap 'rm -rf "$tmpdir"' EXIT
    
    print_status "Cloning Hyper-NixOS repository..."
    
    # Clone the repository with progress
    local repo_url="https://github.com/MasterofNull/Hyper-NixOS.git"
    local clone_output
    clone_output=$(mktemp)
    
    if [[ -t 1 ]]; then
        # Terminal: show progress
        if git clone --progress "$repo_url" "$tmpdir/hyper-nixos" 2>&1 | \
           tee "$clone_output" | \
           grep --line-buffered -oP '(?<=Receiving objects:\s+)\d+(?=%)' | \
           while read -r percent; do
               printf "\r${CYAN}→${NC} Cloning repository... ${GREEN}%3d%%${NC}" "$percent"
           done
        then
            printf "\r\033[K"  # Clear line
            print_success "Repository cloned successfully"
        else
            printf "\r\033[K"
            print_error "Failed to clone repository from $repo_url"
            echo
            echo "Error details:"
            tail -n 10 "$clone_output"
            rm -f "$clone_output"
            exit 1
        fi
    else
        # Non-terminal: quiet clone with error handling
        if ! git clone -q "$repo_url" "$tmpdir/hyper-nixos" 2>"$clone_output"; then
            print_error "Failed to clone repository from $repo_url"
            echo "Error details:"
            cat "$clone_output"
            rm -f "$clone_output"
            exit 1
        fi
        print_success "Repository cloned successfully"
    fi
    
    rm -f "$clone_output"
    
    cd "$tmpdir/hyper-nixos" || {
        print_error "Failed to enter cloned repository directory"
        exit 1
    }
    
    # Run the system installer with optimal defaults
    echo
    print_status "Launching Hyper-NixOS installer..."
    echo
    
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
    # Use BASH_SOURCE if available, fallback to current directory
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        script_dir="$(pwd)"
    fi
    
    echo
    print_line "=" 70
    center_text "Hyper-NixOS Local Installation"
    print_line "=" 70
    echo
    
    print_status "Starting local installation..."
    print_info "Installation directory: $script_dir"
    
    # Verify we have the installer script
    print_status "Verifying installation files..."
    
    local missing_files=()
    local required_files=(
        "scripts/system_installer.sh"
        "configuration.nix"
        "flake.nix"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$script_dir/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        report_error "Missing required files" \
                     "Ensure you're in the Hyper-NixOS repository root"
        echo "Missing files:" >&2
        for file in "${missing_files[@]}"; do
            echo "  - $file" >&2
        done
        exit 1
    fi
    
    print_success "All required files present"
    
    # Run the installer
    echo
    print_status "Launching Hyper-NixOS installer..."
    echo
    
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

# Handle being piped from curl or executed directly
# When piped: BASH_SOURCE is empty; when executed: BASH_SOURCE[0] == $0
# Only skip main if being sourced (BASH_SOURCE[0] != $0)
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
