#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Enhanced UI Functions for Better User Experience
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Advanced UI features for improved usability and guidance
#

# UI State Management
declare -A UI_CONTEXT
UI_CONTEXT[current_menu]="main"
UI_CONTEXT[help_enabled]=true
UI_CONTEXT[tooltips_enabled]=true
UI_CONTEXT[confirm_dangerous]=true

# Colors and Icons
declare -A UI_ICONS
UI_ICONS[info]="ℹ️"
UI_ICONS[warning]="⚠️"
UI_ICONS[error]="❌"
UI_ICONS[success]="✅"
UI_ICONS[question]="❓"
UI_ICONS[tip]="💡"
UI_ICONS[security]="🔒"
UI_ICONS[dangerous]="⚡"
UI_ICONS[vm_running]="🟢"
UI_ICONS[vm_stopped]="🔴"
UI_ICONS[vm_paused]="🟡"
UI_ICONS[new]="🆕"
UI_ICONS[recommended]="⭐"
UI_ICONS[beta]="🔧"

# Enhanced menu with help footer
show_menu_with_help() {
    local title="$1"
    local text="$2"
    local help_text="$3"
    shift 3
    local entries=("$@")
    
    # Add help text to menu
    local full_text="$text"
    if [[ -n "$help_text" && "${UI_CONTEXT[help_enabled]}" == "true" ]]; then
        full_text="$text\n\n${UI_ICONS[tip]} Tip: $help_text"
    fi
    
    # Add navigation help to title
    local full_title="$title | ↑↓:Navigate ↵:Select ←:Back F1:Help"
    
    $DIALOG --title "$full_title" --menu "$full_text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_LIST_HEIGHT \
        "${entries[@]}" 3>&1 1>&2 2>&3
}

# Show a guided wizard with steps
show_wizard() {
    local wizard_name="$1"
    local total_steps="$2"
    local current_step="$3"
    local step_title="$4"
    local step_text="$5"
    shift 5
    
    # Create step indicator
    local step_indicator="Step $current_step of $total_steps"
    local progress_bar=""
    for ((i=1; i<=total_steps; i++)); do
        if [[ $i -eq $current_step ]]; then
            progress_bar+="[●]"
        elif [[ $i -lt $current_step ]]; then
            progress_bar+="[✓]"
        else
            progress_bar+="[ ]"
        fi
    done
    
    # Enhanced title with progress
    local full_title="$wizard_name | $step_indicator"
    local full_text="$progress_bar\n\n$step_title\n\n$step_text"
    
    "$@" --title "$full_title" --msgbox "$full_text"
}

# Show confirmation with severity levels
show_confirmation() {
    local severity="$1"  # info, warning, danger
    local title="$2"
    local text="$3"
    local height="${4:-12}"
    local width="${5:-60}"
    
    # Add icon based on severity
    local icon=""
    local extra_warning=""
    case "$severity" in
        info)
            icon="${UI_ICONS[info]}"
            ;;
        warning)
            icon="${UI_ICONS[warning]}"
            extra_warning="\n\nProceed with caution."
            ;;
        danger)
            icon="${UI_ICONS[dangerous]}"
            extra_warning="\n\n⚠️  This action cannot be undone! ⚠️"
            height=$((height + 2))
            ;;
    esac
    
    local full_text="$icon $text$extra_warning"
    
    # For dangerous operations, require explicit confirmation
    if [[ "$severity" == "danger" && "${UI_CONTEXT[confirm_dangerous]}" == "true" ]]; then
        # First confirmation
        if ! $DIALOG --title "$title" --yesno "$full_text" "$height" "$width"; then
            return 1
        fi
        
        # Second confirmation for dangerous operations
        local confirm_text="Are you ABSOLUTELY SURE?\n\nType 'yes' to confirm this dangerous operation."
        local user_input
        user_input=$($DIALOG --title "Final Confirmation Required" \
            --inputbox "$confirm_text" 10 60 3>&1 1>&2 2>&3) || return 1
        
        if [[ "${user_input,,}" != "yes" ]]; then
            show_info "Cancelled" "Operation cancelled - confirmation not received."
            return 1
        fi
    else
        $DIALOG --title "$title" --yesno "$full_text" "$height" "$width"
    fi
}

# Progress dialog with detailed status
show_progress_detailed() {
    local title="$1"
    local main_text="$2"
    local sub_text="$3"
    local percent="$4"
    local height="${5:-10}"
    local width="${6:-70}"
    
    # Create detailed progress text
    local progress_text="$main_text\n\n"
    
    # Add progress bar visualization
    local bar_length=50
    local filled=$((percent * bar_length / 100))
    local empty=$((bar_length - filled))
    progress_text+="["
    for ((i=0; i<filled; i++)); do progress_text+="█"; done
    for ((i=0; i<empty; i++)); do progress_text+="░"; done
    progress_text+="] $percent%\n\n"
    
    # Add sub-text if provided
    [[ -n "$sub_text" ]] && progress_text+="Status: $sub_text"
    
    echo "$percent" | $DIALOG --title "$title" --gauge "$progress_text" "$height" "$width" "$percent"
}

# Show tooltip/hint
show_tooltip() {
    local text="$1"
    local timeout="${2:-3}"
    
    if [[ "${UI_CONTEXT[tooltips_enabled]}" == "true" ]]; then
        $DIALOG --title "${UI_ICONS[tip]} Hint" --infobox "$text" 6 50
        sleep "$timeout"
    fi
}

# Context-sensitive help
show_context_help() {
    local context="${1:-${UI_CONTEXT[current_menu]}}"
    local help_file="/etc/hypervisor/docs/help/${context}.txt"
    
    if [[ -f "$help_file" ]]; then
        $DIALOG --title "${UI_ICONS[question]} Help - $context" \
            --textbox "$help_file" 20 70
    else
        # Inline help based on context
        local help_text=""
        case "$context" in
            main)
                help_text="Main Menu Help\n\n"
                help_text+="• Select a VM to start it immediately\n"
                help_text+="• Use arrow keys to navigate options\n"
                help_text+="• Press Enter to select an option\n"
                help_text+="• Press Esc or select Exit to quit\n\n"
                help_text+="Keyboard Shortcuts:\n"
                help_text+="  F1 - Show this help\n"
                help_text+="  F2 - Quick VM status\n"
                help_text+="  F3 - System health check\n"
                help_text+="  Ctrl+C - Emergency exit"
                ;;
            vm_operations)
                help_text="VM Operations Help\n\n"
                help_text+="${UI_ICONS[recommended]} Recommended for new users:\n"
                help_text+="  'Install VMs' - Guided workflow\n\n"
                help_text+="Common Tasks:\n"
                help_text+="• Create VM - Build new virtual machine\n"
                help_text+="• ISO Management - Download/verify OS images\n"
                help_text+="• VM Dashboard - Monitor all VMs\n"
                help_text+="• Snapshots - Backup VM states\n"
                ;;
            security)
                help_text="${UI_ICONS[security]} Security Information\n\n"
                help_text+="Operations marked with [sudo] require admin rights.\n\n"
                help_text+="Security Levels:\n"
                help_text+="• ${UI_ICONS[info]} Info - Safe operations\n"
                help_text+="• ${UI_ICONS[warning]} Warning - Review effects\n"
                help_text+="• ${UI_ICONS[dangerous]} Danger - Irreversible actions\n\n"
                help_text+="Always verify dangerous operations!"
                ;;
        esac
        
        show_info "Help - $context" "$help_text" 20 70
    fi
}

# Enhanced input with validation
show_input_validated() {
    local title="$1"
    local text="$2"
    local default="$3"
    local validator="$4"  # Function name to validate input
    local error_msg="${5:-Invalid input. Please try again.}"
    local height="${6:-8}"
    local width="${7:-60}"
    
    while true; do
        local input
        input=$($DIALOG --title "$title" --inputbox "$text" \
            "$height" "$width" "$default" 3>&1 1>&2 2>&3) || return 1
        
        # Validate input if validator provided
        if [[ -n "$validator" ]]; then
            if $validator "$input"; then
                echo "$input"
                return 0
            else
                show_error "Invalid Input" "$error_msg"
                default="$input"  # Keep user's input as default
            fi
        else
            echo "$input"
            return 0
        fi
    done
}

# Show options with descriptions
show_descriptive_menu() {
    local title="$1"
    local text="$2"
    shift 2
    
    # Build menu with descriptions
    local entries=()
    local descriptions=()
    
    while [[ $# -gt 0 ]]; do
        local key="$1"
        local label="$2"
        local description="${3:-}"
        shift 3 || shift 2
        
        entries+=("$key" "$label")
        [[ -n "$description" ]] && descriptions+=("$key:$description")
    done
    
    # Show menu with description footer
    local selected
    selected=$(show_menu "$title" "$text" "${entries[@]}") || return 1
    
    echo "$selected"
}

# Show VM status with visual indicators
format_vm_status() {
    local vm_name="$1"
    local state="$2"
    local cpu="${3:-0}"
    local memory="${4:-0}"
    
    local status_icon=""
    local status_color=""
    
    case "$state" in
        running)
            status_icon="${UI_ICONS[vm_running]}"
            status_color="32"  # Green
            ;;
        "shut off"|stopped)
            status_icon="${UI_ICONS[vm_stopped]}"
            status_color="31"  # Red
            ;;
        paused)
            status_icon="${UI_ICONS[vm_paused]}"
            status_color="33"  # Yellow
            ;;
        *)
            status_icon="❔"
            status_color="37"  # White
            ;;
    esac
    
    # Format with colors if terminal supports it
    if [[ -t 1 ]]; then
        echo -e "$status_icon \033[${status_color}m$vm_name\033[0m - CPU: ${cpu}% MEM: ${memory}%"
    else
        echo "$status_icon $vm_name - CPU: ${cpu}% MEM: ${memory}%"
    fi
}

# Show error with suggestions
show_error_with_help() {
    local title="$1"
    local error_msg="$2"
    local suggestions="$3"
    local height="${4:-15}"
    local width="${5:-70}"
    
    local full_text="${UI_ICONS[error]} Error: $error_msg"
    
    if [[ -n "$suggestions" ]]; then
        full_text+="\n\n${UI_ICONS[tip]} Suggestions:\n$suggestions"
    fi
    
    full_text+="\n\nPress OK to continue or check the logs for more details."
    
    $DIALOG --title "$title" --msgbox "$full_text" "$height" "$width"
}

# Show success with next steps
show_success_with_next() {
    local title="$1"
    local success_msg="$2"
    local next_steps="$3"
    local height="${4:-12}"
    local width="${5:-70}"
    
    local full_text="${UI_ICONS[success]} Success!\n\n$success_msg"
    
    if [[ -n "$next_steps" ]]; then
        full_text+="\n\n${UI_ICONS[tip]} What's next:\n$next_steps"
    fi
    
    $DIALOG --title "$title" --msgbox "$full_text" "$height" "$width"
}

# Interactive mode selector
show_mode_selector() {
    local title="$1"
    local text="$2"
    shift 2
    
    local modes=()
    while [[ $# -gt 0 ]]; do
        local mode="$1"
        local label="$2"
        local description="$3"
        local recommended="${4:-false}"
        shift 4 || shift 3
        
        local display_label="$label"
        [[ "$recommended" == "true" ]] && display_label="${UI_ICONS[recommended]} $label (Recommended)"
        
        modes+=("$mode" "$display_label")
    done
    
    show_menu "$title" "$text" "${modes[@]}"
}

# Show loading spinner
show_loading() {
    local pid="$1"
    local message="${2:-Please wait...}"
    
    local spinner=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
    
    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${spinner[@]}"; do
            printf "\r%s %s" "$frame" "$message"
            sleep 0.1
        done
    done
    
    printf "\r%s\n" "✓ Done!"
}

# Set UI context
set_ui_context() {
    local key="$1"
    local value="$2"
    UI_CONTEXT[$key]="$value"
}

# Get UI context
get_ui_context() {
    local key="$1"
    echo "${UI_CONTEXT[$key]:-}"
}