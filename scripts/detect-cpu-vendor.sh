#!/usr/bin/env bash
#
# Hyper-NixOS CPU Vendor Detection
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Detects CPU vendor (Intel or AMD) and returns appropriate NixOS settings
# This script is used during installation to configure correct CPU-specific settings

set -euo pipefail

# Detect CPU vendor from /proc/cpuinfo
detect_cpu_vendor() {
    local vendor=""

    if grep -qi "AuthenticAMD\|Advanced Micro Devices" /proc/cpuinfo 2>/dev/null; then
        vendor="amd"
    elif grep -qi "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
        vendor="intel"
    else
        # Fallback: try lscpu
        if command -v lscpu >/dev/null 2>&1; then
            local vendor_string
            vendor_string=$(lscpu | grep "Vendor ID:" | awk '{print $3}' || echo "")
            if [[ "$vendor_string" =~ AMD|AuthenticAMD ]]; then
                vendor="amd"
            elif [[ "$vendor_string" =~ Intel|GenuineIntel ]]; then
                vendor="intel"
            fi
        fi
    fi

    # Default to unknown if detection fails
    echo "${vendor:-unknown}"
}

# Get IOMMU kernel parameter
get_iommu_param() {
    local vendor="$1"
    case "$vendor" in
        amd) echo "amd_iommu=on" ;;
        intel) echo "intel_iommu=on" ;;
        *) echo "iommu=on" ;;  # Generic fallback
    esac
}

# Get KVM nested parameter
get_kvm_nested_param() {
    local vendor="$1"
    case "$vendor" in
        amd) echo "kvm_amd.nested=1" ;;
        intel) echo "kvm_intel.nested=1" ;;
        *) echo "" ;;  # Unknown, omit parameter
    esac
}

# Get KVM kernel module name
get_kvm_module() {
    local vendor="$1"
    case "$vendor" in
        amd) echo "kvm-amd" ;;
        intel) echo "kvm-intel" ;;
        *) echo "kvm" ;;  # Generic fallback
    esac
}

# Main function
main() {
    local mode="${1:-json}"
    local vendor
    vendor=$(detect_cpu_vendor)

    case "$mode" in
        vendor)
            echo "$vendor"
            ;;
        iommu)
            get_iommu_param "$vendor"
            ;;
        nested)
            get_kvm_nested_param "$vendor"
            ;;
        module)
            get_kvm_module "$vendor"
            ;;
        json)
            # Output JSON for easy parsing
            cat <<EOF
{
  "vendor": "$vendor",
  "iommu_param": "$(get_iommu_param "$vendor")",
  "nested_param": "$(get_kvm_nested_param "$vendor")",
  "kvm_module": "$(get_kvm_module "$vendor")"
}
EOF
            ;;
        nix-boot-params)
            # Output Nix list format for boot.kernelParams
            local iommu nested
            iommu=$(get_iommu_param "$vendor")
            nested=$(get_kvm_nested_param "$vendor")
            echo "[ \"$iommu\" \"iommu=pt\" \"$nested\" \"transparent_hugepage=madvise\" ]"
            ;;
        nix-modules)
            # Output Nix list format for boot.kernelModules
            local kvm_mod
            kvm_mod=$(get_kvm_module "$vendor")
            echo "[ \"$kvm_mod\" \"vfio\" \"vfio_iommu_type1\" \"vfio_pci\" ]"
            ;;
        *)
            echo "Usage: $0 [vendor|iommu|nested|module|json|nix-boot-params|nix-modules]" >&2
            echo "" >&2
            echo "Modes:" >&2
            echo "  vendor          - Print CPU vendor (amd/intel/unknown)" >&2
            echo "  iommu           - Print IOMMU kernel parameter" >&2
            echo "  nested          - Print nested virtualization parameter" >&2
            echo "  module          - Print KVM kernel module name" >&2
            echo "  json            - Print all info as JSON (default)" >&2
            echo "  nix-boot-params - Print Nix list for boot.kernelParams" >&2
            echo "  nix-modules     - Print Nix list for boot.kernelModules" >&2
            exit 1
            ;;
    esac
}

main "$@"
