#!/usr/bin/env bash
#
# System Configuration Menu Module
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# System configuration menu functions
#

# Show system configuration menu
show_system_config_menu() {
    while true; do
        local choices=(
            1 "🏭 First-boot setup wizard"
            2 "🌐 Foundational networking (bridges, interfaces)"
            3 "🔐 Relax strict permissions"
            4 "🔏 Harden permissions"
            5 "🚪 SSH host setup"
            6 "🔄 Toggle boot features (menu/GUI/wizard)"
            7 "🌍 Zone manager"
            8 "🔧 Hardware detection"
            9 "🎚️  Performance tuning"
            10 "📦 Update hypervisor packages"
            11 "💻 GUI configuration"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "$BRANDING - System Configuration" \
            "Select system configuration option:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) sudo "$SCRIPTS_DIR/setup_wizard.sh" ;;
            2) sudo "$SCRIPTS_DIR/foundational_networking_setup.sh" ;;
            3) sudo "$SCRIPTS_DIR/relax_permissions.sh" ;;
            4) sudo "$SCRIPTS_DIR/harden_permissions.sh" ;;
            5) "$SCRIPTS_DIR/ssh_setup.sh" ;;
            6) sudo "$SCRIPTS_DIR/toggle_boot_features.sh" ;;
            7) "$SCRIPTS_DIR/zone_manager.sh" ;;
            8) sudo "$SCRIPTS_DIR/hardware_detect.sh" ;;
            9) show_performance_menu ;;
            10) sudo "$SCRIPTS_DIR/update_hypervisor.sh" ;;
            11) show_gui_config_menu ;;
            0|"") return 0 ;;
        esac
    done
}

# Show performance tuning menu
show_performance_menu() {
    while true; do
        local choices=(
            1 "Auto-detect and optimize"
            2 "Manual CPU governor settings"
            3 "Memory hugepages configuration"
            4 "Storage I/O optimization"
            5 "Network performance tuning"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "$BRANDING - Performance Tuning" \
            "Select performance optimization:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) sudo "$SCRIPTS_DIR/detect_and_adjust.sh" ;;
            2) configure_cpu_governor ;;
            3) configure_hugepages ;;
            4) configure_storage_io ;;
            5) configure_network_performance ;;
            0|"") return 0 ;;
        esac
    done
}

# Configure CPU governor
configure_cpu_governor() {
    local governors=(
        "performance" "Maximum performance" ON
        "powersave" "Power saving mode" OFF
        "ondemand" "Dynamic frequency scaling" OFF
        "conservative" "Gradual frequency scaling" OFF
    )
    
    local selected
    selected=$(show_radiolist "CPU Governor" \
        "Select CPU frequency governor:" \
        15 60 4 "${governors[@]}") || return
    
    if [[ -n "$selected" ]]; then
        echo "$selected" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
        show_info "Success" "CPU governor set to: $selected"
    fi
}

# Configure hugepages
configure_hugepages() {
    local current
    current=$(grep -E "^HugePages_Total:" /proc/meminfo | awk '{print $2}')
    
    local new_value
    new_value=$(show_input "Hugepages Configuration" \
        "Enter number of 2MB hugepages (current: $current):" \
        "$current") || return
    
    if [[ "$new_value" =~ ^[0-9]+$ ]]; then
        echo "$new_value" | sudo tee /proc/sys/vm/nr_hugepages
        show_info "Success" "Hugepages set to: $new_value"
    else
        show_info "Error" "Invalid value: must be a number"
    fi
}

# Configure storage I/O
configure_storage_io() {
    local schedulers=(
        "none" "No I/O scheduler (NVMe)" OFF
        "mq-deadline" "Multiqueue deadline (SSD)" ON
        "bfq" "Budget Fair Queueing (HDD)" OFF
        "kyber" "Kyber (general purpose)" OFF
    )
    
    local selected
    selected=$(show_radiolist "I/O Scheduler" \
        "Select I/O scheduler for primary storage:" \
        15 60 4 "${schedulers[@]}") || return
    
    if [[ -n "$selected" ]]; then
        # Find primary storage device
        local device
        device=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
        device=${device##*/}
        
        if [[ -b "/dev/$device" ]]; then
            echo "$selected" | sudo tee "/sys/block/$device/queue/scheduler"
            show_info "Success" "I/O scheduler set to: $selected"
        else
            show_info "Error" "Could not determine primary storage device"
        fi
    fi
}

# Configure network performance
configure_network_performance() {
    local options=(
        "jumbo" "Enable jumbo frames (MTU 9000)" OFF
        "offload" "Enable hardware offloading" ON
        "fastpath" "Enable kernel fast path" OFF
        "tuning" "Apply network stack tuning" OFF
    )
    
    local selected
    selected=$(show_checklist "Network Performance" \
        "Select network optimizations:" \
        15 60 4 "${options[@]}") || return
    
    for opt in $selected; do
        case ${opt//\"/} in
            jumbo)
                configure_jumbo_frames
                ;;
            offload)
                configure_hw_offload
                ;;
            fastpath)
                configure_fast_path
                ;;
            tuning)
                apply_network_tuning
                ;;
        esac
    done
}

# Show GUI configuration menu
show_gui_config_menu() {
    local gui_status="Disabled"
    if systemctl is-enabled display-manager.service &>/dev/null; then
        gui_status="Enabled"
    fi
    
    while true; do
        local choices=(
            1 "Toggle GUI mode (current: $gui_status)"
            2 "Select display manager"
            3 "Configure auto-login"
            4 "Install desktop environment"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "$BRANDING - GUI Configuration" \
            "Configure graphical interface:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) sudo "$SCRIPTS_DIR/toggle_gui.sh" ;;
            2) configure_display_manager ;;
            3) configure_auto_login ;;
            4) install_desktop_environment ;;
            0|"") return 0 ;;
        esac
    done
}