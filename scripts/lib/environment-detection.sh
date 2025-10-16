#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Environment Detection Library
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Detects whether running in admin environment or VM environment

# Detect current environment
detect_environment() {
    # Check if running in a VM
    if systemd-detect-virt >/dev/null 2>&1; then
        local virt_type=$(systemd-detect-virt)
        if [[ "$virt_type" != "none" ]]; then
            echo "vm"
            return 0
        fi
    fi
    
    # Check for hypervisor markers
    if [[ -f /etc/hypervisor/.admin_host ]]; then
        echo "admin"
        return 0
    fi
    
    # Check if libvirtd is running (indicates hypervisor host)
    if systemctl is-active --quiet libvirtd 2>/dev/null; then
        echo "admin"
        return 0
    fi
    
    # Check if KVM modules are loaded (hypervisor host)
    if lsmod | grep -q kvm; then
        echo "admin"
        return 0
    fi
    
    # Default to admin if uncertain
    echo "admin"
}

# Check if current environment allows feature
is_feature_allowed() {
    local feature="$1"
    local current_env=$(detect_environment)
    
    # Features only available in admin environment
    local admin_only_features=(
        "network_configuration"
        "security_hardening"
        "system_configuration"
        "storage_management"
        "monitoring_setup"
        "backup_configuration"
        "phase_switching"
    )
    
    # Features available in both environments
    local universal_features=(
        "vm_management"
        "vm_creation"
        "vm_status"
        "vm_console"
    )
    
    # Check if feature is admin-only
    for admin_feature in "${admin_only_features[@]}"; do
        if [[ "$feature" == "$admin_feature" ]] && [[ "$current_env" != "admin" ]]; then
            return 1  # Not allowed
        fi
    done
    
    # All universal features are allowed
    for universal_feature in "${universal_features[@]}"; do
        if [[ "$feature" == "$universal_feature" ]]; then
            return 0  # Allowed
        fi
    done
    
    # Default: allow in admin, deny in VM
    [[ "$current_env" == "admin" ]]
}

# Get environment display name
get_environment_display() {
    local env=$(detect_environment)
    case "$env" in
        admin) echo "Administrator Host" ;;
        vm) echo "Virtual Machine" ;;
        *) echo "Unknown Environment" ;;
    esac
}

# Get environment icon
get_environment_icon() {
    local env=$(detect_environment)
    case "$env" in
        admin) echo "🖥️" ;;
        vm) echo "📦" ;;
        *) echo "❓" ;;
    esac
}

# Export functions
export -f detect_environment
export -f is_feature_allowed
export -f get_environment_display
export -f get_environment_icon
