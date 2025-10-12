#!/usr/bin/env bash
#
# Hyper-NixOS Common Library
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Shared functions and utilities for all Hyper-NixOS scripts
# Source this file at the beginning of scripts to avoid code duplication
#

# Security: Strict error handling and safe defaults
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# Security: Safe PATH
export PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Security: Trap for cleanup on exit
_cleanup_handlers=()
_register_cleanup() {
    _cleanup_handlers+=("$1")
}
_run_cleanup() {
    local exit_code=$?
    for handler in "${_cleanup_handlers[@]}"; do
        eval "$handler" || true
    done
    exit $exit_code
}
trap '_run_cleanup' EXIT HUP INT TERM

# Version and branding
readonly HYPERVISOR_VERSION="2.0"
readonly HYPERVISOR_BRANDING="Hyper-NixOS v${HYPERVISOR_VERSION} | © 2024-2025 MasterofNull"

# Standard paths
readonly HYPERVISOR_ROOT="/etc/hypervisor"
readonly HYPERVISOR_STATE="/var/lib/hypervisor"
readonly HYPERVISOR_SCRIPTS="${HYPERVISOR_ROOT}/scripts"
readonly HYPERVISOR_CONFIG="${HYPERVISOR_ROOT}/config.json"
readonly HYPERVISOR_PROFILES="${HYPERVISOR_STATE}/vm_profiles"
readonly HYPERVISOR_ISOS="${HYPERVISOR_STATE}/isos"
readonly HYPERVISOR_DISKS="${HYPERVISOR_STATE}/disks"
readonly HYPERVISOR_LOGS="${HYPERVISOR_STATE}/logs"

# Dialog interface selection
: "${DIALOG:=whiptail}"
export DIALOG

# Logging configuration
LOG_ENABLED=true
LOG_FILE="${LOG_FILE:-${HYPERVISOR_LOGS}/script.log}"

# Initialize logging
init_logging() {
    local log_name="${1:-script}"
    LOG_FILE="${HYPERVISOR_LOGS}/${log_name}.log"
    mkdir -p "${HYPERVISOR_LOGS}"
    touch "${LOG_FILE}" 2>/dev/null || LOG_ENABLED=false
}

# Optimized logging function with levels
log() {
    if [[ "${LOG_ENABLED}" == "true" ]]; then
        printf '%s [%s] %s\n' "$(date -Iseconds)" "${1:-INFO}" "${2:-}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*"; }
log_debug() { [[ "${DEBUG:-false}" == "true" ]] && log "DEBUG" "$*"; }

# Dependency checking with caching
_required_bins=()
require() {
    local missing=()
    for bin in "$@"; do
        if [[ ! " ${_required_bins[*]} " =~ " ${bin} " ]]; then
            if command -v "$bin" >/dev/null 2>&1; then
                _required_bins+=("$bin")
            else
                missing+=("$bin")
            fi
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing required dependencies: ${missing[*]}" >&2
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

# Secure input validation
validate_vm_name() {
    local name="$1"
    # Security: Only allow alphanumeric, dash, underscore
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid VM name: $name (must be alphanumeric with dash/underscore)"
        return 1
    fi
    # Security: Prevent path traversal
    if [[ "$name" == *".."* ]] || [[ "$name" == "/"* ]]; then
        log_error "Invalid VM name: $name (path traversal detected)"
        return 1
    fi
    return 0
}

# Secure path validation
validate_path() {
    local path="$1"
    local base_dir="${2:-}"
    # Security: Prevent path traversal
    if [[ "$path" == *".."* ]]; then
        log_error "Invalid path: $path (path traversal detected)"
        return 1
    fi
    # Security: Ensure path is within base directory if specified
    if [[ -n "$base_dir" ]]; then
        local real_path
        real_path=$(realpath -m "$path" 2>/dev/null || echo "$path")
        local real_base
        real_base=$(realpath -m "$base_dir" 2>/dev/null || echo "$base_dir")
        if [[ "$real_path" != "$real_base"* ]]; then
            log_error "Invalid path: $path (outside base directory)"
            return 1
        fi
    fi
    return 0
}

# Secure JSON parsing with validation
json_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    if [[ ! -f "$file" ]]; then
        echo "$default"
        return 0
    fi
    # Security: Validate JSON file is readable and parseable
    if ! jq empty "$file" 2>/dev/null; then
        log_error "Invalid JSON file: $file"
        echo "$default"
        return 1
    fi
    jq -r "$key // \"$default\"" "$file" 2>/dev/null || echo "$default"
}

# Optimized VM state checking with caching
_vm_state_cache=()
_vm_state_cache_time=0
get_vm_state() {
    local vm_name="$1"
    local current_time
    current_time=$(date +%s)
    # Cache for 2 seconds to reduce virsh calls
    if (( current_time - _vm_state_cache_time > 2 )); then
        _vm_state_cache=()
        _vm_state_cache_time=$current_time
    fi
    # Check cache
    for entry in "${_vm_state_cache[@]}"; do
        if [[ "$entry" == "$vm_name:"* ]]; then
            echo "${entry#*:}"
            return 0
        fi
    done
    # Query and cache
    local state
    state=$(virsh domstate "$vm_name" 2>/dev/null || echo "undefined")
    _vm_state_cache+=("$vm_name:$state")
    echo "$state"
}

# Efficient VM listing
list_vms() {
    local filter="${1:-all}"
    case "$filter" in
        running) virsh list --name 2>/dev/null | grep -v '^$' ;;
        stopped) virsh list --inactive --name 2>/dev/null | grep -v '^$' ;;
        all) virsh list --all --name 2>/dev/null | grep -v '^$' ;;
        *) log_error "Invalid VM filter: $filter"; return 1 ;;
    esac
}

# Safe temporary file creation
make_temp_file() {
    local prefix="${1:-hypervisor}"
    local tmp
    tmp=$(mktemp -t "${prefix}.XXXXXXXXXX") || {
        log_error "Failed to create temporary file"
        return 1
    }
    _register_cleanup "rm -f '$tmp'"
    echo "$tmp"
}

# Safe temporary directory creation
make_temp_dir() {
    local prefix="${1:-hypervisor}"
    local tmp
    tmp=$(mktemp -d -t "${prefix}.XXXXXXXXXX") || {
        log_error "Failed to create temporary directory"
        return 1
    }
    _register_cleanup "rm -rf '$tmp'"
    echo "$tmp"
}

# Error handling wrapper
die() {
    log_error "$*"
    echo "ERROR: $*" >&2
    exit 1
}

# Success message
success() {
    log_info "$*"
    echo "SUCCESS: $*"
}

# Load configuration from config.json if available
load_config() {
    if [[ -f "${HYPERVISOR_CONFIG}" ]]; then
        # Export commonly used config values
        export AUTOSTART_TIMEOUT=$(json_get "${HYPERVISOR_CONFIG}" ".features.autostart_timeout_sec" "5")
        export BOOT_SELECTOR_ENABLE=$(json_get "${HYPERVISOR_CONFIG}" ".features.boot_selector_enable" "false")
        export BOOT_SELECTOR_TIMEOUT=$(json_get "${HYPERVISOR_CONFIG}" ".features.boot_selector_timeout_sec" "8")
    fi
}

# Auto-load configuration
load_config

# Efficiency: Pre-check common dependencies
require jq virsh
