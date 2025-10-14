#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Main Menu (Modular Version)
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Modular boot-time console menu for VM management
#

# Get script directory
MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$MENU_DIR/.." && pwd)"

# Source common library
source "${SCRIPT_DIR}/lib/common.sh" || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}
source "${SCRIPT_DIR}/lib/exit_codes.sh"

# Source menu libraries
source "${MENU_DIR}/lib/ui_common.sh"
source "${MENU_DIR}/lib/vm_operations.sh"

# Source menu modules
source "${MENU_DIR}/modules/vm_selector.sh"
source "${MENU_DIR}/modules/system_menu.sh"
source "${MENU_DIR}/modules/admin_menu.sh"

# Initialize logging
init_logging "menu"
script_timer_start

# Script metadata for privilege checking
readonly REQUIRES_SUDO=false  # Main menu doesn't require sudo
readonly OPERATION_TYPE="menu_display"

# Configuration
readonly ROOT="/etc/hypervisor"
readonly TEMPLATE_PROFILES_DIR="$ROOT/vm_profiles"
readonly USER_PROFILES_DIR="$HYPERVISOR_PROFILES"
readonly ISOS_DIR="$HYPERVISOR_ISOS"
readonly SCRIPTS_DIR="$HYPERVISOR_SCRIPTS"
readonly LAST_VM_FILE="$HYPERVISOR_STATE/last_vm"
readonly OWNER_FILTER_FILE="$HYPERVISOR_STATE/owner_filter"
readonly BRANDING="$HYPERVISOR_BRANDING"

# Load configuration
AUTOSTART_SECS=$(json_get "$HYPERVISOR_CONFIG" ".features.autostart_timeout_sec" "5")
BOOT_SELECTOR_ENABLE=$(json_get "$HYPERVISOR_CONFIG" ".features.boot_selector_enable" "false")
BOOT_SELECTOR_TIMEOUT=$(json_get "$HYPERVISOR_CONFIG" ".features.boot_selector_timeout_sec" "8")
BOOT_SELECTOR_EXIT_AFTER_START=$(json_get "$HYPERVISOR_CONFIG" ".features.boot_selector_exit_after_start" "true")

# Load owner filter
if [[ -z "${OWNER_FILTER:-}" && -f "$OWNER_FILTER_FILE" ]]; then
    OWNER_FILTER=$(cat "$OWNER_FILTER_FILE" 2>/dev/null || true)
    export OWNER_FILTER
fi

# Ensure required directories exist
mkdir -p "$USER_PROFILES_DIR" "$ISOS_DIR"

log_info "Menu started (modular version)"

# Main menu function
show_main_menu() {
    local entries=()
    local owner_filter="${OWNER_FILTER:-}"
    
    # Get current user and privilege info
    local current_user=$(get_actual_user)
    local sudo_status=""
    local privilege_info=""
    
    if is_running_as_sudo; then
        sudo_status=" [SUDO MODE]"
        privilege_info="Running with administrator privileges"
    else
        # Check group membership
        if groups 2>/dev/null | grep -q "\blibvirtd\b"; then
            privilege_info="VM management enabled"
        else
            privilege_info="Limited access - add user to libvirtd group"
        fi
    fi
    
    # Add user info at top
    entries+=("__HEADER_USER__" "═══ User: $current_user$sudo_status ═══")
    entries+=("__PRIVILEGE_INFO__" "◦ $privilege_info")
    entries+=("" "")
    
    # Get VM list
    shopt -s nullglob
    for f in "$USER_PROFILES_DIR"/*.json; do
        local name
        name=$(jq -r '.name // empty' "$f" 2>/dev/null || true)
        [[ -z "$name" ]] && name=$(basename "$f" .json)
        
        local owner
        owner=$(jq -r '.owner // empty' "$f" 2>/dev/null || true)
        
        if [[ -n "$owner_filter" && "$owner" != "$owner_filter" ]]; then
            continue
        fi
        
        if [[ -n "$owner" && "$owner" != "null" ]]; then
            entries+=("$f" "VM: $name (owner: $owner)")
        else
            entries+=("$f" "VM: $name")
        fi
    done
    shopt -u nullglob
    
    # Add menu options with clear privilege indicators
    entries+=("__VM_SELECTOR__" "← Back to VM Boot Selector")
    entries+=("" "")
    entries+=("__VM_OPS__" "▸ VM Operations (No sudo required)")
    entries+=("__SYS_CONFIG__" "▸ System Configuration [SUDO REQUIRED]")
    entries+=("__ADMIN__" "▸ Admin Management [SUDO REQUIRED]")
    entries+=("" "")
    
    # Donation option
    local donate_enabled
    donate_enabled=$(json_get "$HYPERVISOR_CONFIG" ".donate.enable" "true")
    if [[ "$donate_enabled" == "true" || "$donate_enabled" == "True" ]]; then
        entries+=("__DONATE__" "❤ Support development (donate)")
    fi
    
    entries+=("" "")
    
    # Owner filter options
    if [[ -n "$owner_filter" ]]; then
        entries+=("__CLEAR_OWNER_FILTER__" "Show all owners (clear filter)")
    else
        entries+=("__SET_OWNER_FILTER__" "Filter by owner…")
    fi
    
    entries+=("" "")
    entries+=("__DESKTOP__" "Start GUI Desktop session [sudo]")
    entries+=("__EXIT__" "Exit")
    
    # Show menu
    show_menu "$BRANDING - Main Menu" \
        "Select a VM to start, or choose an action" \
        "${entries[@]}"
}

# VM operations menu
show_vm_operations_menu() {
    while true; do
        local choices=(
            0 "🚀 Install VMs - Complete guided workflow (RECOMMENDED)"
            1 "Create VM wizard"
            2 "ISO management"
            3 "VM dashboard"
            4 "Clone VM"
            5 "Migrate VM"
            6 "Snapshots & backups"
            7 "Bulk operations"
            8 "Resource optimization"
            "" ""
            9 "← Back"
        )
        
        local choice
        choice=$(show_menu "$BRANDING - VM Operations" \
            "Select VM operation:" \
            "${choices[@]}") || return 0
        
        case $choice in
            0) "$SCRIPTS_DIR/install_vm_workflow.sh" ;;
            1) "$SCRIPTS_DIR/create_vm_wizard.sh" ;;
            2) "$SCRIPTS_DIR/iso_manager.sh" ;;
            3) "$SCRIPTS_DIR/vm_dashboard.sh" ;;
            4) "$SCRIPTS_DIR/vm_clone.sh" ;;
            5) "$SCRIPTS_DIR/migrate_vm.sh" ;;
            6) "$SCRIPTS_DIR/snapshots_backups.sh" ;;
            7) "$SCRIPTS_DIR/bulk_operations.sh" ;;
            8) "$SCRIPTS_DIR/vm_resource_optimizer.sh" ;;
            9|"") return 0 ;;
        esac
    done
}

# Handle owner filter
handle_owner_filter() {
    local action="$1"
    
    case "$action" in
        set)
            local owner
            owner=$(show_input "Set Owner Filter" \
                "Enter owner name to filter by:" \
                "$OWNER_FILTER") || return 0
            
            if [[ -n "$owner" ]]; then
                echo "$owner" > "$OWNER_FILTER_FILE"
                export OWNER_FILTER="$owner"
                log_info "Owner filter set to: $owner"
            fi
            ;;
        clear)
            rm -f "$OWNER_FILTER_FILE"
            unset OWNER_FILTER
            log_info "Owner filter cleared"
            ;;
    esac
}

# Main loop
main() {
    # Check if boot selector should run
    if [[ "$BOOT_SELECTOR_ENABLE" == "true" ]] && [[ -z "${SKIP_BOOT_SELECTOR:-}" ]]; then
        show_vm_boot_selector
    fi
    
    # Main menu loop
    while true; do
        local selection
        selection=$(show_main_menu) || true
        
        case "$selection" in
            *.json)
                # Start selected VM
                start_vm "$selection"
                ;;
            __VM_SELECTOR__)
                show_vm_boot_selector
                ;;
            __VM_OPS__)
                show_vm_operations_menu
                ;;
            __SYS_CONFIG__)
                # System config requires sudo
                if ! is_running_as_sudo; then
                    show_sudo_warning "System Configuration" \
                        "Configure system-wide settings, services, and network"
                    exec sudo "$0" --system-config
                else
                    show_system_config_menu
                fi
                ;;
            __ADMIN__)
                # Admin menu requires sudo
                if ! is_running_as_sudo; then
                    show_sudo_warning "Admin Management" \
                        "Access administrative functions and system management"
                    exec sudo "$0" --admin
                else
                    show_admin_menu
                fi
                ;;
            __DONATE__)
                "$SCRIPTS_DIR/donate.sh"
                ;;
            __SET_OWNER_FILTER__)
                handle_owner_filter set
                ;;
            __CLEAR_OWNER_FILTER__)
                handle_owner_filter clear
                ;;
            __DESKTOP__)
                if show_yesno "Start Desktop" "Start GUI desktop session?"; then
                    show_sudo_warning "Desktop Session" \
                        "Start the graphical desktop environment"
                    sudo systemctl start display-manager.service
                    clear_screen
                    exit 0
                fi
                ;;
            __EXIT__|"")
                break
                ;;
        esac
    done
    
    script_timer_end "Menu session"
    log_info "Menu exited normally"
}

# Signal handlers
cleanup() {
    local exit_code=$?
    script_timer_end "Menu session (interrupted)"
    log_info "Menu cleanup completed"
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Run main function
main "$@"