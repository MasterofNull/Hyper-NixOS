{ config, lib, pkgs, ... }:

# Network Bonding/Link Aggregation Module
# Copyright (C) 2024-2025 MasterofNull  
# Licensed under GPL v3.0

let
  cfg = config.hypervisor.network.bonding;
  phaseConfig = config.hypervisor.security.phaseManagement or { currentPhase = 1; };
  isSetupPhase = phaseConfig.currentPhase == 1;
in
{
  options.hypervisor.network.bonding = {
    enable = lib.mkEnableOption "Network bonding and link aggregation";
    
    bonds = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          interfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Physical interfaces to bond";
            example = [ "eth0" "eth1" ];
          };
          
          mode = lib.mkOption {
            type = lib.types.enum [
              "balance-rr" "active-backup" "balance-xor" "broadcast"
              "802.3ad" "balance-tlb" "balance-alb"
            ];
            default = "802.3ad";
            description = ''
              Bonding mode:
              - balance-rr: Round-robin (load balancing)
              - active-backup: Failover (one active, others standby)
              - balance-xor: XOR load balancing
              - broadcast: Broadcast to all interfaces
              - 802.3ad: IEEE 802.3ad LACP (recommended)
              - balance-tlb: Adaptive transmit load balancing
              - balance-alb: Adaptive load balancing
            '';
          };
          
          miimon = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = "MII link monitoring interval (ms)";
          };
          
          primary = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Primary interface (for active-backup)";
          };
          
          transmitHashPolicy = lib.mkOption {
            type = lib.types.enum [ "layer2" "layer2+3" "layer3+4" "encap2+3" "encap3+4" ];
            default = "layer3+4";
            description = "Transmit hash policy for load distribution";
          };
          
          lacpRate = lib.mkOption {
            type = lib.types.enum [ "slow" "fast" ];
            default = "fast";
            description = "LACP rate (for 802.3ad mode)";
          };
          
          updelay = lib.mkOption {
            type = lib.types.int;
            default = 200;
            description = "Delay before enabling interface after link up (ms)";
          };
          
          downdelay = lib.mkOption {
            type = lib.types.int;
            default = 200;
            description = "Delay before disabling interface after link down (ms)";
          };
        };
      });
      default = {};
      description = "Bond configurations";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install bonding tools
    environment.systemPackages = with pkgs; [
      iproute2
      ifenslave
      ethtool
    ];
    
    # Enable bonding kernel module
    boot.kernelModules = [ "bonding" ];
    
    # Configure bonded interfaces
    networking.bonds = lib.mapAttrs (name: bcfg: {
      interfaces = bcfg.interfaces;
      driverOptions = {
        mode = bcfg.mode;
        miimon = toString bcfg.miimon;
        xmit_hash_policy = bcfg.transmitHashPolicy;
        lacp_rate = if bcfg.mode == "802.3ad" then bcfg.lacpRate else null;
        updelay = toString bcfg.updelay;
        downdelay = toString bcfg.downdelay;
        primary = bcfg.primary;
      };
    }) cfg.bonds;
    
    # Activation script
    system.activationScripts.bonding-setup = ''
      echo "Network Bonding Status:" >&2
      echo "  Phase: ${if isSetupPhase then "Setup" else "Hardened"}" >&2
      echo "  Bonds: ${toString (builtins.attrNames cfg.bonds)}" >&2
    '';
  };
}
