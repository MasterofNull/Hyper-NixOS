#!/usr/bin/env bash
# Error Handling Library for Hyper-NixOS
# Provides robust error handling for all scripts
# Part of Design Ethos - Ease of Use (Pillar 1) + Security (Pillar 2)

# Prevent multiple sourcing
[[ -n "${_ERROR_HANDLING_LOADED:-}" ]] && return 0
readonly _ERROR_HANDLING_LOADED=1

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || true

################################################################################
# Error Trap Setup
################################################################################

# Setup error trap for script
setup_error_trap() {
    local script_name=${1:-$(basename "$0")}
    
    trap 'handle_error $? $LINENO "$BASH_COMMAND" "$script_name"' ERR
    trap 'handle_exit $? "$script_name"' EXIT
    trap 'handle_signal SIGHUP "$script_name"' HUP
    trap 'handle_signal SIGINT "$script_name"' INT
    trap 'handle_signal SIGTERM "$script_name"' TERM
}

# Handle errors
handle_error() {
    local exit_code=$1
    local line_no=$2
    local bash_command=$3
    local script_name=$4
    
    log_error "Error in ${script_name} at line ${line_no}" 2>/dev/null || \
        echo "ERROR: ${script_name}:${line_no} - Command failed: ${bash_command}" >&2
    
    log_error "Command: ${bash_command}" 2>/dev/null || true
    log_error "Exit code: ${exit_code}" 2>/dev/null || true
}

# Handle script exit
handle_exit() {
    local exit_code=$1
    local script_name=$2
    
    if [ "$exit_code" -ne 0 ]; then
        log_error "${script_name} exited with code ${exit_code}" 2>/dev/null || true
    fi
}

# Handle signals
handle_signal() {
    local signal=$1
    local script_name=$2
    
    log_warn "${script_name} received ${signal}, cleaning up..." 2>/dev/null || \
        echo "WARN: ${script_name} received ${signal}" >&2
    
    exit 130
}

################################################################################
# Input Validation
################################################################################

# Validate integer input
validate_integer() {
    local value=$1
    local field_name=${2:-value}
    local min=${3:-}
    local max=${4:-}
    
    # Check if integer
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log_error "${field_name} must be a positive integer, got: ${value}"
        return 1
    fi
    
    # Check minimum
    if [ -n "$min" ] && [ "$value" -lt "$min" ]; then
        log_error "${field_name} must be at least ${min}, got: ${value}"
        return 1
    fi
    
    # Check maximum
    if [ -n "$max" ] && [ "$value" -gt "$max" ]; then
        log_error "${field_name} must be at most ${max}, got: ${value}"
        return 1
    fi
    
    return 0
}

# Validate string input
validate_string() {
    local value=$1
    local field_name=${2:-value}
    local pattern=${3:-'^[a-zA-Z0-9_-]+$'}
    
    if ! [[ "$value" =~ $pattern ]]; then
        log_error "${field_name} contains invalid characters: ${value}"
        return 1
    fi
    
    return 0
}

# Validate file path
validate_path() {
    local path=$1
    local must_exist=${2:-no}
    
    # Check for path traversal attempts
    if [[ "$path" == *".."* ]]; then
        log_error "Path traversal not allowed: ${path}"
        return 1
    fi
    
    # Check if must exist
    if [ "$must_exist" = "yes" ] && [ ! -e "$path" ]; then
        log_error "Path does not exist: ${path}"
        return 1
    fi
    
    return 0
}

# Validate choice from options
validate_choice() {
    local choice=$1
    shift
    local valid_options=("$@")
    
    for option in "${valid_options[@]}"; do
        if [ "$choice" = "$option" ]; then
            return 0
        fi
    done
    
    log_error "Invalid choice: ${choice}"
    log_error "Valid options: ${valid_options[*]}"
    return 1
}

################################################################################
# Safe Operations
################################################################################

# Safe command execution with retry
safe_execute() {
    local max_attempts=${1:-3}
    shift
    local cmd=("$@")
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "${cmd[@]}"; then
            return 0
        else
            local exit_code=$?
            log_warn "Attempt ${attempt}/${max_attempts} failed: ${cmd[*]}"
            
            if [ $attempt -eq $max_attempts ]; then
                log_error "Command failed after ${max_attempts} attempts"
                return $exit_code
            fi
            
            attempt=$((attempt + 1))
            sleep 1
        fi
    done
}

# Safe file write with backup
safe_write_file() {
    local file=$1
    local content=$2
    local backup=${3:-yes}
    
    # Backup existing file
    if [ "$backup" = "yes" ] && [ -f "$file" ]; then
        local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup_file" || {
            log_error "Failed to backup ${file}"
            return 1
        }
        log_info "Backed up ${file} to ${backup_file}"
    fi
    
    # Write to temp file first
    local temp_file="${file}.tmp.$$"
    echo "$content" > "$temp_file" || {
        log_error "Failed to write to ${temp_file}"
        return 1
    }
    
    # Validate if JSON
    if [[ "$file" == *.json ]]; then
        if ! jq empty "$temp_file" 2>/dev/null; then
            log_error "Invalid JSON in ${temp_file}"
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    # Move temp to final location
    mv "$temp_file" "$file" || {
        log_error "Failed to move ${temp_file} to ${file}"
        return 1
    }
    
    log_info "Successfully wrote ${file}"
    return 0
}

# Safe directory creation
safe_mkdir() {
    local dir=$1
    local mode=${2:-0755}
    
    if [ -d "$dir" ]; then
        log_debug "Directory already exists: ${dir}"
        return 0
    fi
    
    if mkdir -p -m "$mode" "$dir"; then
        log_info "Created directory: ${dir}"
        return 0
    else
        log_error "Failed to create directory: ${dir}"
        return 1
    fi
}

################################################################################
# Resource Validation
################################################################################

# Check available disk space
check_disk_space() {
    local path=$1
    local required_gb=$2
    
    local available_gb=$(df -BG "$path" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || echo "0")
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_warn "Insufficient disk space at ${path}"
        log_warn "Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    fi
    
    log_debug "Disk space OK: ${available_gb}GB available (need ${required_gb}GB)"
    return 0
}

# Check available memory
check_memory() {
    local required_mb=$1
    
    local available_mb=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0")
    
    if [ "$available_mb" -lt "$required_mb" ]; then
        log_warn "Insufficient memory"
        log_warn "Required: ${required_mb}MB, Available: ${available_mb}MB"
        return 1
    fi
    
    log_debug "Memory OK: ${available_mb}MB available (need ${required_mb}MB)"
    return 0
}

################################################################################
# User Interaction with Validation
################################################################################

# Prompt with validation
prompt_validated() {
    local prompt=$1
    local default=$2
    local validation_func=$3
    shift 3
    local validation_args=("$@")
    
    local value=""
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        read -r -p "$prompt [$default]: " value
        value=${value:-$default}
        
        if $validation_func "$value" "${validation_args[@]}"; then
            echo "$value"
            return 0
        else
            attempts=$((attempts + 1))
            if [ $attempts -lt $max_attempts ]; then
                echo "Please try again ($(($max_attempts - $attempts)) attempts remaining)"
            fi
        fi
    done
    
    log_error "Maximum validation attempts exceeded"
    return 1
}

# Confirm action
confirm_action() {
    local message=$1
    local default=${2:-no}
    
    local prompt="$message (yes/no)"
    [ "$default" = "yes" ] && prompt="$message (yes/no) [yes]"
    [ "$default" = "no" ] && prompt="$message (yes/no) [no]"
    
    local response
    read -r -p "$prompt: " response
    response=${response:-$default}
    
    case "$response" in
        yes|y|Y|YES)
            return 0
            ;;
        no|n|N|NO)
            return 1
            ;;
        *)
            log_warn "Invalid response, treating as 'no'"
            return 1
            ;;
    esac
}

################################################################################
# Cleanup Handlers
################################################################################

# Register cleanup function
CLEANUP_FUNCTIONS=()

register_cleanup() {
    CLEANUP_FUNCTIONS+=("$1")
}

# Execute all cleanup functions
execute_cleanup() {
    log_debug "Running cleanup functions..."
    
    for cleanup_func in "${CLEANUP_FUNCTIONS[@]}"; do
        $cleanup_func 2>/dev/null || true
    done
}

# Standard cleanup (call in EXIT trap)
standard_cleanup() {
    execute_cleanup
    
    # Remove temp files
    rm -f /tmp/hypervisor-*.tmp 2>/dev/null || true
}

################################################################################
# Export functions
################################################################################

export -f setup_error_trap
export -f handle_error
export -f handle_exit
export -f handle_signal
export -f validate_integer
export -f validate_string
export -f validate_path
export -f validate_choice
export -f safe_execute
export -f safe_write_file
export -f safe_mkdir
export -f check_disk_space
export -f check_memory
export -f prompt_validated
export -f confirm_action
export -f register_cleanup
export -f execute_cleanup
export -f standard_cleanup
export -f log_error_tracked
export -f get_error_count
export -f get_error_list
