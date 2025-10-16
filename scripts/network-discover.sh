#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Network Discovery Utility
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Comprehensive network scanning and analysis tool

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/network-discovery.sh"

# Initialize
init_logging "network-discover"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Parse command line
MODE="${1:-interactive}"
INTERFACE="${2:-}"

# Show banner
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}              Hyper-NixOS Network Discovery Tool${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

# Main menu
show_menu() {
    clear
    show_banner
    echo -e "${BOLD}Select discovery mode:${NC}"
    echo
    echo -e "  ${GREEN}1)${NC} Quick Scan - Active hosts and basic info"
    echo -e "  ${GREEN}2)${NC} Full Scan - Comprehensive network analysis"
    echo -e "  ${GREEN}3)${NC} Interface Info - Detailed interface information"
    echo -e "  ${GREEN}4)${NC} Gateway Scan - Scan default gateway services"
    echo -e "  ${GREEN}5)${NC} VLAN Discovery - Detect existing VLANs"
    echo -e "  ${GREEN}6)${NC} Wireless Scan - Scan for WiFi networks"
    echo -e "  ${GREEN}7)${NC} ARP Analysis - Analyze ARP cache"
    echo -e "  ${GREEN}8)${NC} Safe IP Recommendations - Find unused IPs"
    echo -e "  ${GREEN}9)${NC} MAC Vendor Lookup - Identify MAC vendors"
    echo -e "  ${GREEN}0)${NC} Exit"
    echo
}

# Select interface
select_interface() {
    echo
    echo -e "${CYAN}Available interfaces:${NC}"
    echo
    
    local -a interfaces=($(get_physical_interfaces))
    local i=1
    
    for iface in "${interfaces[@]}"; do
        local mac=$(ip link show "$iface" 2>/dev/null | grep link/ether | awk '{print $2}' || echo "N/A")
        local ip=$(ip -4 addr show "$iface" 2>/dev/null | grep inet | awk '{print $2}' || echo "N/A")
        local state=$(ip link show "$iface" 2>/dev/null | grep -o 'state [A-Z]*' | awk '{print $2}' || echo "UNKNOWN")
        
        echo -e "  ${GREEN}$i)${NC} ${BOLD}$iface${NC} - $state - IP: $ip - MAC: $mac"
        ((i++))
    done
    
    echo
    read -p "$(echo -e "${CYAN}Select interface (1-${#interfaces[@]}):${NC} ")" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#interfaces[@]}" ]; then
        echo "${interfaces[$((choice-1))]}"
    else
        echo ""
    fi
}

# Quick scan
quick_scan() {
    local interface="$1"
    
    echo
    echo -e "${BOLD}${CYAN}Quick Network Scan - $interface${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    # Basic info
    echo -e "${YELLOW}Interface Information:${NC}"
    local mac=$(ip link show "$interface" 2>/dev/null | grep link/ether | awk '{print $2}' || echo "N/A")
    local ip=$(ip -4 addr show "$interface" 2>/dev/null | grep inet | awk '{print $2}' || echo "N/A")
    local state=$(ip link show "$interface" 2>/dev/null | grep -o 'state [A-Z]*' | awk '{print $2}' || echo "UNKNOWN")
    
    echo "  MAC:   $mac"
    echo "  IP:    $ip"
    echo "  State: $state"
    echo
    
    # Network range
    echo -e "${YELLOW}Network Range:${NC}"
    local range=$(detect_network_range "$interface" || echo "N/A")
    echo "  $range"
    echo
    
    # Gateway
    echo -e "${YELLOW}Gateway:${NC}"
    local gateway=$(detect_gateway "$interface" || echo "N/A")
    echo "  $gateway"
    echo
    
    # Active hosts
    echo -e "${YELLOW}Scanning for active hosts (this may take a moment)...${NC}"
    local hosts=$(scan_active_hosts "$interface" 2 2>/dev/null || echo "")
    local count=$(echo "$hosts" | grep -c . || echo "0")
    echo "  Found $count active hosts"
    
    if [ "$count" -gt 0 ] && [ "$count" -lt 20 ]; then
        echo
        echo "  Active IPs:"
        echo "$hosts" | head -20 | sed 's/^/    /'
    fi
    
    echo
}

# Full scan
full_scan() {
    local interface="$1"
    
    echo
    echo -e "${BOLD}${CYAN}Full Network Scan - $interface${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    
    # Comprehensive discovery
    local result=$(discover_network "$interface" 2>&1 | tee /dev/tty)
    
    echo
    echo -e "${GREEN}✓ Full scan complete${NC}"
    echo
    echo "Results saved to: ${DISCOVERY_CACHE}/${interface}_discovery.json"
    echo
}

# Interface details
interface_info() {
    local interface="$1"
    
    echo
    echo -e "${BOLD}${CYAN}Interface Details - $interface${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    # Get comprehensive info
    local info_file=$(get_interface_info "$interface")
    
    if [ -f "$info_file" ]; then
        echo -e "${YELLOW}Configuration:${NC}"
        cat "$info_file" | jq -r '
            "  Interface:  \(.interface)",
            "  MAC:        \(.mac)",
            "  IPv4:       \(.ipv4)",
            "  IPv6:       \(.ipv6)",
            "  State:      \(.state)",
            "  Speed:      \(.speed)",
            "  MTU:        \(.mtu)",
            "  Wireless:   \(.wireless)"
        ' 2>/dev/null || cat "$info_file"
        echo
    fi
    
    # Additional details
    echo -e "${YELLOW}Statistics:${NC}"
    ip -s link show "$interface" | grep -A2 "RX:\|TX:" | sed 's/^/  /'
    echo
    
    # Routing
    echo -e "${YELLOW}Routes:${NC}"
    ip route show dev "$interface" | sed 's/^/  /'
    echo
}

# Gateway scan
gateway_scan() {
    local interface="$1"
    
    echo
    echo -e "${BOLD}${CYAN}Gateway Scan${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    local gateway=$(detect_gateway "$interface")
    
    if [ -z "$gateway" ] || [ "$gateway" = "none" ]; then
        echo -e "${RED}No gateway detected${NC}"
        return
    fi
    
    echo -e "${YELLOW}Gateway: $gateway${NC}"
    echo
    
    # Ping test
    echo "Testing connectivity..."
    if ping -c 3 "$gateway" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Gateway reachable${NC}"
    else
        echo -e "  ${RED}✗ Gateway unreachable${NC}"
    fi
    echo
    
    # Service scan
    if command -v nmap >/dev/null 2>&1; then
        echo "Scanning for services (this may take a moment)..."
        echo
        scan_gateway_services "$gateway" 2>/dev/null | sed 's/^/  /' || echo "  No services detected"
    else
        echo "Install nmap for service scanning"
    fi
    echo
}

# VLAN discovery
vlan_discovery() {
    echo
    echo -e "${BOLD}${CYAN}VLAN Discovery${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    # Detect existing VLANs
    local vlans=$(detect_vlans)
    
    if [ -z "$vlans" ]; then
        echo "No VLANs currently configured"
    else
        echo -e "${YELLOW}Configured VLANs:${NC}"
        echo "$vlans" | while read -r vlan; do
            echo "  VLAN ID: $vlan"
            
            # Show VLAN interface details
            local vlan_if=$(ip -d link show | grep "vlan id $vlan" | awk '{print $2}' | cut -d@ -f1)
            if [ -n "$vlan_if" ]; then
                local ip=$(ip -4 addr show "$vlan_if" 2>/dev/null | grep inet | awk '{print $2}' || echo "N/A")
                echo "    Interface: $vlan_if"
                echo "    IP: $ip"
            fi
            echo
        done
    fi
    
    # Recommend unused VLAN IDs
    echo -e "${YELLOW}Recommended unused VLAN IDs:${NC}"
    recommend_vlan_ids 5 | sed 's/^/  /'
    echo
}

# Wireless scan
wireless_scan() {
    local interface="$1"
    
    echo
    echo -e "${BOLD}${CYAN}Wireless Network Scan - $interface${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    # Check if wireless
    local wireless_interfaces=$(get_wireless_interfaces)
    
    if [ -z "$wireless_interfaces" ]; then
        echo -e "${YELLOW}No wireless interfaces detected${NC}"
        return
    fi
    
    # Check if specific interface is wireless
    if ! echo "$wireless_interfaces" | grep -q "^${interface}$"; then
        echo -e "${YELLOW}$interface is not a wireless interface${NC}"
        echo
        echo "Available wireless interfaces:"
        echo "$wireless_interfaces" | sed 's/^/  /'
        return
    fi
    
    # Scan
    echo "Scanning for wireless networks (requires root)..."
    echo
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Wireless scanning requires root privileges${NC}"
        echo "Run with: sudo $0"
        return
    fi
    
    scan_wireless_networks "$interface" 2>/dev/null | head -20 | sed 's/^/  /' || \
        echo "  No networks found or scanning failed"
    echo
}

# ARP analysis
arp_analysis() {
    echo
    echo -e "${BOLD}${CYAN}ARP Cache Analysis${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    echo -e "${YELLOW}ARP Cache Entries:${NC}"
    get_arp_cache | head -30 | while read -r ip mac; do
        local vendor=$(lookup_mac_vendor "$mac" 2>/dev/null || echo "Unknown")
        echo "  $ip -> $mac ($vendor)"
    done
    echo
    
    # Check for conflicts
    echo -e "${YELLOW}Checking for MAC conflicts...${NC}"
    local conflicts=$(detect_arp_conflicts)
    if [ -z "$conflicts" ]; then
        echo "  No conflicts detected"
    else
        echo "  Potential conflicts:"
        echo "$conflicts" | sed 's/^/    /'
    fi
    echo
}

# Safe IP recommendations
safe_ip_recommendations() {
    local interface="$1"
    
    echo
    echo -e "${BOLD}${CYAN}Safe IP Recommendations - $interface${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    # Show network info
    local network_range=$(detect_network_range "$interface")
    echo -e "${YELLOW}Network Range:${NC} $network_range"
    echo
    
    # Get used IPs
    echo "Scanning for used IPs (this may take a moment)..."
    local used_count=$(get_used_ips "$interface" 2>/dev/null | wc -l || echo "0")
    echo "  Found $used_count IPs in use"
    echo
    
    # Recommend safe IPs
    echo -e "${YELLOW}Recommended unused IPs:${NC}"
    recommend_safe_ips "$interface" 10 2>/dev/null | sed 's/^/  /' || \
        echo "  Could not generate recommendations"
    echo
    
    # Show usable range
    local range=$(get_usable_ip_range "$network_range" 2>/dev/null || echo "N/A")
    echo -e "${YELLOW}Usable IP Range:${NC} $range"
    echo
}

# MAC vendor lookup
mac_vendor_lookup() {
    echo
    echo -e "${BOLD}${CYAN}MAC Vendor Lookup${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    read -p "Enter MAC address (XX:XX:XX:XX:XX:XX): " mac
    
    if [ -z "$mac" ]; then
        echo "No MAC address provided"
        return
    fi
    
    echo
    echo -e "${YELLOW}Looking up vendor for: $mac${NC}"
    local vendor=$(lookup_mac_vendor "$mac" 2>/dev/null || echo "Unknown")
    echo "  Vendor: $vendor"
    echo
    
    # Show common vendor prefixes
    echo -e "${YELLOW}Common vendor prefixes for MAC spoofing:${NC}"
    get_common_vendor_prefixes | head -10 | sed 's/^/  /'
    echo
}

# Interactive mode
interactive_mode() {
    while true; do
        show_menu
        
        read -p "$(echo -e "${CYAN}Enter choice:${NC} ")" choice
        
        case "$choice" in
            1|2|3|4|6|8)
                local iface=$(select_interface)
                if [ -z "$iface" ]; then
                    echo -e "${RED}Invalid selection${NC}"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                case "$choice" in
                    1) quick_scan "$iface" ;;
                    2) full_scan "$iface" ;;
                    3) interface_info "$iface" ;;
                    4) gateway_scan "$iface" ;;
                    6) wireless_scan "$iface" ;;
                    8) safe_ip_recommendations "$iface" ;;
                esac
                ;;
            5) vlan_discovery ;;
            7) arp_analysis ;;
            9) mac_vendor_lookup ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Command-line mode
command_mode() {
    local mode="$1"
    local interface="$2"
    
    case "$mode" in
        quick)
            if [ -z "$interface" ]; then
                echo "Usage: $0 quick <interface>"
                exit 1
            fi
            quick_scan "$interface"
            ;;
        full)
            if [ -z "$interface" ]; then
                echo "Usage: $0 full <interface>"
                exit 1
            fi
            full_scan "$interface"
            ;;
        info)
            if [ -z "$interface" ]; then
                echo "Usage: $0 info <interface>"
                exit 1
            fi
            interface_info "$interface"
            ;;
        gateway)
            if [ -z "$interface" ]; then
                echo "Usage: $0 gateway <interface>"
                exit 1
            fi
            gateway_scan "$interface"
            ;;
        vlan)
            vlan_discovery
            ;;
        wireless)
            if [ -z "$interface" ]; then
                echo "Usage: $0 wireless <interface>"
                exit 1
            fi
            wireless_scan "$interface"
            ;;
        arp)
            arp_analysis
            ;;
        safe-ips)
            if [ -z "$interface" ]; then
                echo "Usage: $0 safe-ips <interface>"
                exit 1
            fi
            safe_ip_recommendations "$interface"
            ;;
        *)
            cat <<EOF
Usage: $0 [MODE] [INTERFACE]

Modes:
  interactive     Interactive menu (default)
  quick          Quick network scan
  full           Full network analysis
  info           Interface details
  gateway        Gateway service scan
  vlan           VLAN discovery
  wireless       Wireless network scan
  arp            ARP cache analysis
  safe-ips       Recommend safe IPs

Examples:
  $0                      # Interactive mode
  $0 quick eth0           # Quick scan of eth0
  $0 full eth0            # Full scan of eth0
  $0 vlan                 # Discover VLANs
  $0 safe-ips eth0        # Get safe IP recommendations
EOF
            exit 1
            ;;
    esac
}

# Main
main() {
    if [ "$MODE" = "interactive" ]; then
        interactive_mode
    else
        command_mode "$MODE" "$INTERFACE"
    fi
}

# Run
main "$@"
