#!/usr/bin/env bash
# Hyper-NixOS Backup Configuration Wizard
# Intelligent defaults based on detected storage and data size
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

# Detect data size and storage
detect_backup_requirements() {
    local vm_storage=$(du -sh /var/lib/hypervisor 2>/dev/null | awk '{print $1}' || echo "0G")
    local available_space=$(get_available_storage_gb /var/lib/hypervisor/backups)
    local storage_type=$(detect_storage_type)
    
    # Convert vm_storage to GB
    local vm_size_gb=$(echo "$vm_storage" | sed 's/G//' | sed 's/M//' | awk '{print int($1+0.5)}')
    
    echo "$vm_size_gb|$available_space|$storage_type"
}

# Recommend backup strategy
recommend_backup_strategy() {
    local data_size=$1
    local available_space=$2
    local storage_type=$3
    
    # Calculate recommended retention based on space
    local retention_days=7
    if [ "$available_space" -gt 500 ]; then
        retention_days=30
    elif [ "$available_space" -gt 200 ]; then
        retention_days=14
    fi
    
    # Recommend compression based on storage type
    local compression="zstd"
    if [ "$storage_type" = "hdd" ]; then
        compression="lz4"  # Faster, less CPU
    fi
    
    # Recommend schedule based on data size
    local schedule="daily"
    if [ "$data_size" -lt 50 ]; then
        schedule="every_6h"
    fi
    
    echo "$schedule|$retention_days|$compression"
}

# Main wizard
main() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║  ${BOLD}Backup Configuration Wizard${NC}${CYAN}                           "
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Analyzing backup requirements...${NC}\n"
    
    local requirements=$(detect_backup_requirements)
    IFS='|' read -r data_size available_space storage_type <<< "$requirements"
    
    echo -e "${GREEN}Detection Results:${NC}"
    echo -e "  • Data size: ${BOLD}${data_size}GB${NC}"
    echo -e "  • Available backup space: ${BOLD}${available_space}GB${NC}"
    echo -e "  • Storage type: ${BOLD}${storage_type}${NC}"
    echo ""
    
    # Get recommendation
    local strategy=$(recommend_backup_strategy "$data_size" "$available_space" "$storage_type")
    IFS='|' read -r rec_schedule rec_retention rec_compression <<< "$strategy"
    
    echo -e "${CYAN}Intelligent Backup Recommendation:${NC}\n"
    echo -e "  • Schedule: ${BOLD}$rec_schedule${NC}"
    echo -e "  • Retention: ${BOLD}$rec_retention days${NC}"
    echo -e "  • Compression: ${BOLD}$rec_compression${NC}"
    echo ""
    
    # Show reasoning
    cat << EOF
${YELLOW}Why these settings?${NC}

  ${BOLD}Schedule: $rec_schedule${NC}
EOF
    
    if [ "$data_size" -lt 50 ]; then
        echo "    • Small dataset ($data_size GB) - frequent backups practical"
    else
        echo "    • Moderate dataset ($data_size GB) - daily backups optimal"
    fi
    
    echo ""
    echo -e "  ${BOLD}Retention: $rec_retention days${NC}"
    
    if [ "$available_space" -gt 500 ]; then
        echo "    • Large backup space ($available_space GB) - can keep 30 days"
    elif [ "$available_space" -gt 200 ]; then
        echo "    • Good backup space ($available_space GB) - 14 days safe"
    else
        echo "    • Limited space ($available_space GB) - 7 days recommended"
    fi
    
    echo ""
    echo -e "  ${BOLD}Compression: $rec_compression${NC}"
    
    if [ "$storage_type" = "hdd" ]; then
        echo "    • HDD storage - lz4 faster with less CPU overhead"
    else
        echo "    • Fast storage - zstd better compression ratio"
    fi
    
    # Options
    echo ""
    echo -e "${GREEN}Backup Strategy Options:${NC}\n"
    echo -e "  ${BOLD}simple${NC}      - Daily backups, 7-day retention, standard compression"
    echo -e "  ${BOLD}balanced${NC}    - Daily backups, 14-day retention, good compression"
    echo -e "  ${BOLD}comprehensive${NC} - Every 6h, 30-day retention, best compression"
    echo -e "  ${BOLD}custom${NC}      - Configure manually\n"
    
    # Selection
    local selected_strategy=""
    while [ -z "$selected_strategy" ]; do
        echo -e "${CYAN}Select backup strategy (or 'recommend' for intelligent defaults):${NC}"
        read -r -p "> " choice
        
        case "$choice" in
            simple)
                selected_strategy="simple"
                rec_schedule="daily"
                rec_retention="7"
                rec_compression="gzip"
                ;;
            balanced)
                selected_strategy="balanced"
                rec_schedule="daily"
                rec_retention="14"
                rec_compression="zstd"
                ;;
            comprehensive)
                selected_strategy="comprehensive"
                rec_schedule="every_6h"
                rec_retention="30"
                rec_compression="zstd"
                ;;
            custom)
                selected_strategy="custom"
                echo -e "\n${CYAN}Custom configuration:${NC}"
                read -r -p "Schedule (hourly/every_6h/daily/weekly): " rec_schedule
                read -r -p "Retention days: " rec_retention
                read -r -p "Compression (none/gzip/zstd/lz4): " rec_compression
                ;;
            recommend|rec)
                selected_strategy="intelligent"
                echo -e "${GREEN}✓${NC} Using intelligent defaults"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                ;;
        esac
    done
    
    # Additional options
    echo ""
    echo -e "${YELLOW}Additional Options:${NC}"
    
    local enable_encryption="yes"
    echo -e "${CYAN}Enable backup encryption? (yes/no) [yes]:${NC}"
    read -r -p "> " enc_choice
    [ -n "$enc_choice" ] && enable_encryption="$enc_choice"
    
    local enable_dedup="yes"
    echo -e "${CYAN}Enable deduplication? (yes/no) [yes]:${NC}"
    read -r -p "> " dedup_choice
    [ -n "$dedup_choice" ] && enable_dedup="$dedup_choice"
    
    # Configure
    echo ""
    echo -e "${YELLOW}Configuring backup system...${NC}\n"
    
    local config_file="/etc/hypervisor/backup-config.json"
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" << EOF
{
  "strategy": "${selected_strategy}",
  "schedule": "${rec_schedule}",
  "retention_days": ${rec_retention},
  "compression": "${rec_compression}",
  "encryption": ${enable_encryption},
  "deduplication": ${enable_dedup},
  "configured_at": "$(date -Iseconds)",
  "detection": {
    "data_size_gb": ${data_size},
    "available_space_gb": ${available_space},
    "storage_type": "${storage_type}"
  },
  "paths": {
    "source": "/var/lib/hypervisor",
    "destination": "/var/lib/hypervisor/backups",
    "repository": "/var/lib/hypervisor/backup-repo"
  }
}
EOF
    
    echo -e "${GREEN}✓${NC} Backup configuration saved"
    echo -e "${GREEN}✓${NC} Configuration: ${BOLD}$config_file${NC}"
    echo ""
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  • Schedule: ${BOLD}$rec_schedule${NC}"
    echo -e "  • Retention: ${BOLD}$rec_retention days${NC}"
    echo -e "  • Compression: ${BOLD}$rec_compression${NC}"
    echo -e "  • Encryption: ${BOLD}$enable_encryption${NC}"
    echo -e "  • Deduplication: ${BOLD}$enable_dedup${NC}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "  1. Initialize backup repo: ${BOLD}restic init${NC}"
    echo -e "  2. Run first backup: ${BOLD}hv backup-now${NC}"
    echo -e "  3. Enable scheduled backups: ${BOLD}systemctl enable --now backup.timer${NC}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
