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
  
  # DNS settings
  networking.nameservers = lib.mkDefault [ "1.1.1.1" "8.8.8.8" ];
  
  # Network manager disabled (server environment)
  networking.networkmanager.enable = lib.mkDefault false;
  
  # Enable IPv6
  networking.enableIPv6 = lib.mkDefault true;
}
