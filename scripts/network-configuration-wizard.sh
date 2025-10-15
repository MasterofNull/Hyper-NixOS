#!/usr/bin/env bash
# Hyper-NixOS Network Configuration Wizard
# Intelligent defaults based on detected network topology
# Part of Design Ethos - Third Pillar: Learning Through Guidance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/system_discovery.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/logging.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/error_handling.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/config_backup.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/dry_run.sh" 2>/dev/null || true

setup_error_trap "network-configuration-wizard.sh"
parse_dry_run_arg "$@"

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
    
    # Show reasoning
    cat << EOF
${YELLOW}Why this recommendation?${NC}

EOF
    
    case "$rec_mode" in
        bridge)
            echo -e "  • Multiple interfaces and existing bridge detected"
            echo -e "  • Bridge mode provides best performance for VMs"
            echo -e "  • Direct network access for VM services"
            ;;
        bridge_recommended)
            echo -e "  • Multiple interfaces available"
            echo -e "  • Bridge mode recommended for better performance"
            echo -e "  • Can create bridge for VM networking"
            ;;
        nat)
            echo -e "  • Single interface or simple topology"
            echo -e "  • NAT provides security isolation"
            echo -e "  • Suitable for development/testing"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Configuration Options:${NC}\n"
    echo -e "  ${BOLD}nat${NC}     - NAT networking (secure, isolated)"
    echo -e "  ${BOLD}bridge${NC}  - Bridge networking (performance, direct access)"
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
            echo -e "${GREEN}✓${NC} NAT configuration:"
            echo -e "  • Bridge: virbr0 (libvirt default)"
            echo -e "  • Subnet: 192.168.122.0/24"
            echo -e "  • DHCP: Enabled"
            echo -e "  • Security: Isolated from host network"
            ;;
        bridge)
            # Get physical interface
            echo -e "${CYAN}Select physical interface for bridge:${NC}"
            local iface_list=($(detect_network_interfaces))
            select iface in "${iface_list[@]}"; do
                if [ -n "$iface" ]; then
                    echo -e "${GREEN}✓${NC} Will create br0 bridging $iface"
                    echo -e "  • Bridge: br0"
                    echo -e "  • Physical: $iface"
                    echo -e "  • Mode: Bridge to physical network"
                    break
                fi
            done
            ;;
        custom)
            echo -e "${YELLOW}Custom configuration selected${NC}"
            echo -e "Edit: /etc/nixos/network-config.nix"
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
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
