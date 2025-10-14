#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# User Feedback and Error Handling
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Enhanced error messages and user feedback systems
#

# Error context tracking
declare -A ERROR_CONTEXT
ERROR_CONTEXT[last_operation]=""
ERROR_CONTEXT[last_error]=""
ERROR_CONTEXT[error_count]=0

# Common error messages with helpful suggestions
declare -A ERROR_SUGGESTIONS
ERROR_SUGGESTIONS[vm_not_found]="• Check VM name spelling
• Use VM Dashboard to see all VMs
• VM may have been deleted"

ERROR_SUGGESTIONS[disk_full]="• Delete old snapshots
• Remove unused VMs
• Clean up ISO files
• Run Admin → System Maintenance"

ERROR_SUGGESTIONS[permission_denied]="• This operation requires sudo
• Check if you're in the correct groups
• Try: sudo usermod -aG libvirtd,kvm $USER"

ERROR_SUGGESTIONS[network_error]="• Check internet connection
• Verify firewall settings
• Try again later
• Check proxy settings"

ERROR_SUGGESTIONS[vm_already_running]="• VM is already started
• Check VM Dashboard for status
• Try stopping first if needed"

ERROR_SUGGESTIONS[invalid_input]="• Check the format requirements
• See examples in help (F1)
• Use suggested values when available"

# Enhanced error display with context
show_detailed_error() {
    local error_type="$1"
    local error_msg="$2"
    local operation="${3:-${ERROR_CONTEXT[last_operation]}}"
    local suggestions="${ERROR_SUGGESTIONS[$error_type]:-}"
    local log_location="/var/lib/hypervisor/logs/menu.log"
    
    # Increment error count
    ((ERROR_CONTEXT[error_count]++))
    ERROR_CONTEXT[last_error]="$error_msg"
    
    # Build detailed error message
    local full_msg="${UI_ICONS[error]} Error Details:\n\n"
    full_msg+="Operation: $operation\n"
    full_msg+="Error: $error_msg\n"
    
    if [[ -n "$suggestions" ]]; then
        full_msg+="\n${UI_ICONS[tip]} Possible Solutions:\n$suggestions\n"
    fi
    
    full_msg+="\n${UI_ICONS[info]} Additional Info:\n"
    full_msg+="• Error #${ERROR_CONTEXT[error_count]} in this session\n"
    full_msg+="• Check logs at: $log_location\n"
    full_msg+="• Press F1 for help\n"
    
    # Add recovery options
    full_msg+="\nWhat would you like to do?"
    
    # Log the error
    log_error "[$error_type] $error_msg (Operation: $operation)"
    
    # Show error with options
    local choices=(
        retry "🔄 Retry Operation"
        help "${UI_ICONS[question]} Get Help"
        logs "📋 View Logs"
        continue "➡️  Continue Anyway"
    )
    
    local action
    action=$(show_menu "Error Occurred" "$full_msg" "${choices[@]}") || return 1
    
    case "$action" in
        retry)
            return 2  # Special code for retry
            ;;
        help)
            show_context_help "$operation"
            return 1
            ;;
        logs)
            view_recent_logs
            return 1
            ;;
        continue)
            return 0
            ;;
    esac
}

# Progress tracking for long operations
run_with_progress() {
    local operation="$1"
    local command="$2"
    local estimated_time="${3:-10}"  # seconds
    
    # Set operation context
    ERROR_CONTEXT[last_operation]="$operation"
    
    # Create temporary file for command output
    local output_file
    output_file=$(mktemp)
    local status_file
    status_file=$(mktemp)
    
    # Run command in background
    (
        $command >"$output_file" 2>&1
        echo $? >"$status_file"
    ) &
    local cmd_pid=$!
    
    # Show progress
    local elapsed=0
    while kill -0 "$cmd_pid" 2>/dev/null; do
        local percent=$((elapsed * 100 / estimated_time))
        [[ $percent -gt 100 ]] && percent=100
        
        local status="Processing... ($elapsed/$estimated_time seconds)"
        show_progress_detailed "$operation" \
            "Please wait while the operation completes" \
            "$status" \
            "$percent" \
            10 70
        
        sleep 1
        ((elapsed++))
    done
    
    # Get command result
    wait "$cmd_pid"
    local exit_code
    exit_code=$(cat "$status_file")
    local output
    output=$(cat "$output_file")
    
    # Cleanup
    rm -f "$output_file" "$status_file"
    
    # Handle result
    if [[ $exit_code -eq 0 ]]; then
        show_operation_success "$operation" "$output"
        return 0
    else
        show_operation_failure "$operation" "$output" "$exit_code"
        return $exit_code
    fi
}

# Show operation success with details
show_operation_success() {
    local operation="$1"
    local details="${2:-}"
    
    local msg="Operation completed successfully!"
    
    if [[ -n "$details" ]]; then
        # Extract key information from output
        local summary
        summary=$(echo "$details" | grep -E "(Created|Started|Completed|Success)" | head -5)
        if [[ -n "$summary" ]]; then
            msg+="\n\nDetails:\n$summary"
        fi
    fi
    
    # Suggest next steps based on operation
    local next_steps=""
    case "$operation" in
        "Create VM")
            next_steps="• Start the VM from main menu
• Configure VM settings
• Install operating system"
            ;;
        "Start VM")
            next_steps="• Connect to VM console
• Check VM Dashboard for status
• Configure VM networking"
            ;;
        "Backup VM")
            next_steps="• Verify backup in storage
• Test restore procedure
• Schedule automatic backups"
            ;;
    esac
    
    show_success_with_next "$operation Complete" "$msg" "$next_steps"
}

# Show operation failure with recovery options
show_operation_failure() {
    local operation="$1"
    local error_output="$2"
    local exit_code="$3"
    
    # Try to identify error type
    local error_type="unknown"
    local error_msg="Operation failed with exit code $exit_code"
    
    # Parse common error patterns
    if [[ "$error_output" =~ "not found" ]]; then
        error_type="vm_not_found"
        error_msg="Resource not found"
    elif [[ "$error_output" =~ "Permission denied" ]]; then
        error_type="permission_denied"
        error_msg="Insufficient permissions"
    elif [[ "$error_output" =~ "No space left" ]]; then
        error_type="disk_full"
        error_msg="Disk space exhausted"
    elif [[ "$error_output" =~ "already exists" ]]; then
        error_type="already_exists"
        error_msg="Resource already exists"
    elif [[ "$error_output" =~ "Connection refused" ]]; then
        error_type="network_error"
        error_msg="Connection failed"
    fi
    
    # Extract meaningful error from output
    local clean_error
    clean_error=$(echo "$error_output" | grep -E "(Error|Failed|Cannot)" | head -3)
    if [[ -n "$clean_error" ]]; then
        error_msg+="\n\n$clean_error"
    fi
    
    show_detailed_error "$error_type" "$error_msg" "$operation"
}

# View recent logs
view_recent_logs() {
    local log_file="/var/lib/hypervisor/logs/menu.log"
    
    if [[ -f "$log_file" ]]; then
        # Get last 50 lines of errors and warnings
        local recent_issues
        recent_issues=$(grep -E "(ERROR|WARN)" "$log_file" | tail -50)
        
        if [[ -n "$recent_issues" ]]; then
            echo "$recent_issues" | $DIALOG --title "Recent Issues" \
                --programbox "Recent Errors and Warnings:" 20 80
        else
            show_info "No Issues" "No recent errors or warnings found in logs."
        fi
    else
        show_error "Log Not Found" "Log file not found at: $log_file"
    fi
}

# Input validation feedback
provide_input_feedback() {
    local input="$1"
    local validation_type="$2"
    local is_valid="$3"
    local feedback=""
    
    if [[ "$is_valid" == "true" ]]; then
        feedback="${UI_ICONS[success]} Valid $validation_type"
    else
        feedback="${UI_ICONS[error]} Invalid $validation_type\n"
        
        # Provide specific feedback based on type
        case "$validation_type" in
            vm_name)
                feedback+="VM names must:
• Use only letters, numbers, dash, underscore
• Not contain spaces or special characters
• Not start with a number
• Be 1-63 characters long

Examples: my-vm, test_vm_01, ubuntu-desktop"
                ;;
            ip_address)
                feedback+="IP addresses must be in format: X.X.X.X
where X is 0-255

Examples: 192.168.1.100, 10.0.0.50"
                ;;
            disk_size)
                feedback+="Disk size format: NUMBER[UNIT]
Units: M=MB, G=GB, T=TB

Examples: 20G, 500M, 1.5T"
                ;;
            memory_size)
                feedback+="Memory size must be:
• At least 512 (MB)
• In increments of 128
• Number only (MB assumed)

Examples: 1024, 2048, 4096"
                ;;
        esac
    fi
    
    # Show feedback as tooltip
    show_tooltip "$feedback" 4
}

# Confirmation with undo information
show_confirmation_with_undo() {
    local title="$1"
    local action_desc="$2"
    local undo_info="$3"
    local severity="${4:-warning}"
    
    local full_text="$action_desc\n\n"
    
    if [[ -n "$undo_info" ]]; then
        full_text+="${UI_ICONS[info]} Undo Information:\n$undo_info\n\n"
    fi
    
    full_text+="Do you want to proceed?"
    
    show_confirmation "$severity" "$title" "$full_text"
}

# Status feedback for background operations
show_background_status() {
    local operation="$1"
    local status_file="$2"
    local check_interval="${3:-2}"
    
    while [[ -f "$status_file" ]]; do
        local status
        status=$(cat "$status_file" 2>/dev/null || echo "Working...")
        
        show_infobox "$operation Status" "$status" 6 50
        sleep "$check_interval"
    done
}

# User preference tracking
save_user_preference() {
    local key="$1"
    local value="$2"
    local pref_file="$HYPERVISOR_STATE/user_preferences.conf"
    
    # Create or update preference
    if grep -q "^$key=" "$pref_file" 2>/dev/null; then
        sed -i "s/^$key=.*/$key=$value/" "$pref_file"
    else
        echo "$key=$value" >> "$pref_file"
    fi
}

# Get user preference
get_user_preference() {
    local key="$1"
    local default="$2"
    local pref_file="$HYPERVISOR_STATE/user_preferences.conf"
    
    if [[ -f "$pref_file" ]]; then
        grep "^$key=" "$pref_file" | cut -d'=' -f2- || echo "$default"
    else
        echo "$default"
    fi
}

# Show first-time tips
show_first_time_tip() {
    local feature="$1"
    local tip_key="tip_shown_$feature"
    
    if [[ "$(get_user_preference "$tip_key" "false")" == "false" ]]; then
        local tip_text=""
        case "$feature" in
            vm_creation)
                tip_text="First time creating a VM?

${UI_ICONS[tip]} Tips for success:
• Start with 2GB RAM and 20GB disk
• Use NAT networking for internet access
• Take a snapshot after OS installation
• Press F1 anytime for detailed help"
                ;;
            snapshots)
                tip_text="Using snapshots for the first time?

${UI_ICONS[tip]} Best practices:
• Snapshot before major changes
• Name snapshots descriptively
• Don't keep too many (uses disk space)
• Test restore procedure occasionally"
                ;;
        esac
        
        if [[ -n "$tip_text" ]]; then
            show_info "Helpful Tip" "$tip_text" 12 60
            save_user_preference "$tip_key" "true"
        fi
    fi
}