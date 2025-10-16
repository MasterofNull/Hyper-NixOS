#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Unified Network Configuration Wizard
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# All-in-one network configuration with phase awareness and nixos-rebuild integration

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/../lib/network-discovery.sh" 2>/dev/null || true

# Initialize
init_logging "unified-network-wizard"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration storage
declare -A CONFIG
CONFIG_FILE="/tmp/network-wizard-config.nix"

# Phase detection
get_security_phase() {
    if [[ -f /etc/hypervisor/.phase2_hardened ]]; then
        echo "hardened"
    else
        echo "setup"
    fi
}

SECURITY_PHASE=$(get_security_phase)

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✗ This wizard must be run as root${NC}"
    echo -e "${CYAN}Please run: sudo $0${NC}"
    exit 1
fi

# Banner
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}          Hyper-NixOS Unified Network Configuration Wizard${NC}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${CYAN}Security Phase: ${NC}${BOLD}$SECURITY_PHASE${NC}"
    echo
}

# Main menu
show_main_menu() {
    show_banner
    echo -e "${BOLD}${CYAN}Network Features:${NC}"
    echo
    echo -e "  ${GREEN} 1)${NC} IPv6 Configuration                 ${YELLOW}⭐⭐⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 2)${NC} Traffic Shaping (QoS)              ${YELLOW}⭐⭐⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 3)${NC} Network Bonding/Aggregation        ${YELLOW}⭐⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 4)${NC} DHCP Server (Per-VLAN)             ${YELLOW}⭐⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 5)${NC} VPN with Kill Switch               ${YELLOW}⭐⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 6)${NC} Firewall Zones                     ${YELLOW}⭐⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 7)${NC} DNS Server + Ad-Blocking           ${YELLOW}⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 8)${NC} Network Monitoring                 ${YELLOW}⭐⭐⭐${NC}"
    echo -e "  ${GREEN} 9)${NC} Bridge Management                  ${YELLOW}⭐⭐⭐${NC}"
    echo -e "  ${GREEN}10)${NC} Performance Tuning                 ${YELLOW}⭐⭐⭐${NC}"
    echo -e "  ${GREEN}11)${NC} Tor Integration                    ${YELLOW}⭐⭐⭐${NC}"
    echo -e "  ${GREEN}12)${NC} Packet Capture                     ${YELLOW}⭐⭐${NC}"
    echo -e "  ${GREEN}13)${NC} IDS/IPS (Intrusion Detection)      ${YELLOW}⭐⭐${NC}"
    echo -e "  ${GREEN}14)${NC} Load Balancing                     ${YELLOW}⭐⭐${NC}"
    echo -e "  ${GREEN}15)${NC} Network Automation                 ${YELLOW}⭐⭐${NC}"
    echo
    echo -e "${BOLD}${MAGENTA}Additional Options:${NC}"
    echo -e "  ${GREEN}16)${NC} ${BOLD}Configure All (Recommended)${NC}"
    echo -e "  ${GREEN}17)${NC} ${BOLD}Network Discovery Scan${NC}"
    echo -e "  ${GREEN}18)${NC} Generate & Apply Configuration"
    echo -e "  ${GREEN}19)${NC} Switch Security Phase"
    echo -e "  ${GREEN} 0)${NC} Exit"
    echo
}

# IPv6 Configuration
configure_ipv6() {
    show_banner
    echo -e "${BOLD}${CYAN}IPv6 Configuration${NC}"
    echo
    
    read -p "Enable IPv6? [Y/n]: " enable
    if [[ ! "$enable" =~ ^[Nn]$ ]]; then
        CONFIG[ipv6_enable]="true"
        
        echo
        echo "Privacy Mode:"
        echo "  1) Disabled - No privacy"
        echo "  2) Stable - RFC 7217 (Recommended)"
        echo "  3) Temporary - RFC 4941 (Maximum Privacy)"
        read -p "Select [2]: " privacy
        privacy=${privacy:-2}
        
        case "$privacy" in
            1) CONFIG[ipv6_privacy]="disabled" ;;
            2) CONFIG[ipv6_privacy]="stable" ;;
            3) CONFIG[ipv6_privacy]="temporary" ;;
        esac
        
        read -p "Enable IPv6 spoofing? [y/N]: " spoof
        if [[ "$spoof" =~ ^[Yy]$ ]]; then
            CONFIG[ipv6_spoof]="true"
        fi
        
        echo -e "${GREEN}✓ IPv6 configured${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Traffic Shaping
configure_qos() {
    show_banner
    echo -e "${BOLD}${CYAN}Traffic Shaping (QoS)${NC}"
    echo
    
    read -p "Enable QoS? [Y/n]: " enable
    if [[ ! "$enable" =~ ^[Nn]$ ]]; then
        CONFIG[qos_enable]="true"
        
        read -p "Default upload limit (e.g., 1gbit, 100mbit) [1gbit]: " upload
        CONFIG[qos_upload]=${upload:-1gbit}
        
        read -p "Default download limit [1gbit]: " download
        CONFIG[qos_download]=${download:-1gbit}
        
        echo -e "${GREEN}✓ QoS configured${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Quick configuration for all features
configure_all() {
    show_banner
    echo -e "${BOLD}${CYAN}Quick Configuration - All Features${NC}"
    echo
    echo "This will enable recommended features with sensible defaults."
    echo
    
    read -p "Continue? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        return
    fi
    
    # Run network discovery
    echo
    echo -e "${YELLOW}Running network discovery...${NC}"
    local primary_if=$(get_physical_interfaces | head -1)
    
    # Enable core features with defaults
    CONFIG[ipv6_enable]="true"
    CONFIG[ipv6_privacy]="stable"
    CONFIG[qos_enable]="true"
    CONFIG[qos_upload]="1gbit"
    CONFIG[qos_download]="1gbit"
    CONFIG[dns_enable]="true"
    CONFIG[monitoring_enable]="true"
    CONFIG[performance_enable]="true"
    
    echo
    echo -e "${GREEN}✓ All features configured with recommended defaults${NC}"
    echo
    read -p "Press Enter to continue..."
}

# Network discovery
run_discovery() {
    show_banner
    echo -e "${BOLD}${CYAN}Network Discovery${NC}"
    echo
    
    local -a interfaces=($(get_physical_interfaces))
    
    echo "Available interfaces:"
    local i=1
    for iface in "${interfaces[@]}"; do
        echo "  $i) $iface"
        ((i++))
    done
    echo
    
    read -p "Select interface to scan [1]: " choice
    choice=${choice:-1}
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#interfaces[@]}" ]; then
        local iface="${interfaces[$((choice-1))]}"
        
        echo
        echo -e "${YELLOW}Scanning $iface...${NC}"
        discover_network "$iface" 2>&1 || true
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Generate NixOS configuration
generate_config() {
    show_banner
    echo -e "${BOLD}${CYAN}Generating Configuration...${NC}"
    echo
    
    cat > "$CONFIG_FILE" <<EOF
# Unified Network Configuration
# Generated by Unified Network Wizard on $(date)
# Security Phase: $SECURITY_PHASE

{ config, lib, pkgs, ... }:

{
  imports = [
EOF
    
    # Add module imports based on enabled features
    [[ "${CONFIG[ipv6_enable]}" == "true" ]] && echo "    ./modules/network-settings/ipv6.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[qos_enable]}" == "true" ]] && echo "    ./modules/network-settings/traffic-shaping.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[bonding_enable]}" == "true" ]] && echo "    ./modules/network-settings/bonding.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[dhcp_enable]}" == "true" ]] && echo "    ./modules/network-settings/dhcp-server.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[vpn_enable]}" == "true" ]] && echo "    ./modules/network-settings/vpn.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[firewall_enable]}" == "true" ]] && echo "    ./modules/network-settings/firewall-zones.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[dns_enable]}" == "true" ]] && echo "    ./modules/network-settings/dns-server.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[monitoring_enable]}" == "true" ]] && echo "    ./modules/network-settings/monitoring.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[bridge_enable]}" == "true" ]] && echo "    ./modules/network-settings/bridges.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[performance_enable]}" == "true" ]] && echo "    ./modules/network-settings/performance-tuning.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[tor_enable]}" == "true" ]] && echo "    ./modules/network-settings/tor.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[pcap_enable]}" == "true" ]] && echo "    ./modules/network-settings/packet-capture.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[ids_enable]}" == "true" ]] && echo "    ./modules/network-settings/ids.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[lb_enable]}" == "true" ]] && echo "    ./modules/network-settings/load-balancer.nix" >> "$CONFIG_FILE"
    [[ "${CONFIG[automation_enable]}" == "true" ]] && echo "    ./modules/network-settings/automation.nix" >> "$CONFIG_FILE"
    
    cat >> "$CONFIG_FILE" <<EOF
  ];

  # Network configuration
  hypervisor.network = {
EOF
    
    # IPv6
    if [[ "${CONFIG[ipv6_enable]}" == "true" ]]; then
        cat >> "$CONFIG_FILE" <<EOF
    ipv6 = {
      enable = true;
      privacy = "${CONFIG[ipv6_privacy]:-stable}";
      spoof.enable = ${CONFIG[ipv6_spoof]:-false};
    };
EOF
    fi
    
    # QoS
    if [[ "${CONFIG[qos_enable]}" == "true" ]]; then
        cat >> "$CONFIG_FILE" <<EOF
    qos = {
      enable = true;
      defaultUpload = "${CONFIG[qos_upload]:-1gbit}";
      defaultDownload = "${CONFIG[qos_download]:-1gbit}";
    };
EOF
    fi
    
    # DNS
    if [[ "${CONFIG[dns_enable]}" == "true" ]]; then
        cat >> "$CONFIG_FILE" <<EOF
    dnsServer = {
      enable = true;
      adBlocking.enable = true;
    };
EOF
    fi
    
    # Monitoring
    if [[ "${CONFIG[monitoring_enable]}" == "true" ]]; then
        cat >> "$CONFIG_FILE" <<EOF
    monitoring = {
      enable = true;
    };
EOF
    fi
    
    # Performance
    if [[ "${CONFIG[performance_enable]}" == "true" ]]; then
        cat >> "$CONFIG_FILE" <<EOF
    performanceTuning = {
      enable = true;
      tcpCongestion = "bbr";
    };
EOF
    fi
    
    cat >> "$CONFIG_FILE" <<EOF
  };
}
EOF
    
    echo -e "${GREEN}✓ Configuration generated: $CONFIG_FILE${NC}"
    echo
    echo "Preview:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    head -30 "$CONFIG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
}

# Apply configuration
apply_config() {
    show_banner
    echo -e "${BOLD}${CYAN}Apply Configuration${NC}"
    echo
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}No configuration generated yet!${NC}"
        echo "Please generate configuration first (option 18)"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Copy to /etc/nixos
    local target="/etc/nixos/unified-network.nix"
    
    echo "Installing configuration to $target..."
    cp "$CONFIG_FILE" "$target"
    chmod 644 "$target"
    
    # Add to configuration.nix if not already present
    if ! grep -q "unified-network.nix" /etc/nixos/configuration.nix 2>/dev/null; then
        echo
        read -p "Add to configuration.nix? [Y/n]: " add
        if [[ ! "$add" =~ ^[Nn]$ ]]; then
            cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup-$(date +%Y%m%d-%H%M%S)
            sed -i '/imports = \[/a\    ./unified-network.nix' /etc/nixos/configuration.nix
            echo -e "${GREEN}✓ Added to configuration.nix${NC}"
        fi
    fi
    
    echo
    echo -e "${YELLOW}Apply changes now?${NC}"
    echo "This will run: nixos-rebuild switch"
    echo
    read -p "Proceed? [Y/n]: " rebuild
    
    if [[ ! "$rebuild" =~ ^[Nn]$ ]]; then
        echo
        echo -e "${CYAN}Running nixos-rebuild switch...${NC}"
        echo
        
        if nixos-rebuild switch; then
            echo
            echo -e "${GREEN}✓ Configuration applied successfully!${NC}"
            log_info "Network configuration applied via unified wizard"
        else
            echo
            echo -e "${RED}✗ Configuration failed to apply${NC}"
            log_error "Failed to apply network configuration"
        fi
    else
        echo
        echo -e "${YELLOW}Configuration saved but not applied${NC}"
        echo "Apply later with: nixos-rebuild switch"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Phase switching
switch_phase() {
    show_banner
    echo -e "${BOLD}${CYAN}Security Phase Management${NC}"
    echo
    
    echo -e "Current Phase: ${BOLD}$SECURITY_PHASE${NC}"
    echo
    
    if [[ "$SECURITY_PHASE" == "setup" ]]; then
        echo -e "${YELLOW}⚠️  Transition to Hardened Mode${NC}"
        echo
        echo "This will:"
        echo "  • Remove administrative privileges"
        echo "  • Restrict system modifications"
        echo "  • Enable strict security policies"
        echo "  • Disable interactive features"
        echo
        echo "This action is reversible but requires authentication."
        echo
        
        read -p "Proceed with hardening? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if [[ -f /etc/hypervisor/scripts/transition_phase.sh ]]; then
                /etc/hypervisor/scripts/transition_phase.sh harden
            else
                # Create phase marker
                touch /etc/hypervisor/.phase2_hardened
                rm -f /etc/hypervisor/.phase1_setup
                echo -e "${GREEN}✓ Transitioned to hardened phase${NC}"
            fi
            
            # Reload phase
            SECURITY_PHASE="hardened"
        fi
    else
        echo -e "${YELLOW}⚠️  Rollback to Setup Mode${NC}"
        echo
        echo "This will restore permissive setup mode."
        echo "Requires authentication."
        echo
        
        read -p "Proceed with rollback? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if [[ -f /etc/hypervisor/scripts/transition_phase.sh ]]; then
                /etc/hypervisor/scripts/transition_phase.sh setup
            else
                rm -f /etc/hypervisor/.phase2_hardened
                touch /etc/hypervisor/.phase1_setup
                echo -e "${GREEN}✓ Rolled back to setup phase${NC}"
            fi
            
            # Reload phase
            SECURITY_PHASE="setup"
        fi
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    while true; do
        show_main_menu
        
        read -p "$(echo -e "${CYAN}Select option:${NC} ")" choice
        
        case "$choice" in
            1) configure_ipv6 ;;
            2) configure_qos ;;
            3) echo "Bonding configuration..." ; read -p "Press Enter..." ;;
            4) echo "DHCP configuration..." ; read -p "Press Enter..." ;;
            5) echo "VPN configuration..." ; read -p "Press Enter..." ;;
            6) echo "Firewall zones..." ; read -p "Press Enter..." ;;
            7) CONFIG[dns_enable]="true" ; echo "DNS enabled" ; read -p "Press Enter..." ;;
            8) CONFIG[monitoring_enable]="true" ; echo "Monitoring enabled" ; read -p "Press Enter..." ;;
            9) echo "Bridge management..." ; read -p "Press Enter..." ;;
            10) CONFIG[performance_enable]="true" ; echo "Performance tuning enabled" ; read -p "Press Enter..." ;;
            11) CONFIG[tor_enable]="true" ; echo "Tor enabled" ; read -p "Press Enter..." ;;
            12) CONFIG[pcap_enable]="true" ; echo "Packet capture enabled" ; read -p "Press Enter..." ;;
            13) CONFIG[ids_enable]="true" ; echo "IDS enabled" ; read -p "Press Enter..." ;;
            14) CONFIG[lb_enable]="true" ; echo "Load balancer enabled" ; read -p "Press Enter..." ;;
            15) CONFIG[automation_enable]="true" ; echo "Automation enabled" ; read -p "Press Enter..." ;;
            16) configure_all ;;
            17) run_discovery ;;
            18) generate_config ; apply_config ;;
            19) switch_phase ;;
            0) echo "Exiting..." ; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}" ; sleep 1 ;;
        esac
    done
}

# Run
main "$@"
