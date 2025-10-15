#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS GUI Setup Wizard
# Provides graphical interface for system configuration
#

set -euo pipefail

# Use zenity for GUI if available, fallback to whiptail
if command -v zenity >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    GUI_MODE="zenity"
elif command -v whiptail >/dev/null 2>&1; then
    GUI_MODE="whiptail"
else
    echo "Error: No GUI tool available (zenity or whiptail required)"
    exit 1
fi

# Configuration
WIZARD_STATE="/var/lib/hypervisor/.wizard-state"
SELECTED_PROFILE=""
SELECTED_FEATURES=()
ENABLE_GUI_AFTER=false

# GUI wrapper functions
show_info() {
    local title="$1"
    local message="$2"
    
    case "$GUI_MODE" in
        zenity)
            zenity --info --title="$title" --text="$message" --width=500
            ;;
        whiptail)
            whiptail --title "$title" --msgbox "$message" 20 70
            ;;
    esac
}

show_question() {
    local title="$1"
    local message="$2"
    
    case "$GUI_MODE" in
        zenity)
            zenity --question --title="$title" --text="$message" --width=400
            ;;
        whiptail)
            whiptail --title "$title" --yesno "$message" 12 60
            ;;
    esac
}

show_list() {
    local title="$1"
    local message="$2"
    shift 2
    local options=("$@")
    
    case "$GUI_MODE" in
        zenity)
            local zen_opts=()
            for opt in "${options[@]}"; do
                zen_opts+=("$opt" "$opt")
            done
            zenity --list --title="$title" --text="$message" \
                --column="Option" --column="Description" \
                --width=600 --height=400 \
                "${zen_opts[@]}"
            ;;
        whiptail)
            local items=()
            for i in "${!options[@]}"; do
                items+=("$((i+1))" "${options[$i]}")
            done
            local choice
            choice=$(whiptail --title "$title" --menu "$message" 20 70 10 "${items[@]}" 3>&1 1>&2 2>&3)
            [[ -n "$choice" ]] && echo "${options[$((choice-1))]}"
            ;;
    esac
}

show_checklist() {
    local title="$1"
    local message="$2"
    shift 2
    local options=("$@")
    
    case "$GUI_MODE" in
        zenity)
            local zen_opts=()
            for opt in "${options[@]}"; do
                zen_opts+=("FALSE" "$opt" "$opt")
            done
            zenity --list --title="$title" --text="$message" \
                --checklist --separator="|" \
                --column="Select" --column="Feature" --column="Description" \
                --width=700 --height=500 \
                "${zen_opts[@]}"
            ;;
        whiptail)
            local items=()
            for opt in "${options[@]}"; do
                items+=("$opt" "$opt" "OFF")
            done
            whiptail --title "$title" --checklist "$message" 20 70 12 "${items[@]}" 3>&1 1>&2 2>&3
            ;;
    esac
}

# Step 1: Welcome
show_welcome() {
    show_info "Hyper-NixOS Setup Wizard" \
"Welcome to Hyper-NixOS!

This wizard will help you configure your hypervisor system.

You will be able to:
• Select a system profile (tier)
• Choose optional features
• Configure networking
• Set up storage
• Configure security policies

The wizard will then build your customized system.

Click OK to continue."
}

# Step 2: Profile Selection
select_profile() {
    local profiles=(
        "minimal - Basic VM management (2GB RAM)"
        "standard - Common features (4GB RAM)"
        "enhanced - Advanced features (8GB RAM)"
        "professional - Full features (16GB RAM)"
        "enterprise - All features (32GB RAM)"
    )
    
    local selected
    selected=$(show_list "Select System Profile" \
        "Choose the system tier that matches your needs:" \
        "${profiles[@]}")
    
    # Extract profile name
    SELECTED_PROFILE="${selected%% -*}"
    
    if [[ -z "$SELECTED_PROFILE" ]]; then
        show_info "No Selection" "You must select a profile. Using 'standard' as default."
        SELECTED_PROFILE="standard"
    fi
}

# Step 3: Feature Selection
select_features() {
    local available_features=()
    
    # Define features based on selected profile
    case "$SELECTED_PROFILE" in
        minimal)
            available_features=(
                "web-dashboard - Web-based VM management"
                "basic-monitoring - System resource monitoring"
                "vm-templates - Pre-configured VM templates"
            )
            ;;
        standard)
            available_features=(
                "web-dashboard - Web-based VM management"
                "monitoring-stack - Prometheus + Grafana"
                "vm-templates - Pre-configured VM templates"
                "auto-backups - Automated VM backups"
                "network-isolation - Basic network isolation"
            )
            ;;
        enhanced|professional|enterprise)
            available_features=(
                "web-dashboard - Web-based VM management"
                "monitoring-stack - Full monitoring with alerting"
                "vm-templates - Advanced VM templates"
                "auto-backups - Automated backups with retention"
                "network-isolation - Advanced network isolation"
                "gpu-passthrough - GPU virtualization support"
                "clustering - Multi-host clustering"
                "api-server - REST/GraphQL API"
                "audit-logging - Comprehensive audit logs"
                "encryption - VM disk encryption"
            )
            ;;
    esac
    
    # Add GUI option
    available_features+=("desktop-environment - Keep GUI after setup")
    
    local selected_list
    selected_list=$(show_checklist "Select Optional Features" \
        "Choose additional features to enable:" \
        "${available_features[@]}")
    
    # Parse selections
    IFS='|' read -ra selections <<< "$selected_list"
    SELECTED_FEATURES=()
    for selection in "${selections[@]}"; do
        if [[ -n "$selection" ]]; then
            feature="${selection%% -*}"
            feature="${feature// /_}"  # Replace spaces with underscores
            
            if [[ "$feature" == "desktop_environment" ]]; then
                ENABLE_GUI_AFTER=true
            else
                SELECTED_FEATURES+=("$feature")
            fi
        fi
    done
}

# Step 4: Network Configuration
configure_network() {
    if show_question "Network Configuration" \
        "Would you like to configure advanced networking now?

This includes:
• Network bridges for VMs
• VLANs and network isolation
• Firewall rules

You can also configure this later."; then
        
        # Run network setup script
        if [[ -x /etc/hypervisor/scripts/foundational_networking_setup.sh ]]; then
            if [[ "$GUI_MODE" == "zenity" ]]; then
                # Run in terminal
                gnome-terminal -- bash -c "/etc/hypervisor/scripts/foundational_networking_setup.sh; read -p 'Press Enter to continue...'"
            else
                /etc/hypervisor/scripts/foundational_networking_setup.sh
            fi
        fi
    fi
}

# Step 5: Storage Configuration
configure_storage() {
    if show_question "Storage Configuration" \
        "Would you like to configure storage pools now?

This includes:
• VM storage location
• ISO storage location
• Backup storage

You can also configure this later."; then
        
        # Simple storage setup
        local vm_path
        if [[ "$GUI_MODE" == "zenity" ]]; then
            vm_path=$(zenity --file-selection --directory --title="Select VM Storage Location" \
                --filename=/var/lib/libvirt/images/)
        else
            read -p "Enter VM storage path [/var/lib/libvirt/images]: " vm_path
            vm_path="${vm_path:-/var/lib/libvirt/images}"
        fi
        
        if [[ -n "$vm_path" ]]; then
            mkdir -p "$vm_path"
            echo "VM_STORAGE_PATH=$vm_path" >> "$WIZARD_STATE"
        fi
    fi
}

# Step 6: Confirmation
show_confirmation() {
    local summary="Configuration Summary:

Profile: $SELECTED_PROFILE
Features: ${SELECTED_FEATURES[*]:-none}
Keep GUI: $ENABLE_GUI_AFTER

The system will now be rebuilt with your selected configuration.
This may take 10-20 minutes.

Continue?"
    
    if ! show_question "Confirm Configuration" "$summary"; then
        show_info "Cancelled" "Setup cancelled. You can run the wizard again later."
        exit 0
    fi
}

# Step 7: Apply Configuration
apply_configuration() {
    show_info "Building System" \
"Your system is being configured...

This process will:
1. Generate final configuration
2. Download required packages
3. Build the system
4. Activate new configuration

Please wait..."
    
    # Generate feature configuration string
    local feature_config=""
    for feature in "${SELECTED_FEATURES[@]}"; do
        feature_config="${feature_config}    $feature = true;\n"
    done
    
    # Run completion script
    if [[ -x /etc/nixos/complete-setup.sh ]]; then
        /etc/nixos/complete-setup.sh "$SELECTED_PROFILE" "$feature_config" "$ENABLE_GUI_AFTER"
    fi
}

# Main wizard flow
main() {
    # Check if running as first boot
    if [[ "$1" == "--first-boot" ]] && [[ ! -f /var/lib/hypervisor/.first-boot-complete ]]; then
        # First boot mode
        show_welcome
    elif [[ -f /var/lib/hypervisor/.first-boot-complete ]]; then
        show_info "Already Configured" \
            "This system has already been configured. 
            
Use the hypervisor menu to manage your system."
        exit 0
    fi
    
    # Run wizard steps
    select_profile
    select_features
    configure_network
    configure_storage
    show_confirmation
    apply_configuration
    
    # Show completion
    show_info "Setup Complete!" \
"Hyper-NixOS has been successfully configured!

Your system is now ready to use with the $SELECTED_PROFILE profile.

You can access:
• Main menu: hypervisor-menu
• Web dashboard: http://localhost:8080 (if enabled)
• Documentation: /etc/nixos/docs/

Enjoy your new hypervisor!"
}

# Run main wizard
main "$@"