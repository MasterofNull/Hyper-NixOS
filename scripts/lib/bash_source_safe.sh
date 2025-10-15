#!/usr/bin/env bash
# bash_source_safe.sh - Safe BASH_SOURCE handling utilities
# 
# This library provides safe patterns for accessing BASH_SOURCE
# that work when scripts are executed, sourced, or piped from curl.
#
# Usage:
#   source "$(dirname "$(get_script_path)")/lib/bash_source_safe.sh"
#   SCRIPT_DIR="$(get_script_dir)"

# Get the script path, safe for piped execution
# Returns: Script path if available, empty string if piped
get_script_path() {
    echo "${BASH_SOURCE[1]:-}"
}

# Get the script directory, safe for piped execution
# Returns: Script directory if available, current directory if piped
get_script_dir() {
    local source="${BASH_SOURCE[1]:-}"
    if [[ -n "$source" ]]; then
        cd "$(dirname "$source")" && pwd
    else
        pwd
    fi
}

# Check if script is being piped from stdin
# Returns: 0 (true) if piped, 1 (false) if not
is_piped() {
    [[ -z "${BASH_SOURCE[1]:-}" ]]
}

# Check if script is being sourced
# Returns: 0 (true) if sourced, 1 (false) if not
is_sourced() {
    [[ -n "${BASH_SOURCE[1]:-}" ]] && [[ "${BASH_SOURCE[1]}" != "${0}" ]]
}

# Check if script is being executed directly
# Returns: 0 (true) if executed, 1 (false) if not
is_executed() {
    [[ -n "${BASH_SOURCE[1]:-}" ]] && [[ "${BASH_SOURCE[1]}" == "${0}" ]]
}

# Safe main execution guard
# Usage: run_main_if_not_sourced main "$@"
run_main_if_not_sourced() {
    local main_func="$1"
    shift
    
    if [[ -z "${BASH_SOURCE[1]:-}" ]] || [[ "${BASH_SOURCE[1]}" == "${0}" ]]; then
        "$main_func" "$@"
    fi
}

# Get script directory with fallback (most common pattern)
# Usage: SCRIPT_DIR="$(get_script_dir_safe)"
get_script_dir_safe() {
    local source="${BASH_SOURCE[1]:-}"
    local script_dir
    
    if [[ -n "$source" ]]; then
        script_dir="$(cd "$(dirname "$source")" && pwd)"
    else
        # Fallback for piped execution
        script_dir="$(pwd)"
    fi
    
    echo "$script_dir"
}

# Export functions for use in other scripts
export -f get_script_path
export -f get_script_dir
export -f is_piped
export -f is_sourced
export -f is_executed
export -f run_main_if_not_sourced
export -f get_script_dir_safe
