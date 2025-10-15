#!/usr/bin/env bash
# Dry Run Mode Library
# Allows testing wizard recommendations without applying changes
# Part of Design Ethos - Ease of Use (Pillar 1)

# Prevent multiple sourcing
[[ -n "${_DRY_RUN_LOADED:-}" ]] && return 0
readonly _DRY_RUN_LOADED=1

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
}

################################################################################
# Configuration
################################################################################

# Dry run mode flag (set by --dry-run argument)
DRY_RUN=${HV_DRY_RUN:-false}

# Color for dry run indicators
readonly DRY_RUN_COLOR='\033[1;35m'  # Magenta
readonly NC='\033[0m'

################################################################################
# Mode Detection
################################################################################

# Check if running in dry run mode
is_dry_run() {
    [ "$DRY_RUN" = "true" ]
}

# Enable dry run mode
enable_dry_run() {
    DRY_RUN=true
    export DRY_RUN
    log_warn "DRY RUN MODE ENABLED - No changes will be made"
}

# Disable dry run mode
disable_dry_run() {
    DRY_RUN=false
    export DRY_RUN
}

# Parse dry run argument
parse_dry_run_arg() {
    for arg in "$@"; do
        if [ "$arg" = "--dry-run" ] || [ "$arg" = "-n" ]; then
            enable_dry_run
            return 0
        fi
    done
    return 1
}

################################################################################
# Dry Run Operations
################################################################################

# Wrapper for file write operations
dry_run_write_file() {
    local file=$1
    local content=$2
    
    if is_dry_run; then
        echo -e "${DRY_RUN_COLOR}[DRY RUN]${NC} Would write to: $file"
        echo "Content preview:"
        echo "$content" | head -20
        if [ $(echo "$content" | wc -l) -gt 20 ]; then
            echo "... ($(echo "$content" | wc -l) lines total)"
        fi
        return 0
    else
        # Actually write the file
        echo "$content" > "$file"
        return $?
    fi
}

# Wrapper for command execution
dry_run_execute() {
    local cmd=("$@")
    
    if is_dry_run; then
        echo -e "${DRY_RUN_COLOR}[DRY RUN]${NC} Would execute: ${cmd[*]}"
        return 0
    else
        # Actually execute
        "${cmd[@]}"
        return $?
    fi
}

# Wrapper for directory creation
dry_run_mkdir() {
    local dir=$1
    local mode=${2:-0755}
    
    if is_dry_run; then
        echo -e "${DRY_RUN_COLOR}[DRY RUN]${NC} Would create directory: $dir (mode: $mode)"
        return 0
    else
        mkdir -p -m "$mode" "$dir"
        return $?
    fi
}

# Wrapper for service management
dry_run_systemctl() {
    local action=$1
    local service=$2
    
    if is_dry_run; then
        echo -e "${DRY_RUN_COLOR}[DRY RUN]${NC} Would run: systemctl $action $service"
        return 0
    else
        systemctl "$action" "$service"
        return $?
    fi
}

# Wrapper for NixOS rebuild
dry_run_nixos_rebuild() {
    local action=${1:-switch}
    
    if is_dry_run; then
        echo -e "${DRY_RUN_COLOR}[DRY RUN]${NC} Would run: nixos-rebuild $action"
        echo "Use: nixos-rebuild dry-build (to see what would be built)"
        return 0
    else
        nixos-rebuild "$action"
        return $?
    fi
}

################################################################################
# Summary and Preview
################################################################################

# Start dry run summary
dry_run_summary_start() {
    if is_dry_run; then
        echo ""
        echo -e "${DRY_RUN_COLOR}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${DRY_RUN_COLOR}║  DRY RUN MODE - Preview of Changes                        ${NC}"
        echo -e "${DRY_RUN_COLOR}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

# End dry run summary
dry_run_summary_end() {
    if is_dry_run; then
        echo ""
        echo -e "${DRY_RUN_COLOR}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${DRY_RUN_COLOR}║  DRY RUN COMPLETE - No actual changes were made           ${NC}"
        echo -e "${DRY_RUN_COLOR}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "To apply these changes, run without --dry-run flag"
        echo ""
    fi
}

# Show what would be configured
dry_run_show_config() {
    local config_name=$1
    local config_content=$2
    
    if is_dry_run; then
        echo -e "${DRY_RUN_COLOR}[DRY RUN]${NC} Configuration: $config_name"
        echo "$config_content" | jq '.' 2>/dev/null || echo "$config_content"
        echo ""
    fi
}

################################################################################
# Export functions
################################################################################

export -f is_dry_run
export -f enable_dry_run
export -f disable_dry_run
export -f parse_dry_run_arg
export -f dry_run_write_file
export -f dry_run_execute
export -f dry_run_mkdir
export -f dry_run_systemctl
export -f dry_run_nixos_rebuild
export -f dry_run_summary_start
export -f dry_run_summary_end
export -f dry_run_show_config

export DRY_RUN
