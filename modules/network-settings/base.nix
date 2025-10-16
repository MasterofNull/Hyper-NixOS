{ config, lib, pkgs, ... }:

# Base Network Configuration
# Hostname and basic networking settings

{
  # Hostname - can be overridden by system-local.nix
  networking.hostName = lib.mkDefault "hypervisor";
  
  # Enable systemd-networkd for consistent network management
  networking.useNetworkd = lib.mkDefault false;
  
  # DHCP on all interfaces by default
  networking.useDHCP = lib.mkDefault true;
  
  # Optimize DHCP client for faster boot times
  networking.dhcpcd.extraConfig = ''
    # Reduce timeout for faster boot (default is 30s)
    timeout 10
    
    # Don't wait for carrier on all interfaces (speeds up boot)
    noarp
    
    # Use faster DHCP request strategy
    option rapid_commit
    
    # Background immediately after first lease
    background
    
    # Reduce retry interval
    reboot 5
  '';
  
  # Optimize systemd-networkd-wait-online for faster boot
  # This service can significantly delay boot if not configured properly
  systemd.services.systemd-networkd-wait-online = {
    serviceConfig = {
      # Reduce timeout from default 120s to 30s
      TimeoutStartSec = lib.mkDefault "30s";
    };
    # Only wait for any interface, not all interfaces
    # This allows boot to continue as soon as ONE interface is online
    enable = lib.mkDefault true;
  };
  
  # Configure systemd-networkd to not wait for all interfaces
  systemd.network.wait-online = {
    # Only wait for any single interface to be online
    anyInterface = lib.mkDefault true;
    # Reduce timeout (default is 120s)
    timeout = lib.mkDefault 30;
    # Don't fail boot if network is unavailable
    enable = lib.mkDefault true;
  };
  
  # DNS settings
  networking.nameservers = lib.mkDefault [ "1.1.1.1" "8.8.8.8" ];
  
  # Network manager disabled (server environment)
  networking.networkmanager.enable = lib.mkDefault false;
  
  # Enable IPv6
  networking.enableIPv6 = lib.mkDefault true;
}
