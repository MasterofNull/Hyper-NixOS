{ config, lib, pkgs, ... }:

# DHCP Server Module with Per-VLAN Support
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0

let
  cfg = config.hypervisor.network.dhcpServer;
  phaseConfig = config.hypervisor.security.phaseManagement or { currentPhase = 1; };
  isSetupPhase = phaseConfig.currentPhase == 1;
in
{
  options.hypervisor.network.dhcpServer = {
    enable = lib.mkEnableOption "DHCP server";
    
    type = lib.mkOption {
      type = lib.types.enum [ "dnsmasq" "kea" ];
      default = "dnsmasq";
      description = "DHCP server implementation";
    };
    
    defaultLeaseTime = lib.mkOption {
      type = lib.types.str;
      default = "24h";
      description = "Default lease time";
    };
    
    maxLeaseTime = lib.mkOption {
      type = lib.types.str;
      default = "72h";
      description = "Maximum lease time";
    };
    
    vlans = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          range = lib.mkOption {
            type = lib.types.str;
            description = "DHCP range (start-end or start,end,netmask)";
            example = "192.168.10.100-192.168.10.200";
          };
          
          gateway = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Default gateway";
          };
          
          dns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "1.1.1.1" "8.8.8.8" ];
            description = "DNS servers";
          };
          
          leaseTime = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override default lease time";
          };
          
          reservations = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                mac = lib.mkOption {
                  type = lib.types.str;
                  description = "MAC address";
                };
                
                ip = lib.mkOption {
                  type = lib.types.str;
                  description = "Reserved IP address";
                };
                
                hostname = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Hostname";
                };
              };
            });
            default = {};
            description = "Static IP reservations";
          };
          
          options = lib.mkOption {
            type = lib.types.attrs;
            default = {};
            description = "Additional DHCP options";
          };
        };
      });
      default = {};
      description = "Per-VLAN DHCP configuration";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # dnsmasq configuration
    services.dnsmasq = lib.mkIf (cfg.type == "dnsmasq") {
      enable = true;
      settings = {
        # General settings
        domain-needed = true;
        bogus-priv = true;
        no-resolv = true;
        
        # DHCP ranges per VLAN
        dhcp-range = lib.mapAttrsToList (vlan: vcfg:
          "${vcfg.range},${vcfg.leaseTime or cfg.defaultLeaseTime}"
        ) cfg.vlans;
        
        # Static reservations
        dhcp-host = lib.flatten (lib.mapAttrsToList (vlan: vcfg:
          lib.mapAttrsToList (name: res:
            "${res.mac},${res.ip}${lib.optionalString (res.hostname != null) ",${res.hostname}"}"
          ) vcfg.reservations
        ) cfg.vlans);
        
        # Gateway options
        dhcp-option = lib.flatten (lib.mapAttrsToList (vlan: vcfg: [
          (lib.optionalString (vcfg.gateway != null) "option:router,${vcfg.gateway}")
          "option:dns-server,${lib.concatStringsSep "," vcfg.dns}"
        ]) cfg.vlans);
      };
    };
    
    system.activationScripts.dhcp-setup = ''
      echo "DHCP Server Status:" >&2
      echo "  Type: ${cfg.type}" >&2
      echo "  VLANs: ${toString (builtins.attrNames cfg.vlans)}" >&2
    '';
  };
}
