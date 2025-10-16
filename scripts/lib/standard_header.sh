#!/usr/bin/env bash
# Standard Script Header for Hyper-NixOS
# Version: 2.0.0
# This header should be sourced by all Hyper-NixOS scripts

# Strict error handling
set -Eeuo pipefail
IFS=$'\n\t'

# Script metadata (override these in your script)
SCRIPT_NAME="${SCRIPT_NAME:-$(basename "${BASH_SOURCE[1]}")}"
SCRIPT_VERSION="${SCRIPT_VERSION:-1.0.0}"
SCRIPT_DESCRIPTION="${SCRIPT_DESCRIPTION:-No description provided}"

# Detect script directory
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

# Source common libraries
LIB_DIR="${LIB_DIR:-${SCRIPT_DIR}/lib}"

# Source core libraries if available
if [ -f "${LIB_DIR}/common.sh" ]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/common.sh"
fi

if [ -f "${LIB_DIR}/ui.sh" ]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/ui.sh"
fi

if [ -f "${LIB_DIR}/system.sh" ]; then
    # shellcheck disable=SC1091
    source "${LIB_DIR}/system.sh"
fi

# Logging setup
LOG_DIR="${LOG_DIR:-/var/log/hypervisor}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/${SCRIPT_NAME}.log}"

# Create log directory if it doesn't exist
if [ -w "$(dirname "${LOG_DIR}")" ] 2>/dev/null; then
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
fi

# Logging functions (fallback if common.sh not available)
if ! command -v log_info &> /dev/null; then
    log_info() { echo "[INFO] $*" | tee -a "${LOG_FILE}" 2>/dev/null || echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" | tee -a "${LOG_FILE}" 2>/dev/null || echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" | tee -a "${LOG_FILE}" 2>/dev/null || echo "[WARN] $*"; }
    log_debug() { [ "${DEBUG:-0}" = "1" ] && echo "[DEBUG] $*" | tee -a "${LOG_FILE}" 2>/dev/null || true; }
fi

# Error handling
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

error_handler() {
    local exit_code=$1
    local line_number=$2
    local command=$3
    
    log_error "Script failed at line ${line_number}: ${command}"
    log_error "Exit code: ${exit_code}"
    
    # Cleanup if function exists
    if type cleanup &>/dev/null; then
        cleanup
    fi
    
    exit "${exit_code}"
}

# Cleanup handler
trap cleanup EXIT INT TERM

# Default cleanup (override in your script)
cleanup() {
    :  # No-op by default
}

# Display header
display_header() {
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    echo -e "  ${SCRIPT_DESCRIPTION}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Check if running as root
require_root() {
    if [ "${EUID}" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if NOT running as root
require_non_root() {
    if [ "${EUID}" -eq 0 ]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Version check
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

# Feature flag check
check_feature_enabled() {
    local feature=$1
    local conf_file="/etc/hypervisor/features/${feature}.conf"
    
    if [ ! -f "${conf_file}" ]; then
        return 1
    fi
    
    # shellcheck disable=SC1090
    source "${conf_file}"
    
    if [ "${FEATURE_STATUS:-disabled}" = "enabled" ]; then
        return 0
    else
        return 1
    fi
}

# Export functions for use in scripts
export -f log_info log_error log_warn log_debug
export -f error_handler cleanup display_header
export -f require_root require_non_root
export -f check_dependencies check_feature_enabled
