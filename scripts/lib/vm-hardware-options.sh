#!/usr/bin/env bash
#
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# VM Hardware Options Library
# Hardware-aware option presentation for VM creation
#
# © 2024-2025 MasterofNull
# Licensed under the MIT License
#

# Source hardware capabilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/hardware-capabilities.sh" ]]; then
    source "${SCRIPT_DIR}/hardware-capabilities.sh"
fi

# ============================================================================
# VM Hardware Feature Checks
# ============================================================================

# Check if GPU passthrough is available for VMs
can_use_gpu_passthrough() {
    is_feature_available "gpu_passthrough"
}

# Check if nested virtualization is available
can_use_nested_virt() {
    is_feature_available "nested_virtualization"
}

# Check if SR-IOV is available for network cards
can_use_sriov() {
    is_feature_available "iommu"
}

# Check if huge pages are available
can_use_hugepages() {
    [[ -d /sys/kernel/mm/hugepages ]] && return 0 || return 1
}

# ============================================================================
# VM Feature Menu Functions
# ============================================================================

# Show hardware-aware GPU passthrough option
show_gpu_passthrough_option() {
    if can_use_gpu_passthrough; then
        echo "GPU Passthrough: Available"
        echo "  ✓ IOMMU enabled"
        echo "  ✓ Multiple GPUs detected"
        echo "  → You can dedicate a GPU to this VM"
        return 0
    else
        echo "GPU Passthrough: Unavailable"
        local reason=$(get_unavailable_reason "gpu_passthrough")
        echo "  ✗ ${reason}"
        echo "  → This VM will use virtual graphics only"
        return 1
    fi
}

# Show hardware-aware SR-IOV option
show_sriov_option() {
    if can_use_sriov; then
        echo "SR-IOV Network: Available"
        echo "  ✓ IOMMU enabled"
        echo "  → VM can use SR-IOV for high-performance networking"
        return 0
    else
        echo "SR-IOV Network: Unavailable"
        local reason=$(get_unavailable_reason "iommu")
        echo "  ✗ ${reason}"
        echo "  → VM will use standard virtual networking"
        return 1
    fi
}

# Show hardware-aware nested virtualization option
show_nested_virt_option() {
    if can_use_nested_virt; then
        echo "Nested Virtualization: Available"
        echo "  ✓ CPU supports nested virtualization"
        echo "  → This VM can run VMs inside it"
        return 0
    else
        echo "Nested Virtualization: Unavailable"
        local reason=$(get_unavailable_reason "nested_virtualization")
        echo "  ✗ ${reason}"
        echo "  → This VM cannot run VMs inside it"
        return 1
    fi
}

# Show hardware-aware huge pages option
show_hugepages_option() {
    if can_use_hugepages; then
        local hugepage_sizes=$(ls -d /sys/kernel/mm/hugepages/hugepages-* 2>/dev/null | wc -l)
        echo "Huge Pages: Available (${hugepage_sizes} sizes)"
        echo "  ✓ Huge pages configured on host"
        echo "  → Improves VM memory performance"
        return 0
    else
        echo "Huge Pages: Unavailable"
        echo "  ✗ Huge pages not configured on host"
        echo "  → VM will use standard page sizes"
        return 1
    fi
}

# ============================================================================
# Interactive Menu Functions
# ============================================================================

# Create whiptail/dialog checklist of hardware features
# Usage: create_hardware_features_menu
create_hardware_features_menu() {
    local menu_items=()

    # Always available features
    menu_items+=("virtio_disk" "VirtIO Disk (recommended)" "ON")
    menu_items+=("virtio_net" "VirtIO Network (recommended)" "ON")

    # GPU Passthrough (hardware-dependent)
    if can_use_gpu_passthrough; then
        menu_items+=("gpu_passthrough" "GPU Passthrough" "OFF")
    else
        menu_items+=("gpu_passthrough_disabled" "GPU Passthrough (unavailable: $(get_unavailable_reason 'gpu_passthrough'))" "OFF")
    fi

    # Nested Virtualization (hardware-dependent)
    if can_use_nested_virt; then
        menu_items+=("nested_virt" "Nested Virtualization" "OFF")
    else
        menu_items+=("nested_virt_disabled" "Nested Virtualization (unavailable: $(get_unavailable_reason 'nested_virtualization'))" "OFF")
    fi

    # SR-IOV (hardware-dependent)
    if can_use_sriov; then
        menu_items+=("sriov" "SR-IOV Network" "OFF")
    else
        menu_items+=("sriov_disabled" "SR-IOV Network (unavailable: $(get_unavailable_reason 'iommu'))" "OFF")
    fi

    # Huge Pages (system-dependent)
    if can_use_hugepages; then
        menu_items+=("hugepages" "Huge Pages (better performance)" "OFF")
    else
        menu_items+=("hugepages_disabled" "Huge Pages (unavailable: not configured)" "OFF")
    fi

    # Platform-specific features
    if is_laptop; then
        menu_items+=("power_management" "Laptop Power Management" "ON")
    fi

    # GPU-specific features
    if has_nvidia_gpu; then
        menu_items+=("nvidia_vgpu" "NVIDIA vGPU (if licensed)" "OFF")
    fi

    if has_amd_gpu; then
        menu_items+=("amd_mxgpu" "AMD MxGPU (if supported)" "OFF")
    fi

    echo "${menu_items[@]}"
}

# Show VM creation summary with hardware awareness
show_vm_hardware_summary() {
    local vm_name="$1"

    cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VM Hardware Configuration: ${vm_name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Platform: $(get_platform_type)
  CPU Architecture: $(get_cpu_architecture)
  CPU Vendor: $(get_cpu_vendor)

  Available Features:
EOF

    print_option_status "    GPU Passthrough" "gpu_passthrough"
    print_option_status "    Nested Virtualization" "nested_virtualization"
    print_option_status "    SR-IOV Networking" "iommu"
    print_option_status "    Huge Pages" "hugepages"

    if has_nvidia_gpu; then
        print_option_status "    NVIDIA GPU Features" "nvidia_drivers"
    fi

    if has_amd_gpu; then
        print_option_status "    AMD GPU Features" "amd_rocm"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Get recommended VM CPU architecture based on host
get_recommended_vm_arch() {
    local host_arch=$(get_cpu_architecture)

    case "${host_arch}" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64)
            echo "aarch64"
            ;;
        riscv64)
            echo "riscv64"
            ;;
        ppc64le)
            echo "ppc64le"
            ;;
        *)
            echo "${host_arch}"
            ;;
    esac
}

# Get list of supported VM architectures (with emulation)
get_supported_vm_architectures() {
    local host_arch=$(get_cpu_architecture)
    local supported=("${host_arch}")

    # x86_64 can run x86, ARM with QEMU
    if [[ "${host_arch}" == "x86_64" ]]; then
        supported+=("i686" "x86" "aarch64" "arm")
    fi

    # ARM64 can run ARM32 with QEMU
    if [[ "${host_arch}" == "aarch64" ]]; then
        supported+=("arm" "armv7l")
    fi

    echo "${supported[@]}"
}

# Check if architecture requires emulation
is_emulated_architecture() {
    local vm_arch="$1"
    local host_arch=$(get_cpu_architecture)

    [[ "${vm_arch}" != "${host_arch}" ]] && return 0 || return 1
}

# Show warning for emulated architectures
show_emulation_warning() {
    local vm_arch="$1"

    cat <<EOF

⚠️  WARNING: Architecture Emulation

  VM Architecture: ${vm_arch}
  Host Architecture: $(get_cpu_architecture)

  This VM will run in EMULATION mode, which means:
  • Much slower performance (10-100x slower)
  • Higher CPU usage on host
  • Some features may not work correctly

  Emulation is useful for:
  • Cross-platform testing
  • Running software unavailable for your CPU
  • Development and debugging

  For production workloads, use native architecture.

EOF
}

# Export functions for use in wizards
export -f can_use_gpu_passthrough
export -f can_use_nested_virt
export -f can_use_sriov
export -f can_use_hugepages
export -f show_gpu_passthrough_option
export -f show_sriov_option
export -f show_nested_virt_option
export -f show_hugepages_option
export -f create_hardware_features_menu
export -f show_vm_hardware_summary
export -f get_recommended_vm_arch
export -f get_supported_vm_architectures
export -f is_emulated_architecture
export -f show_emulation_warning
