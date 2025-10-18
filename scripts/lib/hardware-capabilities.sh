#!/usr/bin/env bash
#
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Hardware Capabilities Detection Library for Wizards
# This library provides functions to detect hardware capabilities and
# determine which wizard options should be available/unavailable.
#
# © 2024-2025 MasterofNull
# Licensed under the MIT License
#

# Source color definitions if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/branding.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/branding.sh"
fi

# Hardware info cache files
HW_INFO_JSON="/etc/hypervisor/hardware-info.json"
PLATFORM_INFO_JSON="/etc/hypervisor/platform-info.json"
HW_CACHE_DIR="/var/cache/hypervisor"
HW_CACHE_FILE="${HW_CACHE_DIR}/capabilities.json"

# Ensure cache directory exists
mkdir -p "${HW_CACHE_DIR}" 2>/dev/null || true

# ============================================================================
# Core Detection Functions
# ============================================================================

# Get CPU architecture
get_cpu_architecture() {
    if [[ -f "${HW_INFO_JSON}" ]]; then
        jq -r '.architecture // "unknown"' "${HW_INFO_JSON}" 2>/dev/null || echo "unknown"
    else
        uname -m
    fi
}

# Get CPU vendor
get_cpu_vendor() {
    if [[ -f "${HW_INFO_JSON}" ]]; then
        jq -r '.vendor // "unknown"' "${HW_INFO_JSON}" 2>/dev/null || echo "unknown"
    else
        grep -m1 "vendor_id" /proc/cpuinfo | cut -d: -f2 | xargs 2>/dev/null || echo "unknown"
    fi
}

# Get platform type (laptop, desktop, server)
get_platform_type() {
    if [[ -f "${PLATFORM_INFO_JSON}" ]]; then
        jq -r '.platform_type // "unknown"' "${PLATFORM_INFO_JSON}" 2>/dev/null || echo "unknown"
    else
        if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
            echo "laptop"
        elif [[ -n "${DISPLAY}" ]] || systemctl is-active graphical.target &>/dev/null; then
            echo "desktop"
        else
            echo "server"
        fi
    fi
}

# Check if virtualization is supported
has_virtualization() {
    if [[ -f "${HW_INFO_JSON}" ]]; then
        local virt_support=$(jq -r '.virtualization_support // "false"' "${HW_INFO_JSON}" 2>/dev/null)
        [[ "${virt_support}" == "true" ]] && return 0 || return 1
    else
        # Fallback detection
        if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
            return 0
        elif grep -q "virt" /proc/cpuinfo 2>/dev/null; then
            return 0
        fi
        return 1
    fi
}

# Check if IOMMU is available
has_iommu() {
    if [[ -f "${HW_INFO_JSON}" ]]; then
        local iommu=$(jq -r '.iommu_param // ""' "${HW_INFO_JSON}" 2>/dev/null)
        [[ -n "${iommu}" ]] && return 0 || return 1
    else
        # Check kernel command line
        if grep -qE 'intel_iommu=on|amd_iommu=on|iommu\.passthrough' /proc/cmdline 2>/dev/null; then
            return 0
        fi
        # Check for IOMMU groups
        if [[ -d /sys/kernel/iommu_groups ]] && [[ -n "$(ls -A /sys/kernel/iommu_groups 2>/dev/null)" ]]; then
            return 0
        fi
        return 1
    fi
}

# Check GPU passthrough capability
has_gpu_passthrough() {
    # Requires IOMMU + multiple GPUs or iGPU + dGPU
    if ! has_iommu; then
        return 1
    fi

    # Count GPUs
    local gpu_count=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | wc -l)
    [[ ${gpu_count} -ge 2 ]] && return 0 || return 1
}

# Check if system is laptop
is_laptop() {
    [[ "$(get_platform_type)" == "laptop" ]] && return 0 || return 1
}

# Check if system is desktop
is_desktop() {
    [[ "$(get_platform_type)" == "desktop" ]] && return 0 || return 1
}

# Check if system is server/headless
is_server() {
    [[ "$(get_platform_type)" == "server" ]] && return 0 || return 1
}

# Check for specific hardware features
has_touchpad() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.touchpad // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

has_backlight() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.backlight // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

has_battery() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.battery // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

has_nvidia_gpu() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.gpu_nvidia // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

has_amd_gpu() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.gpu_amd // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

has_intel_gpu() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.gpu_intel // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

has_wifi() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.wifi // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

has_bluetooth() {
    [[ -f "${PLATFORM_INFO_JSON}" ]] && \
        [[ "$(jq -r '.hardware.bluetooth // "false"' "${PLATFORM_INFO_JSON}" 2>/dev/null)" == "true" ]]
}

# ============================================================================
# Capability Checking Functions
# ============================================================================

# Check if feature is available
# Usage: is_feature_available "feature_name"
# Returns: 0 if available, 1 if not
is_feature_available() {
    local feature="$1"

    case "${feature}" in
        # Virtualization features
        "kvm"|"virtualization")
            has_virtualization
            ;;
        "nested_virtualization")
            has_virtualization
            ;;
        "gpu_passthrough")
            has_gpu_passthrough
            ;;
        "vfio"|"pci_passthrough")
            has_iommu
            ;;
        "iommu")
            has_iommu
            ;;

        # Platform-specific features
        "laptop_mode"|"battery_management"|"power_management")
            is_laptop
            ;;
        "touchpad_config")
            has_touchpad
            ;;
        "backlight_control")
            has_backlight
            ;;
        "battery_optimization")
            has_battery
            ;;

        # GPU-specific features
        "nvidia_drivers"|"nvidia_cuda")
            has_nvidia_gpu
            ;;
        "amd_rocm")
            has_amd_gpu
            ;;
        "intel_vaapi")
            has_intel_gpu
            ;;

        # Network features
        "wifi_config")
            has_wifi
            ;;
        "bluetooth_config")
            has_bluetooth
            ;;

        # Desktop features
        "multi_monitor")
            is_desktop || is_laptop
            ;;
        "gaming_optimizations")
            is_desktop && (has_nvidia_gpu || has_amd_gpu)
            ;;

        # Architecture-specific
        "x86_optimizations")
            local arch=$(get_cpu_architecture)
            [[ "${arch}" =~ ^(x86_64|x86)$ ]]
            ;;
        "arm_optimizations")
            local arch=$(get_cpu_architecture)
            [[ "${arch}" =~ ^(aarch64|arm)$ ]]
            ;;

        *)
            # Unknown feature, assume available
            return 0
            ;;
    esac
}

# Get reason why feature is unavailable
# Usage: get_unavailable_reason "feature_name"
get_unavailable_reason() {
    local feature="$1"

    case "${feature}" in
        "kvm"|"virtualization")
            echo "CPU does not support hardware virtualization (VMX/SVM)"
            ;;
        "nested_virtualization")
            echo "CPU virtualization extensions not detected"
            ;;
        "gpu_passthrough")
            if ! has_iommu; then
                echo "IOMMU not available (required for GPU passthrough)"
            else
                echo "Only one GPU detected (need 2+ for passthrough)"
            fi
            ;;
        "vfio"|"pci_passthrough")
            echo "IOMMU not available (required for PCI passthrough)"
            ;;
        "iommu")
            echo "IOMMU not supported by CPU or not enabled in BIOS"
            ;;
        "laptop_mode"|"battery_management"|"power_management")
            echo "Not a laptop (no battery detected)"
            ;;
        "touchpad_config")
            echo "No touchpad detected on this system"
            ;;
        "backlight_control")
            echo "No backlight device detected"
            ;;
        "battery_optimization")
            echo "No battery detected on this system"
            ;;
        "nvidia_drivers"|"nvidia_cuda")
            echo "No NVIDIA GPU detected"
            ;;
        "amd_rocm")
            echo "No AMD GPU detected"
            ;;
        "intel_vaapi")
            echo "No Intel GPU detected"
            ;;
        "wifi_config")
            echo "No WiFi adapter detected"
            ;;
        "bluetooth_config")
            echo "No Bluetooth adapter detected"
            ;;
        "gaming_optimizations")
            if ! is_desktop; then
                echo "Gaming optimizations are for desktop systems"
            else
                echo "No discrete GPU detected (NVIDIA/AMD required)"
            fi
            ;;
        "x86_optimizations")
            echo "CPU is not x86/x86_64 architecture"
            ;;
        "arm_optimizations")
            echo "CPU is not ARM/ARM64 architecture"
            ;;
        *)
            echo "Feature not available on this hardware"
            ;;
    esac
}

# ============================================================================
# Display Functions for Wizards
# ============================================================================

# Print option status (available/unavailable)
# Usage: print_option_status "option_name" "feature_requirement"
print_option_status() {
    local option_name="$1"
    local feature="$2"

    if is_feature_available "${feature}"; then
        echo -e "${GREEN}✓${NC} ${option_name}"
    else
        local reason=$(get_unavailable_reason "${feature}")
        echo -e "${GRAY}○ ${option_name} ${DIM}(unavailable: ${reason})${NC}"
    fi
}

# Create menu option with availability check
# Usage: create_menu_option "option_id" "option_label" "feature_requirement"
# Returns: JSON object with option details
create_menu_option() {
    local option_id="$1"
    local option_label="$2"
    local feature="$3"

    local available="true"
    local reason=""

    if ! is_feature_available "${feature}"; then
        available="false"
        reason=$(get_unavailable_reason "${feature}")
    fi

    cat <<EOF
{
  "id": "${option_id}",
  "label": "${option_label}",
  "available": ${available},
  "reason": "${reason}",
  "feature": "${feature}"
}
EOF
}

# Filter menu options based on hardware capabilities
# Usage: filter_menu_options < options.json
# Input: JSON array of option objects
# Output: JSON array with availability added
filter_menu_options() {
    local options="$1"

    echo "${options}" | jq -c '.[] | select(.available == true or .available == "true")'
}

# ============================================================================
# Cache Management
# ============================================================================

# Generate full capabilities cache
generate_capabilities_cache() {
    local cache_file="${HW_CACHE_FILE}"

    cat > "${cache_file}" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "architecture": "$(get_cpu_architecture)",
  "vendor": "$(get_cpu_vendor)",
  "platform_type": "$(get_platform_type)",
  "capabilities": {
    "virtualization": $(has_virtualization && echo "true" || echo "false"),
    "iommu": $(has_iommu && echo "true" || echo "false"),
    "gpu_passthrough": $(has_gpu_passthrough && echo "true" || echo "false"),
    "touchpad": $(has_touchpad && echo "true" || echo "false"),
    "backlight": $(has_backlight && echo "true" || echo "false"),
    "battery": $(has_battery && echo "true" || echo "false"),
    "nvidia_gpu": $(has_nvidia_gpu && echo "true" || echo "false"),
    "amd_gpu": $(has_amd_gpu && echo "true" || echo "false"),
    "intel_gpu": $(has_intel_gpu && echo "true" || echo "false"),
    "wifi": $(has_wifi && echo "true" || echo "false"),
    "bluetooth": $(has_bluetooth && echo "true" || echo "false")
  },
  "platform_features": {
    "is_laptop": $(is_laptop && echo "true" || echo "false"),
    "is_desktop": $(is_desktop && echo "true" || echo "false"),
    "is_server": $(is_server && echo "true" || echo "false")
  }
}
EOF

    echo "${cache_file}"
}

# Get cached capabilities
get_capabilities() {
    if [[ ! -f "${HW_CACHE_FILE}" ]] || [[ $(find "${HW_CACHE_FILE}" -mmin +60 2>/dev/null) ]]; then
        # Cache doesn't exist or is older than 60 minutes, regenerate
        generate_capabilities_cache >/dev/null
    fi

    cat "${HW_CACHE_FILE}" 2>/dev/null || echo "{}"
}

# ============================================================================
# Helper Functions for Wizard Integration
# ============================================================================

# Show hardware summary for wizards
show_hardware_summary() {
    local arch=$(get_cpu_architecture)
    local vendor=$(get_cpu_vendor)
    local platform=$(get_platform_type)

    cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Hardware Detected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Architecture:  ${arch}
  CPU Vendor:    ${vendor}
  Platform Type: ${platform}

  Capabilities:
EOF

    print_option_status "  Hardware Virtualization (KVM)" "virtualization"
    print_option_status "  IOMMU / PCI Passthrough" "iommu"
    print_option_status "  GPU Passthrough" "gpu_passthrough"

    if is_laptop; then
        echo ""
        echo "  Laptop Features:"
        print_option_status "    Touchpad Configuration" "touchpad_config"
        print_option_status "    Backlight Control" "backlight_control"
        print_option_status "    Battery Management" "battery_optimization"
    fi

    if has_nvidia_gpu || has_amd_gpu || has_intel_gpu; then
        echo ""
        echo "  GPU Features:"
        print_option_status "    NVIDIA Drivers" "nvidia_drivers"
        print_option_status "    AMD ROCm" "amd_rocm"
        print_option_status "    Intel VA-API" "intel_vaapi"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Export functions for use in other scripts
export -f get_cpu_architecture
export -f get_cpu_vendor
export -f get_platform_type
export -f has_virtualization
export -f has_iommu
export -f has_gpu_passthrough
export -f is_laptop
export -f is_desktop
export -f is_server
export -f is_feature_available
export -f get_unavailable_reason
export -f print_option_status
export -f create_menu_option
export -f show_hardware_summary
export -f get_capabilities
