# Enterprise Multi-Tenant Stack Template
# Complete multi-tenant network with isolation

{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/network-settings/vlan.nix
    ../../modules/network-settings/dhcp-server.nix
    ../../modules/network-settings/dns-server.nix
    ../../modules/network-settings/firewall-zones.nix
    ../../modules/network-settings/traffic-shaping.nix
    ../../modules/network-settings/monitoring.nix
  ];

  hypervisor.network = {
    # VLANs for tenant isolation
    vlan = {
      enable = true;
      interfaces = {
        "vlan10" = {  # Tenant A
          id = 10;
          interface = "eth0";
          addresses = [ "192.168.10.1/24" ];
        };
        "vlan20" = {  # Tenant B
          id = 20;
          interface = "eth0";
          addresses = [ "192.168.20.1/24" ];
        };
        "vlan100" = {  # Management
          id = 100;
          interface = "eth0";
          addresses = [ "192.168.100.1/24" ];
          priority = 7;  # Highest priority
        };
      };
    };
    
    # DHCP per VLAN
    dhcpServer = {
      enable = true;
      vlans = {
        "vlan10" = {
          range = "192.168.10.100-192.168.10.200";
          gateway = "192.168.10.1";
        };
        "vlan20" = {
          range = "192.168.20.100-192.168.20.200";
          gateway = "192.168.20.1";
        };
      };
    };
    
    # Firewall zones for isolation
    firewallZones = {
      enable = true;
      zones = {
        management = {
          vlans = [ 100 ];
          allowAll = true;
        };
        tenant-a = {
          vlans = [ 10 ];
        };
        tenant-b = {
          vlans = [ 20 ];
        };
      };
    };
    
    # QoS per tenant
    qos = {
      enable = true;
      interfaces = {
        "vlan10".uploadLimit = "200mbit";
        "vlan20".uploadLimit = "100mbit";
      };
    };
  };
}
