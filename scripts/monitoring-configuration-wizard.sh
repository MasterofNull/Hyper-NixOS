#!/usr/bin/env bash
# Hyper-NixOS Monitoring Configuration Wizard
# Intelligent defaults based on system resources and workload
# Part of Design Ethos - Third Pillar: Learning Through Guidance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/system_discovery.sh" 2>/dev/null || true

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Detect monitoring requirements
detect_monitoring_requirements() {
    local cpu_cores=$(get_cpu_cores)
    local total_ram=$(get_total_ram_mb)
    local vm_count=$(virsh list --all 2>/dev/null | grep -c "running\|shut off" || echo "0")
    local services=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -c "\.service" || echo "0")
    
    echo "$cpu_cores|$total_ram|$vm_count|$services"
}

# Recommend monitoring level
recommend_monitoring_level() {
    local cpu_cores=$1
    local total_ram=$2
    local vm_count=$3
    local services=$4
    
    if [ "$vm_count" -gt 10 ] || [ "$services" -gt 50 ]; then
        echo "comprehensive"
    elif [ "$vm_count" -gt 5 ] || [ "$cpu_cores" -gt 8 ]; then
        echo "enhanced"
    elif [ "$vm_count" -gt 0 ]; then
        echo "standard"
    else
        echo "basic"
    fi
}

# Main wizard
main() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║  ${BOLD}Monitoring Configuration Wizard${NC}${CYAN}                       "
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Analyzing monitoring requirements...${NC}\n"
    
    local requirements=$(detect_monitoring_requirements)
    IFS='|' read -r cpu_cores total_ram vm_count services <<< "$requirements"
    
    echo -e "${GREEN}Detection Results:${NC}"
    echo -e "  • CPU cores: ${BOLD}$cpu_cores${NC}"
    echo -e "  • RAM: ${BOLD}${total_ram}MB${NC}"
    echo -e "  • VMs: ${BOLD}$vm_count${NC}"
    echo -e "  • Services: ${BOLD}$services${NC}"
    echo ""
    
    local rec_level=$(recommend_monitoring_level "$cpu_cores" "$total_ram" "$vm_count" "$services")
    
    echo -e "${CYAN}Recommended Monitoring Level: ${BOLD}$rec_level${NC}\n"
    
    # Show reasoning
    cat << EOF
${YELLOW}Why this recommendation?${NC}

EOF
    
    if [ "$vm_count" -gt 10 ]; then
        echo "  • High VM count ($vm_count) requires comprehensive monitoring"
    elif [ "$vm_count" -gt 5 ]; then
        echo "  • Moderate VM count ($vm_count) benefits from enhanced monitoring"
    elif [ "$vm_count" -gt 0 ]; then
        echo "  • Some VMs ($vm_count) need standard monitoring"
    else
        echo "  • No VMs yet - basic monitoring sufficient"
    fi
    
    echo ""
    echo -e "${GREEN}Monitoring Levels:${NC}\n"
    
    cat << EOF
${BOLD}basic${NC} - Essential metrics only
  • CPU, RAM, disk usage
  • 5-minute scrape interval
  • 7-day retention
  • Minimal resource overhead

${BOLD}standard${NC} - VM and host monitoring
  • All basic metrics plus VM-specific
  • Prometheus + Grafana dashboards
  • 1-minute scrape interval
  • 30-day retention
  • Low resource overhead

${BOLD}enhanced${NC} - Advanced monitoring with alerts
  • All standard metrics plus:
  • Network traffic, disk I/O
  • Alert rules and notifications
  • 15-second scrape interval
  • 90-day retention
  • Log aggregation
  • Moderate resource overhead

${BOLD}comprehensive${NC} - Full observability stack
  • All enhanced metrics plus:
  • Distributed tracing
  • APM integration
  • AI-powered anomaly detection
  • 5-second scrape interval
  • 180-day retention
  • SIEM integration
  • Higher resource overhead

EOF
    
    # Selection
    local selected_level=""
    while [ -z "$selected_level" ]; do
        echo -e "${CYAN}Select monitoring level (or 'recommend' for ${rec_level}):${NC}"
        read -r -p "> " choice
        
        case "$choice" in
            basic|standard|enhanced|comprehensive)
                selected_level="$choice"
                ;;
            recommend|rec)
                selected_level="$rec_level"
                echo -e "${GREEN}✓${NC} Using recommended: ${BOLD}${selected_level}${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                ;;
        esac
    done
    
    # Additional options
    echo ""
    echo -e "${YELLOW}Additional Options:${NC}"
    
    local enable_alerts="yes"
    if [ "$selected_level" = "basic" ]; then
        enable_alerts="no"
    fi
    echo -e "${CYAN}Enable alerting? (yes/no) [$enable_alerts]:${NC}"
    read -r -p "> " alert_choice
    [ -n "$alert_choice" ] && enable_alerts="$alert_choice"
    
    local enable_grafana="yes"
    echo -e "${CYAN}Enable Grafana dashboards? (yes/no) [yes]:${NC}"
    read -r -p "> " grafana_choice
    [ -n "$grafana_choice" ] && enable_grafana="$grafana_choice"
    
    # Configure
    echo ""
    echo -e "${YELLOW}Configuring monitoring...${NC}\n"
    
    # Set scrape interval based on level
    local scrape_interval="1m"
    local retention_days=30
    
    case "$selected_level" in
        basic)
            scrape_interval="5m"
            retention_days=7
            ;;
        standard)
            scrape_interval="1m"
            retention_days=30
            ;;
        enhanced)
            scrape_interval="15s"
            retention_days=90
            ;;
        comprehensive)
            scrape_interval="5s"
            retention_days=180
            ;;
    esac
    
    local config_file="/etc/hypervisor/monitoring-config.json"
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" << EOF
{
  "level": "${selected_level}",
  "scrape_interval": "${scrape_interval}",
  "retention_days": ${retention_days},
  "alerting": ${enable_alerts},
  "grafana": ${enable_grafana},
  "configured_at": "$(date -Iseconds)",
  "detection": {
    "cpu_cores": ${cpu_cores},
    "total_ram_mb": ${total_ram},
    "vm_count": ${vm_count},
    "services": ${services}
  },
  "exporters": {
    "node_exporter": true,
    "libvirt_exporter": $([ "$vm_count" -gt 0 ] && echo "true" || echo "false"),
    "prometheus": true,
    "grafana": ${enable_grafana}
  }
}
EOF
    
    echo -e "${GREEN}✓${NC} Monitoring configuration saved"
    echo -e "${GREEN}✓${NC} Level: ${BOLD}${selected_level}${NC}"
    echo ""
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  • Scrape interval: ${BOLD}${scrape_interval}${NC}"
    echo -e "  • Retention: ${BOLD}${retention_days} days${NC}"
    echo -e "  • Alerting: ${BOLD}${enable_alerts}${NC}"
    echo -e "  • Grafana: ${BOLD}${enable_grafana}${NC}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "  1. Apply configuration: ${BOLD}nixos-rebuild switch${NC}"
    echo -e "  2. Access Grafana: ${BOLD}http://localhost:3000${NC}"
    echo -e "  3. View metrics: ${BOLD}http://localhost:9090${NC}"
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
