#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Network Discovery Library
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Comprehensive network scanning and discovery utilities
# For intelligent recommendations in network configuration wizards

set -euo pipefail

# Source common library if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/common.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Cache directory for discovery results
readonly DISCOVERY_CACHE="/var/lib/hypervisor/network-discovery"
mkdir -p "$DISCOVERY_CACHE" 2>/dev/null || true

# ============================================================================
# Network Interface Discovery
# ============================================================================

# Get all physical network interfaces (excluding virtual and lo)
get_physical_interfaces() {
    ip -o link show | \
        awk -F': ' '{print $2}' | \
        grep -v '^lo$' | \
        grep -v '^vir' | \
        grep -v '^br-' | \
        grep -v '^docker' | \
        grep -v '^veth' | \
        grep -v '@' || true
}

# Get wireless interfaces
get_wireless_interfaces() {
    if command -v iw >/dev/null 2>&1; then
        iw dev | awk '/Interface/ {print $2}' || true
    else
        # Fallback: check for common wireless interface names
        ip -o link show | awk -F': ' '{print $2}' | grep -E '^(wlan|wlp)' || true
    fi
}

# Get interface details
get_interface_info() {
    local interface="$1"
    local info_file="${DISCOVERY_CACHE}/${interface}_info.json"
    
    # Get MAC address
    local mac=$(ip link show "$interface" 2>/dev/null | grep link/ether | awk '{print $2}' || echo "unknown")
    
    # Get IP addresses
    local ipv4=$(ip -4 addr show "$interface" 2>/dev/null | grep inet | awk '{print $2}' | head -1 || echo "none")
    local ipv6=$(ip -6 addr show "$interface" 2>/dev/null | grep inet6 | grep -v fe80 | awk '{print $2}' | head -1 || echo "none")
    
    # Get link state
    local state=$(ip link show "$interface" 2>/dev/null | grep -o 'state [A-Z]*' | awk '{print $2}' || echo "UNKNOWN")
    
    # Get speed if available
    local speed="unknown"
    if command -v ethtool >/dev/null 2>&1; then
        speed=$(ethtool "$interface" 2>/dev/null | grep Speed | awk '{print $2}' || echo "unknown")
    fi
    
    # Get MTU
    local mtu=$(ip link show "$interface" 2>/dev/null | grep -o 'mtu [0-9]*' | awk '{print $2}' || echo "1500")
    
    # Check if wireless
    local wireless="false"
    if echo "$interface" | grep -qE '^(wlan|wlp)' || iw dev "$interface" info >/dev/null 2>&1; then
        wireless="true"
    fi
    
    # Create JSON output
    cat > "$info_file" <<EOF
{
  "interface": "$interface",
  "mac": "$mac",
  "ipv4": "$ipv4",
  "ipv6": "$ipv6",
  "state": "$state",
  "speed": "$speed",
  "mtu": $mtu,
  "wireless": $wireless
}
EOF
    
    echo "$info_file"
}

# ============================================================================
# Network Range Discovery
# ============================================================================

# Detect network range from interface
detect_network_range() {
    local interface="$1"
    
    # Get IP and netmask
    local ip_cidr=$(ip -4 addr show "$interface" 2>/dev/null | grep inet | awk '{print $2}' | head -1)
    
    if [ -z "$ip_cidr" ] || [ "$ip_cidr" = "none" ]; then
        echo ""
        return 1
    fi
    
    # Extract network address
    local network=$(ipcalc -n "$ip_cidr" 2>/dev/null | cut -d= -f2)
    local prefix=$(echo "$ip_cidr" | cut -d/ -f2)
    
    echo "${network}/${prefix}"
}

# Calculate usable IP range
get_usable_ip_range() {
    local cidr="$1"
    
    if ! command -v ipcalc >/dev/null 2>&1; then
        echo "ipcalc not available"
        return 1
    fi
    
    local first=$(ipcalc -n "$cidr" 2>/dev/null | grep HostMin | awk '{print $2}')
    local last=$(ipcalc -n "$cidr" 2>/dev/null | grep HostMax | awk '{print $2}')
    
    echo "${first}-${last}"
}

# ============================================================================
# Active Host Discovery
# ============================================================================

# Scan for active hosts on network (fast ping sweep)
scan_active_hosts() {
    local interface="$1"
    local timeout="${2:-2}"
    local cache_file="${DISCOVERY_CACHE}/${interface}_active_hosts.txt"
    
    local network_range=$(detect_network_range "$interface")
    
    if [ -z "$network_range" ]; then
        echo "Error: Could not detect network range for $interface" >&2
        return 1
    fi
    
    echo "Scanning for active hosts on $network_range..." >&2
    
    # Use nmap if available (faster)
    if command -v nmap >/dev/null 2>&1; then
        nmap -sn -T4 --max-retries 1 "$network_range" 2>/dev/null | \
            grep "Nmap scan report" | \
            awk '{print $NF}' | \
            tr -d '()' > "$cache_file"
    else
        # Fallback to ping sweep
        local network=$(echo "$network_range" | cut -d/ -f1 | cut -d. -f1-3)
        local prefix=$(echo "$network_range" | cut -d/ -f2)
        
        > "$cache_file"
        
        # Determine host range based on prefix
        local start=1
        local end=254
        
        if [ "$prefix" -gt 24 ]; then
            end=$((2 ** (32 - prefix) - 2))
        fi
        
        for i in $(seq $start $end); do
            local ip="${network}.${i}"
            if ping -c 1 -W "$timeout" "$ip" >/dev/null 2>&1; then
                echo "$ip" >> "$cache_file"
            fi
        done
    fi
    
    cat "$cache_file"
}

# Scan for used IPs (to avoid conflicts)
get_used_ips() {
    local interface="$1"
    scan_active_hosts "$interface" 1
}

# Recommend safe IP addresses
recommend_safe_ips() {
    local interface="$1"
    local count="${2:-3}"
    
    local network_range=$(detect_network_range "$interface")
    local used_ips=$(get_used_ips "$interface")
    
    if [ -z "$network_range" ]; then
        echo "Error: Could not detect network range" >&2
        return 1
    fi
    
    local network=$(echo "$network_range" | cut -d/ -f1 | cut -d. -f1-3)
    local prefix=$(echo "$network_range" | cut -d/ -f2)
    
    # Start from .100 to avoid common DHCP ranges
    local recommended=()
    local start=100
    local end=250
    
    for i in $(seq $start $end); do
        local ip="${network}.${i}"
        
        # Check if IP is not in use
        if ! echo "$used_ips" | grep -q "^${ip}$"; then
            recommended+=("$ip")
            
            if [ ${#recommended[@]} -ge "$count" ]; then
                break
            fi
        fi
    done
    
    printf '%s\n' "${recommended[@]}"
}

# ============================================================================
# Gateway and Router Discovery
# ============================================================================

# Detect default gateway
detect_gateway() {
    local interface="${1:-}"
    
    if [ -n "$interface" ]; then
        ip route show dev "$interface" 2>/dev/null | grep default | awk '{print $3}' | head -1
    else
        ip route show default 2>/dev/null | awk '{print $3}' | head -1
    fi
}

# Detect DNS servers
detect_dns_servers() {
    if [ -f /etc/resolv.conf ]; then
        grep '^nameserver' /etc/resolv.conf | awk '{print $2}'
    fi
}

# Scan gateway for services
scan_gateway_services() {
    local gateway="$1"
    
    if ! command -v nmap >/dev/null 2>&1; then
        echo "nmap not available for service scanning" >&2
        return 1
    fi
    
    echo "Scanning gateway $gateway for services..." >&2
    
    nmap -sT -Pn --top-ports 20 "$gateway" 2>/dev/null | \
        grep '^[0-9]' | \
        grep open
}

# ============================================================================
# DHCP Server Detection
# ============================================================================

# Detect DHCP server
detect_dhcp_server() {
    local interface="$1"
    local cache_file="${DISCOVERY_CACHE}/${interface}_dhcp.txt"
    
    echo "Detecting DHCP server on $interface..." >&2
    
    # Try to get DHCP lease info
    if [ -d /var/lib/dhcp ]; then
        local lease_file="/var/lib/dhcp/dhclient.${interface}.leases"
        if [ -f "$lease_file" ]; then
            grep "dhcp-server-identifier" "$lease_file" | tail -1 | awk '{print $3}' | tr -d ';'
            return 0
        fi
    fi
    
    # Try systemd-networkd
    if command -v networkctl >/dev/null 2>&1; then
        networkctl status "$interface" 2>/dev/null | grep "Gateway" | awk '{print $2}'
        return 0
    fi
    
    # Fallback: assume gateway is DHCP server
    detect_gateway "$interface"
}

# ============================================================================
# VLAN Discovery
# ============================================================================

# Detect existing VLANs
detect_vlans() {
    local interface="${1:-}"
    
    if [ -n "$interface" ]; then
        ip -d link show | grep -A 5 "$interface\." | grep vlan | awk '{print $3}' | cut -d. -f2
    else
        ip -d link show | grep 'vlan protocol' | awk '{print $2}' | cut -d@ -f1 | cut -d. -f2 | sort -u
    fi
}

# Recommend VLAN IDs (unused)
recommend_vlan_ids() {
    local count="${1:-3}"
    local existing_vlans=($(detect_vlans))
    
    local recommended=()
    
    # Common VLAN ranges: 10-99 (user), 100-199 (servers), 200-299 (guests)
    for vlan in 10 20 30 100 110 120 200 210 220; do
        if ! echo "${existing_vlans[@]}" | grep -qw "$vlan"; then
            recommended+=("$vlan")
            
            if [ ${#recommended[@]} -ge "$count" ]; then
                break
            fi
        fi
    done
    
    printf '%s\n' "${recommended[@]}"
}

# ============================================================================
# MAC Vendor Lookup
# ============================================================================

# Lookup MAC vendor (using OUI database)
lookup_mac_vendor() {
    local mac="$1"
    local oui=$(echo "$mac" | cut -d: -f1-3 | tr '[:lower:]' '[:upper:]' | tr -d ':')
    
    # Use online lookup if available
    if command -v curl >/dev/null 2>&1; then
        local vendor=$(curl -s "https://api.macvendors.com/${mac}" 2>/dev/null)
        if [ -n "$vendor" ] && [ "$vendor" != "Not Found" ]; then
            echo "$vendor"
            return 0
        fi
    fi
    
    # Fallback: common vendors
    case "${oui:0:6}" in
        "00155D"|"000C29"|"005056") echo "VMware" ;;
        "080027") echo "VirtualBox" ;;
        "525400") echo "QEMU/KVM" ;;
        "0003FF") echo "Microsoft" ;;
        *) echo "Unknown" ;;
    esac
}

# Get safe vendor prefixes for MAC spoofing
get_common_vendor_prefixes() {
    cat <<EOF
00:1A:2B:Intel Corporation
00:50:56:VMware
08:00:27:VirtualBox
52:54:00:QEMU/KVM
00:0C:29:VMware
B8:27:EB:Raspberry Pi
DC:A6:32:Raspberry Pi
E4:5F:01:Raspberry Pi
00:16:3E:Xen
00:15:5D:Microsoft
EOF
}

# ============================================================================
# Network Speed and Performance
# ============================================================================

# Test network speed to gateway
test_network_speed() {
    local interface="$1"
    local gateway=$(detect_gateway "$interface")
    
    if [ -z "$gateway" ]; then
        echo "No gateway detected" >&2
        return 1
    fi
    
    echo "Testing network latency to $gateway..." >&2
    
    # Ping test
    local avg_latency=$(ping -c 10 -W 2 "$gateway" 2>/dev/null | \
        grep 'avg' | \
        awk -F'/' '{print $5}' || echo "N/A")
    
    echo "Average latency: ${avg_latency}ms"
}

# Detect network bandwidth
detect_bandwidth() {
    local interface="$1"
    
    if command -v ethtool >/dev/null 2>&1; then
        ethtool "$interface" 2>/dev/null | grep Speed | awk '{print $2}'
    else
        echo "Unknown"
    fi
}

# ============================================================================
# Wireless Network Discovery
# ============================================================================

# Scan for wireless networks
scan_wireless_networks() {
    local interface="$1"
    
    if ! command -v iw >/dev/null 2>&1; then
        echo "iw not available for wireless scanning" >&2
        return 1
    fi
    
    echo "Scanning for wireless networks on $interface..." >&2
    
    # Require root for scanning
    if [ "$EUID" -ne 0 ]; then
        echo "Wireless scanning requires root privileges" >&2
        return 1
    fi
    
    iw dev "$interface" scan 2>/dev/null | \
        awk '/^BSS / {mac=$2} /SSID:/ {ssid=$2} /signal:/ {signal=$2; print ssid, signal, mac}'
}

# ============================================================================
# ARP Cache Analysis
# ============================================================================

# Get ARP cache
get_arp_cache() {
    ip neigh show | grep -v FAILED | awk '{print $1, $5}'
}

# Detect potential ARP conflicts
detect_arp_conflicts() {
    local mac="$1"
    
    if [ -n "$mac" ]; then
        ip neigh show | grep -i "$mac" | awk '{print $1}'
    else
        # Show duplicate MACs
        ip neigh show | awk '{print $5}' | sort | uniq -d
    fi
}

# ============================================================================
# Network Discovery Summary
# ============================================================================

# Comprehensive network discovery
discover_network() {
    local interface="$1"
    local output_file="${DISCOVERY_CACHE}/${interface}_discovery.json"
    
    echo "Performing comprehensive network discovery on $interface..." >&2
    echo >&2
    
    # Get basic info
    local mac=$(ip link show "$interface" 2>/dev/null | grep link/ether | awk '{print $2}' || echo "unknown")
    local ipv4=$(ip -4 addr show "$interface" 2>/dev/null | grep inet | awk '{print $2}' | head -1 || echo "none")
    local network_range=$(detect_network_range "$interface" || echo "none")
    local gateway=$(detect_gateway "$interface" || echo "none")
    local dns_servers=$(detect_dns_servers | tr '\n' ',' | sed 's/,$//')
    local dhcp_server=$(detect_dhcp_server "$interface" || echo "none")
    
    # Scan network
    local active_hosts=$(scan_active_hosts "$interface" 2 2>/dev/null | wc -l || echo "0")
    local recommended_ips=$(recommend_safe_ips "$interface" 3 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "none")
    
    # Performance
    local bandwidth=$(detect_bandwidth "$interface" || echo "unknown")
    
    # Create summary JSON
    cat > "$output_file" <<EOF
{
  "interface": "$interface",
  "mac": "$mac",
  "ipv4": "$ipv4",
  "network_range": "$network_range",
  "gateway": "$gateway",
  "dns_servers": "$dns_servers",
  "dhcp_server": "$dhcp_server",
  "active_hosts": $active_hosts,
  "recommended_ips": "$recommended_ips",
  "bandwidth": "$bandwidth",
  "scan_time": "$(date -Iseconds)"
}
EOF
    
    # Display summary
    echo -e "${GREEN}Network Discovery Summary:${NC}" >&2
    echo -e "  Interface:       $interface" >&2
    echo -e "  MAC Address:     $mac" >&2
    echo -e "  IP Address:      $ipv4" >&2
    echo -e "  Network Range:   $network_range" >&2
    echo -e "  Gateway:         $gateway" >&2
    echo -e "  DNS Servers:     $dns_servers" >&2
    echo -e "  DHCP Server:     $dhcp_server" >&2
    echo -e "  Active Hosts:    $active_hosts" >&2
    echo -e "  Bandwidth:       $bandwidth" >&2
    echo >&2
    
    cat "$output_file"
}

# Export functions
export -f get_physical_interfaces
export -f get_wireless_interfaces
export -f get_interface_info
export -f detect_network_range
export -f get_usable_ip_range
export -f scan_active_hosts
export -f get_used_ips
export -f recommend_safe_ips
export -f detect_gateway
export -f detect_dns_servers
export -f detect_dhcp_server
export -f detect_vlans
export -f recommend_vlan_ids
export -f lookup_mac_vendor
export -f get_common_vendor_prefixes
export -f test_network_speed
export -f detect_bandwidth
export -f scan_wireless_networks
export -f get_arp_cache
export -f detect_arp_conflicts
export -f discover_network
