#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# IP Address Management and Spoofing Setup Wizard
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# ⚠️  LEGAL NOTICE ⚠️
# IP address manipulation should only be used for:
# - Authorized penetration testing and security research
# - Development and testing environments
# - Load balancing and high availability setups
# - Network troubleshooting and diagnostics
#
# Unauthorized use may violate network policies, terms of service, or laws.
# The user assumes all responsibility for proper and legal use.

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh" 2>/dev/null || {
    echo "Error: Could not source common library"
    exit 1
}

# Initialize
init_logging "ip-spoofing-wizard"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This wizard must be run as root${NC}"
        echo -e "${CYAN}Please run: sudo $0${NC}"
        exit 1
    fi
}

# Show legal warning
show_legal_warning() {
    clear
    echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║              ⚠️  LEGAL WARNING AND DISCLAIMER ⚠️              ║${NC}"
    echo -e "${BOLD}${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC}                                                               ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}IP address manipulation can be used for:${NC}                  ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Authorized penetration testing/security research        ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Development and testing environments                    ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Load balancing and high availability setups             ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Network troubleshooting and diagnostics                 ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                               ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}${YELLOW}However, improper use may:${NC}                                ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Violate network policies or terms of service            ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Be illegal in certain jurisdictions                     ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Cause IP conflicts and network outages                  ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Result in account suspension or legal action            ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Disrupt network services for others                     ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                               ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}By continuing, you acknowledge that:${NC}                     ${RED}║${NC}"
    echo -e "${RED}║${NC}    ✓ You will use this feature only for legitimate purposes  ${RED}║${NC}"
    echo -e "${RED}║${NC}    ✓ You have authorization to modify network settings       ${RED}║${NC}"
    echo -e "${RED}║${NC}    ✓ You understand the legal and technical risks            ${RED}║${NC}"
    echo -e "${RED}║${NC}    ✓ You accept full responsibility for your actions         ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                               ${RED}║${NC}"
    echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    read -p "$(echo -e "${BOLD}Do you accept these terms and conditions? [yes/NO]:${NC} ")" response
    
    if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Setup cancelled. No changes have been made.${NC}"
        exit 0
    fi
    
    log_warn "User accepted IP spoofing legal disclaimer"
}

# Get list of network interfaces
get_interfaces() {
    ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$"
}

# Get current IP addresses
get_current_ips() {
    local interface="$1"
    ip -4 addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | tr '\n' ' '
}

# Select mode
select_mode() {
    clear
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}              IP Management Mode Selection${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${BOLD}Select IP management mode:${NC}"
    echo
    echo -e "  ${GREEN}1)${NC} ${BOLD}Alias${NC} - Add multiple IP addresses to interfaces"
    echo -e "     └─ For load balancing, multiple services, or failover"
    echo -e "     └─ All IPs active simultaneously"
    echo
    echo -e "  ${GREEN}2)${NC} ${BOLD}Rotation${NC} - Rotate through a pool of IPs periodically"
    echo -e "     └─ For privacy, testing, or evading rate limits"
    echo -e "     └─ One active IP at a time, changes periodically"
    echo
    echo -e "  ${GREEN}3)${NC} ${BOLD}Dynamic${NC} - Generate random IPs within specified ranges"
    echo -e "     └─ For advanced testing and research"
    echo -e "     └─ Automatically generates IPs from CIDR ranges"
    echo
    echo -e "  ${GREEN}4)${NC} ${BOLD}Proxy Chain${NC} - Route traffic through proxy chains"
    echo -e "     └─ For anonymization and circumvention"
    echo -e "     └─ Configure SOCKS5/HTTP proxy chains"
    echo
    echo -e "  ${GREEN}5)${NC} ${BOLD}Disabled${NC} - Turn off IP management"
    echo -e "     └─ Restore standard network configuration"
    echo
    
    local choice
    read -p "$(echo -e "${CYAN}Enter your choice [1-5]:${NC} ")" choice
    
    case "$choice" in
        1) echo "alias" ;;
        2) echo "rotation" ;;
        3) echo "dynamic" ;;
        4) echo "proxy" ;;
        5) echo "disabled" ;;
        *) 
            echo -e "${RED}Invalid choice. Defaulting to disabled.${NC}"
            echo "disabled"
            ;;
    esac
}

# Select interfaces
select_interfaces() {
    local -a selected=()
    
    clear
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}              Network Interface Selection${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${BOLD}Available network interfaces:${NC}"
    echo
    
    local -a interfaces=($(get_interfaces))
    local i=1
    
    for iface in "${interfaces[@]}"; do
        local ips=$(get_current_ips "$iface")
        echo -e "  ${GREEN}$i)${NC} ${BOLD}$iface${NC} - Current IPs: $ips"
        ((i++))
    done
    
    echo
    read -p "$(echo -e "${CYAN}Enter interface numbers (space-separated, or 'all'):${NC} ")" selection
    
    if [[ "$selection" == "all" ]]; then
        selected=("${interfaces[@]}")
    else
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#interfaces[@]}" ]; then
                selected+=("${interfaces[$((num-1))]}")
            fi
        done
    fi
    
    printf '%s\n' "${selected[@]}"
}

# Configure alias IPs
configure_alias() {
    local interface="$1"
    local -a aliases=()
    
    echo
    echo -e "${CYAN}Configuring IP aliases for${NC} ${BOLD}$interface${NC}"
    echo -e "${YELLOW}Enter IP addresses with CIDR notation (e.g., 192.168.1.100/24)${NC}"
    echo -e "${YELLOW}Enter 'done' when finished${NC}"
    echo
    
    while true; do
        read -p "$(echo -e "${CYAN}IP address (or 'done'):${NC} ")" ip
        
        if [[ "$ip" == "done" ]]; then
            break
        fi
        
        # Validate IP format
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            aliases+=("$ip")
            echo -e "${GREEN}✓ Added: $ip${NC}"
        else
            echo -e "${RED}Invalid format. Use: X.X.X.X/XX${NC}"
        fi
    done
    
    printf '%s\n' "${aliases[@]}"
}

# Configure rotation pool
configure_rotation() {
    local interface="$1"
    local -a pool=()
    
    echo
    echo -e "${CYAN}Configuring IP rotation pool for${NC} ${BOLD}$interface${NC}"
    echo -e "${YELLOW}Enter IP addresses (without CIDR, e.g., 192.168.1.100)${NC}"
    echo -e "${YELLOW}Enter 'done' when finished${NC}"
    echo
    
    while true; do
        read -p "$(echo -e "${CYAN}IP address (or 'done'):${NC} ")" ip
        
        if [[ "$ip" == "done" ]]; then
            break
        fi
        
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            pool+=("$ip")
            echo -e "${GREEN}✓ Added: $ip${NC}"
        else
            echo -e "${RED}Invalid format. Use: X.X.X.X${NC}"
        fi
    done
    
    # Get rotation interval
    echo
    read -p "$(echo -e "${CYAN}Rotation interval in seconds [default: 3600]:${NC} ")" interval
    interval=${interval:-3600}
    
    echo "POOL:${pool[*]}:INTERVAL:$interval"
}

# Configure dynamic range
configure_dynamic() {
    local interface="$1"
    
    echo
    echo -e "${CYAN}Configuring dynamic IP range for${NC} ${BOLD}$interface${NC}"
    echo -e "${YELLOW}Enter CIDR range for random IP generation${NC}"
    echo -e "${YELLOW}Example: 10.0.0.0/24 (generates IPs from 10.0.0.1 to 10.0.0.254)${NC}"
    echo
    
    local range
    read -p "$(echo -e "${CYAN}CIDR range:${NC} ")" range
    
    echo "$range"
}

# Configure proxy chain
configure_proxy() {
    local -a proxies=()
    
    clear
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}              Proxy Chain Configuration${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Enter proxy details. Proxies will be chained in order.${NC}"
    echo -e "${YELLOW}Enter 'done' when finished.${NC}"
    echo
    
    while true; do
        echo
        echo -e "${BOLD}Proxy entry #$((${#proxies[@]} + 1)):${NC}"
        read -p "$(echo -e "${CYAN}Proxy type (socks5/http/https) or 'done':${NC} ")" type
        
        if [[ "$type" == "done" ]]; then
            break
        fi
        
        if [[ ! "$type" =~ ^(socks5|http|https)$ ]]; then
            echo -e "${RED}Invalid type. Use: socks5, http, or https${NC}"
            continue
        fi
        
        read -p "$(echo -e "${CYAN}Host:${NC} ")" host
        read -p "$(echo -e "${CYAN}Port:${NC} ")" port
        read -p "$(echo -e "${CYAN}Username (optional):${NC} ")" username
        
        if [ -n "$username" ]; then
            read -sp "$(echo -e "${CYAN}Password:${NC} ")" password
            echo
            proxies+=("$type:$host:$port:$username:$password")
        else
            proxies+=("$type:$host:$port")
        fi
        
        echo -e "${GREEN}✓ Proxy added${NC}"
    done
    
    # Randomize order
    echo
    read -p "$(echo -e "${CYAN}Randomize proxy chain order? [Y/n]:${NC} ")" randomize
    if [[ ! "$randomize" =~ ^[Nn]$ ]]; then
        echo "RANDOMIZE:true"
    else
        echo "RANDOMIZE:false"
    fi
    
    printf '%s\n' "${proxies[@]}"
}

# Generate NixOS configuration
generate_nix_config() {
    local mode="$1"
    shift
    
    cat > /tmp/ip-spoof-config.nix <<EOF
# IP Address Management Configuration
# Generated by IP spoofing wizard on $(date)
# ⚠️  Use only for legitimate purposes

{ config, lib, pkgs, ... }:

{
  # Import the IP spoofing module
  imports = [ ./modules/network-settings/ip-spoofing.nix ];
  
  # Enable and configure IP management
  hypervisor.network.ipSpoof = {
    enable = true;
    mode = "$mode";
    logChanges = true;
    avoidConflicts = true;
    
EOF
    
    case "$mode" in
        alias|rotation|dynamic)
            echo "    interfaces = {" >> /tmp/ip-spoof-config.nix
            
            local -a interfaces=("$@")
            for iface in "${interfaces[@]}"; do
                echo "      \"$iface\" = {" >> /tmp/ip-spoof-config.nix
                echo "        enable = true;" >> /tmp/ip-spoof-config.nix
                
                case "$mode" in
                    alias)
                        local -a aliases
                        mapfile -t aliases < <(configure_alias "$iface")
                        if [ ${#aliases[@]} -gt 0 ]; then
                            echo "        aliases = [" >> /tmp/ip-spoof-config.nix
                            for alias in "${aliases[@]}"; do
                                echo "          \"$alias\"" >> /tmp/ip-spoof-config.nix
                            done
                            echo "        ];" >> /tmp/ip-spoof-config.nix
                        fi
                        ;;
                    rotation)
                        local config=$(configure_rotation "$iface")
                        local pool_part=$(echo "$config" | grep "POOL:" | cut -d: -f2)
                        local interval=$(echo "$config" | grep "INTERVAL:" | cut -d: -f4)
                        
                        echo "        ipPool = [ $(echo "$pool_part" | tr ' ' '\n' | sed 's/^/\"/' | sed 's/$/\"/' | tr '\n' ' ') ];" >> /tmp/ip-spoof-config.nix
                        echo "        rotationInterval = $interval;" >> /tmp/ip-spoof-config.nix
                        ;;
                    dynamic)
                        local range=$(configure_dynamic "$iface")
                        echo "        dynamicRange = \"$range\";" >> /tmp/ip-spoof-config.nix
                        ;;
                esac
                
                echo "      };" >> /tmp/ip-spoof-config.nix
            done
            
            echo "    };" >> /tmp/ip-spoof-config.nix
            ;;
        proxy)
            echo "    proxy = {" >> /tmp/ip-spoof-config.nix
            echo "      enable = true;" >> /tmp/ip-spoof-config.nix
            
            local config=$(configure_proxy)
            local randomize=$(echo "$config" | grep "RANDOMIZE:" | cut -d: -f2)
            local -a proxies=($(echo "$config" | grep -v "RANDOMIZE:"))
            
            echo "      randomizeOrder = $randomize;" >> /tmp/ip-spoof-config.nix
            echo "      proxies = [" >> /tmp/ip-spoof-config.nix
            
            for proxy in "${proxies[@]}"; do
                IFS=: read -r type host port username password <<< "$proxy"
                echo "        {" >> /tmp/ip-spoof-config.nix
                echo "          type = \"$type\";" >> /tmp/ip-spoof-config.nix
                echo "          host = \"$host\";" >> /tmp/ip-spoof-config.nix
                echo "          port = $port;" >> /tmp/ip-spoof-config.nix
                if [ -n "$username" ]; then
                    echo "          username = \"$username\";" >> /tmp/ip-spoof-config.nix
                    echo "          password = \"$password\";" >> /tmp/ip-spoof-config.nix
                fi
                echo "        }" >> /tmp/ip-spoof-config.nix
            done
            
            echo "      ];" >> /tmp/ip-spoof-config.nix
            echo "    };" >> /tmp/ip-spoof-config.nix
            ;;
    esac
    
    cat >> /tmp/ip-spoof-config.nix <<EOF
  };
}
EOF
    
    echo -e "${GREEN}✓ Configuration generated${NC}"
}

# Install configuration
install_config() {
    local target="/etc/nixos/ip-spoof.nix"
    
    echo
    echo -e "${CYAN}Installing configuration...${NC}"
    
    # Backup existing config if present
    if [ -f "$target" ]; then
        cp "$target" "${target}.backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${YELLOW}Existing configuration backed up${NC}"
    fi
    
    # Copy new configuration
    cp /tmp/ip-spoof-config.nix "$target"
    chmod 644 "$target"
    
    echo -e "${GREEN}✓ Configuration installed to $target${NC}"
    
    # Add to configuration.nix if not already present
    if ! grep -q "ip-spoof.nix" /etc/nixos/configuration.nix 2>/dev/null; then
        echo
        echo -e "${YELLOW}Note: Add the following to your configuration.nix imports:${NC}"
        echo -e "${CYAN}  imports = [${NC}"
        echo -e "${CYAN}    ./ip-spoof.nix${NC}"
        echo -e "${CYAN}  ];${NC}"
        echo
        read -p "$(echo -e "${CYAN}Add automatically? [Y/n]:${NC} ")" auto_add
        if [[ ! "$auto_add" =~ ^[Nn]$ ]]; then
            # Backup configuration.nix
            cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup-$(date +%Y%m%d-%H%M%S)
            
            # Add import
            sed -i '/imports = \[/a\    ./ip-spoof.nix' /etc/nixos/configuration.nix
            echo -e "${GREEN}✓ Added to configuration.nix${NC}"
        fi
    fi
}

# Apply configuration
apply_config() {
    echo
    echo -e "${CYAN}Applying configuration...${NC}"
    echo -e "${YELLOW}This will rebuild your NixOS configuration.${NC}"
    echo
    
    read -p "$(echo -e "${CYAN}Apply now? [Y/n]:${NC} ")" apply
    
    if [[ ! "$apply" =~ ^[Nn]$ ]]; then
        echo
        echo -e "${BLUE}Running nixos-rebuild...${NC}"
        if nixos-rebuild switch; then
            echo -e "${GREEN}✓ Configuration applied successfully${NC}"
            log_info "IP spoofing configuration applied"
        else
            echo -e "${RED}✗ Failed to apply configuration${NC}"
            echo -e "${YELLOW}You can apply manually later with: nixos-rebuild switch${NC}"
            log_error "Failed to apply IP spoofing configuration"
        fi
    else
        echo -e "${YELLOW}Configuration saved but not applied.${NC}"
        echo -e "${CYAN}To apply later, run: nixos-rebuild switch${NC}"
    fi
}

# Show summary
show_summary() {
    local mode="$1"
    
    clear
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║              IP Management Configuration Summary              ║${NC}"
    echo -e "${BOLD}${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Mode:${NC} $mode                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Configuration files:${NC}                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}    • /etc/nixos/ip-spoof.nix                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}Useful commands:${NC}                                         ${GREEN}║${NC}"
    
    case "$mode" in
        alias)
            echo -e "${GREEN}║${NC}    • View aliases: ip addr show                            ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}    • Service: systemctl status ip-alias                    ${GREEN}║${NC}"
            ;;
        rotation)
            echo -e "${GREEN}║${NC}    • View logs: journalctl -t ip-rotation                  ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}    • Service: systemctl status ip-rotation                 ${GREEN}║${NC}"
            ;;
        proxy)
            echo -e "${GREEN}║${NC}    • Test: proxychains curl ifconfig.me                    ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}    • Config: /etc/proxychains/proxychains.conf             ${GREEN}║${NC}"
            ;;
    esac
    
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

# Main wizard flow
main() {
    clear
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}        Hyper-NixOS IP Management Setup Wizard${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Check root
    check_root
    
    # Show legal warning
    show_legal_warning
    
    # Select mode
    local mode
    mode=$(select_mode)
    
    if [ "$mode" = "disabled" ]; then
        echo -e "${YELLOW}IP management will be disabled.${NC}"
        # TODO: Remove configuration
        exit 0
    fi
    
    # Select interfaces (except for proxy mode)
    local -a interfaces=()
    if [ "$mode" != "proxy" ]; then
        mapfile -t interfaces < <(select_interfaces)
        
        if [ ${#interfaces[@]} -eq 0 ]; then
            echo -e "${RED}No interfaces selected. Exiting.${NC}"
            exit 1
        fi
    fi
    
    # Generate configuration
    generate_nix_config "$mode" "${interfaces[@]}"
    
    # Install configuration
    install_config
    
    # Apply configuration
    apply_config
    
    # Show summary
    show_summary "$mode"
    
    echo
    echo -e "${BOLD}${GREEN}Setup completed successfully!${NC}"
    log_info "IP spoofing wizard completed successfully"
}

# Run main
main "$@"
