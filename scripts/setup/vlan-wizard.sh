#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# VLAN Configuration Wizard
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/../lib/network-discovery.sh" 2>/dev/null || true

# Initialize
init_logging "vlan-wizard"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This wizard must be run as root${NC}"
        echo -e "${CYAN}Please run: sudo $0${NC}"
        exit 1
    fi
}

# Show banner
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}              Hyper-NixOS VLAN Configuration Wizard${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

# Select parent interface
select_parent_interface() {
    echo
    echo -e "${BOLD}${CYAN}Select Parent Interface${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Available physical interfaces:${NC}"
    echo
    
    local -a interfaces=($(get_physical_interfaces))
    local i=1
    
    for iface in "${interfaces[@]}"; do
        local mac=$(ip link show "$iface" 2>/dev/null | grep link/ether | awk '{print $2}' || echo "N/A")
        local ip=$(ip -4 addr show "$iface" 2>/dev/null | grep inet | awk '{print $2}' || echo "N/A")
        local state=$(ip link show "$iface" 2>/dev/null | grep -o 'state [A-Z]*' | awk '{print $2}' || echo "DOWN")
        
        echo -e "  ${GREEN}$i)${NC} ${BOLD}$iface${NC} - $state - IP: $ip"
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

# Get VLAN ID with recommendations
get_vlan_id() {
    local parent_interface="$1"
    
    echo
    echo -e "${BOLD}${CYAN}VLAN ID Selection${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    # Show existing VLANs
    local existing=$(detect_vlans "$parent_interface" 2>/dev/null || true)
    if [ -n "$existing" ]; then
        echo -e "${YELLOW}Existing VLANs on $parent_interface:${NC}"
        echo "$existing" | sed 's/^/  VLAN /'
        echo
    fi
    
    # Show recommendations
    echo -e "${YELLOW}💡 Recommended unused VLAN IDs:${NC}"
    local -a recommended=($(recommend_vlan_ids 5 2>/dev/null || echo "10 20 30"))
    for rec in "${recommended[@]}"; do
        echo "  $rec"
    done
    echo
    
    echo -e "${CYAN}Common VLAN ranges:${NC}"
    echo "  1-9:    Reserved (avoid)"
    echo "  10-99:  User/Department VLANs"
    echo "  100-199: Server VLANs"
    echo "  200-299: Guest/DMZ VLANs"
    echo "  1005-4094: Extended range"
    echo
    
    local vlan_id
    while true; do
        read -p "$(echo -e "${CYAN}Enter VLAN ID (1-4094) [${recommended[0]}]:${NC} ")" vlan_id
        
        # Use recommended if empty
        if [ -z "$vlan_id" ]; then
            vlan_id="${recommended[0]}"
        fi
        
        # Validate
        if [[ "$vlan_id" =~ ^[0-9]+$ ]] && [ "$vlan_id" -ge 1 ] && [ "$vlan_id" -le 4094 ]; then
            # Check if already in use
            if echo "$existing" | grep -q "^${vlan_id}$"; then
                echo -e "${RED}VLAN $vlan_id is already in use${NC}"
                continue
            fi
            echo "$vlan_id"
            return 0
        else
            echo -e "${RED}Invalid VLAN ID. Must be 1-4094${NC}"
        fi
    done
}

# Configure IP addressing
configure_vlan_ip() {
    local vlan_name="$1"
    local parent_interface="$2"
    
    echo
    echo -e "${BOLD}${CYAN}IP Address Configuration${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    # Detect parent network for suggestions
    local parent_network=$(detect_network_range "$parent_interface" 2>/dev/null || true)
    if [ -n "$parent_network" ]; then
        echo -e "${YELLOW}Parent network: $parent_network${NC}"
        echo
    fi
    
    echo "Choose addressing mode:"
    echo
    echo -e "  ${GREEN}1)${NC} DHCP - Automatic IP configuration"
    echo -e "  ${GREEN}2)${NC} Static - Manual IP configuration"
    echo -e "  ${GREEN}3)${NC} None - Configure later"
    echo
    
    local choice
    read -p "$(echo -e "${CYAN}Enter choice [1-3]:${NC} ")" choice
    
    case "$choice" in
        1)
            echo "dhcp"
            ;;
        2)
            echo
            echo "Enter static IP configuration:"
            echo
            
            # Get IP with recommendations
            if command -v recommend_safe_ips >/dev/null 2>&1; then
                echo -e "${YELLOW}💡 Recommended safe IPs:${NC}"
                recommend_safe_ips "$parent_interface" 3 2>/dev/null | sed 's/^/  /' || true
                echo
            fi
            
            local ip_addr
            while true; do
                read -p "$(echo -e "${CYAN}IP address with CIDR (e.g., 192.168.10.2/24):${NC} ")" ip_addr
                
                if [[ "$ip_addr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
                    break
                else
                    echo -e "${RED}Invalid format. Use: X.X.X.X/XX${NC}"
                fi
            done
            
            # Optional gateway
            read -p "$(echo -e "${CYAN}Gateway (optional, press Enter to skip):${NC} ")" gateway
            
            echo "static:${ip_addr}:${gateway}"
            ;;
        3)
            echo "none"
            ;;
        *)
            echo "none"
            ;;
    esac
}

# Generate NixOS VLAN configuration
generate_vlan_config() {
    local -n vlans_ref=$1
    
    cat > /tmp/vlan-config.nix <<EOF
# VLAN Configuration
# Generated by VLAN wizard on $(date)

{ config, lib, pkgs, ... }:

{
  # Import the VLAN module
  imports = [ ./modules/network-settings/vlan.nix ];
  
  # Enable and configure VLANs
  hypervisor.network.vlan = {
    enable = true;
    
    interfaces = {
EOF
    
    for vlan_name in "${!vlans_ref[@]}"; do
        local vlan_data="${vlans_ref[$vlan_name]}"
        
        # Parse data: parent:id:mode:ip:gateway
        IFS=: read -r parent id mode ip gateway <<< "$vlan_data"
        
        cat >> /tmp/vlan-config.nix <<EOF
      "$vlan_name" = {
        id = $id;
        interface = "$parent";
EOF
        
        case "$mode" in
            dhcp)
                echo "        dhcp = true;" >> /tmp/vlan-config.nix
                ;;
            static)
                cat >> /tmp/vlan-config.nix <<EOF
        addresses = [ "$ip" ];
        dhcp = false;
EOF
                if [ -n "$gateway" ]; then
                    echo "        gateway = \"$gateway\";" >> /tmp/vlan-config.nix
                fi
                ;;
        esac
        
        echo "      };" >> /tmp/vlan-config.nix
    done
    
    cat >> /tmp/vlan-config.nix <<EOF
    };
  };
}
EOF
    
    echo -e "${GREEN}✓ Configuration generated${NC}"
}

# Add VLAN
add_vlan() {
    local -n vlans_ref=$1
    
    show_banner
    echo -e "${BOLD}Add VLAN Configuration${NC}"
    echo
    
    # Select parent interface
    local parent=$(select_parent_interface)
    if [ -z "$parent" ]; then
        echo -e "${RED}Invalid interface selection${NC}"
        return 1
    fi
    
    # Get VLAN ID
    local vlan_id=$(get_vlan_id "$parent")
    
    # Generate VLAN interface name
    local vlan_name="vlan${vlan_id}"
    
    # Configure IP
    local ip_config=$(configure_vlan_ip "$vlan_name" "$parent")
    
    # Parse IP config
    local mode=$(echo "$ip_config" | cut -d: -f1)
    local ip_addr=$(echo "$ip_config" | cut -d: -f2)
    local gateway=$(echo "$ip_config" | cut -d: -f3)
    
    # Store VLAN config
    vlans_ref["$vlan_name"]="${parent}:${vlan_id}:${mode}:${ip_addr}:${gateway}"
    
    echo
    echo -e "${GREEN}✓ VLAN $vlan_name added${NC}"
    echo
}

# Show VLAN summary
show_vlan_summary() {
    local -n vlans_ref=$1
    
    echo
    echo -e "${BOLD}${CYAN}Configured VLANs Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    
    if [ ${#vlans_ref[@]} -eq 0 ]; then
        echo "No VLANs configured"
        return
    fi
    
    for vlan_name in "${!vlans_ref[@]}"; do
        local vlan_data="${vlans_ref[$vlan_name]}"
        IFS=: read -r parent id mode ip gateway <<< "$vlan_data"
        
        echo -e "${BOLD}$vlan_name${NC}"
        echo "  Parent Interface: $parent"
        echo "  VLAN ID: $id"
        echo "  Mode: $mode"
        if [ "$mode" = "static" ] && [ -n "$ip" ]; then
            echo "  IP Address: $ip"
            [ -n "$gateway" ] && echo "  Gateway: $gateway"
        fi
        echo
    done
}

# Install configuration
install_config() {
    local target="/etc/nixos/vlan.nix"
    
    echo
    echo -e "${CYAN}Installing configuration...${NC}"
    
    # Backup existing
    if [ -f "$target" ]; then
        cp "$target" "${target}.backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${YELLOW}Existing configuration backed up${NC}"
    fi
    
    # Copy new config
    cp /tmp/vlan-config.nix "$target"
    chmod 644 "$target"
    
    echo -e "${GREEN}✓ Configuration installed to $target${NC}"
    
    # Add to configuration.nix
    if ! grep -q "vlan.nix" /etc/nixos/configuration.nix 2>/dev/null; then
        echo
        read -p "$(echo -e "${CYAN}Add to configuration.nix automatically? [Y/n]:${NC} ")" auto_add
        if [[ ! "$auto_add" =~ ^[Nn]$ ]]; then
            cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup-$(date +%Y%m%d-%H%M%S)
            sed -i '/imports = \[/a\    ./vlan.nix' /etc/nixos/configuration.nix
            echo -e "${GREEN}✓ Added to configuration.nix${NC}"
        fi
    fi
}

# Apply configuration
apply_config() {
    echo
    echo -e "${CYAN}Applying configuration...${NC}"
    echo
    
    read -p "$(echo -e "${CYAN}Apply now (nixos-rebuild switch)? [Y/n]:${NC} ")" apply
    
    if [[ ! "$apply" =~ ^[Nn]$ ]]; then
        echo
        if nixos-rebuild switch; then
            echo
            echo -e "${GREEN}✓ Configuration applied successfully${NC}"
            log_info "VLAN configuration applied"
        else
            echo
            echo -e "${RED}✗ Failed to apply configuration${NC}"
            log_error "Failed to apply VLAN configuration"
        fi
    else
        echo -e "${YELLOW}Configuration saved but not applied${NC}"
        echo -e "${CYAN}Apply later with: nixos-rebuild switch${NC}"
    fi
}

# Main wizard
main() {
    show_banner
    
    check_root
    
    # VLAN storage
    declare -A vlans
    
    echo -e "${BOLD}Welcome to the VLAN Configuration Wizard${NC}"
    echo
    echo "This wizard will help you configure 802.1Q VLANs on your interfaces."
    echo
    read -p "Press Enter to continue..."
    
    # Add VLANs
    while true; do
        add_vlan vlans
        
        echo
        read -p "$(echo -e "${CYAN}Add another VLAN? [y/N]:${NC} ")" another
        if [[ ! "$another" =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    # Show summary
    show_banner
    show_vlan_summary vlans
    
    if [ ${#vlans[@]} -eq 0 ]; then
        echo -e "${YELLOW}No VLANs configured. Exiting.${NC}"
        exit 0
    fi
    
    # Generate configuration
    generate_vlan_config vlans
    
    # Install
    install_config
    
    # Apply
    apply_config
    
    # Final summary
    echo
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║              VLAN Configuration Complete                     ║${NC}"
    echo -e "${BOLD}${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Configured VLANs:${NC} ${#vlans[@]}                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Useful commands:${NC}                                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    • View VLANs: ip -d link show                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    • Check IPs: ip addr show                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    • Test VLAN: ping -I vlanXX <target>                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    • View logs: journalctl -t vlan                           ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    echo
    echo -e "${BOLD}${GREEN}Setup completed successfully!${NC}"
    log_info "VLAN wizard completed successfully"
}

# Run
main "$@"
