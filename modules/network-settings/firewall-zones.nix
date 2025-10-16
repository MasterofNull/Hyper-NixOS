{ config, lib, pkgs, ... }:

# Firewall Zones Module - Zone-based Security
# Two-Phase Compatible

let
  cfg = config.hypervisor.network.firewallZones;
  phaseConfig = config.hypervisor.security.phaseManagement or { currentPhase = 1; };
  isSetupPhase = phaseConfig.currentPhase == 1;
in
{
  options.hypervisor.network.firewallZones = {
    enable = lib.mkEnableOption "Zone-based firewall";
    
    defaultAction = lib.mkOption {
      type = lib.types.enum [ "accept" "drop" "reject" ];
      default = "drop";
    };
    
    zones = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          interfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          
          vlans = lib.mkOption {
            type = lib.types.listOf lib.types.int;
            default = [];
          };
          
          allowAll = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          
          allowedServices = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          
          allowedPorts = lib.mkOption {
            type = lib.types.listOf lib.types.int;
            default = [];
          };
          
          allowTo = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          
          blockFrom = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      });
      default = {};
    };
  };
  
  config = lib.mkIf cfg.enable {
    networking.firewall.enable = true;
    
    # Zone-based rules would be implemented here
    # Complex iptables/nftables rules for zone policies
    
    system.activationScripts.firewall-zones = ''
      echo "Firewall Zones: ${toString (builtins.attrNames cfg.zones)}" >&2
    '';
  };
}
