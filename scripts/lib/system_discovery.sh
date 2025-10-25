#!/usr/bin/env bash
# Hyper-NixOS System Discovery Library
# Implements intelligent hardware/platform detection for best-practice defaults
# Part of Design Ethos - Third Pillar: Learning Through Guidance

# Prevent multiple sourcing
[[ -n "${_SYSTEM_DISCOVERY_LOADED:-}" ]] && return 0
readonly _SYSTEM_DISCOVERY_LOADED=1

set -euo pipefail

################################################################################
# CPU Detection
################################################################################

# Get total CPU cores
get_cpu_cores() {
    nproc 2>/dev/null || echo "1"
}

# Get CPU model name
get_cpu_model() {
    grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown"
}

# Check for virtualization support
check_virt_support() {
    if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
        echo "yes"
    else
        echo "no"
    fi
}

# Get CPU architecture
get_cpu_arch() {
    uname -m 2>/dev/null || echo "x86_64"
}

# Calculate recommended vCPUs for VM (25-50% of host cores)
calculate_recommended_vcpus() {
    local total_cores=$1
    local percentage=${2:-25}  # Default 25%
    local min_vcpus=${3:-2}    # Minimum 2 vCPUs
    
    local recommended=$((total_cores * percentage / 100))
    
    # Ensure minimum
    if [ "$recommended" -lt "$min_vcpus" ]; then
        recommended=$min_vcpus
    fi
    
    echo "$recommended"
}

################################################################################
# Memory Detection
################################################################################

# Get total system RAM in MB
get_total_ram_mb() {
    local mem_kb
    mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    echo $((mem_kb / 1024))
}

# Get available RAM in MB
get_available_ram_mb() {
    local mem_kb
    mem_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
    echo $((mem_kb / 1024))
}

# Calculate recommended RAM for VM
calculate_recommended_ram() {
    local total_ram_mb=$1
    local vcpus=$2
    local ram_per_vcpu=${3:-2048}  # Default 2GB per vCPU
    
    # Calculate based on vCPUs
    local ram_by_vcpu=$((vcpus * ram_per_vcpu))
    
    # Don't exceed 50% of host RAM
    local max_ram=$((total_ram_mb / 2))
    
    if [ "$ram_by_vcpu" -gt "$max_ram" ]; then
        echo "$max_ram"
    else
        echo "$ram_by_vcpu"
    fi
}

################################################################################
# Storage Detection
################################################################################

# Detect storage type (nvme, ssd, hdd)
detect_storage_type() {
    local device=${1:-/dev/sda}
    
    # Check for NVMe
    if [[ $device == *"nvme"* ]]; then
        echo "nvme"
        return 0
    fi
    
    # Check rotation (0 = SSD, 1 = HDD)
    local rotation
    if [ -b "$device" ]; then
        local dev_name=$(basename "$device")
        rotation=$(cat "/sys/block/${dev_name}/queue/rotational" 2>/dev/null || echo "1")
        if [ "$rotation" -eq 0 ]; then
            echo "ssd"
        else
            echo "hdd"
        fi
    else
        # Check primary storage device
        local primary_device=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
        detect_storage_type "$primary_device"
    fi
}

# Get available storage space in GB
get_available_storage_gb() {
    local path=${1:-/var/lib/hypervisor}
    
    if [ ! -d "$path" ]; then
        # Use root if path doesn't exist
        path="/"
    fi
    
    df -BG "$path" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || echo "0"
}

# Recommend disk format based on storage type
recommend_disk_format() {
    local storage_type=$1
    
    case "$storage_type" in
        nvme|ssd)
            echo "qcow2"  # Best for snapshots, thin provisioning
            ;;
        hdd)
            echo "raw"    # Better performance on spinning disks
            ;;
        *)
            echo "qcow2"  # Default to qcow2
            ;;
    esac
}

# Calculate recommended disk size
calculate_recommended_disk_gb() {
    local os_type=${1:-linux}
    
    case "$os_type" in
        windows)
            echo "60"  # Windows needs more space
            ;;
        linux|ubuntu|debian|fedora|arch)
            echo "40"  # Standard Linux
            ;;
        minimal)
            echo "20"  # Minimal installations
            ;;
        *)
            echo "40"  # Default
            ;;
    esac
}

################################################################################
# Network Detection
################################################################################

# List available bridges
list_bridges() {
    bridge link 2>/dev/null | awk '{print $7}' | sort -u | grep -v '^$' || echo ""
}

# Check if default bridge exists
check_default_bridge() {
    local bridge=${1:-virbr0}
    
    if bridge link 2>/dev/null | grep -q "$bridge"; then
        echo "yes"
    else
        echo "no"
    fi
}

# Recommend network mode
recommend_network_mode() {
    local has_bridges=$(list_bridges)
    
    if [ -n "$has_bridges" ]; then
        # Bridges available, but NAT is more secure by default
        echo "nat"
    else
        echo "nat"
    fi
}

# Get default network bridge
get_default_bridge() {
    local bridges=$(list_bridges | head -1)
    
    if [ -n "$bridges" ]; then
        echo "$bridges"
    else
        echo "virbr0"  # Standard default
    fi
}

################################################################################
# GPU Detection
################################################################################

# Detect GPU
detect_gpu() {
    if lspci 2>/dev/null | grep -iE "VGA|3D" | grep -iq "nvidia"; then
        echo "nvidia"
    elif lspci 2>/dev/null | grep -iE "VGA|3D" | grep -iq "amd"; then
        echo "amd"
    elif lspci 2>/dev/null | grep -iE "VGA|3D" | grep -iq "intel"; then
        echo "intel"
    else
        echo "none"
    fi
}

# Check if GPU passthrough is possible
check_gpu_passthrough() {
    local virt_support=$(check_virt_support)
    local gpu=$(detect_gpu)
    
    if [ "$virt_support" = "yes" ] && [ "$gpu" != "none" ]; then
        if grep -q "IOMMU" /proc/cpuinfo 2>/dev/null || \
           dmesg 2>/dev/null | grep -q "IOMMU"; then
            echo "possible"
        else
            echo "no-iommu"
        fi
    else
        echo "no"
    fi
}

################################################################################
# Platform Detection
################################################################################

# Detect NixOS version
get_nixos_version() {
    nixos-version 2>/dev/null || echo "unknown"
}

# Detect kernel version
get_kernel_version() {
    uname -r 2>/dev/null || echo "unknown"
}

# Detect init system
detect_init_system() {
    if [ -d /run/systemd/system ]; then
        echo "systemd"
    elif [ -f /sbin/openrc ]; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

################################################################################
# Comprehensive System Report
################################################################################

# Generate complete system discovery report
generate_system_report() {
    local format=${1:-text}  # text or json
    
    local cpu_cores=$(get_cpu_cores)
    local cpu_model=$(get_cpu_model)
    local cpu_arch=$(get_cpu_arch)
    local virt_support=$(check_virt_support)
    local total_ram=$(get_total_ram_mb)
    local available_ram=$(get_available_ram_mb)
    local storage_type=$(detect_storage_type)
    local available_storage=$(get_available_storage_gb)
    local gpu=$(detect_gpu)
    local gpu_passthrough=$(check_gpu_passthrough)
    local default_bridge=$(get_default_bridge)
    local nixos_version=$(get_nixos_version)
    
    if [ "$format" = "json" ]; then
        cat <<EOF
{
  "cpu": {
    "cores": $cpu_cores,
    "model": "$cpu_model",
    "architecture": "$cpu_arch",
    "virtualization": "$virt_support"
  },
  "memory": {
    "total_mb": $total_ram,
    "available_mb": $available_ram
  },
  "storage": {
    "type": "$storage_type",
    "available_gb": $available_storage
  },
  "network": {
    "default_bridge": "$default_bridge"
  },
  "gpu": {
    "type": "$gpu",
    "passthrough": "$gpu_passthrough"
  },
  "platform": {
    "nixos_version": "$nixos_version",
    "kernel": "$(get_kernel_version)",
    "init": "$(detect_init_system)"
  }
}
EOF
    else
        cat <<EOF
╔════════════════════════════════════════════════════════════╗
║  System Discovery Report                                   ║
╚════════════════════════════════════════════════════════════╝

CPU:
  • Cores: $cpu_cores
  • Model: $cpu_model
  • Architecture: $cpu_arch
  • Virtualization Support: $virt_support

Memory:
  • Total RAM: ${total_ram}MB
  • Available RAM: ${available_ram}MB

Storage:
  • Type: $storage_type
  • Available Space: ${available_storage}GB

Network:
  • Default Bridge: $default_bridge

GPU:
  • Type: $gpu
  • Passthrough Support: $gpu_passthrough

Platform:
  • NixOS Version: $nixos_version
  • Kernel: $(get_kernel_version)
  • Init System: $(detect_init_system)
EOF
    fi
}

################################################################################
# Intelligent Defaults Generation
################################################################################

# Generate intelligent defaults for VM creation
generate_vm_defaults() {
    local os_type=${1:-linux}
    local format=${2:-bash}
    
    # Detect system
    local cpu_cores=$(get_cpu_cores)
    local total_ram=$(get_total_ram_mb)
    local storage_type=$(detect_storage_type)
    local default_bridge=$(get_default_bridge)
    
    # Calculate recommendations
    local rec_vcpus=$(calculate_recommended_vcpus "$cpu_cores" 25 2)
    local rec_ram=$(calculate_recommended_ram "$total_ram" "$rec_vcpus" 2048)
    local rec_disk=$(calculate_recommended_disk_gb "$os_type")
    local rec_disk_format=$(recommend_disk_format "$storage_type")
    local rec_network=$(recommend_network_mode)
    
    if [ "$format" = "json" ]; then
        cat <<EOF
{
  "vcpus": $rec_vcpus,
  "memory_mb": $rec_ram,
  "disk_gb": $rec_disk,
  "disk_format": "$rec_disk_format",
  "network_mode": "$rec_network",
  "network_bridge": "$default_bridge",
  "detection_info": {
    "host_cores": $cpu_cores,
    "host_ram_mb": $total_ram,
    "storage_type": "$storage_type",
    "reasoning": {
      "vcpus": "25% of $cpu_cores host cores for balanced performance",
      "memory": "2GB per vCPU, max 50% of host RAM",
      "disk_format": "$rec_disk_format optimal for $storage_type storage",
      "network": "NAT for security, can upgrade to bridge if needed"
    }
  }
}
EOF
    else
        # Bash variable output
        cat <<EOF
# Intelligent defaults based on hardware detection
DETECTED_CPU_CORES=$cpu_cores
DETECTED_RAM_MB=$total_ram
DETECTED_STORAGE_TYPE="$storage_type"

# Recommended VM settings
RECOMMENDED_VCPUS=$rec_vcpus        # 25% of $cpu_cores host cores
RECOMMENDED_RAM_MB=$rec_ram          # 2GB per vCPU, max 50% host RAM
RECOMMENDED_DISK_GB=$rec_disk        # Standard for $os_type
RECOMMENDED_DISK_FORMAT="$rec_disk_format"  # Optimal for $storage_type
RECOMMENDED_NETWORK="$rec_network"   # Secure default
RECOMMENDED_BRIDGE="$default_bridge"

# Reasoning
VCPU_REASON="Allocating 25% of host cores ($cpu_cores) for balanced performance"
RAM_REASON="2GB per vCPU (${rec_vcpus} vCPUs), not exceeding 50% host RAM"
DISK_FORMAT_REASON="$rec_disk_format format optimal for $storage_type storage (snapshots, thin provisioning)"
NETWORK_REASON="NAT mode for security isolation, bridge available for performance"
EOF
    fi
}

################################################################################
# Export functions
################################################################################

export -f get_cpu_cores
export -f get_cpu_model
export -f check_virt_support
export -f get_cpu_arch
export -f calculate_recommended_vcpus
export -f get_total_ram_mb
export -f get_available_ram_mb
export -f calculate_recommended_ram
export -f detect_storage_type
export -f get_available_storage_gb
export -f recommend_disk_format
export -f calculate_recommended_disk_gb
export -f list_bridges
export -f check_default_bridge
export -f recommend_network_mode
export -f get_default_bridge
export -f detect_gpu
export -f check_gpu_passthrough
export -f get_nixos_version
export -f get_kernel_version
export -f detect_init_system
export -f generate_system_report
export -f generate_vm_defaults
