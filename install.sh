#!/usr/bin/env bash
# Hyper-NixOS Universal Installer
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License - see LICENSE file
#
# This installer uses:
# - Bash (GPL-3.0+, Free Software Foundation)
# - Git for repository operations (GPL-2.0)
# - curl/wget for downloads (MIT-like/GPL-3.0+)
# - tar for archive extraction
#
# For complete license information, see:
# - LICENSE - Hyper-NixOS license  
# - THIRD_PARTY_LICENSES.md - All dependencies
# - CREDITS.md - Attributions
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
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log directory and files
LOG_DIR="/var/log/hyper-nixos-installer"
ERROR_LOG="${LOG_DIR}/error.log"
INSTALL_LOG="${LOG_DIR}/install.log"
DEBUG_LOG="${LOG_DIR}/debug.log"

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR" 2>/dev/null || {
        # Fallback to temp directory if no permission
        LOG_DIR="/tmp/hyper-nixos-installer-$USER"
        ERROR_LOG="${LOG_DIR}/error.log"
        INSTALL_LOG="${LOG_DIR}/install.log"
        DEBUG_LOG="${LOG_DIR}/debug.log"
        mkdir -p "$LOG_DIR"
    }
    
    # Clear old logs
    > "$ERROR_LOG"
    > "$INSTALL_LOG"
    > "$DEBUG_LOG"
    
    # Log session start
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installation started" >> "$INSTALL_LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] User: $(whoami)" >> "$INSTALL_LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] System: $(uname -a)" >> "$INSTALL_LOG"
}

# Progress indicators with logging
print_status() { 
    echo -e "${BLUE}==>${NC} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS: $*" >> "$INSTALL_LOG" 2>/dev/null || true
}
print_success() { 
    echo -e "${GREEN}✓${NC} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*" >> "$INSTALL_LOG" 2>/dev/null || true
}
print_error() { 
    echo -e "${RED}✗${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$ERROR_LOG" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$INSTALL_LOG" 2>/dev/null || true
}
print_warning() { 
    echo -e "${YELLOW}⚠${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*" >> "$INSTALL_LOG" 2>/dev/null || true
}
print_info() { 
    echo -e "${CYAN}ℹ${NC} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$INSTALL_LOG" 2>/dev/null || true
}
print_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $*" >&2
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $*" >> "$DEBUG_LOG" 2>/dev/null || true
}

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

# Enhanced progress bar for downloads
show_progress_bar() {
    local current="$1"
    local total="$2"
    local prefix="${3:-Progress}"
    local width=50
    
    if [[ "$total" -eq 0 ]]; then
        total=1
    fi
    
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    # Color based on progress
    local color="$CYAN"
    if [[ $percent -ge 100 ]]; then
        color="$GREEN"
    elif [[ $percent -ge 75 ]]; then
        color="$BLUE"
    fi
    
    printf "\r${color}${prefix}:${NC} [%s] %3d%% " "$bar" "$percent"
}

# Progress indicator for multi-step operations
step_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    
    echo
    echo -e "${BOLD}Step $current/$total:${NC} $description"
    show_progress_bar "$current" "$total" "Overall Progress"
    echo
}

# Show error with context from log file
show_error_context() {
    local error_file="$1"
    local search_pattern="${2:-error}"
    local context_before="${3:-3}"
    local context_after="${4:-3}"
    
    if [[ ! -f "$error_file" ]]; then
        return
    fi
    
    echo >&2
    echo -e "${BOLD}${RED}Error Context from: ${error_file}${NC}" >&2
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}" >&2
    
    # Find error lines and show context
    grep -i -n -B"$context_before" -A"$context_after" "$search_pattern" "$error_file" 2>/dev/null | \
        head -n 20 | \
        while IFS= read -r line; do
            if [[ "$line" == "--" ]]; then
                echo -e "${BLUE}---${NC}" >&2
            elif [[ "$line" =~ ^([0-9]+):(.*)$ ]]; then
                local line_num="${BASH_REMATCH[1]}"
                local content="${BASH_REMATCH[2]}"
                if echo "$content" | grep -qi "$search_pattern"; then
                    echo -e "${RED}${line_num}:${NC}${BOLD} ${content}${NC}" >&2
                else
                    echo -e "${YELLOW}${line_num}:${NC} ${content}" >&2
                fi
            else
                echo -e "${YELLOW}${line}${NC}" >&2
            fi
        done
    
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}" >&2
    echo >&2
}

# Enhanced error reporting with context and log information
report_error() {
    local message="$1"
    local suggestion="${2:-}"
    local error_context_file="${3:-}"
    local context_lines="${4:-5}"
    
    # Log the error
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FATAL ERROR: $message" >> "$ERROR_LOG" 2>/dev/null || true
    
    echo >&2
    printf '%b╔══════════════════════════════════════════════════════════════╗%b\n' "$RED" "$NC" >&2
    printf '%b║                         ERROR                                ║%b\n' "$RED" "$NC" >&2
    printf '%b╠══════════════════════════════════════════════════════════════╣%b\n' "$RED" "$NC" >&2
    printf '%b║%b %-60s %b║%b\n' "$RED" "$NC" "$message" "$RED" "$NC" >&2
    
    if [[ -n "$suggestion" ]]; then
        printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
        printf '%b║%b %bSuggestion:%b %-48s %b║%b\n' "$RED" "$NC" "$YELLOW" "$NC" "$suggestion" "$RED" "$NC" >&2
    fi
    
    # Show error context if file provided
    if [[ -n "$error_context_file" && -f "$error_context_file" ]]; then
        printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
        printf '%b║%b %bError output (last %d lines):%b                            %b║%b\n' "$RED" "$NC" "$YELLOW" "$context_lines" "$NC" "$RED" "$NC" >&2
        printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
        
        while IFS= read -r line; do
            # Truncate long lines and display
            local display_line="${line:0:58}"
            printf '%b║%b  %s%b ║%b\n' "$RED" "$NC" "$display_line" "$RED" "$NC" >&2
        done < <(tail -n "$context_lines" "$error_context_file")
    fi
    
    # Show log file locations
    printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
    printf '%b║%b %bLog files:%b                                               %b║%b\n' "$RED" "$NC" "$CYAN" "$NC" "$RED" "$NC" >&2
    printf '%b║%b  Error log: %-47s %b║%b\n' "$RED" "$NC" "${ERROR_LOG:0:47}" "$RED" "$NC" >&2
    printf '%b║%b  Install log: %-45s %b║%b\n' "$RED" "$NC" "${INSTALL_LOG:0:45}" "$RED" "$NC" >&2
    printf '%b║%b  Debug log: %-47s %b║%b\n' "$RED" "$NC" "${DEBUG_LOG:0:47}" "$RED" "$NC" >&2
    
    printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
    printf '%b║%b View full logs with:                                       %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
    printf '%b║%b  cat %-52s %b║%b\n' "$RED" "$NC" "${ERROR_LOG:0:52}" "$RED" "$NC" >&2
    
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

# Prompt for download method
prompt_download_method() {
    # Check if running non-interactively (piped from curl, no TTY)
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        print_warning "Running in non-interactive mode, using default: Tarball Download (fastest)"
        echo -e "${CYAN}ℹ${NC} For interactive mode with more options, download and run: git clone && cd Hyper-NixOS && sudo ./install.sh" >&2
        echo "4"
        return 0
    fi
    
    echo
    print_line "═" 70
    center_text "Download Method Selection"
    print_line "═" 70
    echo
    print_info "Choose how to download Hyper-NixOS:"
    echo
    echo "  ${GREEN}1)${NC} Git Clone (HTTPS)    - Public access, no authentication"
    echo "  ${GREEN}2)${NC} Git Clone (SSH)      - Requires GitHub SSH key setup"
    echo "  ${GREEN}3)${NC} Git Clone (Token)    - Requires GitHub personal access token"
    echo "  ${GREEN}4)${NC} Download Tarball     - No git required, faster for one-time install"
    echo
    
    local choice
    local attempts=0
    local max_attempts=5
    
    while [[ $attempts -lt $max_attempts ]]; do
        # Use read with timeout to prevent hangs
        if read -t 30 -p "$(echo -e "${CYAN}Select method [1-4] (default: 1):${NC} ")" choice; then
            # Handle empty input (Enter pressed) - use default
            if [[ -z "$choice" ]]; then
                choice="1"
                echo -e "${CYAN}ℹ${NC} Using default option: Git Clone (HTTPS)" >&2
            fi
            
            case "$choice" in
                1|2|3|4)
                    echo "$choice"
                    return 0
                    ;;
                *)
                    attempts=$((attempts + 1))
                    print_error "Invalid choice. Please enter 1, 2, 3, or 4. (Attempt $attempts/$max_attempts)"
                    ;;
            esac
        else
            # Timeout or EOF reached
            print_warning "No input received (timeout or EOF). Using default: Git Clone (HTTPS)"
            echo "1"
            return 0
        fi
    done
    
    # Max attempts reached, use default
    print_warning "Maximum attempts reached. Using default: Git Clone (HTTPS)"
    echo "1"
    return 0
}

# Configure git credentials for HTTPS
configure_git_https() {
    local token="$1"
    
    if [[ -n "$token" ]]; then
        print_status "Configuring git with personal access token..."
        
        # Store token in git credential helper
        git config --global credential.helper store
        
        # Create credential file
        mkdir -p ~/.git-credentials
        echo "https://${token}@github.com" > ~/.git-credentials/github
        chmod 600 ~/.git-credentials/github
        
        print_success "Git credentials configured"
    fi
}

# Setup SSH for git if needed
setup_git_ssh() {
    # Check if running non-interactively
    if [[ ! -t 0 ]]; then
        print_error "SSH setup requires interactive terminal"
        return 1
    fi
    
    print_info "Checking SSH key for GitHub..."
    
    # Check if SSH key exists
    if [[ ! -f ~/.ssh/id_rsa && ! -f ~/.ssh/id_ed25519 ]]; then
        print_warning "No SSH key found."
        echo
        
        local generate_key
        if read -t 30 -p "$(echo -e "${CYAN}Generate new SSH key? [y/N]:${NC} ")" generate_key; then
            if [[ "${generate_key,,}" == "y" ]]; then
                print_status "Generating SSH key..."
                ssh-keygen -t ed25519 -C "hyper-nixos-installer" -f ~/.ssh/id_ed25519 -N ""
                print_success "SSH key generated: ~/.ssh/id_ed25519.pub"
                echo
                print_warning "You need to add this key to your GitHub account:"
                echo
                cat ~/.ssh/id_ed25519.pub
                echo
                read -t 60 -p "$(echo -e "${YELLOW}Press Enter after adding the key to GitHub...${NC}")" || {
                    print_error "Timeout waiting for confirmation"
                    return 1
                }
            else
                print_error "SSH key required for SSH clone method"
                return 1
            fi
        else
            print_error "Timeout or no input. SSH key required for SSH clone method"
            return 1
        fi
    fi
    
    # Test SSH connection
    print_status "Testing GitHub SSH connection..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "GitHub SSH authentication successful"
        return 0
    else
        print_error "GitHub SSH authentication failed"
        print_info "Please add your SSH key to GitHub: https://github.com/settings/keys"
        return 1
    fi
}

# Get GitHub personal access token
get_github_token() {
    # Check if running non-interactively
    if [[ ! -t 0 ]]; then
        print_error "Token input requires interactive terminal"
        return 1
    fi
    
    echo
    print_info "GitHub Personal Access Token is required for HTTPS authentication."
    print_info "Generate one at: https://github.com/settings/tokens"
    print_info "Required scopes: repo (full control of private repositories)"
    echo
    
    local token
    if read -t 60 -sp "$(echo -e "${CYAN}Enter GitHub token (input hidden):${NC} ")" token; then
        echo
        
        if [[ -z "$token" ]]; then
            print_error "No token provided"
            return 1
        fi
        
        echo "$token"
        return 0
    else
        echo
        print_error "Timeout or no input received"
        return 1
    fi
}

# Download via tarball with progress tracking
download_tarball() {
    local dest="$1"
    local branch="${2:-main}"
    
    print_status "Downloading tarball from GitHub..."
    print_debug "Tarball destination: $dest"
    print_debug "Branch: $branch"
    
    local tarball_url="https://github.com/MasterofNull/Hyper-NixOS/archive/refs/heads/${branch}.tar.gz"
    local tarball_file="${dest}/hyper-nixos.tar.gz"
    local error_output=$(mktemp)
    
    # Download with progress bar
    if command -v curl >/dev/null 2>&1; then
        print_debug "Using curl for download"
        
        if curl -L --progress-bar -o "$tarball_file" "$tarball_url" 2>&1 | \
           tee -a "$INSTALL_LOG" | \
           grep -oP '\d+\.\d' | \
           while read -r percent; do
               local pct=$(echo "$percent" | cut -d. -f1)
               show_progress_bar "$pct" 100 "Downloading"
           done
        then
            printf "\r\033[K"  # Clear line
            print_success "Tarball downloaded ($(du -h "$tarball_file" | cut -f1))"
        else
            printf "\r\033[K"
            print_error "Failed to download tarball"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Download failed from: $tarball_url" >> "$ERROR_LOG"
            report_error "Tarball download failed" \
                        "Check network connection or try git clone method" \
                        "$error_output"
            rm -f "$error_output"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        print_debug "Using wget for download"
        
        if wget --progress=bar:force -O "$tarball_file" "$tarball_url" 2>&1 | \
           tee -a "$INSTALL_LOG" | \
           grep -oP '\d+%' | tr -d '%' | \
           while read -r percent; do
               show_progress_bar "$percent" 100 "Downloading"
           done
        then
            printf "\r\033[K"
            print_success "Tarball downloaded ($(du -h "$tarball_file" | cut -f1))"
        else
            printf "\r\033[K"
            print_error "Failed to download tarball"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Download failed from: $tarball_url" >> "$ERROR_LOG"
            report_error "Tarball download failed" \
                        "Check network connection or try git clone method" \
                        "$error_output"
            rm -f "$error_output"
            return 1
        fi
    else
        print_error "Neither curl nor wget available"
        report_error "No download tool available" \
                    "Install curl or wget: nix-env -iA nixos.curl" \
                    "$ERROR_LOG"
        return 1
    fi
    
    rm -f "$error_output"
    
    print_status "Extracting tarball..."
    mkdir -p "${dest}/hyper-nixos"
    
    local extract_output=$(mktemp)
    if tar -xzf "$tarball_file" -C "${dest}/hyper-nixos" --strip-components=1 2>"$extract_output"; then
        print_success "Tarball extracted"
        rm -f "$tarball_file" "$extract_output"
        return 0
    else
        print_error "Failed to extract tarball"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Extraction failed" >> "$ERROR_LOG"
        cat "$extract_output" >> "$ERROR_LOG"
        report_error "Tarball extraction failed" \
                    "File may be corrupted, try download again" \
                    "$extract_output"
        rm -f "$extract_output"
        return 1
    fi
}

# Remote mode: Download repo and run installer
remote_install() {
    echo
    print_line "=" 70
    center_text "Hyper-NixOS Remote Installation"
    print_line "=" 70
    echo
    
    print_status "Starting remote installation..."
    
    # Create temporary directory
    local tmpdir
    tmpdir=$(mktemp -d -t hyper-nixos-install.XXXXXX)
    trap 'rm -rf "$tmpdir"' EXIT
    
    # Prompt for download method
    local download_method
    download_method=$(prompt_download_method)
    
    local repo_url
    local clone_output
    clone_output=$(mktemp)
    
    case "$download_method" in
        1)
            # HTTPS clone (public)
            print_status "Using HTTPS clone (public access)..."
            ensure_git
            repo_url="https://github.com/MasterofNull/Hyper-NixOS.git"
            
            if [[ -t 1 ]]; then
                # Terminal: show progress
                if git clone --progress "$repo_url" "$tmpdir/hyper-nixos" 2>&1 | \
                   tee "$clone_output" | \
                   grep --line-buffered -oP 'Receiving objects:\s+\K\d+(?=%)' | \
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
                    cat "$clone_output"
                    rm -f "$clone_output"
                    exit 1
                fi
            else
                # Non-terminal: quiet clone
                if ! git clone -q "$repo_url" "$tmpdir/hyper-nixos" 2>"$clone_output"; then
                    print_error "Failed to clone repository from $repo_url"
                    echo "Error details:"
                    cat "$clone_output"
                    rm -f "$clone_output"
                    exit 1
                fi
                print_success "Repository cloned successfully"
            fi
            ;;
            
        2)
            # SSH clone
            print_status "Using SSH clone (authenticated)..."
            ensure_git
            
            if ! setup_git_ssh; then
                print_error "SSH setup failed. Falling back to HTTPS..."
                repo_url="https://github.com/MasterofNull/Hyper-NixOS.git"
            else
                repo_url="git@github.com:MasterofNull/Hyper-NixOS.git"
            fi
            
            print_status "Cloning repository via SSH..."
            if git clone --progress "$repo_url" "$tmpdir/hyper-nixos" 2>&1 | \
               tee "$clone_output" | \
               grep --line-buffered -oP 'Receiving objects:\s+\K\d+(?=%)' | \
               while read -r percent; do
                   printf "\r${CYAN}→${NC} Cloning repository... ${GREEN}%3d%%${NC}" "$percent"
               done
            then
                printf "\r\033[K"
                print_success "Repository cloned successfully"
            else
                printf "\r\033[K"
                print_error "Failed to clone repository"
                cat "$clone_output"
                rm -f "$clone_output"
                exit 1
            fi
            ;;
            
        3)
            # HTTPS with token
            print_status "Using HTTPS clone with personal access token..."
            ensure_git
            
            local github_token
            if ! github_token=$(get_github_token); then
                print_error "Failed to get GitHub token"
                exit 1
            fi
            
            configure_git_https "$github_token"
            repo_url="https://github.com/MasterofNull/Hyper-NixOS.git"
            
            print_status "Cloning repository with token authentication..."
            if GIT_TERMINAL_PROMPT=0 git clone --progress "$repo_url" "$tmpdir/hyper-nixos" 2>&1 | \
               tee "$clone_output" | \
               grep --line-buffered -oP 'Receiving objects:\s+\K\d+(?=%)' | \
               while read -r percent; do
                   printf "\r${CYAN}→${NC} Cloning repository... ${GREEN}%3d%%${NC}" "$percent"
               done
            then
                printf "\r\033[K"
                print_success "Repository cloned successfully"
            else
                printf "\r\033[K"
                print_error "Failed to clone repository. Check your token permissions."
                cat "$clone_output"
                rm -f "$clone_output"
                exit 1
            fi
            ;;
            
        4)
            # Tarball download
            print_status "Using tarball download (no git required)..."
            
            if ! download_tarball "$tmpdir"; then
                print_error "Tarball download failed"
                exit 1
            fi
            ;;
            
        *)
            print_error "Invalid download method"
            exit 1
            ;;
    esac
    
    rm -f "$clone_output"
    
    cd "$tmpdir/hyper-nixos" || {
        print_error "Failed to enter repository directory"
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
    # Initialize logging system
    init_logging
    
    print_debug "Starting main execution"
    print_debug "Arguments: $*"
    
    # Check for root privileges
    check_root "$@"
    
    # Detect mode and run appropriate installer
    local mode
    mode=$(detect_mode)
    
    print_debug "Detected mode: $mode"
    
    case "$mode" in
        local)
            local_install "$@"
            ;;
        remote)
            remote_install "$@"
            ;;
        *)
            print_error "Could not determine installation mode"
            report_error "Installation mode detection failed" \
                        "Ensure script is run correctly" \
                        "$ERROR_LOG"
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
