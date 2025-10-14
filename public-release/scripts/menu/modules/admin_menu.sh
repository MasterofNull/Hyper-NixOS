#!/usr/bin/env bash
#
# Admin Menu Module
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Administrative functions menu
#

# Show admin management menu
show_admin_menu() {
    while true; do
        local choices=(
            1 "📊 System diagnostics"
            2 "🔍 Security audit"
            3 "📈 Resource monitoring"
            4 "🗄️ Backup management"
            5 "📋 View system logs"
            6 "🔧 Advanced settings"
            7 "🚨 Alert configuration"
            8 "📦 Package management"
            9 "🔄 System maintenance"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "$BRANDING - Admin Management" \
            "Select administrative task:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) "$SCRIPTS_DIR/diagnose.sh" ;;
            2) sudo "$SCRIPTS_DIR/security_audit.sh" ;;
            3) show_resource_monitoring ;;
            4) show_backup_management ;;
            5) show_system_logs ;;
            6) show_advanced_settings ;;
            7) "$SCRIPTS_DIR/alert_manager.sh" ;;
            8) show_package_management ;;
            9) show_system_maintenance ;;
            0|"") return 0 ;;
        esac
    done
}

# Show resource monitoring
show_resource_monitoring() {
    while true; do
        local choices=(
            1 "Real-time system metrics"
            2 "VM resource usage"
            3 "Storage usage analysis"
            4 "Network statistics"
            5 "Historical metrics"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "Resource Monitoring" \
            "Select monitoring option:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) show_realtime_metrics ;;
            2) "$SCRIPTS_DIR/resource_reporter.sh" ;;
            3) show_storage_analysis ;;
            4) show_network_stats ;;
            5) "$SCRIPTS_DIR/guided_metrics_viewer.sh" ;;
            0|"") return 0 ;;
        esac
    done
}

# Show real-time metrics
show_realtime_metrics() {
    clear_screen
    echo "Real-time System Metrics (Press Ctrl+C to exit)"
    echo "================================================"
    
    while true; do
        # CPU usage
        local cpu_usage
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        
        # Memory usage
        local mem_info
        mem_info=$(free -h | grep "^Mem:")
        local mem_total=$(echo "$mem_info" | awk '{print $2}')
        local mem_used=$(echo "$mem_info" | awk '{print $3}')
        local mem_percent=$(free | grep "^Mem:" | awk '{printf "%.1f", $3/$2 * 100}')
        
        # Disk usage
        local disk_info
        disk_info=$(df -h / | tail -1)
        local disk_used=$(echo "$disk_info" | awk '{print $3}')
        local disk_total=$(echo "$disk_info" | awk '{print $2}')
        local disk_percent=$(echo "$disk_info" | awk '{print $5}')
        
        # VM count
        local vms_running
        vms_running=$(virsh list --name | grep -v '^$' | wc -l)
        local vms_total
        vms_total=$(virsh list --all --name | grep -v '^$' | wc -l)
        
        # Display metrics
        printf "\033[H\033[J"  # Clear screen
        echo "Real-time System Metrics (Press Ctrl+C to exit)"
        echo "================================================"
        echo ""
        echo "CPU Usage:    ${cpu_usage}%"
        echo "Memory:       $mem_used / $mem_total (${mem_percent}%)"
        echo "Disk:         $disk_used / $disk_total ($disk_percent)"
        echo "VMs:          $vms_running running / $vms_total total"
        echo ""
        echo "Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
        
        sleep 2
    done
}

# Show backup management
show_backup_management() {
    while true; do
        local choices=(
            1 "Create VM backup"
            2 "Restore from backup"
            3 "Schedule automatic backups"
            4 "Verify backups"
            5 "Clean old backups"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "Backup Management" \
            "Select backup operation:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) "$SCRIPTS_DIR/snapshots_backups.sh" backup ;;
            2) "$SCRIPTS_DIR/snapshots_backups.sh" restore ;;
            3) configure_backup_schedule ;;
            4) "$SCRIPTS_DIR/guided_backup_verification.sh" ;;
            5) clean_old_backups ;;
            0|"") return 0 ;;
        esac
    done
}

# Show system logs
show_system_logs() {
    while true; do
        local choices=(
            1 "Hypervisor menu logs"
            2 "VM operation logs"
            3 "System service logs"
            4 "Security audit logs"
            5 "Error logs"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "System Logs" \
            "Select log type to view:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) view_log "$HYPERVISOR_LOGS/menu.log" ;;
            2) view_log "$HYPERVISOR_LOGS/vm_operations.log" ;;
            3) sudo journalctl -u "hypervisor-*" --no-pager | less ;;
            4) "$SCRIPTS_DIR/audit_viewer.sh" ;;
            5) sudo journalctl -p err --no-pager | less ;;
            0|"") return 0 ;;
        esac
    done
}

# View log file
view_log() {
    local log_file="$1"
    
    if [[ -f "$log_file" ]]; then
        less "$log_file"
    else
        show_info "No Log File" "Log file not found: $log_file"
    fi
}

# Show advanced settings
show_advanced_settings() {
    while true; do
        local choices=(
            1 "LibVirt configuration"
            2 "QEMU settings"
            3 "Network bridge settings"
            4 "Storage pool management"
            5 "Security profiles"
            6 "Kernel parameters"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "Advanced Settings" \
            "Select configuration area:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) configure_libvirt ;;
            2) configure_qemu ;;
            3) "$SCRIPTS_DIR/bridge_helper.sh" ;;
            4) manage_storage_pools ;;
            5) configure_security_profiles ;;
            6) configure_kernel_params ;;
            0|"") return 0 ;;
        esac
    done
}

# Show package management
show_package_management() {
    while true; do
        local choices=(
            1 "Update system packages"
            2 "Install hypervisor updates"
            3 "Check for security updates"
            4 "Clean package cache"
            5 "Show installed packages"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "Package Management" \
            "Select package operation:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) sudo nix-channel --update && sudo nixos-rebuild switch ;;
            2) sudo "$SCRIPTS_DIR/update_hypervisor.sh" ;;
            3) check_security_updates ;;
            4) sudo nix-collect-garbage -d ;;
            5) nix-store -q --requisites /run/current-system | less ;;
            0|"") return 0 ;;
        esac
    done
}

# Show system maintenance
show_system_maintenance() {
    while true; do
        local choices=(
            1 "Clean temporary files"
            2 "Optimize databases"
            3 "Check filesystem"
            4 "Update virus definitions"
            5 "Rebuild system configuration"
            6 "Generate system report"
            "" ""
            0 "← Back"
        )
        
        local choice
        choice=$(show_menu "System Maintenance" \
            "Select maintenance task:" \
            "${choices[@]}") || return 0
        
        case $choice in
            1) "$SCRIPTS_DIR/cleanup.sh" ;;
            2) optimize_databases ;;
            3) check_filesystems ;;
            4) update_virus_definitions ;;
            5) sudo nixos-rebuild switch ;;
            6) generate_system_report ;;
            0|"") return 0 ;;
        esac
    done
}