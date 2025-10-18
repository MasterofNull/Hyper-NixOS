#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: security-configuration-wizard.sh
# Purpose: Intelligent security configuration based on detected attack surface
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
# Part of Design Ethos - Third Pillar: Learning Through Guidance
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/system_discovery.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/ui.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/logging.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/error_handling.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/config_backup.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/dry_run.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/branding.sh" 2>/dev/null || true

# Setup error handling
setup_error_trap "security-configuration-wizard.sh"

# Parse dry-run argument
parse_dry_run_arg "$@"

# Show branded banner
clear
show_banner_large

echo -e "${BOLD}Security Configuration Wizard${NC}"
echo "Configure multi-layered security for your hypervisor."
echo ""

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly CONFIG_FILE="/etc/hypervisor/security-config.json"
readonly SECURITY_STATE="/var/lib/hypervisor/.security-state"

# Detect security posture
detect_security_posture() {
    local open_ports=$(ss -tuln 2>/dev/null | grep LISTEN | wc -l || echo "0")
    local running_services=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -c "\.service" || echo "0")
    local firewall_active="no"
    
    if systemctl is-active --quiet firewalld 2>/dev/null || \
       systemctl is-active --quiet nftables 2>/dev/null || \
       iptables -L -n 2>/dev/null | grep -q "Chain"; then
        firewall_active="yes"
    fi
    
    local ssh_exposed="no"
    if ss -tuln 2>/dev/null | grep -q ":22 "; then
        ssh_exposed="yes"
    fi
    
    echo "$open_ports|$running_services|$firewall_active|$ssh_exposed"
}

# Recommend security level
recommend_security_level() {
    local open_ports=$1
    local running_services=$2
    local firewall_active=$3
    local ssh_exposed=$4
    
    # Calculate risk score
    local risk_score=0
    
    # More open ports = higher risk
    if [ "$open_ports" -gt 20 ]; then
        risk_score=$((risk_score + 3))
    elif [ "$open_ports" -gt 10 ]; then
        risk_score=$((risk_score + 2))
    elif [ "$open_ports" -gt 5 ]; then
        risk_score=$((risk_score + 1))
    fi
    
    # No firewall = high risk
    if [ "$firewall_active" = "no" ]; then
        risk_score=$((risk_score + 3))
    fi
    
    # SSH exposed = risk
    if [ "$ssh_exposed" = "yes" ]; then
        risk_score=$((risk_score + 2))
    fi
    
    # Many services = higher attack surface
    if [ "$running_services" -gt 50 ]; then
        risk_score=$((risk_score + 2))
    elif [ "$running_services" -gt 30 ]; then
        risk_score=$((risk_score + 1))
    fi
    
    # Recommend based on risk
    if [ "$risk_score" -ge 6 ]; then
        echo "strict"
    elif [ "$risk_score" -ge 4 ]; then
        echo "enhanced"
    elif [ "$risk_score" -ge 2 ]; then
        echo "balanced"
    else
        echo "standard"
    fi
}

# Show security level details
show_security_level_details() {
    local level=$1
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║  Security Level: ${BOLD}${level^^}${NC}${CYAN}                                 "
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    case "$level" in
        standard)
            cat << EOF
${GREEN}Standard Security${NC}

${BOLD}Best for:${NC}
  • Development environments
  • Isolated lab systems
  • Learning and testing

${YELLOW}Features:${NC}
  • Basic firewall (SSH + HTTP/HTTPS)
  • Standard SSH configuration
  • Basic intrusion detection
  • Weekly security scans
  • Standard password policy

${BLUE}Protection Level:${NC}
  • Blocks: Common attacks
  • Monitoring: Basic
  • Updates: Weekly
  • Logging: Standard

${MAGENTA}Performance Impact:${NC} Very Low

EOF
            ;;
        balanced)
            cat << EOF
${GREEN}Balanced Security${NC}

${BOLD}Best for:${NC}
  • Production VMs
  • Small business servers
  • Multi-user systems

${YELLOW}Features:${NC}
  • Enhanced firewall with zone isolation
  • Hardened SSH (key-only, rate limiting)
  • IDS/IPS with alerting
  • Daily security scans
  • Strong password policy
  • Fail2ban protection
  • SELinux enforcing

${BLUE}Protection Level:${NC}
  • Blocks: Most attacks
  • Monitoring: Enhanced
  • Updates: Daily
  • Logging: Detailed

${MAGENTA}Performance Impact:${NC} Low

EOF
            ;;
        enhanced)
            cat << EOF
${YELLOW}Enhanced Security${NC}

${BOLD}Best for:${NC}
  • Internet-facing servers
  • Business-critical systems
  • Compliance requirements

${YELLOW}Features:${NC}
  • Advanced firewall with DPI
  • SSH hardening + port knocking
  • AI-powered anomaly detection
  • Real-time security monitoring
  • Automated threat response
  • Strong MFA enforcement
  • File integrity monitoring
  • Advanced logging and SIEM

${BLUE}Protection Level:${NC}
  • Blocks: Advanced threats
  • Monitoring: Real-time AI
  • Updates: Real-time
  • Logging: Comprehensive

${MAGENTA}Performance Impact:${NC} Moderate

EOF
            ;;
        strict)
            cat << EOF
${RED}Strict Security${NC}

${BOLD}Best for:${NC}
  • High-security environments
  • Financial/healthcare systems
  • Government compliance
  • Zero-trust architectures

${YELLOW}Features:${NC}
  • Maximum firewall restrictions
  • SSH certificate authentication only
  • Full AI threat intelligence
  • Continuous security monitoring
  • Automated incident response
  • Mandatory MFA for all access
  • Full disk encryption
  • Network segmentation
  • Application whitelisting
  • Immutable infrastructure

${BLUE}Protection Level:${NC}
  • Blocks: All threats
  • Monitoring: 24/7 AI + Human
  • Updates: Immediate
  • Logging: Forensic-grade

${MAGENTA}Performance Impact:${NC} Moderate-High

EOF
            ;;
    esac
    
    echo -e "\nPress ${BOLD}Enter${NC} to continue..."
    read -r
}

# Main wizard
main() {
    log_wizard_start "security-configuration-wizard"
    dry_run_summary_start
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║  ${BOLD}Hyper-NixOS Security Configuration Wizard${NC}${CYAN}            "
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    is_dry_run && echo -e "${DRY_RUN_COLOR}[DRY RUN MODE]${NC} Preview only - no changes will be made\n"
    
    # Detect current security posture
    echo -e "${YELLOW}Analyzing system security posture...${NC}\n"
    
    local posture=$(detect_security_posture)
    IFS='|' read -r open_ports running_services firewall_active ssh_exposed <<< "$posture"
    
    echo -e "${GREEN}Detection Results:${NC}"
    echo -e "  • Open ports: ${BOLD}$open_ports${NC}"
    echo -e "  • Running services: ${BOLD}$running_services${NC}"
    echo -e "  • Firewall active: ${BOLD}$firewall_active${NC}"
    echo -e "  • SSH exposed: ${BOLD}$ssh_exposed${NC}"
    echo ""
    
    # Calculate recommendation
    local recommended_level=$(recommend_security_level "$open_ports" "$running_services" "$firewall_active" "$ssh_exposed")
    
    echo -e "${CYAN}Based on detected attack surface:${NC}"
    echo -e "${BOLD}Recommended Security Level: ${recommended_level^^}${NC}\n"
    
    # Show reasoning
    cat << EOF
${YELLOW}Why this recommendation?${NC}

EOF
    
    if [ "$firewall_active" = "no" ]; then
        echo -e "  ${RED}⚠${NC} No active firewall detected - ${BOLD}CRITICAL${NC}"
    fi
    
    if [ "$ssh_exposed" = "yes" ]; then
        echo -e "  ${YELLOW}⚠${NC} SSH exposed to network - requires hardening"
    fi
    
    if [ "$open_ports" -gt 10 ]; then
        echo -e "  ${YELLOW}⚠${NC} High number of open ports ($open_ports) - larger attack surface"
    fi
    
    if [ "$running_services" -gt 30 ]; then
        echo -e "  ${YELLOW}⚠${NC} Many running services ($running_services) - complexity increases risk"
    fi
    
    echo ""
    echo -e "${GREEN}Security Level Options:${NC}\n"
    echo -e "  ${BOLD}standard${NC}  - Basic protection (development/testing)"
    echo -e "  ${BOLD}balanced${NC}  - Enhanced protection (production systems)"
    echo -e "  ${BOLD}enhanced${NC}  - Advanced protection (internet-facing)"
    echo -e "  ${BOLD}strict${NC}    - Maximum protection (high-security)\n"
    
    # User selection
    local selected_level=""
    while [ -z "$selected_level" ]; do
        echo -e "${CYAN}Enter choice:${NC}"
        echo -e "  • Type level name for details"
        echo -e "  • Type '${BOLD}recommend${NC}' to use ${BOLD}${recommended_level}${NC}"
        echo -e "  • Type '${BOLD}select <level>${NC}' to choose"
        echo ""
        read -r -p "> " choice
        
        case "$choice" in
            standard|balanced|enhanced|strict)
                show_security_level_details "$choice"
                ;;
            recommend|rec)
                selected_level="$recommended_level"
                echo -e "\n${GREEN}✓${NC} Using recommended level: ${BOLD}${recommended_level}${NC}"
                ;;
            "select standard"|"select balanced"|"select enhanced"|"select strict")
                selected_level=$(echo "$choice" | cut -d' ' -f2)
                echo -e "\n${GREEN}✓${NC} Selected: ${BOLD}${selected_level}${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}\n"
                ;;
        esac
    done
    
    # Configure security features
    echo ""
    echo -e "${YELLOW}Configuring security features for ${BOLD}${selected_level}${NC}${YELLOW} level...${NC}\n"
    
    # Backup existing configuration
    if [ -f "$CONFIG_FILE" ]; then
        backup_config "$CONFIG_FILE" "Pre-security-config backup"
    fi
    
    # Create configuration
    dry_run_mkdir "$(dirname "$CONFIG_FILE")"
    
    local config_content=$(cat << EOF
{
  "security_level": "${selected_level}",
  "configured_at": "$(date -Iseconds)",
  "detection": {
    "open_ports": $open_ports,
    "running_services": $running_services,
    "firewall_active": "$firewall_active",
    "ssh_exposed": "$ssh_exposed"
  },
  "features": $(case "$selected_level" in
    standard)
      cat << 'FEATURES'
{
    "firewall": "basic",
    "ssh_hardening": "standard",
    "ids_ips": "basic",
    "security_scans": "weekly",
    "password_policy": "standard",
    "fail2ban": false,
    "selinux": "permissive"
  }
FEATURES
      ;;
    balanced)
      cat << 'FEATURES'
{
    "firewall": "enhanced",
    "ssh_hardening": "strong",
    "ids_ips": "enabled",
    "security_scans": "daily",
    "password_policy": "strong",
    "fail2ban": true,
    "selinux": "enforcing",
    "zone_isolation": true
  }
FEATURES
      ;;
    enhanced)
      cat << 'FEATURES'
{
    "firewall": "advanced",
    "ssh_hardening": "maximum",
    "ids_ips": "ai_powered",
    "security_scans": "realtime",
    "password_policy": "maximum",
    "fail2ban": true,
    "selinux": "enforcing",
    "zone_isolation": true,
    "mfa": "recommended",
    "file_integrity": true,
    "siem": true
  }
FEATURES
      ;;
    strict)
      cat << 'FEATURES'
{
    "firewall": "maximum",
    "ssh_hardening": "certificates_only",
    "ids_ips": "ai_powered",
    "security_scans": "continuous",
    "password_policy": "maximum",
    "fail2ban": true,
    "selinux": "enforcing",
    "zone_isolation": true,
    "mfa": "required",
    "file_integrity": true,
    "siem": true,
    "disk_encryption": "required",
    "network_segmentation": true,
    "application_whitelisting": true
  }
FEATURES
      ;;
  esac)
}
EOF
)
    
    # Write configuration (respects dry-run mode)
    if is_dry_run; then
        dry_run_show_config "Security Configuration" "$config_content"
    else
        safe_write_file "$CONFIG_FILE" "$config_content"
        log_config_change "$CONFIG_FILE" "security_level" "unknown" "$selected_level"
        log_audit "security_configured" "$USER" "level=${selected_level}"
    fi
    
    echo -e "${GREEN}✓${NC} Security configuration saved to $CONFIG_FILE"
    echo -e "${GREEN}✓${NC} Security level: ${BOLD}${selected_level}${NC}"
    
    # Mark state
    mkdir -p "$(dirname "$SECURITY_STATE")"
    echo "${selected_level}" > "$SECURITY_STATE"
    
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. Review configuration: ${BOLD}cat $CONFIG_FILE${NC}"
    echo -e "  2. Apply configuration: ${BOLD}nixos-rebuild switch${NC}"
    echo -e "  3. Run security audit: ${BOLD}hv security-audit${NC}"
    echo ""
    
    dry_run_summary_end
    log_wizard_end "security-configuration-wizard" "success"
    
    echo -e "${GREEN}Security configuration complete!${NC}"
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
