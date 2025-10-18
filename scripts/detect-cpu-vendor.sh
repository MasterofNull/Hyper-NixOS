#!/usr/bin/env bash
#
# Hyper-NixOS Universal CPU Architecture Detection
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Detects CPU architecture and vendor across ALL supported platforms
# No hardcoded settings - intelligent discovery only
# Supports: x86_64 (Intel/AMD), ARM (32/64), RISC-V, PowerPC, MIPS, etc.

set -euo pipefail

# Detect CPU architecture
detect_architecture() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        i386|i686)
            echo "x86"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        armv7l|armv6l|arm)
            echo "arm"
            ;;
        riscv64)
            echo "riscv64"
            ;;
        riscv32)
            echo "riscv32"
            ;;
        ppc64le)
            echo "ppc64le"
            ;;
        ppc64)
            echo "ppc64"
            ;;
        mips64)
            echo "mips64"
            ;;
        mips)
            echo "mips"
            ;;
        s390x)
            echo "s390x"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect CPU vendor from /proc/cpuinfo
detect_cpu_vendor() {
    local vendor=""
    local arch
    arch=$(detect_architecture)

    case "$arch" in
        x86_64|x86)
            # x86/x86_64 vendor detection
            if grep -qi "AuthenticAMD\|Advanced Micro Devices" /proc/cpuinfo 2>/dev/null; then
                vendor="amd"
            elif grep -qi "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
                vendor="intel"
            elif grep -qi "CentaurHauls" /proc/cpuinfo 2>/dev/null; then
                vendor="via"
            elif grep -qi "Hygon" /proc/cpuinfo 2>/dev/null; then
                vendor="hygon"  # Chinese x86 vendor
            else
                vendor="x86_generic"
            fi
            ;;

        aarch64|arm)
            # ARM vendor detection
            if grep -qi "Qualcomm" /proc/cpuinfo 2>/dev/null; then
                vendor="qualcomm"
            elif grep -qi "Broadcom" /proc/cpuinfo 2>/dev/null; then
                vendor="broadcom"
            elif grep -qi "NVIDIA" /proc/cpuinfo 2>/dev/null; then
                vendor="nvidia"
            elif grep -qi "Apple" /proc/cpuinfo 2>/dev/null; then
                vendor="apple"
            elif grep -qi "Marvell" /proc/cpuinfo 2>/dev/null; then
                vendor="marvell"
            elif grep -qi "Rockchip" /proc/cpuinfo 2>/dev/null; then
                vendor="rockchip"
            elif grep -qi "Allwinner" /proc/cpuinfo 2>/dev/null; then
                vendor="allwinner"
            elif grep -qi "Amlogic" /proc/cpuinfo 2>/dev/null; then
                vendor="amlogic"
            elif grep -qi "MediaTek" /proc/cpuinfo 2>/dev/null; then
                vendor="mediatek"
            else
                # Check device tree for more info
                if [[ -d /proc/device-tree ]]; then
                    if grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
                        vendor="broadcom"  # Raspberry Pi
                    elif grep -qi "odroid" /proc/device-tree/model 2>/dev/null; then
                        vendor="samsung"  # ODROID
                    else
                        vendor="arm_generic"
                    fi
                else
                    vendor="arm_generic"
                fi
            fi
            ;;

        riscv64|riscv32)
            # RISC-V vendor detection
            if grep -qi "SiFive" /proc/cpuinfo 2>/dev/null; then
                vendor="sifive"
            elif grep -qi "StarFive" /proc/cpuinfo 2>/dev/null; then
                vendor="starfive"
            elif grep -qi "Allwinner" /proc/cpuinfo 2>/dev/null; then
                vendor="allwinner"
            else
                vendor="riscv_generic"
            fi
            ;;

        ppc64le|ppc64)
            # PowerPC vendor detection
            if grep -qi "IBM" /proc/cpuinfo 2>/dev/null; then
                vendor="ibm"
            else
                vendor="ppc_generic"
            fi
            ;;

        mips64|mips)
            # MIPS vendor detection
            if grep -qi "Loongson" /proc/cpuinfo 2>/dev/null; then
                vendor="loongson"
            elif grep -qi "Cavium" /proc/cpuinfo 2>/dev/null; then
                vendor="cavium"
            else
                vendor="mips_generic"
            fi
            ;;

        s390x)
            vendor="ibm"  # IBM Z mainframe
            ;;

        *)
            vendor="unknown"
            ;;
    esac

    echo "${vendor:-unknown}"
}

# Detect virtualization capabilities
detect_virt_capability() {
    local arch
    arch=$(detect_architecture)

    case "$arch" in
        x86_64|x86)
            # Check for VMX (Intel) or SVM (AMD)
            if grep -q "vmx" /proc/cpuinfo 2>/dev/null; then
                echo "vmx"  # Intel VT-x
            elif grep -q "svm" /proc/cpuinfo 2>/dev/null; then
                echo "svm"  # AMD-V
            else
                echo "none"
            fi
            ;;
        aarch64|arm)
            # ARM virtualization extensions
            if grep -q "virt" /proc/cpuinfo 2>/dev/null; then
                echo "arm-virt"
            else
                echo "none"
            fi
            ;;
        riscv64|riscv32)
            # RISC-V hypervisor extension
            if grep -q "h" /proc/cpuinfo 2>/dev/null; then
                echo "riscv-h"
            else
                echo "none"
            fi
            ;;
        ppc64le|ppc64)
            # PowerPC has built-in virtualization
            echo "ppc-virt"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get IOMMU kernel parameter (architecture-aware)
get_iommu_param() {
    local vendor="$1"
    local arch
    arch=$(detect_architecture)

    case "$arch" in
        x86_64|x86)
            case "$vendor" in
                amd|hygon) echo "amd_iommu=on" ;;
                intel) echo "intel_iommu=on" ;;
                *) echo "iommu=pt" ;;  # Generic x86
            esac
            ;;
        aarch64|arm)
            echo "iommu.passthrough=0"  # ARM SMMU
            ;;
        *)
            echo ""  # No IOMMU parameter for other architectures
            ;;
    esac
}

# Get virtualization-specific kernel parameters
get_virt_params() {
    local vendor="$1"
    local arch
    arch=$(detect_architecture)

    case "$arch" in
        x86_64|x86)
            case "$vendor" in
                amd|hygon) echo "kvm_amd.nested=1" ;;
                intel) echo "kvm_intel.nested=1" ;;
                *) echo "" ;;
            esac
            ;;
        aarch64|arm)
            echo "kvm-arm.mode=nvhe"  # Non-VHE mode for better compatibility
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get KVM kernel module name (architecture-aware)
get_kvm_module() {
    local vendor="$1"
    local arch
    arch=$(detect_architecture)

    case "$arch" in
        x86_64|x86)
            case "$vendor" in
                amd|hygon) echo "kvm-amd" ;;
                intel) echo "kvm-intel" ;;
                via) echo "kvm" ;;  # VIA uses generic KVM
                *) echo "kvm" ;;
            esac
            ;;
        aarch64|arm)
            echo "kvm"  # ARM uses generic KVM module
            ;;
        riscv64|riscv32)
            echo "kvm"  # RISC-V KVM
            ;;
        ppc64le|ppc64)
            echo "kvm-hv"  # PowerPC hypervisor mode
            ;;
        *)
            echo ""  # No KVM for other architectures
            ;;
    esac
}

# Get all virtualization-related modules for this architecture
get_virt_modules() {
    local arch
    arch=$(detect_architecture)

    case "$arch" in
        x86_64|x86)
            echo "vfio vfio_iommu_type1 vfio_pci vfio_virqfd"
            ;;
        aarch64|arm)
            echo "vfio vfio_platform vfio_platform_base"
            ;;
        *)
            echo "vfio"  # Minimal VFIO support
            ;;
    esac
}

# Main function
main() {
    local mode="${1:-json}"
    local arch vendor virt_cap
    arch=$(detect_architecture)
    vendor=$(detect_cpu_vendor)
    virt_cap=$(detect_virt_capability)

    case "$mode" in
        architecture)
            echo "$arch"
            ;;
        vendor)
            echo "$vendor"
            ;;
        virt-capability)
            echo "$virt_cap"
            ;;
        iommu)
            get_iommu_param "$vendor"
            ;;
        virt-params)
            get_virt_params "$vendor"
            ;;
        kvm-module)
            get_kvm_module "$vendor"
            ;;
        virt-modules)
            get_virt_modules
            ;;
        json)
            # Output comprehensive JSON for easy parsing
            local iommu_param virt_params kvm_mod virt_mods
            iommu_param=$(get_iommu_param "$vendor")
            virt_params=$(get_virt_params "$vendor")
            kvm_mod=$(get_kvm_module "$vendor")
            virt_mods=$(get_virt_modules)

            cat <<EOF
{
  "architecture": "$arch",
  "vendor": "$vendor",
  "virtualization_capability": "$virt_cap",
  "iommu_param": "$iommu_param",
  "virt_params": "$virt_params",
  "kvm_module": "$kvm_mod",
  "virt_modules": "$virt_mods"
}
EOF
            ;;
        nix-boot-params)
            # Output Nix list format for boot.kernelParams (no hardcoding!)
            local params=()
            local iommu virt
            iommu=$(get_iommu_param "$vendor")
            virt=$(get_virt_params "$vendor")

            [[ -n "$iommu" ]] && params+=("\"$iommu\"")
            params+=("\"iommu=pt\"")
            [[ -n "$virt" ]] && params+=("\"$virt\"")
            params+=("\"transparent_hugepage=madvise\"")

            echo "[ $(IFS=' '; echo "${params[*]}") ]"
            ;;
        nix-modules)
            # Output Nix list format for boot.kernelModules (architecture-aware!)
            local kvm_mod virt_mods modules=()
            kvm_mod=$(get_kvm_module "$vendor")
            virt_mods=$(get_virt_modules)

            [[ -n "$kvm_mod" ]] && modules+=("\"$kvm_mod\"")
            for mod in $virt_mods; do
                modules+=("\"$mod\"")
            done

            echo "[ $(IFS=' '; echo "${modules[*]}") ]"
            ;;
        *)
            cat >&2 <<EOF
Usage: $0 [MODE]

Universal Hardware Detection - No Hardcoded Settings!

Modes:
  architecture       - Print CPU architecture (x86_64, aarch64, riscv64, etc.)
  vendor             - Print CPU vendor (amd, intel, broadcom, qualcomm, etc.)
  virt-capability    - Print virtualization capability (vmx, svm, arm-virt, etc.)
  iommu              - Print IOMMU kernel parameter (architecture-aware)
  virt-params        - Print virtualization-specific parameters
  kvm-module         - Print KVM kernel module name
  virt-modules       - Print all virtualization modules
  json               - Print comprehensive info as JSON (default)
  nix-boot-params    - Print Nix list for boot.kernelParams
  nix-modules        - Print Nix list for boot.kernelModules

Supported Architectures:
  • x86_64 / x86     - Intel, AMD, VIA, Hygon
  • aarch64 / arm    - Qualcomm, Broadcom, NVIDIA, Apple, Rockchip, Allwinner, etc.
  • riscv64 / riscv32 - SiFive, StarFive, Allwinner
  • ppc64le / ppc64  - IBM PowerPC
  • mips64 / mips    - Loongson, Cavium
  • s390x            - IBM Z mainframe

Examples:
  $0 json                    # Full hardware info
  $0 architecture            # Just the CPU architecture
  $0 vendor                  # Just the vendor
  $0 nix-boot-params         # For NixOS configuration
EOF
            exit 1
            ;;
    esac
}

main "$@"
