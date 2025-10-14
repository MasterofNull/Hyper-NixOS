#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS System Detection Library
# Provides consistent system information detection and requirement checking
#

# Prevent multiple sourcing
if [[ -n "${_HYPERVISOR_SYSTEM_LOADED:-}" ]]; then
    return 0
fi
readonly _HYPERVISOR_SYSTEM_LOADED=1

# Source UI library if available
[[ -f "${HYPERVISOR_SCRIPTS:-/etc/hypervisor/scripts}/lib/ui.sh" ]] && \
    source "${HYPERVISOR_SCRIPTS:-/etc/hypervisor/scripts}/lib/ui.sh"

# Cache for system information
declare -g SYSTEM_INFO_CACHED=false
declare -g SYSTEM_RAM_MB=0
declare -g SYSTEM_RAM_GB=0
declare -g SYSTEM_CPUS=0
declare -g SYSTEM_ARCH=""
declare -g SYSTEM_KERNEL=""
declare -g SYSTEM_DISK_GB=0
declare -g SYSTEM_DISK_AVAILABLE_GB=0
declare -g SYSTEM_GPU=""
declare -g SYSTEM_GPU_VENDOR=""
declare -g SYSTEM_VIRTUALIZATION=""
declare -g SYSTEM_CONTAINER=""
declare -g SYSTEM_INIT=""

# Hardware capability flags
declare -g HAS_VIRTUALIZATION=false
declare -g HAS_IOMMU=false
declare -g HAS_AVX=false
declare -g HAS_AVX2=false
declare -g HAS_AES=false
declare -g HAS_ECC_RAM=false
declare -g HAS_NVME=false
declare -g HAS_SSD=false

# Network information
declare -g NETWORK_INTERFACES=()
declare -g NETWORK_COUNT=0
declare -g HAS_INTERNET=false

# Detect system resources with caching
detect_system_resources() {
    if [[ "$SYSTEM_INFO_CACHED" == "true" ]]; then
        return 0
    fi
    
    # RAM detection
    if [[ -f /proc/meminfo ]]; then
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        SYSTEM_RAM_MB=$((mem_kb / 1024))
        SYSTEM_RAM_GB=$((SYSTEM_RAM_MB / 1024))
    fi
    
    # CPU detection
    SYSTEM_CPUS=$(nproc 2>/dev/null || echo 1)
    
    # Architecture detection
    SYSTEM_ARCH=$(uname -m)
    
    # Kernel detection
    SYSTEM_KERNEL=$(uname -r)
    
    # Disk space detection
    if command -v df >/dev/null 2>&1; then
        local disk_info=$(df -BG / | tail -1)
        SYSTEM_DISK_GB=$(echo "$disk_info" | awk '{print $2}' | sed 's/G//')
        SYSTEM_DISK_AVAILABLE_GB=$(echo "$disk_info" | awk '{print $4}' | sed 's/G//')
    fi
    
    # GPU detection
    if command -v lspci >/dev/null 2>&1; then
        local gpu_info=$(lspci 2>/dev/null | grep -E "(VGA|3D|Display)" | head -1)
        if [[ -n "$gpu_info" ]]; then
            SYSTEM_GPU="present"
            if echo "$gpu_info" | grep -qi nvidia; then
                SYSTEM_GPU_VENDOR="nvidia"
            elif echo "$gpu_info" | grep -qi amd; then
                SYSTEM_GPU_VENDOR="amd"
            elif echo "$gpu_info" | grep -qi intel; then
                SYSTEM_GPU_VENDOR="intel"
            else
                SYSTEM_GPU_VENDOR="unknown"
            fi
        else
            SYSTEM_GPU="none"
            SYSTEM_GPU_VENDOR="none"
        fi
    fi
    
    # Virtualization detection
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        SYSTEM_VIRTUALIZATION=$(systemd-detect-virt -v 2>/dev/null || echo "none")
        SYSTEM_CONTAINER=$(systemd-detect-virt -c 2>/dev/null || echo "none")
    else
        # Fallback detection
        if [[ -f /proc/cpuinfo ]]; then
            if grep -q "hypervisor" /proc/cpuinfo; then
                SYSTEM_VIRTUALIZATION="vm"
            else
                SYSTEM_VIRTUALIZATION="none"
            fi
        fi
    fi
    
    # Init system detection
    if [[ -d /run/systemd/system ]]; then
        SYSTEM_INIT="systemd"
    elif command -v openrc >/dev/null 2>&1; then
        SYSTEM_INIT="openrc"
    elif [[ -f /etc/init.d/rc ]]; then
        SYSTEM_INIT="sysvinit"
    else
        SYSTEM_INIT="unknown"
    fi
    
    # Hardware capabilities
    detect_hardware_capabilities
    
    # Network interfaces
    detect_network_info
    
    SYSTEM_INFO_CACHED=true
}

# Detect hardware capabilities
detect_hardware_capabilities() {
    # CPU virtualization extensions
    if [[ -f /proc/cpuinfo ]]; then
        if grep -qE "(vmx|svm)" /proc/cpuinfo; then
            HAS_VIRTUALIZATION=true
        fi
        
        # AVX support
        if grep -q " avx " /proc/cpuinfo; then
            HAS_AVX=true
        fi
        
        if grep -q " avx2 " /proc/cpuinfo; then
            HAS_AVX2=true
        fi
        
        # AES-NI support
        if grep -q " aes " /proc/cpuinfo; then
            HAS_AES=true
        fi
    fi
    
    # IOMMU support
    if [[ -d /sys/kernel/iommu_groups ]] && [[ $(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l) -gt 0 ]]; then
        HAS_IOMMU=true
    fi
    
    # ECC RAM detection (requires dmidecode and root)
    if [[ $EUID -eq 0 ]] && command -v dmidecode >/dev/null 2>&1; then
        if dmidecode -t memory 2>/dev/null | grep -q "Error Correction Type: Multi-bit ECC"; then
            HAS_ECC_RAM=true
        fi
    fi
    
    # Storage type detection
    if command -v lsblk >/dev/null 2>&1; then
        if lsblk -d -o name,rota 2>/dev/null | grep -q " 0$"; then
            HAS_SSD=true
        fi
        if lsblk -d -o name,tran 2>/dev/null | grep -q "nvme"; then
            HAS_NVME=true
        fi
    fi
}

# Detect network information
detect_network_info() {
    if command -v ip >/dev/null 2>&1; then
        # Get physical network interfaces (exclude lo, veth, docker, etc.)
        mapfile -t NETWORK_INTERFACES < <(ip -o link show | \
            grep -v "lo:" | \
            grep -vE "(veth|docker|br-|virbr|tap)" | \
            awk -F': ' '{print $2}')
        NETWORK_COUNT=${#NETWORK_INTERFACES[@]}
    fi
    
    # Check internet connectivity
    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || \
           ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            HAS_INTERNET=true
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout 2 --max-time 5 https://cloudflare.com >/dev/null 2>&1; then
            HAS_INTERNET=true
        fi
    fi
}

# Check system requirements
check_requirements() {
    local min_ram_mb="${1:-2048}"
    local min_cpus="${2:-2}"
    local min_disk_gb="${3:-20}"
    local require_virt="${4:-false}"
    
    detect_system_resources
    
    local errors=()
    local warnings=()
    
    # RAM check
    if [[ $SYSTEM_RAM_MB -lt $min_ram_mb ]]; then
        errors+=("Insufficient RAM: ${SYSTEM_RAM_MB}MB < ${min_ram_mb}MB required")
    elif [[ $SYSTEM_RAM_MB -lt $((min_ram_mb * 3 / 2)) ]]; then
        warnings+=("Low RAM: ${SYSTEM_RAM_MB}MB (recommend $((min_ram_mb * 3 / 2))MB+)")
    fi
    
    # CPU check
    if [[ $SYSTEM_CPUS -lt $min_cpus ]]; then
        errors+=("Insufficient CPUs: ${SYSTEM_CPUS} < ${min_cpus} required")
    fi
    
    # Disk check
    if [[ $SYSTEM_DISK_AVAILABLE_GB -lt $min_disk_gb ]]; then
        errors+=("Insufficient disk space: ${SYSTEM_DISK_AVAILABLE_GB}GB < ${min_disk_gb}GB required")
    elif [[ $SYSTEM_DISK_AVAILABLE_GB -lt $((min_disk_gb * 2)) ]]; then
        warnings+=("Low disk space: ${SYSTEM_DISK_AVAILABLE_GB}GB available")
    fi
    
    # Virtualization check
    if [[ "$require_virt" == "true" ]] && [[ "$HAS_VIRTUALIZATION" != "true" ]]; then
        errors+=("CPU virtualization extensions (VT-x/AMD-V) not detected")
    fi
    
    # Architecture check
    case "$SYSTEM_ARCH" in
        x86_64|amd64) ;;
        aarch64|arm64)
            warnings+=("ARM64 architecture - some features may be limited")
            ;;
        *)
            errors+=("Unsupported architecture: $SYSTEM_ARCH")
            ;;
    esac
    
    # Show results
    if [[ ${#errors[@]} -gt 0 ]]; then
        if command -v print_error >/dev/null 2>&1; then
            for error in "${errors[@]}"; do
                print_error "$error"
            done
        else
            for error in "${errors[@]}"; do
                echo "ERROR: $error" >&2
            done
        fi
        return 1
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        if command -v print_warning >/dev/null 2>&1; then
            for warning in "${warnings[@]}"; do
                print_warning "$warning"
            done
        else
            for warning in "${warnings[@]}"; do
                echo "WARNING: $warning" >&2
            done
        fi
    fi
    
    return 0
}

# Get system summary
get_system_summary() {
    detect_system_resources
    
    cat << EOF
System Information:
  Architecture: ${SYSTEM_ARCH}
  Kernel: ${SYSTEM_KERNEL}
  CPUs: ${SYSTEM_CPUS}
  RAM: ${SYSTEM_RAM_GB}GB (${SYSTEM_RAM_MB}MB)
  Disk: ${SYSTEM_DISK_AVAILABLE_GB}GB available / ${SYSTEM_DISK_GB}GB total
  GPU: ${SYSTEM_GPU} ${SYSTEM_GPU_VENDOR:+(${SYSTEM_GPU_VENDOR})}
  Virtualization: ${SYSTEM_VIRTUALIZATION}
  Container: ${SYSTEM_CONTAINER}
  Init System: ${SYSTEM_INIT}
  Network Interfaces: ${NETWORK_COUNT}
  Internet Access: $([ "$HAS_INTERNET" == "true" ] && echo "Yes" || echo "No")

Hardware Capabilities:
  CPU Virtualization: $([ "$HAS_VIRTUALIZATION" == "true" ] && echo "Yes" || echo "No")
  IOMMU: $([ "$HAS_IOMMU" == "true" ] && echo "Yes" || echo "No")
  AVX: $([ "$HAS_AVX" == "true" ] && echo "Yes" || echo "No")
  AVX2: $([ "$HAS_AVX2" == "true" ] && echo "Yes" || echo "No")
  AES-NI: $([ "$HAS_AES" == "true" ] && echo "Yes" || echo "No")
  ECC RAM: $([ "$HAS_ECC_RAM" == "true" ] && echo "Yes" || echo "Unknown")
  SSD: $([ "$HAS_SSD" == "true" ] && echo "Yes" || echo "No")
  NVMe: $([ "$HAS_NVME" == "true" ] && echo "Yes" || echo "No")
EOF
}

# Export system info as JSON
get_system_json() {
    detect_system_resources
    
    cat << EOF
{
  "hardware": {
    "arch": "${SYSTEM_ARCH}",
    "kernel": "${SYSTEM_KERNEL}",
    "cpus": ${SYSTEM_CPUS},
    "ram_mb": ${SYSTEM_RAM_MB},
    "ram_gb": ${SYSTEM_RAM_GB},
    "disk_total_gb": ${SYSTEM_DISK_GB},
    "disk_available_gb": ${SYSTEM_DISK_AVAILABLE_GB},
    "gpu": "${SYSTEM_GPU}",
    "gpu_vendor": "${SYSTEM_GPU_VENDOR}"
  },
  "environment": {
    "virtualization": "${SYSTEM_VIRTUALIZATION}",
    "container": "${SYSTEM_CONTAINER}",
    "init": "${SYSTEM_INIT}"
  },
  "capabilities": {
    "cpu_virt": ${HAS_VIRTUALIZATION},
    "iommu": ${HAS_IOMMU},
    "avx": ${HAS_AVX},
    "avx2": ${HAS_AVX2},
    "aes": ${HAS_AES},
    "ecc_ram": ${HAS_ECC_RAM},
    "ssd": ${HAS_SSD},
    "nvme": ${HAS_NVME}
  },
  "network": {
    "interfaces": $(printf '%s\n' "${NETWORK_INTERFACES[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
    "count": ${NETWORK_COUNT},
    "internet": ${HAS_INTERNET}
  }
}
EOF
}

# Recommend system tier based on resources
recommend_system_tier() {
    detect_system_resources
    
    if [[ $SYSTEM_RAM_GB -ge 32 ]] && [[ $SYSTEM_CPUS -ge 16 ]]; then
        echo "enterprise"
    elif [[ $SYSTEM_RAM_GB -ge 16 ]] && [[ $SYSTEM_CPUS -ge 8 ]]; then
        echo "professional"
    elif [[ $SYSTEM_RAM_GB -ge 8 ]] && [[ $SYSTEM_CPUS -ge 4 ]]; then
        echo "enhanced"
    elif [[ $SYSTEM_RAM_GB -ge 4 ]] && [[ $SYSTEM_CPUS -ge 4 ]]; then
        echo "standard"
    else
        echo "minimal"
    fi
}

# Export all functions
export -f detect_system_resources detect_hardware_capabilities detect_network_info
export -f check_requirements get_system_summary get_system_json recommend_system_tier