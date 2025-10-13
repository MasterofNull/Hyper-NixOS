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

# Performance monitoring
SCRIPT_START_TIME=""
SCRIPT_METRICS_ENABLED="${SCRIPT_METRICS_ENABLED:-false}"

# Start script timer
script_timer_start() {
    SCRIPT_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
    log_debug "Script timer started at $SCRIPT_START_TIME"
}

# End script timer and log duration
script_timer_end() {
    local label="${1:-Script execution}"
    if [[ -n "$SCRIPT_START_TIME" ]]; then
        local end_time=$(date +%s.%N 2>/dev/null || date +%s)
        local duration=$(awk "BEGIN {print $end_time - $SCRIPT_START_TIME}")
        log_info "$label time: ${duration}s"
        
        # Write metrics if enabled
        if [[ "$SCRIPT_METRICS_ENABLED" == "true" ]]; then
            local metrics_file="${HYPERVISOR_LOGS}/script_metrics.csv"
            if [[ ! -f "$metrics_file" ]]; then
                echo "timestamp,script,operation,duration" > "$metrics_file"
            fi
            echo "$(date -Iseconds),${BASH_SOURCE[-1]##*/},$label,$duration" >> "$metrics_file"
        fi
    fi
}

# Measure function execution time
measure_function() {
    local func_name="$1"
    shift
    local start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Execute the function with its arguments
    "$func_name" "$@"
    local result=$?
    
    if [[ "$SCRIPT_METRICS_ENABLED" == "true" ]]; then
        local end_time=$(date +%s.%N 2>/dev/null || date +%s)
        local duration=$(awk "BEGIN {print $end_time - $start_time}")
        log_debug "Function $func_name took ${duration}s"
    fi
    
    return $result
}

# Phase detection functions
get_security_phase() {
    if [[ -f /etc/hypervisor/.phase2_hardened ]]; then
        echo "hardened"
    elif [[ -f /etc/hypervisor/.phase1_setup ]]; then
        echo "setup"
    else
        # Fresh install defaults to setup
        echo "setup"
    fi
}

# Check if operation is allowed in current phase
is_operation_allowed() {
    local operation="$1"
    local phase
    phase=$(get_security_phase)
    
    case "$phase" in
        setup)
            # All operations allowed in setup
            return 0
            ;;
        hardened)
            # Check operation whitelist
            case "$operation" in
                # VM operations
                vm_start|vm_stop|vm_pause|vm_resume|vm_status|vm_console)
                    return 0
                    ;;
                # Backup operations
                backup_create|backup_restore|backup_list)
                    return 0
                    ;;
                # Monitoring operations
                monitoring_view|log_view|metrics_view)
                    return 0
                    ;;
                # Restricted operations
                vm_create|vm_delete|vm_modify|system_config|network_config|user_modify)
                    return 1
                    ;;
                *)
                    # Unknown operations default to denied in hardened mode
                    return 1
                    ;;
            esac
            ;;
    esac
}

# Phase-aware permission check wrapper
check_phase_permission() {
    local operation="$1"
    local phase
    phase=$(get_security_phase)
    
    if ! is_operation_allowed "$operation"; then
        log_error "Operation '$operation' not allowed in $phase mode"
        if [[ "$phase" == "hardened" ]]; then
            die "Operation not permitted in hardened mode. Use 'transition_phase.sh setup' to enable setup mode."
        fi
        return 1
    fi
    
    # Log security-sensitive operations
    if [[ "$phase" == "setup" ]]; then
        log_warn "Setup mode operation: $operation (will be restricted in hardened mode)"
    fi
    
    return 0
}

# Phase-aware directory permissions
get_phase_permissions() {
    local type="$1"  # file, dir, or script
    local phase
    phase=$(get_security_phase)
    
    case "$phase:$type" in
        setup:file)    echo "0644" ;;
        setup:dir)     echo "0755" ;;
        setup:script)  echo "0755" ;;
        hardened:file) echo "0640" ;;
        hardened:dir)  echo "0750" ;;
        hardened:script) echo "0750" ;;
        *)             echo "0644" ;;
    esac
}

# Initialize security phase
SECURITY_PHASE=$(get_security_phase)
export SECURITY_PHASE

# Log current phase
log_info "Security phase: $SECURITY_PHASE"

# Auto-load configuration
load_config

# Efficiency: Pre-check common dependencies
require jq virsh
