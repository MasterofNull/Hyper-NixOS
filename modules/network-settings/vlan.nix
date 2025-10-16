{ config, lib, pkgs, ... }:

# VLAN Configuration Module
# Provides 802.1Q VLAN tagging and management capabilities

let
  cfg = config.hypervisor.network.vlan;
in
{
  options.hypervisor.network.vlan = {
    enable = lib.mkEnableOption "VLAN support";
    
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.int;
            description = "VLAN ID (1-4094)";
          };
          
          interface = lib.mkOption {
            type = lib.types.str;
            description = "Parent physical interface";
            example = "eth0";
          };
          
          addresses = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "IP addresses for this VLAN interface";
            example = [ "192.168.10.2/24" ];
          };
          
          priority = lib.mkOption {
            type = lib.types.nullOr (lib.types.ints.between 0 7);
            default = null;
            description = "802.1p priority (0-7)";
          };
          
          mtu = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "MTU size (typically 1500 for tagged frames)";
          };
          
          dhcp = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Use DHCP for this VLAN";
          };
          
          gateway = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Default gateway for this VLAN";
          };
        };
      });
      default = {};
      description = "VLAN interface definitions";
      example = {
        "vlan10" = {
          id = 10;
          interface = "eth0";
          addresses = [ "192.168.10.2/24" ];
        };
      };
    };
    
    trunking = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          interface = lib.mkOption {
            type = lib.types.str;
            description = "Interface to configure as trunk";
          };
          
          allowedVlans = lib.mkOption {
            type = lib.types.listOf lib.types.int;
            default = [];
            description = "List of allowed VLAN IDs (empty = all)";
          };
          
          nativeVlan = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Native (untagged) VLAN ID";
          };
        };
      });
      default = {};
      description = "Trunk port configurations";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install VLAN utilities
    environment.systemPackages = with pkgs; [
      vlan
      iproute2
      ethtool
    ];
    
    # Enable 802.1Q module
    boot.kernelModules = [ "8021q" ];
    
    # Create VLAN interfaces
    networking.vlans = lib.mapAttrs (name: vcfg: {
      id = vcfg.id;
      interface = vcfg.interface;
    }) cfg.interfaces;
    
    # Configure VLAN interface settings
    systemd.network.networks = lib.mapAttrs' (name: vcfg: 
      lib.nameValuePair "50-${name}" {
        matchConfig.Name = name;
        
        networkConfig = {
          DHCP = if vcfg.dhcp then "yes" else "no";
        } // (if vcfg.mtu != null then { MTU = toString vcfg.mtu; } else {});
        
        address = vcfg.addresses;
        
        routes = lib.optional (vcfg.gateway != null) {
          routeConfig = {
            Gateway = vcfg.gateway;
            GatewayOnLink = true;
          };
        };
        
        # VLAN priority
        vlanConfig = lib.optionalAttrs (vcfg.priority != null) {
          EgressMapping = "${toString vcfg.priority}:${toString vcfg.priority}";
        };
      }
    ) cfg.interfaces;
    
    # Configure trunk ports
    systemd.services.vlan-trunk-setup = lib.mkIf (cfg.trunking != {}) {
      description = "Configure VLAN Trunk Ports";
      after = [ "network-pre.target" ];
      before = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "vlan-trunk-setup" ''
          set -e
          
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: tcfg: ''
            # Configure trunk: ${name}
            echo "Setting up trunk on ${tcfg.interface}..."
            
            # Ensure interface is up
            ip link set ${tcfg.interface} up
            
            ${lib.optionalString (tcfg.nativeVlan != null) ''
              # Set native VLAN
              ip link set ${tcfg.interface} type vlan id ${toString tcfg.nativeVlan}
            ''}
            
            ${lib.optionalString (tcfg.allowedVlans != []) ''
              # Configure allowed VLANs
              # Note: Linux doesn't have explicit VLAN filtering like switches
              # VLANs are implicitly allowed by creating VLAN interfaces
              echo "Trunk ${tcfg.interface} allows VLANs: ${lib.concatMapStringsSep "," toString tcfg.allowedVlans}"
            ''}
            
            echo "✓ Trunk ${name} configured on ${tcfg.interface}"
          '') cfg.trunking)}
        '';
      };
    };
    
    # Logging
    system.activationScripts.vlan-info = lib.mkIf cfg.enable ''
      echo "VLAN Configuration Active" | systemd-cat -t vlan -p info
      echo "Configured VLANs: ${lib.concatStringsSep ", " (lib.mapAttrsToList (n: v: "${n} (ID: ${toString v.id})") cfg.interfaces)}" | \
        systemd-cat -t vlan -p info
    '';
  };
}
