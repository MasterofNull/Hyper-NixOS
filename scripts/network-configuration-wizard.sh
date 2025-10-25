#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: network-configuration-wizard.sh
# Purpose: Intelligent network configuration based on detected topology
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
source "${SCRIPT_DIR}/lib/logging.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/error_handling.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/config_backup.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/dry_run.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/educational-template.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/branding.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/hardware-capabilities.sh" 2>/dev/null || true

setup_error_trap "network-configuration-wizard.sh"
parse_dry_run_arg "$@"

# Show branded banner
clear
show_banner_large

echo -e "${BOLD}Network Configuration Wizard${NC}"
echo "Configure network topology and bridge settings."
echo ""

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Detect network interfaces
detect_network_interfaces() {
    ip link show | grep -E "^[0-9]+" | awk '{print $2}' | sed 's/://' | grep -v "lo"
}

# Detect network topology
detect_network_topology() {
    local interfaces=$(detect_network_interfaces | wc -l)
    local has_bridge=$(bridge link 2>/dev/null | wc -l)
    local has_vlan=$(ip link show type vlan 2>/dev/null | wc -l)
    local default_route=$(ip route | grep default | wc -l)
    
    echo "$interfaces|$has_bridge|$has_vlan|$default_route"
}

# Recommend network mode
recommend_network_mode() {
    local interfaces=$1
    local has_bridge=$2
    local has_vlan=$3
    
    if [ "$interfaces" -ge 2 ] && [ "$has_bridge" -gt 0 ]; then
        echo "bridge"
    elif [ "$interfaces" -ge 2 ]; then
        echo "bridge_recommended"
    else
        echo "nat"
    fi
}

# Main wizard
main() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║  ${BOLD}Network Configuration Wizard${NC}${CYAN}                          "
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Detecting network topology...${NC}\n"
    
    local topology=$(detect_network_topology)
    IFS='|' read -r interfaces has_bridge has_vlan default_route <<< "$topology"
    
    echo -e "${GREEN}Detection Results:${NC}"
    echo -e "  • Network interfaces: ${BOLD}$interfaces${NC}"
    echo -e "  • Existing bridges: ${BOLD}$has_bridge${NC}"
    echo -e "  • VLANs configured: ${BOLD}$has_vlan${NC}"
    echo -e "  • Default routes: ${BOLD}$default_route${NC}"
    echo ""
    
    # Show interfaces
    echo -e "${CYAN}Available Interfaces:${NC}"
    detect_network_interfaces | while read -r iface; do
        local ip_addr=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' || echo "No IP")
        local state=$(ip link show "$iface" 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
        echo -e "  • ${BOLD}$iface${NC}: $ip_addr ($state)"
    done
    echo ""
    
    # Recommendation
    local rec_mode=$(recommend_network_mode "$interfaces" "$has_bridge" "$has_vlan")
    
    echo -e "${CYAN}Recommended Network Mode: ${BOLD}$rec_mode${NC}\n"

    # Educational content about recommendation
    educational_header "Network Topology"

    case "$rec_mode" in
        bridge)
            explain_what "Bridge Networking" \
                "Connecting VMs directly to your physical network using a network bridge"

            explain_why "You have multiple network interfaces" \
                "Bridge mode allows VMs to appear as separate devices on your network, enabling direct access to VM services"

            explain_how "1. Create a software bridge (br0)
2. Attach your physical interface to the bridge
3. VMs connect to the bridge
4. Each VM gets its own network identity"

            show_transferable_skill "Linux Bridge Networking" \
                "Works on Ubuntu, Debian, RHEL, and ANY Linux system. Also used in Docker, Kubernetes, and OpenStack"
            ;;
        bridge_recommended)
            explain_what "Bridge Networking (Recommended)" \
                "Your system has multiple interfaces - perfect for high-performance bridge mode"

            compare_options \
                "Bridge Mode" \
                "Direct network access, better performance, VMs visible on network" \
                "Requires network configuration, VMs exposed to network" \
                "NAT Mode" \
                "Simpler setup, isolated VMs, works with single interface" \
                "Network address translation overhead, port forwarding needed for services"
            ;;
        nat)
            explain_what "NAT Networking" \
                "Network Address Translation - VMs use the host as a gateway to the internet"

            explain_why "Single interface or security-focused setup" \
                "NAT provides a security barrier between VMs and your network, perfect for testing"

            explain_how "1. Create virtual network (virbr0)
2. Run DHCP server for VMs
3. VMs get private IPs (192.168.122.x)
4. Host translates VM traffic to/from internet"

            show_best_practice "NAT for Development VMs" \
                "NAT mode is industry standard for development because it isolates test VMs from production networks"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Configuration Options:${NC}\n"
    echo -e "  ${BOLD}nat${NC}     - NAT networking (secure, isolated)"
    echo -e "  ${BOLD}bridge${NC}  - Bridge networking (performance, direct access)"

    # Show SR-IOV option if hardware supports it
    if is_feature_available "iommu" 2>/dev/null; then
        echo -e "  ${BOLD}sriov${NC}   - SR-IOV networking ${GREEN}(hardware supported)${NC}"
    else
        echo -e "  ${GRAY}sriov${NC}   - SR-IOV networking ${DIM}(unavailable: $(get_unavailable_reason "iommu" 2>/dev/null || echo "IOMMU not available"))${NC}"
    fi

    # Show WiFi management option if WiFi present
    if is_feature_available "wifi_config" 2>/dev/null; then
        echo -e "  ${BOLD}wifi${NC}    - WiFi management ${GREEN}(WiFi adapter detected)${NC}"
    else
        echo -e "  ${GRAY}wifi${NC}    - WiFi management ${DIM}(unavailable: no WiFi adapter)${NC}"
    fi

    echo -e "  ${BOLD}custom${NC}  - Custom configuration\n"
    
    # Selection
    local selected_mode=""
    while [ -z "$selected_mode" ]; do
        echo -e "${CYAN}Select network mode (or 'recommend' for ${rec_mode}):${NC}"
        read -r -p "> " choice

        case "$choice" in
            nat|bridge|custom)
                selected_mode="$choice"
                ;;
            sriov)
                if is_feature_available "iommu" 2>/dev/null; then
                    selected_mode="$choice"
                else
                    echo -e "${RED}✗${NC} SR-IOV unavailable: $(get_unavailable_reason "iommu" 2>/dev/null || echo "IOMMU not supported")"
                    echo -e "${YELLOW}→${NC} Try ${BOLD}bridge${NC} mode for high-performance networking without SR-IOV"
                fi
                ;;
            wifi)
                if is_feature_available "wifi_config" 2>/dev/null; then
                    selected_mode="$choice"
                else
                    echo -e "${RED}✗${NC} WiFi unavailable: No WiFi adapter detected on this system"
                    echo -e "${YELLOW}→${NC} WiFi management requires a WiFi adapter"
                fi
                ;;
            recommend|rec)
                selected_mode="${rec_mode//_recommended/}"
                echo -e "${GREEN}✓${NC} Using recommended: ${BOLD}${selected_mode}${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                ;;
        esac
    done
    
    # Configure
    echo ""
    echo -e "${YELLOW}Configuring ${selected_mode} networking...${NC}\n"

    case "$selected_mode" in
        nat)
            educational_header "NAT Configuration"

            explain_what "Setting up NAT Network" \
                "Creating an isolated virtual network with internet access"

            echo -e "${GREEN}✓${NC} NAT configuration:"
            echo -e "  • Bridge: virbr0 (libvirt default)"
            echo -e "  • Subnet: 192.168.122.0/24"
            echo -e "  • DHCP: Enabled"
            echo -e "  • Security: Isolated from host network"
            echo ""

            real_world_scenario "Home Lab Setup" \
                "NAT mode is perfect for running test VMs at home without affecting your home network. VMs can access the internet but are isolated from other devices."

            track_learning_milestone "networking" "configured-nat-network"
            ;;
        bridge)
            educational_header "Bridge Configuration"

            explain_what "Setting up Bridge Network" \
                "Creating a software bridge to connect VMs to your physical network"

            warn_common_mistake "Bridging the wrong interface" \
                "If you bridge your only network connection incorrectly, you may lose network access" \
                "Choose the interface you want VMs to use. If uncertain, choose NAT mode instead"

            # Get physical interface
            echo -e "${CYAN}Select physical interface for bridge:${NC}"
            local iface_list=($(detect_network_interfaces))
            select iface in "${iface_list[@]}"; do
                if [ -n "$iface" ]; then
                    echo -e "${GREEN}✓${NC} Will create br0 bridging $iface"
                    echo -e "  • Bridge: br0"
                    echo -e "  • Physical: $iface"
                    echo -e "  • Mode: Bridge to physical network"
                    echo ""

                    explain_command "brctl addbr br0 && brctl addif br0 $iface" \
                        "brctl addbr br0 - Creates a new bridge named 'br0'" \
                        "brctl addif br0 $iface - Attaches physical interface $iface to the bridge" \
                        "(NixOS handles this automatically in configuration)"

                    track_learning_milestone "networking" "configured-bridge-network"
                    break
                fi
            done
            ;;
        custom)
            echo -e "${YELLOW}Custom configuration selected${NC}"
            echo -e "Edit: /etc/nixos/network-config.nix"

            link_to_docs "network configuration" "/usr/share/doc/hypervisor/NETWORKING.md"
            ;;
    esac
    
    # Save configuration
    local config_file="/etc/hypervisor/network-config.json"
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" << EOF
{
  "mode": "${selected_mode}",
  "configured_at": "$(date -Iseconds)",
  "detection": {
    "interfaces": $interfaces,
    "has_bridge": $has_bridge,
    "has_vlan": $has_vlan
  }
}
EOF
    
    echo ""
    echo -e "${GREEN}✓${NC} Network configuration saved"
    echo -e "${GREEN}✓${NC} Apply with: ${BOLD}nixos-rebuild switch${NC}"
    echo ""

    learning_checkpoint "Network Configuration Completed" \
        "• Network topology detection
• Understanding NAT vs Bridge networking
• Selecting appropriate network mode
• Configuring virtual network infrastructure
• Linux networking skills applicable to any distribution"

    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "1. Run: ${BOLD}sudo nixos-rebuild switch${NC}"
    echo -e "2. Create a VM: ${BOLD}hv vm-create${NC}"
    echo -e "3. Test network connectivity from the VM"
    echo ""
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
