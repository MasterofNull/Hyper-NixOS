#!/usr/bin/env bash
# Hyper-NixOS Storage Configuration Wizard
# Intelligent defaults for storage tiers and pools
# Part of Design Ethos - Third Pillar: Learning Through Guidance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/system_discovery.sh" 2>/dev/null || true

# Colors  
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Detect storage devices
detect_storage_devices() {
    lsblk -d -n -o NAME,SIZE,ROTA,TYPE 2>/dev/null | grep disk
}

# Classify storage tiers
classify_storage_tiers() {
    local hot_tier=0
    local warm_tier=0
    local cold_tier=0
    
    while read -r device size rota type; do
        # ROTA=0 is SSD/NVMe, ROTA=1 is HDD
        if [[ "$device" == nvme* ]]; then
            hot_tier=$((hot_tier + 1))
        elif [ "$rota" -eq 0 ]; then
            warm_tier=$((warm_tier + 1))
        else
            cold_tier=$((cold_tier + 1))
        fi
    done < <(detect_storage_devices)
    
    echo "$hot_tier|$warm_tier|$cold_tier"
}

# Main wizard
main() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║  ${BOLD}Storage Configuration Wizard${NC}${CYAN}                          "
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Detecting storage devices...${NC}\n"
    
    echo -e "${GREEN}Available Storage:${NC}\n"
    echo -e "${BOLD}DEVICE    SIZE    TYPE${NC}"
    detect_storage_devices | while read -r device size rota type; do
        local storage_type="HDD"
        if [[ "$device" == nvme* ]]; then
            storage_type="NVMe"
        elif [ "$rota" -eq 0 ]; then
            storage_type="SSD"
        fi
        printf "%-10s %-8s %s\n" "$device" "$size" "$storage_type"
    done
    
    echo ""
    
    # Classify tiers
    local tiers=$(classify_storage_tiers)
    IFS='|' read -r hot_tier warm_tier cold_tier <<< "$tiers"
    
    echo -e "${CYAN}Detected Storage Tiers:${NC}"
    echo -e "  • ${BOLD}Hot tier${NC} (NVMe): $hot_tier devices"
    echo -e "  • ${BOLD}Warm tier${NC} (SSD): $warm_tier devices"
    echo -e "  • ${BOLD}Cold tier${NC} (HDD): $cold_tier devices"
    echo ""
    
    # Recommendation
    echo -e "${YELLOW}Intelligent Storage Recommendation:${NC}\n"
    
    if [ "$hot_tier" -gt 0 ]; then
        cat << EOF
${GREEN}Multi-Tier Storage Configuration${NC}

${BOLD}Hot Tier (NVMe):${NC}
  • Use for: Active VMs, databases, high-IOPS workloads
  • Format: ext4 or XFS
  • Features: Snapshots, thin provisioning

EOF
    fi
    
    if [ "$warm_tier" -gt 0 ]; then
        cat << EOF
${BOLD}Warm Tier (SSD):${NC}
  • Use for: VM storage pools, images, backups
  • Format: ext4 or ZFS
  • Features: Compression, snapshots

EOF
    fi
    
    if [ "$cold_tier" -gt 0 ]; then
        cat << EOF
${BOLD}Cold Tier (HDD):${NC}
  • Use for: Archives, long-term backups, media
  • Format: ext4 or ZFS
  • Features: High capacity, RAID redundancy

EOF
    fi
    
    # Configuration
    echo -e "${CYAN}Recommended Configuration:${NC}\n"
    
    if [ "$hot_tier" -gt 0 ] && [ "$warm_tier" -gt 0 ]; then
        echo -e "  ${BOLD}Tiered storage with automatic migration${NC}"
        echo "    • Hot: Frequently accessed VMs"
        echo "    • Warm: Occasionally used VMs"
        echo "    • Cold: Archived/snapshot storage"
    elif [ "$warm_tier" -gt 0 ]; then
        echo -e "  ${BOLD}Single-tier SSD storage${NC}"
        echo "    • All VMs on fast storage"
        echo "    • Good performance for all workloads"
    else
        echo -e "  ${BOLD}Basic storage configuration${NC}"
        echo "    • Standard VM storage"
        echo "    • Backup to external storage recommended"
    fi
    
    echo ""
    echo -e "${GREEN}Storage configuration guidance provided${NC}"
    echo -e "${CYAN}Apply settings in: /etc/nixos/storage-config.nix${NC}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
