{ config, lib, pkgs, ... }:

# VPN with Kill Switch Module
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0

let
  cfg = config.hypervisor.network.vpn;
  phaseConfig = config.hypervisor.security.phaseManagement or { currentPhase = 1; };
  isSetupPhase = phaseConfig.currentPhase == 1;
in
{
  options.hypervisor.network.vpn = {
    enable = lib.mkEnableOption "VPN with kill switch";
    
    type = lib.mkOption {
      type = lib.types.enum [ "wireguard" "openvpn" ];
      default = "wireguard";
      description = "VPN type";
    };
    
    killSwitch = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable kill switch (block traffic if VPN fails)";
      };
      
      allowLAN = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow local network access when VPN is down";
      };
      
      allowedIPs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional IPs to allow when VPN is down";
      };
    };
    
    wireguard = lib.mkOption {
      type = lib.types.submodule {
        options = {
          interface = lib.mkOption {
            type = lib.types.str;
            default = "wg0";
            description = "WireGuard interface name";
          };
          
          privateKeyFile = lib.mkOption {
            type = lib.types.str;
            description = "Path to private key file";
          };
          
          address = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "VPN IP addresses";
          };
          
          peers = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                publicKey = lib.mkOption {
                  type = lib.types.str;
                  description = "Peer public key";
                };
                
                endpoint = lib.mkOption {
                  type = lib.types.str;
                  description = "Peer endpoint (host:port)";
                };
                
                allowedIPs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "0.0.0.0/0" ];
                  description = "Allowed IPs";
                };
                
                persistentKeepalive = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = 25;
                  description = "Persistent keepalive interval (seconds)";
                };
              };
            });
            description = "WireGuard peers";
          };
        };
      };
      default = {};
      description = "WireGuard configuration";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # WireGuard configuration
    networking.wireguard.interfaces = lib.mkIf (cfg.type == "wireguard") {
      "${cfg.wireguard.interface}" = {
        privateKeyFile = cfg.wireguard.privateKeyFile;
        ips = cfg.wireguard.address;
        peers = cfg.wireguard.peers;
      };
    };
    
    # Kill switch firewall rules
    networking.firewall.extraCommands = lib.mkIf cfg.killSwitch.enable ''
      # VPN Kill Switch - Block all traffic except VPN
      
      # Allow loopback
      iptables -A OUTPUT -o lo -j ACCEPT
      
      ${lib.optionalString cfg.killSwitch.allowLAN ''
        # Allow LAN
        iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
        iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
        iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
      ''}
      
      ${lib.concatMapStringsSep "\n" (ip: ''
        iptables -A OUTPUT -d ${ip} -j ACCEPT
      '') cfg.killSwitch.allowedIPs}
      
      # Allow VPN interface
      iptables -A OUTPUT -o ${cfg.wireguard.interface} -j ACCEPT
      
      # Allow VPN establishment
      ${lib.concatMapStringsSep "\n" (peer: ''
        iptables -A OUTPUT -d ${lib.head (lib.splitString ":" peer.endpoint)} -j ACCEPT
      '') cfg.wireguard.peers}
      
      # Block everything else
      iptables -A OUTPUT -j REJECT
    '';
    
    system.activationScripts.vpn-setup = ''
      echo "VPN Status:" >&2
      echo "  Type: ${cfg.type}" >&2
      echo "  Kill Switch: ${if cfg.killSwitch.enable then "Enabled" else "Disabled"}" >&2
    '';
  };
}
