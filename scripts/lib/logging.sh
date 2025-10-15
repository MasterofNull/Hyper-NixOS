#!/usr/bin/env bash
# Centralized Logging Library for Hyper-NixOS
# Provides consistent logging across all wizards and tools
# Part of Design Ethos - Security & Organization (Pillar 2)

# Prevent multiple sourcing
[[ -n "${_LOGGING_LOADED:-}" ]] && return 0
readonly _LOGGING_LOADED=1

set -euo pipefail

################################################################################
# Configuration
################################################################################

# Log directory and file setup
LOG_DIR="${HV_LOG_DIR:-/var/lib/hypervisor/logs}"
LOG_DATE="$(date +%Y%m%d)"
LOG_FILE="${LOG_DIR}/hypervisor-${LOG_DATE}.log"
WIZARD_LOG="${LOG_DIR}/wizards-${LOG_DATE}.log"
ERROR_LOG="${LOG_DIR}/errors-${LOG_DATE}.log"
AUDIT_LOG="${LOG_DIR}/audit-${LOG_DATE}.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Log levels
readonly LOG_LEVEL_TRACE=0
readonly LOG_LEVEL_DEBUG=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_WARN=3
readonly LOG_LEVEL_ERROR=4
readonly LOG_LEVEL_FATAL=5

# Current log level (can be overridden by environment)
CURRENT_LOG_LEVEL=${HV_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Colors for terminal output
readonly COLOR_TRACE='\033[0;37m'    # Gray
readonly COLOR_DEBUG='\033[0;36m'    # Cyan
readonly COLOR_INFO='\033[0;32m'     # Green
readonly COLOR_WARN='\033[1;33m'     # Yellow
readonly COLOR_ERROR='\033[0;31m'    # Red
readonly COLOR_FATAL='\033[1;31m'    # Bold Red
readonly COLOR_RESET='\033[0m'

################################################################################
# Core Logging Functions
################################################################################

# Internal logging function
_log() {
    local level=$1
    local level_name=$2
    local color=$3
    shift 3
    local message="$*"
    
    # Check if we should log this level
    if [ "$level" -lt "$CURRENT_LOG_LEVEL" ]; then
        return 0
    fi
    
    # Timestamp
    local timestamp=$(date -Iseconds)
    
    # Format: [TIMESTAMP] LEVEL: MESSAGE
    local log_entry="[${timestamp}] ${level_name}: ${message}"
    
    # Write to main log file
    echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
    
    # Write to appropriate specialized log
    case "$level_name" in
        ERROR|FATAL)
            echo "$log_entry" >> "$ERROR_LOG" 2>/dev/null || true
            ;;
    esac
    
    # Terminal output (if stdout is a terminal)
    if [ -t 1 ]; then
        echo -e "${color}[${level_name}]${COLOR_RESET} ${message}"
    else
        echo "[${level_name}] ${message}"
    fi
}

# Public logging functions
log_trace() {
    _log $LOG_LEVEL_TRACE "TRACE" "$COLOR_TRACE" "$@"
}

log_debug() {
    _log $LOG_LEVEL_DEBUG "DEBUG" "$COLOR_DEBUG" "$@"
}

log_info() {
    _log $LOG_LEVEL_INFO "INFO" "$COLOR_INFO" "$@"
}

log_warn() {
    _log $LOG_LEVEL_WARN "WARN" "$COLOR_WARN" "$@"
}

log_error() {
    _log $LOG_LEVEL_ERROR "ERROR" "$COLOR_ERROR" "$@"
}

log_fatal() {
    _log $LOG_LEVEL_FATAL "FATAL" "$COLOR_FATAL" "$@"
}

################################################################################
# Specialized Logging
################################################################################

# Wizard-specific logging
log_wizard_start() {
    local wizard_name=$1
    local log_entry="[$(date -Iseconds)] WIZARD_START: ${wizard_name}"
    echo "$log_entry" >> "$WIZARD_LOG" 2>/dev/null || true
    log_info "Starting wizard: ${wizard_name}"
}

log_wizard_end() {
    local wizard_name=$1
    local status=${2:-success}
    local log_entry="[$(date -Iseconds)] WIZARD_END: ${wizard_name} (${status})"
    echo "$log_entry" >> "$WIZARD_LOG" 2>/dev/null || true
    log_info "Wizard completed: ${wizard_name} - ${status}"
}

log_wizard_choice() {
    local wizard_name=$1
    local field=$2
    local detected=$3
    local recommended=$4
    local chosen=$5
    
    local log_entry="[$(date -Iseconds)] CHOICE: ${wizard_name} | ${field} | detected:${detected} | recommended:${recommended} | chosen:${chosen}"
    echo "$log_entry" >> "$WIZARD_LOG" 2>/dev/null || true
}

# Audit logging for security-sensitive operations
log_audit() {
    local action=$1
    local user=${2:-${USER:-unknown}}
    local details=${3:-}
    
    local log_entry="[$(date -Iseconds)] AUDIT: user=${user} action=${action} details=${details}"
    echo "$log_entry" >> "$AUDIT_LOG" 2>/dev/null || true
    
    # Also log to syslog if available
    if command -v logger &> /dev/null; then
        logger -t hypervisor-audit -p auth.info "user=${user} action=${action} ${details}"
    fi
}

# Configuration change logging
log_config_change() {
    local config_file=$1
    local field=$2
    local old_value=$3
    local new_value=$4
    
    local log_entry="[$(date -Iseconds)] CONFIG_CHANGE: ${config_file} | ${field}: ${old_value} -> ${new_value}"
    echo "$log_entry" >> "$WIZARD_LOG" 2>/dev/null || true
    log_info "Configuration updated: ${field}"
}

################################################################################
# Error Tracking
################################################################################

# Track errors for reporting
ERROR_COUNT=0
declare -a ERROR_LIST=()

log_error_tracked() {
    local error_msg="$*"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    ERROR_LIST+=("$error_msg")
    log_error "$error_msg"
}

get_error_count() {
    echo "$ERROR_COUNT"
}

get_error_list() {
    printf '%s\n' "${ERROR_LIST[@]}"
}

################################################################################
# Log Rotation and Cleanup
################################################################################

# Rotate logs older than N days
rotate_logs() {
    local keep_days=${1:-30}
    
    find "$LOG_DIR" -name "*.log" -type f -mtime +${keep_days} -delete 2>/dev/null || true
    log_info "Rotated logs older than ${keep_days} days"
}

# Get log file size
get_log_size() {
    du -sh "$LOG_DIR" 2>/dev/null | awk '{print $1}' || echo "0"
}

################################################################################
# Convenience Functions
################################################################################

# Log with context (file, line, function)
log_context() {
    local level=$1
    shift
    local message="$*"
    
    local caller_info="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]} ${FUNCNAME[2]}()"
    
    case "$level" in
        trace) log_trace "[$caller_info] $message" ;;
        debug) log_debug "[$caller_info] $message" ;;
        info) log_info "[$caller_info] $message" ;;
        warn) log_warn "[$caller_info] $message" ;;
        error) log_error "[$caller_info] $message" ;;
        fatal) log_fatal "[$caller_info] $message" ;;
    esac
}

# Log command execution
log_command() {
    local cmd="$*"
    log_debug "Executing: $cmd"
    
    local output
    local exit_code=0
    
    output=$("$@" 2>&1) || exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_debug "Command succeeded: $cmd"
    else
        log_error "Command failed (exit $exit_code): $cmd"
        log_error "Output: $output"
    fi
    
    return $exit_code
}

# Simple log function (backward compatibility)
log() {
    log_info "$@"
}

################################################################################
# Export functions
################################################################################

export -f log_trace
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_fatal
export -f log_wizard_start
export -f log_wizard_end
export -f log_wizard_choice
export -f log_audit
export -f log_config_change
export -f log_error_tracked
export -f get_error_count
export -f get_error_list
export -f rotate_logs
export -f get_log_size
export -f log_context
export -f log_command
export -f log

# Export variables
export LOG_DIR
export LOG_FILE
export WIZARD_LOG
export ERROR_LOG
export AUDIT_LOG
