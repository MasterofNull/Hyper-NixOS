#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Menu UI Common Functions
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Shared UI functions for menu system
#

# Dialog configuration
: "${DIALOG:=whiptail}"
export DIALOG

# Common dialog dimensions
readonly DIALOG_HEIGHT=22
readonly DIALOG_WIDTH=90
readonly DIALOG_LIST_HEIGHT=14

# Show a menu dialog
show_menu() {
    local title="$1"
    local text="$2"
    shift 2
    local entries=("$@")
    
    $DIALOG --title "$title" --menu "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_LIST_HEIGHT \
        "${entries[@]}" 3>&1 1>&2 2>&3
}

# Show a yes/no dialog
show_yesno() {
    local title="$1"
    local text="$2"
    local height="${3:-8}"
    local width="${4:-60}"
    
    $DIALOG --title "$title" --yesno "$text" "$height" "$width"
}

# Show an info message
show_info() {
    local title="$1"
    local text="$2"
    local height="${3:-8}"
    local width="${4:-60}"
    
    $DIALOG --title "$title" --msgbox "$text" "$height" "$width"
}

# Show an input dialog
show_input() {
    local title="$1"
    local text="$2"
    local default="${3:-}"
    local height="${4:-8}"
    local width="${5:-60}"
    
    $DIALOG --title "$title" --inputbox "$text" "$height" "$width" "$default" 3>&1 1>&2 2>&3
}

# Show a password dialog
show_password() {
    local title="$1"
    local text="$2"
    local height="${3:-8}"
    local width="${4:-60}"
    
    $DIALOG --title "$title" --passwordbox "$text" "$height" "$width" 3>&1 1>&2 2>&3
}

# Show a checklist
show_checklist() {
    local title="$1"
    local text="$2"
    local height="$3"
    local width="$4"
    local list_height="$5"
    shift 5
    local items=("$@")
    
    $DIALOG --title "$title" --checklist "$text" \
        "$height" "$width" "$list_height" \
        "${items[@]}" 3>&1 1>&2 2>&3
}

# Show a radiolist
show_radiolist() {
    local title="$1"
    local text="$2"
    local height="$3"
    local width="$4"
    local list_height="$5"
    shift 5
    local items=("$@")
    
    $DIALOG --title "$title" --radiolist "$text" \
        "$height" "$width" "$list_height" \
        "${items[@]}" 3>&1 1>&2 2>&3
}

# Show a progress gauge
show_progress() {
    local title="$1"
    local text="$2"
    local percent="$3"
    local height="${4:-8}"
    local width="${5:-60}"
    
    echo "$percent" | $DIALOG --title "$title" --gauge "$text" "$height" "$width" "$percent"
}

# Show an infobox (no wait)
show_infobox() {
    local title="$1"
    local text="$2"
    local height="${3:-8}"
    local width="${4:-60}"
    
    $DIALOG --title "$title" --infobox "$text" "$height" "$width"
}

# Clear the screen
clear_screen() {
    clear
}

# Wait for keypress
wait_for_key() {
    local message="${1:-Press any key to continue...}"
    echo -n "$message"
    read -n 1 -s -r
    echo
}