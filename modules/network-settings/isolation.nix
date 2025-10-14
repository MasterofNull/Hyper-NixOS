{ config, lib, pkgs, ... }:

# Network Isolation Configuration
# Provides VLAN tagging, private networks, and traffic isolation for VMs
#
# Features:
# - VLAN support for network segmentation
# - Private networks (VM-to-VM only, no external access)
# - Network isolation tools and utilities
# - Scripts for managing network attachments

{
  # Enable advanced networking
  networking = {
    # VLAN support
    vlans = {
      # Example VLANs (configure as needed)
      # vlan10 = { id = 10; interface = "eth0"; };
      # vlan20 = { id = 20; interface = "eth0"; };
    };
    
    # Enable IP forwarding for routing between networks
    # Note: Firewall configuration is handled by modules/network-settings/firewall.nix
    nat.internalInterfaces = lib.mkDefault [ "virbr+" ];
  };
  
  # Bridge utilities for network management
  environment.systemPackages =  [
    pkgs.bridge-utils
    pkgs.vlan
    pkgs.iproute2
    pkgs.iptables
    pkgs.ebtables
    pkgs.tcpdump
    pkgs.wireshark-cli  # tshark for traffic analysis
  ];
  
  # Network isolation management script
  environment.etc."hypervisor/scripts/network_isolation.sh" = {
    text = ''
      #!/usr/bin/env bash
      #
      # Hyper-NixOS Network Isolation Manager
      # Copyright (C) 2024-2025 MasterofNull
      # Licensed under GPL v3.0
      #
      # Manages VLANs, private networks, and VM network isolation
      
      set -euo pipefail
      PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      
      NETWORK_CONFIG="/var/lib/hypervisor/configuration/networks.conf"
      
      usage() {
        cat <<EOF
      Usage: $(basename "$0") <command> [options]
      
      Commands:
        create-vlan <vlan-id> <bridge-name> [physical-interface]
        create-private <network-name> [subnet]
        attach-vm <vm-name> <network-name> [vlan-id]
        detach-vm <vm-name> <interface>
        list-networks
        list-vlans
        show-vm-networks <vm-name>
        isolate-vm <vm-name>
      
      Examples:
        # Create VLAN 10 on bridge br0
        $(basename "$0") create-vlan 10 br0-vlan10 eth0
        
        # Create private network (no external access)
        $(basename "$0") create-private db-network 10.0.100.0/24
        
        # Attach VM to network
        $(basename "$0") attach-vm web-server br0-vlan10 10
        
        # Completely isolate a VM (no network)
        $(basename "$0") isolate-vm sensitive-vm
      
      Network Types:
        VLAN:    Tagged network on physical interface
        Private: Isolated internal network (VM-to-VM only)
        Bridged: Connected to physical network
        NAT:     Outbound only (no inbound connections)
      EOF
      }
      
      # Create VLAN network
      create_vlan() {
        local vlan_id="$1"
        local bridge_name="$2"
        local physical_if="''${3:-eth0}"
        
        if [[ $vlan_id -lt 1 ]] || [[ $vlan_id -gt 4094 ]]; then
          echo "Error: VLAN ID must be 1-4094" >&2
          return 1
        fi
        
        echo "Creating VLAN $vlan_id on $physical_if..."
        
        # Create VLAN interface
        if ! ip link show "$physical_if.$vlan_id" >/dev/null 2>&1; then
          ip link add link "$physical_if" name "$physical_if.$vlan_id" type vlan id "$vlan_id"
          ip link set dev "$physical_if.$vlan_id" up
        fi
        
        # Create bridge for VLAN
        if ! ip link show "$bridge_name" >/dev/null 2>&1; then
          ip link add name "$bridge_name" type bridge
          ip link set dev "$bridge_name" up
          
          # Attach VLAN interface to bridge
          ip link set dev "$physical_if.$vlan_id" master "$bridge_name"
        fi
        
        # Create libvirt network
        cat > /tmp/vlan-network-$vlan_id.xml <<EOF
      <network>
        <name>$bridge_name</name>
        <forward mode="bridge"/>
        <bridge name="$bridge_name"/>
        <virtualport type='openvswitch'/>
        <vlan>
          <tag id='$vlan_id'/>
        </vlan>
      </network>
      EOF
        
        virsh net-define /tmp/vlan-network-$vlan_id.xml
        virsh net-start "$bridge_name" 2>/dev/null || true
        virsh net-autostart "$bridge_name"
        
        rm /tmp/vlan-network-$vlan_id.xml
        
        echo "✓ VLAN $vlan_id created on bridge $bridge_name"
      }
      
      # Create private network
      create_private() {
        local network_name="$1"
        local subnet="''${2:-10.0.$(( RANDOM % 200 + 10 )).0/24}"
        
        echo "Creating private network: $network_name ($subnet)"
        
        # Extract network details
        local ip_base=$(echo "$subnet" | cut -d/ -f1 | cut -d. -f1-3)
        local gateway="$ip_base.1"
        local dhcp_start="$ip_base.10"
        local dhcp_end="$ip_base.250"
        
        cat > /tmp/private-network.xml <<EOF
      <network>
        <name>$network_name</name>
        <bridge name="virbr-$network_name"/>
        <forward mode="none"/>
        <ip address="$gateway" netmask="255.255.255.0">
          <dhcp>
            <range start="$dhcp_start" end="$dhcp_end"/>
          </dhcp>
        </ip>
      </network>
      EOF
        
        virsh net-define /tmp/private-network.xml
        virsh net-start "$network_name" 2>/dev/null || true
        virsh net-autostart "$network_name"
        
        rm /tmp/private-network.xml
        
        echo "✓ Private network created: $network_name"
        echo "  Gateway: $gateway"
        echo "  DHCP:    $dhcp_start - $dhcp_end"
        echo "  Isolation: Complete (no external access)"
      }
      
      # Attach VM to network
      attach_vm() {
        local vm="$1"
        local network="$2"
        local vlan_id="''${3:-}"
        
        if ! virsh list --all --name | grep -q "^$vm$"; then
          echo "Error: VM $vm not found" >&2
          return 1
        fi
        
        if ! virsh net-list --all --name | grep -q "^$network$"; then
          echo "Error: Network $network not found" >&2
          return 1
        fi
        
        echo "Attaching VM $vm to network $network..."
        
        # Generate MAC address
        local mac="52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"
        
        # Create interface XML
        local vlan_xml=""
        if [[ -n "$vlan_id" ]]; then
          vlan_xml="<vlan><tag id='$vlan_id'/></vlan>"
        fi
        
        cat > /tmp/vm-interface.xml <<EOF
      <interface type='network'>
        <source network='$network'/>
        <mac address='$mac'/>
        <model type='virtio'/>
        $vlan_xml
      </interface>
      EOF
        
        virsh attach-device "$vm" /tmp/vm-interface.xml --config
        
        # Attach to running VM if online
        if virsh list --name | grep -q "^$vm$"; then
          virsh attach-device "$vm" /tmp/vm-interface.xml --live || true
        fi
        
        rm /tmp/vm-interface.xml
        
        echo "✓ VM attached to network"
        echo "  MAC: $mac"
        if [[ -n "$vlan_id" ]]; then
          echo "  VLAN: $vlan_id"
        fi
      }
      
      # Detach VM from network
      detach_vm() {
        local vm="$1"
        local interface="$2"
        
        echo "Detaching interface $interface from VM $vm..."
        
        virsh detach-interface "$vm" network --mac "$interface" --config
        
        if virsh list --name | grep -q "^$vm$"; then
          virsh detach-interface "$vm" network --mac "$interface" --live || true
        fi
        
        echo "✓ Interface detached"
      }
      
      # List all networks
      list_networks() {
        echo "Libvirt Networks:"
        echo ""
        virsh net-list --all
        
        echo ""
        echo "System Bridges:"
        echo ""
        ip link show type bridge | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/:$//'
        
        echo ""
        echo "VLANs:"
        echo ""
        ip -d link show | grep -E "vlan id" | awk '{print $2, $4, $5, $6}'
      }
      
      # List VLANs
      list_vlans() {
        echo "VLAN Interfaces:"
        echo ""
        printf "%-20s %-10s %-10s %-10s\n" "Interface" "VLAN ID" "Parent" "State"
        printf "%-20s %-10s %-10s %-10s\n" "---------" "-------" "------" "-----"
        
        ip -d link show | grep -B1 "vlan id" | grep -E "^[0-9]+:" | while read -r line; do
          local iface=$(echo "$line" | awk '{print $2}' | sed 's/:$//')
          local state=$(echo "$line" | awk '{print $9}')
          local vlan_line=$(ip -d link show "$iface" | grep "vlan id")
          local vlan_id=$(echo "$vlan_line" | awk '{print $3}')
          local parent=$(echo "$iface" | cut -d. -f1)
          
          printf "%-20s %-10s %-10s %-10s\n" "$iface" "$vlan_id" "$parent" "$state"
        done
      }
      
      # Show VM networks
      show_vm_networks() {
        local vm="$1"
        
        if ! virsh list --all --name | grep -q "^$vm$"; then
          echo "Error: VM $vm not found" >&2
          return 1
        fi
        
        echo "Networks for VM: $vm"
        echo ""
        
        virsh domiflist "$vm"
      }
      
      # Completely isolate VM (remove all networks)
      isolate_vm() {
        local vm="$1"
        
        echo "Isolating VM: $vm (removing all network connections)"
        
        local interfaces=$(virsh domiflist "$vm" | awk 'NR>2 {print $5}')
        
        for mac in $interfaces; do
          [[ -z "$mac" ]] && continue
          virsh detach-interface "$vm" network --mac "$mac" --config 2>/dev/null || true
          
          if virsh list --name | grep -q "^$vm$"; then
            virsh detach-interface "$vm" network --mac "$mac" --live 2>/dev/null || true
          fi
        done
        
        echo "✓ VM isolated (no network access)"
      }
      
      # Main
      case "''${1:-}" in
        create-vlan)
          create_vlan "''${2:-}" "''${3:-}" "''${4:-eth0}"
          ;;
        create-private)
          create_private "''${2:-}" "''${3:-}"
          ;;
        attach-vm)
          attach_vm "''${2:-}" "''${3:-}" "''${4:-}"
          ;;
        detach-vm)
          detach_vm "''${2:-}" "''${3:-}"
          ;;
        list-networks)
          list_networks
          ;;
        list-vlans)
          list_vlans
          ;;
        show-vm-networks)
          show_vm_networks "''${2:-}"
          ;;
        isolate-vm)
          isolate_vm "''${2:-}"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
    mode = "0755";
  };
}
