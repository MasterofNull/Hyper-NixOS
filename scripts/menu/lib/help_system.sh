#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Interactive Help System
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Context-sensitive help and user guidance
#

# Help topics database
declare -A HELP_TOPICS
declare -A HELP_SHORTCUTS

# Initialize help topics
init_help_topics() {
    # Main topics
    HELP_TOPICS[getting_started]="Getting Started with Hyper-NixOS

Welcome! Here's how to get started:

1. ${UI_ICONS[new]} First Time Setup
   - Run 'System Configuration' → 'First-boot setup wizard'
   - This configures networking, storage, and basic settings

2. ${UI_ICONS[vm_running]} Creating Your First VM
   - Select 'VM Operations' → 'Install VMs'
   - Follow the guided workflow for best results

3. ${UI_ICONS[tip]} Quick Tips
   - Press F1 anytime for context help
   - Use arrow keys to navigate menus
   - Items marked ${UI_ICONS[recommended]} are recommended choices

Need more help? Select a specific topic from the help menu."

    HELP_TOPICS[vm_management]="Virtual Machine Management

${UI_ICONS[vm_running]} VM States:
- ${UI_ICONS[vm_running]} Running - VM is active
- ${UI_ICONS[vm_stopped]} Stopped - VM is shut down
- ${UI_ICONS[vm_paused]} Paused - VM is suspended

Common VM Operations:
• Start VM - Select VM from main menu
• Stop VM - Use VM Dashboard → Select VM → Stop
• Create VM - VM Operations → Create VM wizard
• Delete VM - VM Dashboard → Select VM → Delete

${UI_ICONS[tip]} Pro Tips:
- Use snapshots before major changes
- Regular backups are recommended
- Monitor resource usage in VM Dashboard"

    HELP_TOPICS[security_guide]="${UI_ICONS[security]} Security Guide

Security Levels in Hyper-NixOS:

1. ${UI_ICONS[info]} Informational (Green)
   - Safe, read-only operations
   - No system changes

2. ${UI_ICONS[warning]} Warning (Yellow)
   - May modify system state
   - Review effects before proceeding

3. ${UI_ICONS[dangerous]} Dangerous (Red)
   - Irreversible operations
   - Requires double confirmation
   - Can delete data or VMs

${UI_ICONS[security]} Best Practices:
• Regular security audits (Admin → Security Audit)
• Keep system updated
• Use strong passwords for VMs
• Enable firewall rules per VM
• Regular backups before changes"

    HELP_TOPICS[networking]="Network Configuration

${UI_ICONS[info]} Network Modes:

1. NAT (Default)
   - VMs share host's IP
   - Internet access enabled
   - Isolated from external network

2. Bridged
   - VMs get own IP from network
   - Accessible from LAN
   - Requires bridge setup

3. Isolated
   - No external network access
   - VMs can communicate with each other
   - Maximum security

${UI_ICONS[tip]} Setup Steps:
1. System Config → Foundational networking
2. Configure bridges if needed
3. Set VM network in creation wizard"

    HELP_TOPICS[storage_guide]="Storage Management

Disk Types:
• qcow2 - Flexible, supports snapshots (recommended)
• raw - Better performance, no compression
• LVM - Advanced features, better for servers

${UI_ICONS[tip]} Storage Tips:
- Pre-allocate for better performance
- Use thin provisioning to save space
- Regular cleanup of old snapshots
- Monitor disk usage in Admin menu

${UI_ICONS[warning]} Important:
- Always have 20% free space
- Backup before resizing disks
- Use quotas to prevent overuse"

    HELP_TOPICS[troubleshooting]="Troubleshooting Guide

Common Issues:

${UI_ICONS[error]} VM Won't Start
- Check disk space (Admin → Resource Monitor)
- Verify VM state (VM Dashboard)
- Check logs (Admin → System Logs)
- Run diagnostics (Admin → System Diagnostics)

${UI_ICONS[error]} Network Issues
- Verify bridge configuration
- Check firewall rules
- Test with 'ping' from VM console
- Review network isolation settings

${UI_ICONS[error]} Performance Problems
- Check CPU governor settings
- Monitor resource usage
- Enable hugepages for large VMs
- Consider VFIO for GPU passthrough

${UI_ICONS[tip]} Getting Help:
- Press F1 for context help
- Run diagnostics first
- Check system logs
- Save error messages"

    HELP_TOPICS[keyboard_shortcuts]="Keyboard Shortcuts

Global Shortcuts:
  F1     - Show context help
  F2     - Quick VM status
  F3     - System health
  F5     - Refresh current view
  Ctrl+L - Clear screen
  Ctrl+C - Cancel operation
  Esc    - Go back/Cancel

Menu Navigation:
  ↑/↓    - Move selection
  ←/→    - Switch tabs (if available)
  Enter  - Select item
  Space  - Toggle checkbox
  Tab    - Next field
  
VM Console:
  Ctrl+] - Exit console
  Ctrl+Alt+F[1-6] - Switch TTY

${UI_ICONS[tip]} Pro tip: Most actions can be cancelled with Esc"

    # Shortcuts mapping
    HELP_SHORTCUTS[F1]="show_help"
    HELP_SHORTCUTS[F2]="quick_vm_status"
    HELP_SHORTCUTS[F3]="system_health_check"
    HELP_SHORTCUTS[F5]="refresh_view"
}

# Show help menu
show_help_menu() {
    local context="${1:-main}"
    
    while true; do
        local choices=(
            getting_started "${UI_ICONS[new]} Getting Started"
            vm_management "${UI_ICONS[vm_running]} VM Management"
            security_guide "${UI_ICONS[security]} Security Guide"
            networking "🌐 Network Configuration"
            storage_guide "💾 Storage Management"
            troubleshooting "${UI_ICONS[error]} Troubleshooting"
            keyboard_shortcuts "⌨️  Keyboard Shortcuts"
            "" ""
            context "${UI_ICONS[question]} Current Screen Help"
            interactive "🎓 Interactive Tutorial"
            "" ""
            back "← Back"
        )
        
        local choice
        choice=$(show_menu "${UI_ICONS[question]} Help System" \
            "Select a help topic:" \
            "${choices[@]}") || return 0
        
        case "$choice" in
            getting_started|vm_management|security_guide|networking|storage_guide|troubleshooting|keyboard_shortcuts)
                show_help_topic "$choice"
                ;;
            context)
                show_context_help "$context"
                ;;
            interactive)
                start_interactive_tutorial
                ;;
            back|"")
                return 0
                ;;
        esac
    done
}

# Show specific help topic
show_help_topic() {
    local topic="$1"
    local content="${HELP_TOPICS[$topic]:-No help available for this topic.}"
    
    show_info "Help: $topic" "$content" 20 70
}

# Quick VM status (F2)
quick_vm_status() {
    local status_text="VM Quick Status\n\n"
    
    # Get running VMs
    local running_vms
    running_vms=$(virsh list --name | grep -v '^$' | wc -l)
    local total_vms
    total_vms=$(virsh list --all --name | grep -v '^$' | wc -l)
    
    status_text+="VMs: $running_vms running / $total_vms total\n\n"
    
    # List running VMs with resources
    if [[ $running_vms -gt 0 ]]; then
        status_text+="Running VMs:\n"
        while IFS= read -r vm; do
            [[ -z "$vm" ]] && continue
            local vcpus
            vcpus=$(virsh vcpucount "$vm" --current 2>/dev/null || echo "?")
            local mem
            mem=$(virsh dommemstat "$vm" 2>/dev/null | grep "actual" | awk '{print int($2/1024)}' || echo "?")
            status_text+="  ${UI_ICONS[vm_running]} $vm (${vcpus} vCPUs, ${mem}MB RAM)\n"
        done < <(virsh list --name)
    else
        status_text+="No VMs currently running.\n"
    fi
    
    show_info "Quick Status (F2)" "$status_text" 15 50
}

# System health check (F3)
system_health_check() {
    show_infobox "System Health" "Checking system health..." 6 40
    
    local health_text="System Health Report\n\n"
    local issues=0
    
    # CPU check
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    if [[ $cpu_usage -gt 80 ]]; then
        health_text+="${UI_ICONS[warning]} CPU: High usage (${cpu_usage}%)\n"
        ((issues++))
    else
        health_text+="${UI_ICONS[success]} CPU: Normal (${cpu_usage}%)\n"
    fi
    
    # Memory check
    local mem_percent
    mem_percent=$(free | grep "^Mem:" | awk '{printf "%d", $3/$2 * 100}')
    if [[ $mem_percent -gt 85 ]]; then
        health_text+="${UI_ICONS[warning]} Memory: High usage (${mem_percent}%)\n"
        ((issues++))
    else
        health_text+="${UI_ICONS[success]} Memory: Normal (${mem_percent}%)\n"
    fi
    
    # Disk check
    local disk_percent
    disk_percent=$(df / | tail -1 | awk '{print int($5)}')
    if [[ $disk_percent -gt 85 ]]; then
        health_text+="${UI_ICONS[warning]} Disk: Low space (${disk_percent}% used)\n"
        ((issues++))
    else
        health_text+="${UI_ICONS[success]} Disk: Normal (${disk_percent}% used)\n"
    fi
    
    # Service check
    if systemctl is-active libvirtd >/dev/null 2>&1; then
        health_text+="${UI_ICONS[success]} Libvirt: Running\n"
    else
        health_text+="${UI_ICONS[error]} Libvirt: Not running\n"
        ((issues++))
    fi
    
    # Summary
    health_text+="\n"
    if [[ $issues -eq 0 ]]; then
        health_text+="${UI_ICONS[success]} System is healthy!"
    else
        health_text+="${UI_ICONS[warning]} $issues issue(s) detected."
    fi
    
    show_info "System Health (F3)" "$health_text" 20 50
}

# Interactive tutorial
start_interactive_tutorial() {
    local tutorial_step=1
    local total_steps=5
    
    # Step 1: Welcome
    show_wizard "Interactive Tutorial" $total_steps $tutorial_step \
        "Welcome to Hyper-NixOS!" \
        "This tutorial will guide you through basic operations.
        
We'll cover:
• Navigating menus
• Creating a VM
• Managing VMs
• Using help resources

Press OK to continue..." \
        show_info "Tutorial" "" 15 60
    
    ((tutorial_step++))
    
    # Step 2: Navigation
    show_wizard "Interactive Tutorial" $total_steps $tutorial_step \
        "Menu Navigation" \
        "Use these keys to navigate:

↑/↓ - Move up/down
Enter - Select item
Esc - Go back
F1 - Get help

Try pressing F1 now to see context help!
(Press OK when ready to continue)" \
        show_info "Tutorial" "" 15 60
    
    ((tutorial_step++))
    
    # Step 3: VM Creation
    show_wizard "Interactive Tutorial" $total_steps $tutorial_step \
        "Creating VMs" \
        "To create a VM:

1. Select 'VM Operations' from main menu
2. Choose 'Install VMs' (recommended)
3. Follow the guided workflow

The wizard will help you:
• Choose an operating system
• Set resources (CPU, RAM, disk)
• Configure networking
• Start the installation" \
        show_info "Tutorial" "" 18 60
    
    ((tutorial_step++))
    
    # Step 4: VM Management
    show_wizard "Interactive Tutorial" $total_steps $tutorial_step \
        "Managing VMs" \
        "Common VM tasks:

• Start VM - Select from main menu
• Stop VM - Use VM Dashboard
• Take Snapshot - Snapshots & Backups
• Check Status - Press F2 anytime

${UI_ICONS[tip]} Tip: Always snapshot before major changes!" \
        show_info "Tutorial" "" 16 60
    
    ((tutorial_step++))
    
    # Step 5: Getting Help
    show_wizard "Interactive Tutorial" $total_steps $tutorial_step \
        "Getting Help" \
        "Help is always available:

• Press F1 - Context-sensitive help
• Help menu - Detailed guides
• Tooltips - Watch for ${UI_ICONS[tip]} icons
• Diagnostics - In Admin menu

${UI_ICONS[success]} Tutorial complete!

Ready to start using Hyper-NixOS!" \
        show_info "Tutorial" "" 18 60
    
    show_success_with_next "Tutorial Complete" \
        "You've completed the interactive tutorial!" \
        "• Try creating your first VM
• Explore the help system
• Check out advanced features"
}

# Handle keyboard shortcuts
handle_shortcut() {
    local key="$1"
    local action="${HELP_SHORTCUTS[$key]:-}"
    
    if [[ -n "$action" ]]; then
        case "$action" in
            show_help)
                show_help_menu "$(get_ui_context current_menu)"
                ;;
            quick_vm_status)
                quick_vm_status
                ;;
            system_health_check)
                system_health_check
                ;;
            refresh_view)
                # Trigger refresh in calling function
                return 2
                ;;
        esac
    fi
}

# Initialize help system
init_help_topics