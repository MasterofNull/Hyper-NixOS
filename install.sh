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
        echo -e "${RED}✗ Installation failed${NC}"
        echo
        case $exit_code in
            1)   echo -e "${YELLOW}Reason:${NC} General error - check error messages above" ;;
            2)   echo -e "${YELLOW}Reason:${NC} Invalid arguments or configuration" ;;
            126) echo -e "${YELLOW}Reason:${NC} Permission denied - ensure you're running with sudo" ;;
            127) echo -e "${YELLOW}Reason:${NC} Command not found - this may indicate a script loading issue" ;;
            130) echo -e "${YELLOW}Reason:${NC} Script interrupted by user (Ctrl+C)" ;;
            *)   echo -e "${YELLOW}Reason:${NC} Unknown error (exit code: $exit_code)" ;;
        esac
        echo
        if [[ -n "${ERROR_LOG:-}" && -f "${ERROR_LOG:-}" ]]; then
            echo -e "${CYAN}For detailed error information, check:${NC}"
            echo -e "  ${ERROR_LOG}"
            echo
        fi
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

# State file for resume capability
STATE_FILE="/tmp/hyper-nixos-install-state"

# Error codes for better debugging
ERROR_NO_NETWORK=10
ERROR_DISK_SPACE=11
ERROR_DOWNLOAD_FAILED=12
ERROR_EXTRACTION_FAILED=13
ERROR_VERIFICATION_FAILED=14
ERROR_MISSING_DEPS=15
ERROR_USER_CANCELLED=16

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

# Enhanced error reporting with contextual help
print_error_with_help() {
    local error_code=$1
    shift
    local message="$*"
    
    print_error "$message (Error code: $error_code)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR_CODE: $error_code" >> "$ERROR_LOG" 2>/dev/null || true
    
    case $error_code in
        $ERROR_NO_NETWORK)
            echo "  ${YELLOW}→${NC} Troubleshooting steps:" >&2
            echo "    • Check network connection: ping github.com" >&2
            echo "    • Check firewall/proxy settings" >&2
            echo "    • Try using mobile hotspot temporarily" >&2
            ;;
        $ERROR_DISK_SPACE)
            echo "  ${YELLOW}→${NC} Troubleshooting steps:" >&2
            echo "    • Free up space: nix-collect-garbage -d" >&2
            echo "    • Or specify different temp dir: TMPDIR=/other/path" >&2
            echo "    • Check disk usage: df -h /tmp" >&2
            ;;
        $ERROR_DOWNLOAD_FAILED)
            echo "  ${YELLOW}→${NC} Troubleshooting steps:" >&2
            echo "    • Try alternative download method from menu" >&2
            echo "    • Check GitHub status: https://www.githubstatus.com" >&2
            echo "    • Retry the installation (automatic retry enabled)" >&2
            ;;
        $ERROR_EXTRACTION_FAILED)
            echo "  ${YELLOW}→${NC} Troubleshooting steps:" >&2
            echo "    • File may be corrupted, will retry download" >&2
            echo "    • Check disk space: df -h /tmp" >&2
            ;;
        $ERROR_VERIFICATION_FAILED)
            echo "  ${YELLOW}→${NC} Troubleshooting steps:" >&2
            echo "    • Download may be corrupted or tampered" >&2
            echo "    • Will retry download automatically" >&2
            echo "    • Check network stability" >&2
            ;;
        $ERROR_MISSING_DEPS)
            echo "  ${YELLOW}→${NC} Troubleshooting steps:" >&2
            echo "    • Install missing tools via: nix-env -iA nixos.<tool>" >&2
            echo "    • Or use NixOS live environment" >&2
            ;;
    esac
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
        echo -e "${RED}✗ This installer must be run as root${NC}" >&2
        echo >&2
        echo -e "${CYAN}Please run with sudo:${NC}" >&2
        echo -e "  sudo bash <(curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh)" >&2
        echo -e "${YELLOW}Or for local installation:${NC}" >&2
        echo -e "  sudo ./install.sh" >&2
        echo >&2
        exit 126
    fi
}

# State management for resume capability
save_state() {
    local state="$1"
    echo "$state:$(date +%s):$$" > "$STATE_FILE"
    print_debug "State saved: $state"
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        local state=$(cut -d: -f1 "$STATE_FILE")
        local timestamp=$(cut -d: -f2 "$STATE_FILE")
        local age=$(( $(date +%s) - timestamp ))
        
        # Only resume if state is less than 1 hour old
        if [[ $age -lt 3600 ]]; then
            echo "$state"
            return 0
        else
            print_debug "State file too old (${age}s), ignoring"
        fi
    fi
    echo ""
}

clear_state() {
    rm -f "$STATE_FILE"
    print_debug "State file cleared"
}

# Pre-flight system checks
preflight_checks() {
    echo >&2
    print_status "Running pre-flight system checks..." >&2
    local failed=false
    local warnings=0
    
    # Check disk space (need ~2GB for download + install)
    print_debug "Checking disk space in /tmp"
    if command -v df >/dev/null 2>&1; then
        local available_space=$(df /tmp --output=avail 2>/dev/null | tail -1)
        if [[ -n "$available_space" && $available_space -lt 2097152 ]]; then  # 2GB in KB
            print_error_with_help $ERROR_DISK_SPACE \
                "Insufficient disk space in /tmp: $(( available_space / 1024 ))MB available, 2GB required"
            failed=true
        else
            local space_gb=$(( available_space / 1024 / 1024 ))
            print_success "Disk space: ${space_gb}GB available in /tmp" >&2
        fi
    else
        print_warning "Cannot check disk space (df not available)" >&2
        warnings=$((warnings + 1))
    fi
    
    # Check internet connectivity
    print_debug "Checking internet connectivity"
    local connectivity_ok=false
    if ping -c 1 -W 2 github.com >/dev/null 2>&1; then
        print_success "Internet connectivity: GitHub reachable" >&2
        connectivity_ok=true
    elif ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        print_success "Internet connectivity: OK (DNS may have issues)" >&2
        connectivity_ok=true
    fi
    
    if ! $connectivity_ok; then
        print_error_with_help $ERROR_NO_NETWORK \
            "No internet connectivity detected"
        failed=true
    fi
    
    # Check for required tools
    print_debug "Checking required tools"
    local required_tools=("tar" "bash")
    local missing_tools=()
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error_with_help $ERROR_MISSING_DEPS \
            "Required tools missing: ${missing_tools[*]}"
        failed=true
    else
        print_success "Required tools: All present (tar, bash)" >&2
    fi
    
    # Check for recommended tools
    local recommended_tools=("curl" "wget" "git")
    local missing_recommended=()
    for tool in "${recommended_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_recommended+=("$tool")
        fi
    done
    
    if [[ ${#missing_recommended[@]} -gt 0 ]]; then
        print_warning "Some recommended tools missing: ${missing_recommended[*]}" >&2
        warnings=$((warnings + 1))
    else
        print_success "Recommended tools: All present (curl, wget, git)" >&2
    fi
    
    # Summary
    echo >&2
    if [[ "$failed" == "true" ]]; then
        print_error "Pre-flight checks failed. Please resolve critical issues before continuing." >&2
        return 1
    elif [[ $warnings -gt 0 ]]; then
        print_warning "Pre-flight checks completed with $warnings warning(s)" >&2
        return 0
    else
        print_success "All pre-flight checks passed" >&2
        return 0
    fi
}

# Interactive confirmation before installation
confirm_installation() {
    local method_name="$1"
    local install_location="${2:-/etc/nixos}"
    
    echo >&2
    print_line "=" 70 >&2
    center_text "Installation Confirmation" >&2
    print_line "=" 70 >&2
    echo >&2
    echo -e "  ${BOLD}Download method:${NC} $method_name" >&2
    echo -e "  ${BOLD}Install location:${NC} $install_location" >&2
    echo -e "  ${BOLD}Estimated time:${NC} ~5-10 minutes" >&2
    echo -e "  ${BOLD}Disk space needed:${NC} ~2GB" >&2
    echo -e "  ${BOLD}Log directory:${NC} $LOG_DIR" >&2
    echo >&2
    
    # Only prompt if interactive
    if [[ -t 0 ]]; then
        read -t 60 -p "$(echo -e "${CYAN}Continue with installation? [Y/n]:${NC} ")" -r choice
        echo >&2
        if [[ -z "$choice" ]] || [[ "$choice" =~ ^[Yy]$ ]]; then
            return 0
        else
            print_info "Installation cancelled by user" >&2
            return 1
        fi
    fi
    
    return 0
}

# Show installation summary at completion
show_install_summary() {
    local download_method="$1"
    local install_location="${2:-/etc/nixos}"
    
    echo >&2
    print_line "=" 70 >&2
    center_text "Installation Complete" >&2
    print_line "=" 70 >&2
    echo >&2
    echo -e "  ${GREEN}✓${NC} Repository source: $download_method" >&2
    echo -e "  ${GREEN}✓${NC} Installed to: $install_location" >&2
    echo -e "  ${GREEN}✓${NC} Configuration: ${install_location}/configuration.nix" >&2
    echo -e "  ${GREEN}✓${NC} Logs saved to: $LOG_DIR" >&2
    echo >&2
    echo -e "  ${BOLD}Next steps:${NC}" >&2
    echo -e "    ${CYAN}1.${NC} Review logs: less $INSTALL_LOG" >&2
    echo -e "    ${CYAN}2.${NC} Reboot system: sudo reboot" >&2
    echo -e "    ${CYAN}3.${NC} Access menu after reboot via SSH/console" >&2
    echo -e "    ${CYAN}4.${NC} Create your first VM: hv vm-create" >&2
    echo >&2
    print_line "=" 70 >&2
    echo >&2
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
        echo
        echo -e "${CYAN}To install git manually:${NC}"
        echo "  nix-env -iA nixos.git"
        echo "  # or"
        echo "  nix profile install nixpkgs#git"
        if [[ -n "${install_output:-}" ]]; then
            echo
            echo "Error output:"
            echo "$install_output" | tail -n 10
        fi
        echo
        echo -e "${YELLOW}After installing git, run this script again.${NC}"
        exit 1
    fi
    
    stop_spinner success "Git installed successfully"
}

# Prompt for download method
prompt_download_method() {
    # Allow override via environment variable
    if [[ -n "${HYPER_INSTALL_METHOD:-}" ]]; then
        case "${HYPER_INSTALL_METHOD}" in
            https|1) echo "1"; return 0 ;;
            ssh|2) echo "2"; return 0 ;;
            token|3) echo "3"; return 0 ;;
            tarball|4) echo "4"; return 0 ;;
            *)
                print_warning "Invalid HYPER_INSTALL_METHOD: ${HYPER_INSTALL_METHOD}"
                print_warning "Valid options: https, ssh, token, tarball"
                ;;
        esac
    fi
    
    # Check if we can prompt user (try /dev/tty for piped scenarios)
    local input_source="/dev/stdin"
    if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
        # stdin not available but /dev/tty exists - use it for piped scenarios
        input_source="/dev/tty"
        print_info "Running in piped mode, but interactive input available via terminal"
    elif [[ ! -t 0 ]]; then
        # No terminal available at all - use default
        print_warning "Running in non-interactive mode (no terminal), using default: Git Clone HTTPS"
        echo -e "${CYAN}ℹ${NC} To choose a different method:" >&2
        echo -e "${CYAN}ℹ${NC}   Set environment: HYPER_INSTALL_METHOD=tarball curl ... | sudo -E bash" >&2
        echo -e "${CYAN}ℹ${NC}   Or download and run: git clone && cd Hyper-NixOS && sudo ./install.sh" >&2
        echo "1"  # Default to git HTTPS (more reliable than tarball)
        return 0
    fi
    
    echo >&2
    print_line "═" 70 >&2
    center_text "Download Method Selection" >&2
    print_line "═" 70 >&2
    echo >&2
    print_info "Choose how to download Hyper-NixOS:"
    echo >&2
    echo -e "  ${GREEN}1)${NC} Git Clone (HTTPS)    - Public access, no authentication" >&2
    echo -e "  ${GREEN}2)${NC} Git Clone (SSH)      - Requires GitHub SSH key setup" >&2
    echo -e "  ${GREEN}3)${NC} Git Clone (Token)    - Requires GitHub personal access token" >&2
    echo -e "  ${GREEN}4)${NC} Download Tarball     - No git required, faster for one-time install" >&2
    echo >&2
    
    local choice
    local attempts=0
    local max_attempts=5
    
    while [[ $attempts -lt $max_attempts ]]; do
        # Use read with timeout to prevent hangs, reading from appropriate source
        if read -t 50 -p "$(echo -e "${CYAN}Select method [1-4] (default: 4):${NC} ")" choice <"$input_source"; then
            # Handle empty input (Enter pressed) - use default
            if [[ -z "$choice" ]]; then
                choice="4"
                echo -e "${CYAN}ℹ${NC} Using default option: Download Tarball" >&2
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
            print_warning "No input received (timeout or EOF). Using default: Download Tarball"
            echo "4"
            return 0
        fi
    done
    
    # Max attempts reached, use default
    print_warning "Maximum attempts reached. Using default: Download Tarball"
    echo "4"
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
                echo -e "${CYAN}=== Copy this key ===${NC}"
                cat ~/.ssh/id_ed25519.pub
                echo -e "${CYAN}=====================${NC}"
                echo
                echo -e "${YELLOW}Steps:${NC}"
                echo "  1. Go to: https://github.com/settings/ssh/new"
                echo "  2. Paste the key above"
                echo "  3. Click 'Add SSH key'"
                echo
                read -t 60 -p "$(echo -e "${YELLOW}Press Enter after adding the key to GitHub...${NC}")" || {
                    print_error "Timeout waiting for confirmation"
                    echo -e "${CYAN}Tip:${NC} Re-run installer and select option 1 (HTTPS) for simpler setup"
                    return 1
                }
            else
                print_error "SSH key required for SSH clone method"
                echo -e "${CYAN}Tip:${NC} Use option 1 (HTTPS) instead - no SSH key needed"
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
# Download with retry logic and exponential backoff
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1
    local wait_time=5
    local download_tool=""
    local start_time=$(date +%s)
    
    # Determine which tool to use
    if command -v curl >/dev/null 2>&1; then
        download_tool="curl"
    elif command -v wget >/dev/null 2>&1; then
        download_tool="wget"
    else
        print_error_with_help $ERROR_MISSING_DEPS "Neither curl nor wget available"
        return 1
    fi
    
    while [[ $attempt -le $max_attempts ]]; do
        print_debug "Download attempt $attempt/$max_attempts using $download_tool"
        if [[ $attempt -gt 1 ]]; then
            print_info "Retry attempt $attempt/$max_attempts..." >&2
        fi
        
        local success=false
        if [[ "$download_tool" == "curl" ]]; then
            if curl -L --fail --progress-bar -o "$output" "$url" 2>&1 | \
               tee -a "$INSTALL_LOG" | \
               grep -oP '\d+\.\d' | \
               while read -r percent; do
                   local pct=$(echo "$percent" | cut -d. -f1)
                   show_progress_bar "$pct" 100 "Downloading"
               done
            then
                printf "\r\033[K"
                success=true
            fi
        else
            if wget --progress=bar:force -O "$output" "$url" 2>&1 | \
               tee -a "$INSTALL_LOG" | \
               grep -oP '\d+%' | tr -d '%' | \
               while read -r percent; do
                   show_progress_bar "$percent" 100 "Downloading"
               done
            then
                printf "\r\033[K"
                success=true
            fi
        fi
        
        if $success; then
            local elapsed=$(($(date +%s) - start_time))
            print_debug "Download successful on attempt $attempt (${elapsed}s elapsed)"
            return 0
        else
            printf "\r\033[K"
            if [[ $attempt -lt $max_attempts ]]; then
                print_warning "Download failed, retrying in ${wait_time}s... (attempt $attempt/$max_attempts)" >&2
                sleep $wait_time
                wait_time=$((wait_time * 2))  # Exponential backoff
            fi
        fi
        attempt=$((attempt + 1))
    done
    
    print_error_with_help $ERROR_DOWNLOAD_FAILED "Download failed after $max_attempts attempts"
    return 1
}

# Verify tarball integrity
verify_tarball() {
    local tarball_file="$1"
    
    print_status "Verifying download integrity..." >&2
    
    # Check if file exists and is not empty
    if [[ ! -f "$tarball_file" ]] || [[ ! -s "$tarball_file" ]]; then
        print_error_with_help $ERROR_VERIFICATION_FAILED "Tarball file is missing or empty"
        return 1
    fi
    
    # Verify it's a valid gzip file
    if ! gzip -t "$tarball_file" 2>/dev/null; then
        print_error_with_help $ERROR_VERIFICATION_FAILED "Tarball file is not a valid gzip archive"
        return 1
    fi
    
    # Compute checksum if sha256sum available
    if command -v sha256sum >/dev/null 2>&1; then
        local checksum=$(sha256sum "$tarball_file" | cut -d' ' -f1)
        print_debug "Tarball SHA256: $checksum"
        print_success "Download verified (SHA256: ${checksum:0:16}...)" >&2
    else
        print_success "Download verified (valid gzip archive)" >&2
    fi
    
    return 0
}

download_tarball() {
    local dest="$1"
    local branch="${2:-main}"
    local max_download_attempts=2
    local download_attempt=1
    
    print_status "Downloading tarball from GitHub..." >&2
    print_debug "Tarball destination: $dest"
    print_debug "Branch: $branch"
    
    local tarball_url="https://github.com/MasterofNull/Hyper-NixOS/archive/refs/heads/${branch}.tar.gz"
    local tarball_file="${dest}/hyper-nixos.tar.gz"
    
    # Try download with verification
    while [[ $download_attempt -le $max_download_attempts ]]; do
        if [[ $download_attempt -gt 1 ]]; then
            print_warning "Retrying download (attempt $download_attempt/$max_download_attempts)..." >&2
            rm -f "$tarball_file"
        fi
        
        # Download with built-in retry logic
        if download_with_retry "$tarball_url" "$tarball_file"; then
            local file_size=$(du -h "$tarball_file" | cut -f1)
            print_success "Tarball downloaded ($file_size)" >&2
            
            # Verify integrity
            if verify_tarball "$tarball_file"; then
                break
            else
                # Verification failed, retry if attempts remain
                if [[ $download_attempt -lt $max_download_attempts ]]; then
                    print_warning "Verification failed, will retry download..." >&2
                else
                    print_error_with_help $ERROR_VERIFICATION_FAILED "Download verification failed after $max_download_attempts attempts"
                    return 1
                fi
            fi
        else
            # Download failed
            if [[ $download_attempt -ge $max_download_attempts ]]; then
                return 1
            fi
        fi
        
        download_attempt=$((download_attempt + 1))
    done
    
    # Extract tarball
    print_status "Extracting tarball..." >&2
    mkdir -p "${dest}/hyper-nixos"
    
    local extract_output=$(mktemp)
    local max_extract_attempts=2
    local extract_attempt=1
    
    while [[ $extract_attempt -le $max_extract_attempts ]]; do
        if tar -xzf "$tarball_file" -C "${dest}/hyper-nixos" --strip-components=1 2>"$extract_output"; then
            print_success "Tarball extracted successfully" >&2
            rm -f "$tarball_file" "$extract_output"
            return 0
        else
            if [[ $extract_attempt -lt $max_extract_attempts ]]; then
                print_warning "Extraction failed, retrying... (attempt $extract_attempt/$max_extract_attempts)" >&2
                rm -rf "${dest}/hyper-nixos"
                mkdir -p "${dest}/hyper-nixos"
            else
                print_error_with_help $ERROR_EXTRACTION_FAILED "Failed to extract tarball after $max_extract_attempts attempts"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Extraction failed" >> "$ERROR_LOG"
                cat "$extract_output" >> "$ERROR_LOG"
                rm -f "$extract_output"
                return 1
            fi
        fi
        extract_attempt=$((extract_attempt + 1))
    done
    
    return 1
}

# Try a download method with optional fallback
try_download_method() {
    local method="$1"
    local tmpdir="$2"
    local method_name=""
    
    case "$method" in
        1) method_name="Git Clone (HTTPS)" ;;
        2) method_name="Git Clone (SSH)" ;;
        3) method_name="Git Clone (Token)" ;;
        4) method_name="Download Tarball" ;;
        *) return 1 ;;
    esac
    
    print_info "Trying method: $method_name" >&2
    save_state "downloading_${method}"
    
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
                    print_error "Failed to clone repository from GitHub"
                    echo
                    echo -e "${YELLOW}Attempted URL:${NC} $repo_url"
                    echo
                    echo -e "${CYAN}Error details:${NC}"
                    cat "$clone_output"
                    echo
                    echo -e "${CYAN}Possible solutions:${NC}"
                    echo "  1. Check your internet connection"
                    echo "  2. Verify GitHub is accessible: ping github.com"
                    echo "  3. Try a different download method (tarball is most reliable)"
                    echo "  4. Check if a firewall is blocking git:// or https:// protocols"
                    echo
                    rm -f "$clone_output"
                    exit 1
                fi
            else
                # Non-terminal: quiet clone
                if ! git clone -q "$repo_url" "$tmpdir/hyper-nixos" 2>"$clone_output"; then
                    print_error "Failed to clone repository from GitHub"
                    echo
                    echo -e "${YELLOW}Attempted URL:${NC} $repo_url"
                    echo
                    echo -e "${CYAN}Error details:${NC}"
                    cat "$clone_output"
                    echo
                    echo -e "${CYAN}Possible solutions:${NC}"
                    echo "  1. Check your internet connection"
                    echo "  2. Verify GitHub is accessible: ping github.com"
                    echo "  3. Try a different download method (tarball is most reliable)"
                    echo
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
                print_error "SSH setup failed"
                echo
                echo -e "${YELLOW}Automatically falling back to HTTPS (public access)...${NC}"
                echo -e "${CYAN}Note:${NC} HTTPS doesn't require SSH keys"
                echo
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
                echo
                echo -e "${CYAN}Token is required for private repository access${NC}"
                echo -e "${CYAN}For public repositories, use option 1 (HTTPS) instead${NC}"
                echo
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
                print_error "Failed to clone repository with token authentication"
                echo
                echo -e "${CYAN}Error details:${NC}"
                cat "$clone_output"
                echo
                echo -e "${YELLOW}Common causes:${NC}"
                echo "  1. Invalid or expired GitHub personal access token"
                echo "  2. Token doesn't have 'repo' scope permissions"
                echo "  3. Repository is private and token doesn't have access"
                echo
                echo -e "${CYAN}To fix:${NC}"
                echo "  1. Generate a new token at: https://github.com/settings/tokens"
                echo "  2. Ensure 'repo' scope is selected"
                echo "  3. Or use option 1 (HTTPS without token) for public access"
                echo
                rm -f "$clone_output"
                exit 1
            fi
            ;;
            
        4)
            # Tarball download
            print_status "Using tarball download (no git required)..."
            
            if ! download_tarball "$tmpdir"; then
                print_error "Tarball download failed"
                echo
                echo -e "${CYAN}Alternative methods:${NC}"
                echo "  1. Try git clone: choose option 1 when re-running installer"
                echo "  2. Manual download:"
                echo "     wget https://github.com/MasterofNull/Hyper-NixOS/archive/refs/heads/main.tar.gz"
                echo "     tar xzf main.tar.gz"
                echo "     cd Hyper-NixOS-main"
                echo "     sudo ./install.sh"
                echo
                exit 1
            fi
            ;;
            
        *)
            print_error "Invalid download method selected"
            echo
            echo -e "${YELLOW}Expected: 1, 2, 3, or 4${NC}"
            echo -e "${YELLOW}Received: $download_method${NC}"
            echo
            echo "This is likely a bug in the installer script."
            echo "Please report this at: https://github.com/MasterofNull/Hyper-NixOS/issues"
            echo
            exit 1
            ;;
    esac
    
    rm -f "$clone_output"
    
    cd "$tmpdir/hyper-nixos" || {
        print_error "Failed to enter repository directory"
        echo
        echo -e "${YELLOW}Expected directory:${NC} $tmpdir/hyper-nixos"
        echo
        echo "This could mean:"
        echo "  1. Download/extraction failed silently"
        echo "  2. Disk space issue prevented directory creation"
        echo "  3. Permission issue with temporary directory"
        echo
        echo -e "${CYAN}Try:${NC}"
        echo "  1. Check available disk space: df -h"
        echo "  2. Check /tmp permissions: ls -ld /tmp"
        echo "  3. Set alternative temp dir: export TMPDIR=/var/tmp"
        echo
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

# Remote mode: Download and install
remote_install() {
    echo
    print_line "=" 70
    center_text "Hyper-NixOS Remote Installation"
    print_line "=" 70
    echo
    
    print_status "Starting remote installation..."
    
    # Run pre-flight checks
    if ! preflight_checks; then
        print_error "Pre-flight checks failed. Cannot proceed with installation."
        echo
        echo -e "${CYAN}Fix the issues above and try again.${NC}"
        exit $ERROR_MISSING_DEPS
    fi
    
    # Create temporary directory
    tmpdir=$(mktemp -d -t hyper-nixos-XXXXXX)
    print_info "Using temporary directory: $tmpdir"
    
    # Check if we can resume from saved state
    if [[ -f "$STATE_FILE" ]]; then
        local state_age=$(($(date +%s) - $(stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0)))
        if [[ $state_age -lt 3600 ]]; then
            print_info "Found previous installation state ($(($state_age / 60)) minutes old)"
            if load_state; then
                print_info "Resuming from previous state..."
            fi
        else
            print_info "Previous installation state expired, starting fresh"
            clear_state
        fi
    fi
    
    # Prompt for download method
    local download_method
    download_method=$(prompt_download_method)
    
    print_debug "Selected download method: $download_method"
    
    # Map download method number to name
    local method_name
    case "$download_method" in
        1) method_name="Git Clone (HTTPS)" ;;
        2) method_name="Git Clone (SSH)" ;;
        3) method_name="Git Clone (Token)" ;;
        4) method_name="Download Tarball" ;;
        *) method_name="Unknown method: $download_method" ;;
    esac
    
    # Show installation confirmation
    confirm_installation "$method_name" "$tmpdir"
    
    # Perform the download based on method
    local repo_url
    local clone_output
    clone_output=$(mktemp)
    
    save_state "downloading"
    
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
                    print_error_with_help $ERROR_DOWNLOAD_FAILED "git_clone" \
                        "Failed to clone repository from GitHub" \
                        "Attempted URL: $repo_url" \
                        "$(cat "$clone_output")"
                    rm -f "$clone_output"
                    exit $ERROR_DOWNLOAD_FAILED
                fi
            else
                # Non-terminal: quiet clone
                if ! git clone -q "$repo_url" "$tmpdir/hyper-nixos" 2>"$clone_output"; then
                    print_error_with_help $ERROR_DOWNLOAD_FAILED "git_clone" \
                        "Failed to clone repository from GitHub" \
                        "Attempted URL: $repo_url" \
                        "$(cat "$clone_output")"
                    rm -f "$clone_output"
                    exit $ERROR_DOWNLOAD_FAILED
                fi
                print_success "Repository cloned successfully"
            fi
            ;;
            
        2)
            # SSH clone
            print_status "Using SSH clone (authenticated)..."
            ensure_git
            
            if ! setup_git_ssh; then
                print_warning "SSH setup failed, falling back to HTTPS..."
                repo_url="https://github.com/MasterofNull/Hyper-NixOS.git"
            else
                repo_url="git@github.com:MasterofNull/Hyper-NixOS.git"
            fi
            
            print_status "Cloning repository..."
            if ! git clone --progress "$repo_url" "$tmpdir/hyper-nixos" 2>"$clone_output"; then
                print_error_with_help $ERROR_DOWNLOAD_FAILED "git_clone_ssh" \
                    "Failed to clone repository via SSH" \
                    "$(cat "$clone_output")"
                rm -f "$clone_output"
                exit $ERROR_DOWNLOAD_FAILED
            fi
            print_success "Repository cloned successfully"
            ;;
            
        3)
            # HTTPS with token
            print_status "Using HTTPS clone with personal access token..."
            ensure_git
            
            local github_token
            if ! github_token=$(get_github_token); then
                print_error_with_help $ERROR_DOWNLOAD_FAILED "git_token" \
                    "Failed to get GitHub token" \
                    "Token authentication required for private repository access"
                exit $ERROR_DOWNLOAD_FAILED
            fi
            
            configure_git_https "$github_token"
            repo_url="https://github.com/MasterofNull/Hyper-NixOS.git"
            
            print_status "Cloning repository with authentication..."
            if ! GIT_TERMINAL_PROMPT=0 git clone --progress "$repo_url" "$tmpdir/hyper-nixos" 2>"$clone_output"; then
                print_error_with_help $ERROR_DOWNLOAD_FAILED "git_token_auth" \
                    "Failed to clone repository with token authentication" \
                    "$(cat "$clone_output")"
                rm -f "$clone_output"
                exit $ERROR_DOWNLOAD_FAILED
            fi
            print_success "Repository cloned successfully"
            ;;
            
        4)
            # Tarball download
            print_status "Using tarball download (no git required)..."
            
            if ! download_tarball "$tmpdir"; then
                print_error_with_help $ERROR_DOWNLOAD_FAILED "tarball" \
                    "Tarball download failed"
                exit $ERROR_DOWNLOAD_FAILED
            fi
            ;;
            
        *)
            print_error "Invalid download method: $download_method"
            exit 2
            ;;
    esac
    
    rm -f "$clone_output"
    save_state "downloaded"
    
    # Enter the downloaded directory
    cd "$tmpdir/hyper-nixos" || {
        print_error "Failed to enter repository directory: $tmpdir/hyper-nixos"
        exit 1
    }
    
    save_state "ready_to_install"
    
    # Map download method number to name for summary
    local method_name
    case "$download_method" in
        1) method_name="Git Clone (HTTPS)" ;;
        2) method_name="Git Clone (SSH)" ;;
        3) method_name="Git Clone (Token)" ;;
        4) method_name="Download Tarball" ;;
        *) method_name="Unknown method: $download_method" ;;
    esac
    
    # Show installation summary
    show_install_summary "$method_name" "$tmpdir/hyper-nixos"
    
    # Run the system installer
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
        print_error "Missing required files for local installation"
        echo
        echo -e "${YELLOW}Missing files:${NC}"
        for file in "${missing_files[@]}"; do
            echo "  ✗ $file"
        done
        echo
        echo -e "${CYAN}This means:${NC}"
        echo "  You're not in the Hyper-NixOS repository root directory"
        echo
        echo -e "${CYAN}To fix:${NC}"
        echo "  1. Clone the repository first:"
        echo "     git clone https://github.com/MasterofNull/Hyper-NixOS.git"
        echo "  2. Enter the directory:"
        echo "     cd Hyper-NixOS"
        echo "  3. Run the installer:"
        echo "     sudo ./install.sh"
        echo
        echo -e "${CYAN}Current directory:${NC} $(pwd)"
        echo
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
            echo
            echo -e "${YELLOW}Mode detection returned:${NC} $mode"
            echo
            echo "This is an internal error in the installer."
            echo
            echo -e "${CYAN}Expected modes:${NC}"
            echo "  • local  - Running from cloned repository"
            echo "  • remote - Piped from curl/wget"
            echo
            echo -e "${CYAN}Workaround:${NC}"
            echo "  Download and run locally:"
            echo "    git clone https://github.com/MasterofNull/Hyper-NixOS.git"
            echo "    cd Hyper-NixOS"
            echo "    sudo ./install.sh"
            echo
            echo "Please report this at: https://github.com/MasterofNull/Hyper-NixOS/issues"
            echo
            exit 1
            ;;
    esac
}

# Verify all critical functions are defined before executing
verify_functions() {
    local required_functions=(
        "print_error"
        "print_status" 
        "print_success"
        "detect_mode"
        "remote_install"
        "local_install"
    )
    
    local missing=()
    for func in "${required_functions[@]}"; do
        if ! declare -F "$func" >/dev/null 2>&1; then
            missing+=("$func")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}✗ CRITICAL ERROR: Script loading failed${NC}" >&2
        echo >&2
        echo "Missing functions: ${missing[*]}" >&2
        echo >&2
        echo -e "${YELLOW}This can happen when:${NC}" >&2
        echo "  1. The script is downloaded incompletely" >&2
        echo "  2. There's a syntax error preventing function definitions" >&2
        echo "  3. Network issues interrupted the download" >&2
        echo >&2
        echo -e "${CYAN}Try these solutions:${NC}" >&2
        echo "  1. Download and run locally:" >&2
        echo "     git clone https://github.com/MasterofNull/Hyper-NixOS.git" >&2
        echo "     cd Hyper-NixOS" >&2
        echo "     sudo ./install.sh" >&2
        echo >&2
        echo "  2. Or use tarball download (more reliable):" >&2
        echo "     wget https://github.com/MasterofNull/Hyper-NixOS/archive/refs/heads/main.tar.gz" >&2
        echo "     tar xzf main.tar.gz" >&2
        echo "     cd Hyper-NixOS-main" >&2
        echo "     sudo ./install.sh" >&2
        echo >&2
        exit 127
    fi
}

# Handle being piped from curl or executed directly
# When piped: BASH_SOURCE is empty; when executed: BASH_SOURCE[0] == $0
# Only skip main if being sourced (BASH_SOURCE[0] != $0)
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Verify script loaded completely
    verify_functions
    
    # Run main installer
    main "$@"
fi
