#!/usr/bin/env bash
#
# Hyper-NixOS Script Template
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# This template demonstrates how to create new scripts or refactor existing ones
# to use the common library for improved security, efficiency, and maintainability.
#
# Usage: Copy this template and replace the placeholder sections with your logic.
#

# ============================================================================
# STEP 1: Source Common Library
# ============================================================================
# This replaces all the boilerplate: set -e, IFS, umask, PATH, trap, etc.
# It also provides: logging, require(), validation functions, and more.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}

# ============================================================================
# STEP 2: Initialize Logging
# ============================================================================
# Choose a descriptive name for the log file (will be in /var/lib/hypervisor/logs/)

init_logging "your_script_name"
log_info "Script started"

# ============================================================================
# STEP 3: Declare Script-Specific Variables
# ============================================================================
# Use readonly for constants to prevent accidental modification
# Common paths are already defined in common.sh:
#   $HYPERVISOR_ROOT, $HYPERVISOR_STATE, $HYPERVISOR_SCRIPTS,
#   $HYPERVISOR_PROFILES, $HYPERVISOR_ISOS, $HYPERVISOR_DISKS

readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_NAME="Your Script Name"

# ============================================================================
# STEP 4: Check Additional Dependencies
# ============================================================================
# Common dependencies (jq, virsh) are already checked in common.sh
# Add any additional dependencies your script needs:

require curl wget  # Example: add curl and wget if needed

# ============================================================================
# STEP 5: Load Configuration (Optional)
# ============================================================================
# Common config values are already loaded in common.sh
# Use json_get() for additional config values:

# MY_CONFIG=$(json_get "$HYPERVISOR_CONFIG" ".my_feature.setting" "default_value")

# ============================================================================
# STEP 6: Define Your Functions
# ============================================================================
# Follow these best practices:
# 1. Validate all inputs using validate_vm_name() or validate_path()
# 2. Use log_info/log_warn/log_error for logging
# 3. Use die() for fatal errors
# 4. Return meaningful exit codes

your_main_function() {
    local vm_name="$1"
    
    # Security: Validate input
    if ! validate_vm_name "$vm_name"; then
        die "Invalid VM name: $vm_name"
    fi
    
    # Efficiency: Use caching functions
    local vm_state
    vm_state=$(get_vm_state "$vm_name") || die "Failed to get VM state"
    
    log_info "Processing VM: $vm_name (state: $vm_state)"
    
    # Your logic here...
    
    success "Operation completed for $vm_name"
    return 0
}

your_list_function() {
    # Efficiency: Use built-in list functions
    local vms
    mapfile -t vms < <(list_vms "running")
    
    if [[ ${#vms[@]} -eq 0 ]]; then
        log_warn "No running VMs found"
        return 0
    fi
    
    log_info "Found ${#vms[@]} running VMs"
    
    for vm in "${vms[@]}"; do
        # Process each VM
        echo "VM: $vm"
    done
}

your_file_operation() {
    local source_file="$1"
    local dest_dir="$2"
    
    # Security: Validate paths
    if ! validate_path "$source_file"; then
        die "Invalid source path: $source_file"
    fi
    
    if ! validate_path "$dest_dir" "$HYPERVISOR_STATE"; then
        die "Invalid destination path: $dest_dir (must be under $HYPERVISOR_STATE)"
    fi
    
    # Efficiency: Use temporary files with automatic cleanup
    local temp_file
    temp_file=$(make_temp_file "processing") || die "Failed to create temp file"
    
    # Work with temp file - it will be automatically cleaned up on exit
    cp "$source_file" "$temp_file"
    # ... process temp file ...
    mv "$temp_file" "$dest_dir/"
    
    success "File operation completed"
}

# ============================================================================
# STEP 7: Parse Arguments (if needed)
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <vm_name>

$SCRIPT_NAME - Brief description of what your script does

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -d, --debug         Enable debug logging
    
Arguments:
    vm_name             Name of the virtual machine

Examples:
    $0 my-vm            Process VM 'my-vm'
    $0 -v my-vm         Process VM with verbose output

EOF
    exit 0
}

parse_arguments() {
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--debug)
                export DEBUG=true
                shift
                ;;
            -*)
                die "Unknown option: $1 (use --help for usage)"
                ;;
            *)
                # First non-option argument
                VM_NAME="$1"
                shift
                break
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "${VM_NAME:-}" ]]; then
        die "VM name is required (use --help for usage)"
    fi
    
    # Security: Validate VM name
    if ! validate_vm_name "$VM_NAME"; then
        die "Invalid VM name: $VM_NAME"
    fi
}

# ============================================================================
# STEP 8: Main Execution
# ============================================================================

main() {
    log_info "========================================"
    log_info "$SCRIPT_NAME v$SCRIPT_VERSION"
    log_info "========================================"
    
    # Parse command line arguments (if your script needs them)
    # parse_arguments "$@"
    
    # Example: Check if running as root (if needed)
    # if [[ $EUID -ne 0 ]]; then
    #     die "This script must be run as root"
    # fi
    
    # Your main logic here
    # Replace this with calls to your functions:
    
    # your_main_function "$VM_NAME"
    # your_list_function
    # your_file_operation "$source" "$dest"
    
    # Example placeholder
    log_info "Script template executed successfully"
    success "All operations completed"
    
    log_info "Script finished"
    return 0
}

# ============================================================================
# STEP 9: Entry Point
# ============================================================================
# Run main function with all arguments
# The common library handles exit traps and cleanup automatically

main "$@"

# ============================================================================
# REFACTORING CHECKLIST
# ============================================================================
# When refactoring an existing script to use this template:
#
# [ ] Remove old boilerplate (set -e, IFS, umask, PATH, trap)
# [ ] Replace require() with common library version
# [ ] Replace log() with log_info/log_warn/log_error
# [ ] Add validate_vm_name() before using VM names
# [ ] Add validate_path() before file operations
# [ ] Replace config reading with json_get()
# [ ] Use get_vm_state() instead of direct virsh calls
# [ ] Use list_vms() instead of virsh list loops
# [ ] Use make_temp_file() for temporary files
# [ ] Use die() for error handling
# [ ] Add init_logging() with script-specific name
# [ ] Test thoroughly after refactoring
#
# ============================================================================
