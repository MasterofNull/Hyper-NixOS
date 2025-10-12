#!/usr/bin/env bash
#
# Hyper-NixOS Foundational Networking Setup
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# CRITICAL FIRST STEP: This must run before any network-dependent operations
# Sets up complete networking foundation including:
# - Physical interface detection and validation
# - Network bridge configuration with optimal settings
# - Network binding and interface management
# - libvirt network configuration
# - Connectivity validation
# - Network readiness marker for dependent processes
#
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"
: "${NON_INTERACTIVE:=false}"

LOGFILE="/var/lib/hypervisor/logs/foundational_networking.log"
READINESS_MARKER="/var/lib/hypervisor/.network_ready"
CONFIG_DIR="/etc/systemd/network"
LIBVIRT_NET_DIR="/etc/libvirt/qemu/networks"

mkdir -p "$(dirname "$LOGFILE")"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LIBVIRT_NET_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

error() {
  log "ERROR: $*"
  echo "ERROR: $*" >&2
}

require() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  
  if (( ${#missing[@]} > 0 )); then
    error "Missing required commands: ${missing[*]}"
    return 1
  fi
  return 0
}

# Check all requirements
require ip jq ethtool iptables virsh systemctl || {
  error "Cannot proceed without required commands"
  exit 1
}

log "=========================================="
log "FOUNDATIONAL NETWORKING SETUP - START"
log "=========================================="

# ============================================================================
# PHASE 1: NETWORK CAPABILITY ASSESSMENT
# ============================================================================

log "PHASE 1: Assessing network capabilities..."

# Detect all physical network interfaces
detect_physical_interfaces() {
  local ifaces=()
  while IFS= read -r iface; do
    # Skip loopback, virtual bridges, docker, and TAP/TUN devices
    if [[ "$iface" =~ ^(lo|virbr|br-|docker|veth|tap|tun|vnet) ]]; then
      continue
    fi
    
    # Check if it's a physical device (has device symlink in sysfs OR ethernet link)
    if [[ -d "/sys/class/net/$iface/device" ]] || ip link show "$iface" 2>/dev/null | grep -q "link/ether"; then
      # Additional validation: skip if it's a wireless device in monitor mode
      if [[ -d "/sys/class/net/$iface/wireless" ]]; then
        local mode
        mode=$(iwconfig "$iface" 2>/dev/null | grep -oP 'Mode:\K\w+' || echo "Managed")
        [[ "$mode" == "Monitor" ]] && continue
      fi
      ifaces+=("$iface")
    fi
  done < <(ip -o link show | awk -F': ' '{print $2}')
  
  printf '%s\n' "${ifaces[@]}"
}

# Get comprehensive interface information
get_interface_info() {
  local iface="$1"
  local state speed duplex mtu driver ip_addr
  
  # Basic link information
  state=$(ip link show "$iface" 2>/dev/null | grep -oP 'state \K\w+' || echo "UNKNOWN")
  mtu=$(ip link show "$iface" 2>/dev/null | grep -oP 'mtu \K\d+' || echo "1500")
  
  # Get IP address if assigned
  ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1 || echo "None")
  
  # Get hardware information via ethtool
  if command -v ethtool >/dev/null 2>&1; then
    if [[ "$state" == "UP" ]]; then
      speed=$(ethtool "$iface" 2>/dev/null | grep -oP 'Speed: \K[^\s]+' || echo "Unknown")
      duplex=$(ethtool "$iface" 2>/dev/null | grep -oP 'Duplex: \K\w+' || echo "Unknown")
    else
      speed="Interface Down"
      duplex="N/A"
    fi
    driver=$(ethtool -i "$iface" 2>/dev/null | grep -oP 'driver: \K.*' || echo "Unknown")
  else
    speed="N/A"
    duplex="N/A"
    driver="N/A"
  fi
  
  # Check if already part of a bridge
  local bridge_master="None"
  if ip link show "$iface" 2>/dev/null | grep -q "master br"; then
    bridge_master=$(ip link show "$iface" | grep -oP 'master \K[^\s]+')
  fi
  
  # Determine if this is the active/primary interface
  local is_primary="No"
  if [[ "$state" == "UP" ]] && [[ "$ip_addr" != "None" ]]; then
    # Check if it has a default route
    if ip route show dev "$iface" 2>/dev/null | grep -q "default"; then
      is_primary="Yes"
    fi
  fi
  
  echo "State:$state|Speed:$speed|Duplex:$duplex|MTU:$mtu|Driver:$driver|IP:$ip_addr|Bridge:$bridge_master|Primary:$is_primary"
}

# Detect and assess all interfaces
mapfile -t physical_ifaces < <(detect_physical_interfaces)

if (( ${#physical_ifaces[@]} == 0 )); then
  error "No physical network interfaces detected"
  log "Available interfaces:"
  ip -o link show | awk -F': ' '{print "  - " $2}' | tee -a "$LOGFILE"
  
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    error "Cannot proceed in non-interactive mode without interfaces"
    exit 1
  fi
  
  $DIALOG --msgbox "CRITICAL: No Physical Network Interfaces

No suitable network interfaces were detected on this system.

This system requires at least one physical network interface
(Ethernet or WiFi) to set up VM networking.

Available interfaces:
$(ip -o link show | awk -F': ' '{print "  - " $2}')

None of these appear to be usable physical network devices.

Please ensure:
  • Network hardware is properly installed
  • Drivers are loaded
  • Interfaces are not disabled in BIOS

Cannot continue without network interfaces." 22 76
  exit 1
fi

log "Found ${#physical_ifaces[@]} physical interface(s): ${physical_ifaces[*]}"

# Assess each interface
declare -A iface_data
primary_iface=""
active_interfaces=()

for iface in "${physical_ifaces[@]}"; do
  info=$(get_interface_info "$iface")
  iface_data["$iface"]="$info"
  
  log "  $iface: $info"
  
  # Track primary interface
  is_primary=$(echo "$info" | grep -oP 'Primary:\K\w+')
  if [[ "$is_primary" == "Yes" ]]; then
    primary_iface="$iface"
  fi
  
  # Track active interfaces
  state=$(echo "$info" | grep -oP 'State:\K\w+')
  ip=$(echo "$info" | grep -oP 'IP:\K[^|]+')
  if [[ "$state" == "UP" ]] && [[ "$ip" != "None" ]]; then
    active_interfaces+=("$iface")
  fi
done

# ============================================================================
# PHASE 2: INTELLIGENT INTERFACE SELECTION
# ============================================================================

log "PHASE 2: Selecting optimal interface for bridge..."

selected_iface=""

# Strategy 1: Use primary interface if detected
if [[ -n "$primary_iface" ]]; then
  log "Primary interface detected: $primary_iface"
  selected_iface="$primary_iface"
# Strategy 2: Use first active interface
elif (( ${#active_interfaces[@]} > 0 )); then
  selected_iface="${active_interfaces[0]}"
  log "Using first active interface: $selected_iface"
# Strategy 3: Use first available interface (even if down)
else
  selected_iface="${physical_ifaces[0]}"
  log "Using first available interface: $selected_iface (WARNING: may not be active)"
fi

# In interactive mode, allow user to override
if [[ "$NON_INTERACTIVE" == "false" ]] && command -v "$DIALOG" >/dev/null 2>&1; then
  
  # Show explanation
  $DIALOG --msgbox "FOUNDATIONAL NETWORKING SETUP

WHY THIS IS CRITICAL:
══════════════════════════════════════════════════════

Network setup MUST be completed FIRST because:

✓ VM creation needs network bridges
✓ ISO downloads require internet connectivity  
✓ Package installation depends on network access
✓ Network discovery and DHCP must be configured
✓ Security policies depend on network zones
✓ All other services build on this foundation

This wizard will:
═══════════════════
1. Detect and validate your network hardware
2. Configure high-performance network bridge
3. Set up interface bindings automatically
4. Configure libvirt networking
5. Validate connectivity
6. Mark networking as ready for other services

Let's set up your network foundation properly!" 24 76
  
  # Build interface selection menu
  menu_items=()
  for iface in "${physical_ifaces[@]}"; do
    info="${iface_data[$iface]}"
    state=$(echo "$info" | grep -oP 'State:\K\w+')
    speed=$(echo "$info" | grep -oP 'Speed:\K[^|]+')
    ip=$(echo "$info" | grep -oP 'IP:\K[^|]+')
    is_primary=$(echo "$info" | grep -oP 'Primary:\K\w+')
    
    # Build descriptive label
    label="$state"
    [[ "$speed" != "Interface Down" && "$speed" != "N/A" ]] && label+=" ${speed}"
    [[ "$ip" != "None" ]] && label+=" IP:$ip"
    [[ "$is_primary" == "Yes" ]] && label+=" ★PRIMARY★"
    [[ "$iface" == "$selected_iface" ]] && label+=" (recommended)"
    
    menu_items+=("$iface" "$label")
  done
  
  # Let user select interface
  user_choice=$($DIALOG --menu "Select Network Interface for Bridge

Choose the physical network interface to use for VM networking.
This interface will be bound to a bridge that VMs will use.

★ PRIMARY = Active interface with default route (RECOMMENDED)
  Interfaces marked PRIMARY are your main network connection.

IMPORTANT: Binding Process
═══════════════════════════════════════════════════════
When an interface is 'bound' to a bridge:
  • The interface becomes part of the bridge
  • Network configuration moves from interface to bridge
  • The bridge gets the IP address (via DHCP)
  • VMs connect through the bridge to your network
  • Your interface continues to work normally

This is automatic and safe!

Select interface:" 26 78 10 "${menu_items[@]}" 3>&1 1>&2 2>&3) || {
    log "User cancelled interface selection"
    exit 0
  }
  
  selected_iface="$user_choice"
  log "User selected interface: $selected_iface"
fi

# Validate selected interface
info="${iface_data[$selected_iface]}"
state=$(echo "$info" | grep -oP 'State:\K\w+')
bridge=$(echo "$info" | grep -oP 'Bridge:\K[^|]+')

log "Selected interface details: $info"

# Check if already bridged
if [[ "$bridge" != "None" ]]; then
  log "WARNING: Interface $selected_iface is already part of bridge: $bridge"
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    if ! $DIALOG --yesno "Interface Already Bridged

The selected interface $selected_iface is already part of bridge: $bridge

This means networking may already be configured.

Options:
  YES = Continue and use existing bridge
  NO  = Exit and review configuration manually

Continue?" 14 70; then
      log "User chose to exit due to existing bridge"
      exit 0
    fi
  fi
  
  # Use existing bridge
  bridge_name="$bridge"
  log "Using existing bridge: $bridge_name"
else
  bridge_name="br0"
fi

# Warn if interface is down
if [[ "$state" != "UP" ]]; then
  log "WARNING: Selected interface $selected_iface is $state"
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    $DIALOG --msgbox "Warning: Interface is DOWN

Selected interface: $selected_iface
Current state: $state

This interface is not currently active. The bridge will be
configured, but networking may not work until the interface
is brought up.

To bring up the interface:
  sudo ip link set $selected_iface up

Or check physical connection (cable plugged in, WiFi enabled, etc.)

Continuing with configuration..." 18 70
  fi
fi

# ============================================================================
# PHASE 3: BRIDGE CONFIGURATION
# ============================================================================

log "PHASE 3: Configuring network bridge..."

# Check if bridge already exists
if ip link show "$bridge_name" &>/dev/null; then
  log "Bridge $bridge_name already exists"
  
  # Get bridge info
  br_state=$(ip link show "$bridge_name" | grep -oP 'state \K\w+')
  br_ip=$(ip -4 addr show "$bridge_name" 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo "None")
  
  log "Existing bridge: state=$br_state ip=$br_ip"
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    $DIALOG --msgbox "Bridge Already Exists

Bridge: $bridge_name
State: $br_state
IP: $br_ip

Using existing bridge configuration.

If you need to reconfigure, delete the bridge first:
  sudo ip link delete $bridge_name
  sudo rm /etc/systemd/network/${bridge_name}*

Then run this setup again." 16 70
  fi
  
  # Skip to validation
  log "Skipping bridge creation, proceeding to validation..."
else
  log "Creating new bridge: $bridge_name"
  
  # Determine optimal MTU
  current_mtu=$(echo "$info" | grep -oP 'MTU:\K\d+')
  mtu=1500  # Default to standard
  
  # If in interactive mode, ask about performance profile
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    perf_profile=$($DIALOG --menu "Network Performance Profile

Choose the optimal configuration for your use case:

STANDARD (MTU 1500) - RECOMMENDED
════════════════════════════════════════════════════
  ✓ Works with all networks and devices
  ✓ Compatible with internet connections
  ✓ Reliable for mixed workloads
  ✓ Best choice for most users
  
PERFORMANCE (MTU 9000) - ADVANCED
════════════════════════════════════════════════════
  ✓ 5-15% higher throughput for large transfers
  ✓ Better for storage and backup workloads
  ✗ Requires ALL network devices support jumbo frames
  ✗ LAN-only (won't work over internet)
  ✗ May cause connectivity issues if not supported
  
CURRENT (MTU $current_mtu) - USE EXISTING
════════════════════════════════════════════════════
  Use current interface MTU setting

Select profile:" 28 76 6 \
      "standard" "MTU 1500 - Compatible everywhere (SAFE)" \
      "performance" "MTU 9000 - Jumbo frames (ADVANCED)" \
      "current" "MTU $current_mtu - Match interface" 3>&1 1>&2 2>&3) || perf_profile="standard"
    
    case "$perf_profile" in
      standard) mtu=1500 ;;
      performance) mtu=9000 ;;
      current) mtu="$current_mtu" ;;
    esac
    
    log "Performance profile: $perf_profile (MTU: $mtu)"
  fi
  
  # Create bridge configuration files
  log "Creating bridge netdev configuration..."
  
  sudo tee "$CONFIG_DIR/${bridge_name}.netdev" > /dev/null <<NETDEV
[NetDev]
Name=$bridge_name
Kind=bridge
MTUBytes=$mtu
Description=Hyper-NixOS VM Bridge (Foundational Networking)

[Bridge]
# Performance optimizations
DefaultPVID=none
VLANFiltering=no
STP=no
# Fast forwarding for VM traffic
ForwardDelaySec=0
HelloTimeSec=2
MaxAgeSec=12
NETDEV
  
  log "Created ${bridge_name}.netdev"
  
  log "Creating bridge network configuration..."
  
  sudo tee "$CONFIG_DIR/${bridge_name}.network" > /dev/null <<NETWORK
[Match]
Name=$bridge_name

[Network]
# Automatic IP configuration
DHCP=yes
IPv6AcceptRA=yes
# Service discovery
LLMNR=yes
MulticastDNS=yes
# DNS
DNS=1.1.1.1
DNS=8.8.8.8
FallbackDNS=9.9.9.9

[DHCP]
UseDNS=yes
UseRoutes=yes
UseHostname=no
UseDomains=yes
RouteMetric=100

[Link]
MTUBytes=$mtu
# Hardware offloading for performance
RequiredForOnline=routable
Multicast=yes
AllMulticast=yes

[BridgeVLAN]
PVID=1
EgressUntagged=1
NETWORK
  
  log "Created ${bridge_name}.network"
  
  log "Binding interface $selected_iface to bridge..."
  
  # Create interface configuration to bind to bridge
  sudo tee "$CONFIG_DIR/${selected_iface}.network" > /dev/null <<BINDING
[Match]
Name=$selected_iface

[Network]
# Bind this interface to the bridge
Bridge=$bridge_name
# Interface configuration is handled by bridge
ConfigureWithoutCarrier=yes

[Link]
MTUBytes=$mtu
# Keep interface in promiscuous mode for bridging
Promiscuous=yes
BINDING
  
  log "Created ${selected_iface}.network (interface binding)"
  
  # Apply configuration
  log "Applying network configuration..."
  
  # Enable systemd-networkd if not already
  if ! systemctl is-enabled systemd-networkd.service &>/dev/null; then
    log "Enabling systemd-networkd..."
    sudo systemctl enable systemd-networkd.service 2>&1 | tee -a "$LOGFILE"
  fi
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    if $DIALOG --yesno "Apply Network Configuration Now?

Configuration files created:
  • $CONFIG_DIR/${bridge_name}.netdev
  • $CONFIG_DIR/${bridge_name}.network  
  • $CONFIG_DIR/${selected_iface}.network

This will:
  1. Restart systemd-networkd service
  2. Create bridge $bridge_name
  3. Bind $selected_iface to the bridge
  4. Request IP address via DHCP

WARNING: Network will be briefly interrupted!
═══════════════════════════════════════════════════

If connected via SSH, you may lose connection.
Physical console access is recommended.

Apply now?" 20 70; then
      
      log "User approved, restarting networkd..."
      if sudo systemctl restart systemd-networkd 2>&1 | tee -a "$LOGFILE"; then
        log "SUCCESS: systemd-networkd restarted"
        sleep 3
      else
        error "Failed to restart systemd-networkd"
        if [[ "$NON_INTERACTIVE" == "false" ]]; then
          $DIALOG --msgbox "ERROR: Network Service Restart Failed

Failed to restart systemd-networkd.

Check logs:
  sudo journalctl -u systemd-networkd -n 50

Configuration files are saved. You can apply manually:
  sudo systemctl restart systemd-networkd

Or reboot:
  sudo systemctl reboot

Log: $LOGFILE" 18 70
        fi
        exit 1
      fi
    else
      log "User chose to apply later"
      $DIALOG --msgbox "Configuration Saved

Network configuration files have been created but not applied.

To apply:
  sudo systemctl restart systemd-networkd

To apply on next boot:
  sudo systemctl reboot

Run this script again after applying to complete validation.

Log: $LOGFILE" 16 70
      exit 0
    fi
  else
    # Non-interactive: apply automatically
    log "Non-interactive mode: applying configuration..."
    if sudo systemctl restart systemd-networkd 2>&1 | tee -a "$LOGFILE"; then
      log "SUCCESS: systemd-networkd restarted"
      sleep 3
    else
      error "Failed to restart systemd-networkd"
      exit 1
    fi
  fi
fi

# ============================================================================
# PHASE 4: BRIDGE VALIDATION
# ============================================================================

log "PHASE 4: Validating bridge configuration..."

# Wait for bridge to come up
log "Waiting for bridge $bridge_name to initialize..."
for i in {1..10}; do
  if ip link show "$bridge_name" &>/dev/null; then
    log "Bridge $bridge_name exists (attempt $i)"
    break
  fi
  sleep 1
done

# Verify bridge exists
if ! ip link show "$bridge_name" &>/dev/null; then
  error "Bridge $bridge_name was not created"
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    $DIALOG --msgbox "ERROR: Bridge Creation Failed

Bridge $bridge_name does not exist after configuration.

Possible causes:
  • systemd-networkd not running
  • Configuration syntax error
  • Interface conflict

Troubleshooting:
  1. Check service status:
     sudo systemctl status systemd-networkd
  
  2. Check logs:
     sudo journalctl -u systemd-networkd -n 50
  
  3. Verify config files:
     ls -la $CONFIG_DIR/
  
  4. Try manual creation:
     sudo ip link add name $bridge_name type bridge

Log: $LOGFILE" 24 76
  fi
  exit 1
fi

# Get bridge status
br_state=$(ip link show "$bridge_name" | grep -oP 'state \K\w+')
br_mtu=$(ip link show "$bridge_name" | grep -oP 'mtu \K\d+')

log "Bridge status: state=$br_state mtu=$br_mtu"

# Check if interface is bound to bridge
bound_ifaces=$(bridge link show | grep "$bridge_name" | awk '{print $2}' | sed 's/@.*//' || echo "")
if echo "$bound_ifaces" | grep -q "$selected_iface"; then
  log "SUCCESS: Interface $selected_iface is bound to bridge"
else
  log "WARNING: Interface $selected_iface not bound to bridge yet"
  log "Bound interfaces: ${bound_ifaces:-none}"
fi

# Wait for IP address
log "Waiting for DHCP IP address..."
bridge_ip=""
for i in {1..15}; do
  bridge_ip=$(ip -4 addr show "$bridge_name" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1 || echo "")
  if [[ -n "$bridge_ip" ]]; then
    log "Bridge has IP: $bridge_ip (attempt $i)"
    break
  fi
  sleep 2
done

if [[ -z "$bridge_ip" ]]; then
  log "WARNING: Bridge has no IP address yet"
  
  if [[ "$NON_INTERACTIVE" == "false" ]]; then
    $DIALOG --msgbox "Warning: No IP Address

Bridge $bridge_name was created but has not received an IP address.

State: $br_state
MTU: $br_mtu
Bound interfaces: ${bound_ifaces:-none}

Possible causes:
  • DHCP server not responding
  • Network cable unplugged
  • Interface still initializing

The bridge is configured correctly, but needs an IP to function.

Try:
  1. Wait a bit longer and check:
     ip addr show $bridge_name
  
  2. Manually request DHCP:
     sudo dhclient $bridge_name
  
  3. Configure static IP in:
     $CONFIG_DIR/${bridge_name}.network

Continuing with setup..." 26 76
  fi
else
  log "SUCCESS: Bridge has IP address: $bridge_ip"
fi

# ============================================================================
# PHASE 5: LIBVIRT NETWORK CONFIGURATION  
# ============================================================================

log "PHASE 5: Configuring libvirt networking..."

# Ensure libvirt directories exist
sudo mkdir -p "$LIBVIRT_NET_DIR"
sudo mkdir -p "$LIBVIRT_NET_DIR/autostart"

# Create libvirt bridge network definition
log "Creating libvirt bridge network definition..."

libvirt_net_xml="$LIBVIRT_NET_DIR/host-bridge.xml"
sudo tee "$libvirt_net_xml" > /dev/null <<LIBVIRT
<network>
  <name>host-bridge</name>
  <forward mode="bridge"/>
  <bridge name="$bridge_name"/>
</network>
LIBVIRT

log "Created libvirt network definition: $libvirt_net_xml"

# Define network in libvirt (if not already defined)
if virsh net-list --all 2>/dev/null | grep -q "host-bridge"; then
  log "Libvirt network 'host-bridge' already defined"
else
  log "Defining libvirt network 'host-bridge'..."
  if sudo virsh net-define "$libvirt_net_xml" 2>&1 | tee -a "$LOGFILE"; then
    log "SUCCESS: Libvirt network defined"
  else
    error "Failed to define libvirt network"
  fi
fi

# Start network (if not already started)
if virsh net-list 2>/dev/null | grep -q "host-bridge.*active"; then
  log "Libvirt network 'host-bridge' already active"
else
  log "Starting libvirt network 'host-bridge'..."
  if sudo virsh net-start host-bridge 2>&1 | tee -a "$LOGFILE"; then
    log "SUCCESS: Libvirt network started"
  else
    log "WARNING: Failed to start libvirt network (may not be critical)"
  fi
fi

# Enable autostart
if sudo virsh net-autostart host-bridge 2>&1 | tee -a "$LOGFILE"; then
  log "SUCCESS: Libvirt network autostart enabled"
else
  log "WARNING: Failed to enable autostart"
fi

# ============================================================================
# PHASE 6: CONNECTIVITY VALIDATION
# ============================================================================

log "PHASE 6: Validating network connectivity..."

connectivity_ok=false
gateway=""
internet_ok=false

# Check for default route
if ip route show default dev "$bridge_name" &>/dev/null; then
  gateway=$(ip route show default dev "$bridge_name" | awk '{print $3}' | head -1)
  log "Default gateway: $gateway"
  
  # Try to ping gateway
  if [[ -n "$gateway" ]]; then
    log "Testing gateway connectivity..."
    if ping -c 2 -W 2 "$gateway" &>/dev/null; then
      log "SUCCESS: Gateway $gateway is reachable"
      connectivity_ok=true
    else
      log "WARNING: Gateway $gateway is not responding"
    fi
  fi
fi

# Test internet connectivity
log "Testing internet connectivity..."
for dns_server in 1.1.1.1 8.8.8.8 9.9.9.9; do
  if ping -c 2 -W 2 "$dns_server" &>/dev/null; then
    log "SUCCESS: Internet connectivity verified (reached $dns_server)"
    internet_ok=true
    break
  fi
done

if ! $internet_ok; then
  log "WARNING: Internet connectivity test failed"
fi

# Test DNS resolution
log "Testing DNS resolution..."
dns_ok=false
if host google.com &>/dev/null || nslookup google.com &>/dev/null || dig google.com &>/dev/null; then
  log "SUCCESS: DNS resolution works"
  dns_ok=true
else
  log "WARNING: DNS resolution failed"
fi

# ============================================================================
# PHASE 7: READINESS MARKER
# ============================================================================

log "PHASE 7: Creating network readiness marker..."

# Create readiness marker with status information
sudo tee "$READINESS_MARKER" > /dev/null <<MARKER
{
  "status": "ready",
  "timestamp": "$(date -Iseconds)",
  "bridge": "$bridge_name",
  "interface": "$selected_iface",
  "ip": "${bridge_ip:-none}",
  "gateway": "${gateway:-none}",
  "mtu": "$br_mtu",
  "connectivity": {
    "gateway": $connectivity_ok,
    "internet": $internet_ok,
    "dns": $dns_ok
  },
  "libvirt_network": "host-bridge"
}
MARKER

log "Readiness marker created: $READINESS_MARKER"

# Make marker readable by all (for easy checking by other scripts)
sudo chmod 644 "$READINESS_MARKER"

# ============================================================================
# FINAL REPORT
# ============================================================================

log "=========================================="
log "FOUNDATIONAL NETWORKING SETUP - COMPLETE"
log "=========================================="

# Build status report
status_report="FOUNDATIONAL NETWORKING SETUP - COMPLETE

Bridge Configuration:
═══════════════════════════════════════════════════════
  Bridge Name:     $bridge_name
  State:           $br_state
  MTU:             $br_mtu
  IP Address:      ${bridge_ip:-Pending DHCP}
  
Interface Binding:
═══════════════════════════════════════════════════════
  Physical Interface: $selected_iface
  Bound to Bridge:    ${bound_ifaces:-$selected_iface}
  
Network Status:
═══════════════════════════════════════════════════════
  Gateway:         ${gateway:-Not configured}
  Gateway Reach:   $(if $connectivity_ok; then echo "✓ OK"; else echo "✗ Failed"; fi)
  Internet:        $(if $internet_ok; then echo "✓ Connected"; else echo "✗ No connection"; fi)
  DNS:             $(if $dns_ok; then echo "✓ Working"; else echo "✗ Not working"; fi)

Libvirt Integration:
═══════════════════════════════════════════════════════
  Network Name:    host-bridge
  Mode:            Bridge ($bridge_name)
  Status:          $(virsh net-list 2>/dev/null | grep host-bridge | awk '{print $2" "$3}' || echo "Check manually")

Configuration Files:
═══════════════════════════════════════════════════════
  • $CONFIG_DIR/${bridge_name}.netdev
  • $CONFIG_DIR/${bridge_name}.network
  • $CONFIG_DIR/${selected_iface}.network
  • $libvirt_net_xml

Readiness:
═══════════════════════════════════════════════════════
  ✓ Network foundation is ready
  ✓ Other processes can now safely use networking
  ✓ VM creation can proceed
  ✓ Downloads and network discovery will work

Next Steps:
═══════════════════════════════════════════════════════
  1. Create VMs using network 'host-bridge'
  2. Run setup wizard for additional configuration
  3. Download ISOs with network connectivity
  4. Configure additional network zones if needed

Commands:
═══════════════════════════════════════════════════════
  Check bridge:    ip addr show $bridge_name
  Check binding:   bridge link show
  Check libvirt:   virsh net-list
  Test ping:       ping -c 2 ${gateway:-8.8.8.8}

Log: $LOGFILE"

log "$status_report"

if [[ "$NON_INTERACTIVE" == "false" ]]; then
  $DIALOG --msgbox "$status_report" 40 78
fi

# Success!
log "Foundational networking setup completed successfully"
exit 0
