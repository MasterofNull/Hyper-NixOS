#!/usr/bin/env bash
#
# Hyper-NixOS Network Bridge Configuration Wizard
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Intelligent network bridge setup with automatic interface detection,
# performance optimization, and MTU configuration for optimal VM networking.
#
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
: "${DIALOG:=whiptail}"

LOGFILE="/var/lib/hypervisor/logs/bridge_setup.log"
mkdir -p "$(dirname "$LOGFILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

require() { 
  for b in $DIALOG ip jq ethtool; do 
    if ! command -v "$b" >/dev/null 2>&1; then
      log "ERROR: Missing required command: $b"
      echo "Missing $b" >&2
      exit 1
    fi
  done
}
require

log "=== Bridge Configuration Wizard Started ==="

# Detect physical network interfaces (exclude virtual, loopback, bridges)
detect_physical_interfaces() {
  local ifaces=()
  while IFS= read -r iface; do
    # Skip loopback, virtual bridges, and TAP/TUN devices
    if [[ "$iface" =~ ^(lo|virbr|br-|docker|veth|tap|tun) ]]; then
      continue
    fi
    # Check if it's a physical device
    if [[ -d "/sys/class/net/$iface/device" ]] || ip link show "$iface" | grep -q "link/ether"; then
      ifaces+=("$iface")
    fi
  done < <(ip -o link show | awk -F': ' '{print $2}')
  
  printf '%s\n' "${ifaces[@]}"
}

# Get detailed interface information
get_interface_info() {
  local iface="$1"
  local state speed duplex mtu driver
  
  state=$(ip link show "$iface" | grep -oP 'state \K\w+' || echo "UNKNOWN")
  mtu=$(ip link show "$iface" | grep -oP 'mtu \K\d+' || echo "1500")
  
  if command -v ethtool >/dev/null 2>&1 && [[ "$state" == "UP" ]]; then
    speed=$(ethtool "$iface" 2>/dev/null | grep -oP 'Speed: \K.*' || echo "Unknown")
    duplex=$(ethtool "$iface" 2>/dev/null | grep -oP 'Duplex: \K.*' || echo "Unknown")
    driver=$(ethtool -i "$iface" 2>/dev/null | grep -oP 'driver: \K.*' || echo "Unknown")
  else
    speed="Down"
    duplex="N/A"
    driver=$(ethtool -i "$iface" 2>/dev/null | grep -oP 'driver: \K.*' || echo "Unknown")
  fi
  
  # Check if interface has IP
  local has_ip="No"
  if ip addr show "$iface" | grep -q "inet "; then
    has_ip="Yes"
  fi
  
  echo "State:$state Speed:$speed Duplex:$duplex MTU:$mtu Driver:$driver HasIP:$has_ip"
}

# Recommend optimal MTU
recommend_mtu() {
  local iface="$1"
  local current_mtu
  current_mtu=$(ip link show "$iface" | grep -oP 'mtu \K\d+' || echo "1500")
  
  # Check if interface supports jumbo frames
  local max_mtu=1500
  if ethtool -k "$iface" 2>/dev/null | grep -q "tx-checksumming: on"; then
    # Most modern NICs support 9000
    max_mtu=9000
  fi
  
  # For VM networking, 1500 is safest, 9000 for storage/backend
  echo "$current_mtu:$max_mtu"
}

# Validate interface selection
validate_interface() {
  local iface="$1"
  local issues=()
  
  # Check if interface exists
  if ! ip link show "$iface" &>/dev/null; then
    issues+=("Interface does not exist")
    printf '%s\n' "${issues[@]}"
    return 1
  fi
  
  # Check if already bridged
  if ip link show "$iface" | grep -q "master br"; then
    issues+=("Already part of a bridge")
  fi
  
  # Check if it's a bridge itself
  if [[ -d "/sys/class/net/$iface/bridge" ]]; then
    issues+=("This is already a bridge device")
  fi
  
  # Warn if interface is down
  if ! ip link show "$iface" | grep -q "state UP"; then
    issues+=("Interface is currently DOWN")
  fi
  
  if (( ${#issues[@]} > 0 )); then
    printf '%s\n' "${issues[@]}"
    return 1
  fi
  
  return 0
}

# Show welcome and explanation
$DIALOG --msgbox "Network Bridge Configuration Wizard

A network bridge allows your VMs to appear as physical devices on your network.

Benefits:
✓ VMs get their own IP addresses from your router
✓ VMs can communicate with other network devices
✓ Better performance than NAT for many workloads
✓ Direct network access for services

This wizard will:
1. Detect your network interfaces
2. Recommend optimal configuration
3. Set up a high-performance bridge
4. Validate the configuration

Logs: $LOGFILE" 22 78

# Detect interfaces
log "Detecting physical network interfaces..."
mapfile -t physical_ifaces < <(detect_physical_interfaces)

if (( ${#physical_ifaces[@]} == 0 )); then
  log "ERROR: No physical network interfaces detected"
  $DIALOG --msgbox "Error: No suitable network interfaces found.

This system needs at least one physical network interface (Ethernet or WiFi) to create a bridge.

Available interfaces:
$(ip -o link show | awk -F': ' '{print "  - " $2}')

None of these appear to be physical network devices." 16 70
  exit 1
fi

log "Found ${#physical_ifaces[@]} physical interface(s): ${physical_ifaces[*]}"

# Build interface selection menu with detailed info
menu_items=()
for iface in "${physical_ifaces[@]}"; do
  info=$(get_interface_info "$iface")
  state=$(echo "$info" | grep -oP 'State:\K\w+')
  speed=$(echo "$info" | grep -oP 'Speed:\K[^:]+' | awk '{print $1}')
  has_ip=$(echo "$info" | grep -oP 'HasIP:\K\w+')
  
  # Create descriptive label
  label="$state"
  [[ "$speed" != "Down" && "$speed" != "Unknown" ]] && label+=" ${speed}"
  [[ "$has_ip" == "Yes" ]] && label+=" (Active)"
  
  menu_items+=("$iface" "$label")
done

# Select interface
selected_iface=$($DIALOG --menu "Select Network Interface to Bridge

Choose the physical network interface that connects to your network.
This interface will be added to the bridge.

Recommendation: Choose the interface marked (Active) if available.
This is typically your primary network connection.

Interface Details:" 22 76 10 "${menu_items[@]}" 3>&1 1>&2 2>&3) || {
  log "User cancelled interface selection"
  exit 0
}

log "User selected interface: $selected_iface"

# Validate selection
validation_errors=$(validate_interface "$selected_iface" 2>&1) || {
  log "ERROR: Interface validation failed: $validation_errors"
  $DIALOG --msgbox "Warning: Issues detected with $selected_iface

$validation_errors

You can proceed, but the bridge may not work correctly.

Continue anyway?" 14 70 || exit 1
}

# Show detailed interface information
info=$(get_interface_info "$selected_iface")
$DIALOG --msgbox "Selected Interface: $selected_iface

Configuration:
$(echo "$info" | tr ':' '\n' | sed 's/^/  /')

This interface will be added to the bridge.
The bridge will inherit the network configuration." 16 70

# Ask for bridge name
bridge_name=$($DIALOG --inputbox "Bridge Name

Enter a name for the bridge (e.g., br0, br-lan, br-vm)

Standard naming:
  br0     - First bridge (recommended)
  br-lan  - LAN bridge
  br-vm   - VM bridge
  br-dmz  - DMZ bridge

Name:" 18 70 "br0" 3>&1 1>&2 2>&3) || exit 0

log "Bridge name: $bridge_name"

# Validate bridge name
if [[ ! "$bridge_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  log "ERROR: Invalid bridge name: $bridge_name"
  $DIALOG --msgbox "Error: Invalid bridge name '$bridge_name'

Bridge names must contain only letters, numbers, hyphens, and underscores." 10 70
  exit 1
fi

# Check if bridge already exists
if ip link show "$bridge_name" &>/dev/null; then
  log "ERROR: Bridge $bridge_name already exists"
  $DIALOG --msgbox "Error: Bridge '$bridge_name' already exists

Choose a different name or delete the existing bridge first." 10 70
  exit 1
fi

# Performance configuration options
perf_choice=$($DIALOG --menu "Performance Configuration

Choose performance profile for this bridge:

Standard: Good for most use cases (MTU 1500)
  - Compatible with all networks
  - Reliable and tested
  - Recommended for WAN-connected interfaces

Performance: Optimized for internal networks (MTU 9000)
  - Higher throughput for large transfers
  - Better for storage/backup traffic
  - Requires all devices to support jumbo frames
  - Recommended for LAN-only bridges

Custom: Manually configure advanced options" 24 76 8 \
  "standard" "MTU 1500 - Compatible (Recommended)" \
  "performance" "MTU 9000 - Jumbo frames (Advanced)" \
  "custom" "Custom configuration" 3>&1 1>&2 2>&3) || exit 0

log "Performance profile selected: $perf_choice"

# Set MTU based on profile
case "$perf_choice" in
  standard)
    mtu=1500
    ;;
  performance)
    mtu=9000
    ;;
  custom)
    mtu=$($DIALOG --inputbox "MTU Size

Maximum Transmission Unit (MTU) in bytes.

Common values:
  1500 - Standard Ethernet (safest)
  9000 - Jumbo frames (best performance)
  1450 - For VLAN/tunnel overhead

Current interface MTU: $(ip link show "$selected_iface" | grep -oP 'mtu \K\d+')" 16 70 "1500" 3>&1 1>&2 2>&3) || exit 0
    ;;
esac

log "MTU configured: $mtu"

# Confirm configuration
$DIALOG --yesno "Review Configuration

Bridge Name:     $bridge_name
Interface:       $selected_iface
MTU:             $mtu
Profile:         $perf_choice

The system will create systemd-networkd configuration files:
  /etc/systemd/network/$bridge_name.netdev
  /etc/systemd/network/$bridge_name.network
  /etc/systemd/network/$selected_iface.network

Network will be restarted after configuration.

Proceed?" 20 76 || {
  log "User cancelled at confirmation"
  exit 0
}

log "Creating bridge configuration files..."

# Create bridge netdev with performance options
sudo tee "/etc/systemd/network/$bridge_name.netdev" > /dev/null <<CONF
[NetDev]
Name=$bridge_name
Kind=bridge
MTUBytes=$mtu

[Bridge]
# Performance optimizations
DefaultPVID=none
VLANFiltering=no
STP=no
CONF

log "Created $bridge_name.netdev"

# Create bridge network configuration
sudo tee "/etc/systemd/network/$bridge_name.network" > /dev/null <<CONF
[Match]
Name=$bridge_name

[Network]
DHCP=yes
# Enable IPv6 if available
IPv6AcceptRA=yes
# DNS resolution
LLMNR=yes
MulticastDNS=yes

[DHCP]
# Use DNS from DHCP
UseDNS=yes
UseRoutes=yes
UseHostname=no

[Link]
MTUBytes=$mtu
# Performance: Enable all offloading features
Multicast=yes
AllMulticast=yes
CONF

log "Created $bridge_name.network"

# Create interface network configuration to add it to bridge
sudo tee "/etc/systemd/network/$selected_iface.network" > /dev/null <<CONF
[Match]
Name=$selected_iface

[Network]
Bridge=$bridge_name

[Link]
MTUBytes=$mtu
CONF

log "Created $selected_iface.network"

# Offer to apply immediately or require reboot
apply_choice=$($DIALOG --menu "Apply Configuration

Configuration files created successfully.

Choose how to apply:

Restart Network: Apply immediately (may drop connections)
  - Fastest option
  - May cause temporary network interruption
  - Recommended for local access

Reboot System: Apply on next boot (safest)
  - No interruption now
  - Guaranteed clean state
  - Recommended for remote access

What would you like to do?" 22 76 6 \
  "restart" "Restart systemd-networkd (Quick)" \
  "reboot" "Reboot system (Safest)" \
  "manual" "Apply manually later" 3>&1 1>&2 2>&3) || apply_choice="manual"

log "Apply choice: $apply_choice"

case "$apply_choice" in
  restart)
    log "Restarting systemd-networkd..."
    if sudo systemctl restart systemd-networkd; then
      log "SUCCESS: systemd-networkd restarted"
      sleep 3
      
      # Verify bridge was created
      if ip link show "$bridge_name" &>/dev/null; then
        log "SUCCESS: Bridge $bridge_name is UP"
        
        # Get bridge status
        bridge_state=$(ip link show "$bridge_name" | grep -oP 'state \K\w+')
        bridge_ip=$(ip -4 addr show "$bridge_name" | grep -oP 'inet \K[0-9.]+' || echo "No IP yet")
        
        $DIALOG --msgbox "Bridge Created Successfully!

Bridge: $bridge_name
State: $bridge_state
IP Address: $bridge_ip
Interface: $selected_iface
MTU: $mtu

The bridge is now ready for VM use.

Next steps:
- Create a VM profile with this bridge
- Or use 'default' in VM network config (will use br0)
- Check status: ip addr show $bridge_name

Log: $LOGFILE" 20 76
        
        log "=== Bridge Configuration Completed Successfully ==="
      else
        log "WARNING: Bridge $bridge_name not found after restart"
        $DIALOG --msgbox "Warning: Bridge Not Detected

The configuration was applied but the bridge is not visible yet.

This can happen if:
- The interface was not ready
- Network initialization is still in progress

Try:
1. Wait a few seconds and check: ip addr show $bridge_name
2. Or reboot the system for a clean start

Log: $LOGFILE" 16 76
      fi
    else
      log "ERROR: Failed to restart systemd-networkd"
      $DIALOG --msgbox "Error: Failed to restart systemd-networkd

The configuration files were created but couldn't be applied.

Please reboot the system or restart manually:
  sudo systemctl restart systemd-networkd

Log: $LOGFILE" 14 76
    fi
    ;;
    
  reboot)
    log "User chose to reboot"
    if $DIALOG --yesno "Reboot Now?

The system will reboot to apply the bridge configuration.

Reboot now?" 10 60; then
      log "Initiating system reboot..."
      sudo systemctl reboot
    else
      log "Reboot postponed by user"
      $DIALOG --msgbox "Reboot Postponed

Bridge configuration saved. Reboot when ready:
  sudo systemctl reboot

Log: $LOGFILE" 12 76
    fi
    ;;
    
  manual)
    log "User chose manual application"
    $DIALOG --msgbox "Configuration Saved

Bridge configuration files created:
  /etc/systemd/network/$bridge_name.netdev
  /etc/systemd/network/$bridge_name.network
  /etc/systemd/network/$selected_iface.network

To apply:
  sudo systemctl restart systemd-networkd

Or reboot:
  sudo systemctl reboot

Log: $LOGFILE" 16 76
    ;;
esac

log "=== Bridge Configuration Wizard Completed ==="
