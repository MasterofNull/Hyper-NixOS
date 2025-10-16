{ config, lib, pkgs, ... }:

# IPv6 Configuration Module with Privacy Extensions
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Two-Phase Security Model: Compatible with both setup and hardened phases

let
  cfg = config.hypervisor.network.ipv6;
  phaseConfig = config.hypervisor.security.phaseManagement or { currentPhase = 1; };
  isSetupPhase = phaseConfig.currentPhase == 1;
in
{
  options.hypervisor.network.ipv6 = {
    enable = lib.mkEnableOption "IPv6 support with privacy extensions";
    
    privacy = lib.mkOption {
      type = lib.types.enum [ "disabled" "stable" "temporary" ];
      default = "stable";
      description = ''
        IPv6 privacy mode:
        - disabled: No privacy extensions
        - stable: RFC 7217 stable privacy addresses (recommended)
        - temporary: RFC 4941 temporary addresses (maximum privacy)
      '';
    };
    
    randomize = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable periodic IPv6 address randomization";
      };
      
      intervalDays = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "Days between address regeneration";
      };
    };
    
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable IPv6 on this interface";
          };
          
          addresses = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Static IPv6 addresses (CIDR format)";
            example = [ "2001:db8::1/64" ];
          };
          
          autoconf = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable SLAAC (Stateless Address Autoconfiguration)";
          };
          
          acceptRA = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Accept Router Advertisements";
          };
          
          tempaddr = lib.mkOption {
            type = lib.types.enum [ 0 1 2 ];
            default = if cfg.privacy == "temporary" then 2 else 1;
            description = ''
              Temporary address usage:
              0 = disabled
              1 = enabled but prefer public
              2 = enabled and prefer temporary
            '';
          };
          
          dhcpv6 = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable DHCPv6 for this interface";
          };
        };
      });
      default = {};
      description = "Per-interface IPv6 configuration";
    };
    
    spoof = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable IPv6 address spoofing";
      };
      
      mode = lib.mkOption {
        type = lib.types.enum [ "random-suffix" "fully-random" "manual" ];
        default = "random-suffix";
        description = ''
          IPv6 spoofing mode:
          - random-suffix: Keep prefix, randomize suffix
          - fully-random: Completely random address
          - manual: Use manually specified addresses
        '';
      };
    };
    
    forwardingMode = lib.mkOption {
      type = lib.types.enum [ "disabled" "router" "host" ];
      default = "host";
      description = ''
        IPv6 forwarding configuration:
        - disabled: No forwarding
        - router: Full routing
        - host: Host-only (default)
      '';
    };
    
    logChanges = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Log IPv6 address changes";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Enable IPv6 kernel module
    boot.kernelModules = [ "ipv6" ];
    
    # Install IPv6 utilities
    environment.systemPackages = with pkgs; [
      iproute2
      iputils
      ndisc6  # IPv6 network discovery
      radvd   # Router Advertisement daemon
    ] ++ lib.optionals isSetupPhase [
      # Additional tools in setup phase
      wireshark-cli  # For IPv6 debugging
    ];
    
    # Kernel parameters for IPv6
    boot.kernel.sysctl = {
      # Enable IPv6
      "net.ipv6.conf.all.disable_ipv6" = 0;
      "net.ipv6.conf.default.disable_ipv6" = 0;
      
      # Privacy extensions
      "net.ipv6.conf.all.use_tempaddr" = if cfg.privacy == "disabled" then 0 else 2;
      "net.ipv6.conf.default.use_tempaddr" = if cfg.privacy == "disabled" then 0 else 2;
      
      # Stable privacy addresses (RFC 7217)
      "net.ipv6.conf.all.stable_secret" = lib.mkIf (cfg.privacy == "stable") 
        (builtins.hashString "sha256" "${config.networking.hostName}");
      
      # Router Advertisement
      "net.ipv6.conf.all.accept_ra" = 1;
      "net.ipv6.conf.default.accept_ra" = 1;
      
      # Address generation
      "net.ipv6.conf.all.addr_gen_mode" = if cfg.privacy == "stable" then 3 else 0;
      
      # Forwarding
      "net.ipv6.conf.all.forwarding" = if cfg.forwardingMode == "router" then 1 else 0;
      
      # Temp address lifetime (1 day for temporary addresses)
      "net.ipv6.conf.all.temp_valid_lft" = 86400;
      "net.ipv6.conf.all.temp_prefered_lft" = 14400;
      
      # Security
      "net.ipv6.conf.all.accept_redirects" = if isSetupPhase then 1 else 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
    };
    
    # Configure network interfaces
    systemd.network.networks = lib.mapAttrs' (name: icfg:
      lib.nameValuePair "50-ipv6-${name}" (lib.mkIf icfg.enable {
        matchConfig.Name = name;
        
        networkConfig = {
          IPv6AcceptRA = icfg.acceptRA;
          LinkLocalAddressing = "ipv6";
          DHCP = if icfg.dhcpv6 then "ipv6" else "no";
          IPv6PrivacyExtensions = if cfg.privacy == "temporary" then "yes" else "no";
        };
        
        address = icfg.addresses;
        
        # IPv6 specific settings
        ipv6AcceptRAConfig = lib.mkIf icfg.acceptRA {
          UseDNS = true;
          UseAutonomousPrefix = icfg.autoconf;
          Token = if cfg.privacy == "stable" then "static" else null;
        };
        
        dhcpV6Config = lib.mkIf icfg.dhcpv6 {
          UseDNS = true;
          UseNTP = true;
        };
      })
    ) cfg.interfaces;
    
    # IPv6 address spoofing service
    systemd.services.ipv6-spoof = lib.mkIf cfg.spoof.enable {
      description = "IPv6 Address Spoofing Service";
      after = [ "network-pre.target" ];
      before = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "ipv6-spoof-start" ''
          set -e
          
          ${lib.optionalString cfg.logChanges ''
            echo "Starting IPv6 address spoofing (mode: ${cfg.spoof.mode})" | systemd-cat -t ipv6-spoof -p info
          ''}
          
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: icfg: lib.optionalString (icfg.enable && cfg.spoof.enable) ''
            # Spoof IPv6 for ${name}
            case "${cfg.spoof.mode}" in
              random-suffix)
                # Keep prefix, randomize suffix
                prefix=$(ip -6 addr show ${name} | grep inet6 | grep -v fe80 | head -1 | awk '{print $2}' | cut -d: -f1-4)
                if [ -n "$prefix" ]; then
                  suffix=$(openssl rand -hex 8 | sed 's/\(..\)\(..\)\(..\)\(..\)/\1:\2:\3:\4/')
                  new_addr="$prefix:$suffix/64"
                  ip -6 addr add "$new_addr" dev ${name}
                  ${lib.optionalString cfg.logChanges ''
                    echo "Generated IPv6: $new_addr for ${name}" | systemd-cat -t ipv6-spoof -p info
                  ''}
                fi
                ;;
              
              fully-random)
                # Generate completely random IPv6 (ULA range)
                random_addr="fd$(openssl rand -hex 6 | sed 's/../&:/g;s/:$//')::1/64"
                ip -6 addr add "$random_addr" dev ${name}
                ${lib.optionalString cfg.logChanges ''
                  echo "Generated random IPv6: $random_addr for ${name}" | systemd-cat -t ipv6-spoof -p info
                ''}
                ;;
              
              manual)
                # Use manually configured addresses (already applied via networkd)
                echo "Using manual IPv6 configuration for ${name}" | systemd-cat -t ipv6-spoof -p info
                ;;
            esac
          '') cfg.interfaces)}
        '';
      };
    };
    
    # IPv6 randomization timer
    systemd.timers.ipv6-randomization = lib.mkIf cfg.randomize.enable {
      description = "IPv6 Address Randomization Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1h";
        OnUnitActiveSec = "${toString (cfg.randomize.intervalDays * 24)}h";
        Persistent = true;
      };
    };
    
    systemd.services.ipv6-randomization = lib.mkIf cfg.randomize.enable {
      description = "IPv6 Address Randomization Service";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "ipv6-randomize" ''
          set -e
          
          echo "Randomizing IPv6 addresses..." | systemd-cat -t ipv6-randomize -p info
          
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: icfg: lib.optionalString icfg.enable ''
            # Remove old temporary addresses
            ip -6 addr show ${name} | grep "scope global temporary" | awk '{print $2}' | while read addr; do
              ip -6 addr del "$addr" dev ${name} 2>/dev/null || true
            done
            
            # Generate new temporary address
            echo 2 > /proc/sys/net/ipv6/conf/${name}/use_tempaddr
            
            ${lib.optionalString cfg.logChanges ''
              echo "Regenerated IPv6 addresses for ${name}" | systemd-cat -t ipv6-randomize -p info
            ''}
          '') cfg.interfaces)}
        '';
      };
    };
    
    # Activation script for legal warning and backup
    system.activationScripts.ipv6-setup = lib.mkIf (isSetupPhase && cfg.spoof.enable) ''
      echo "⚠️  IPv6 Address Spoofing Enabled" >&2
      echo "   This feature modifies your IPv6 addresses." >&2
      echo "   Ensure you have proper authorization." >&2
      
      # Backup original IPv6 configuration
      mkdir -p /var/lib/hypervisor/backups
      if [ ! -f /var/lib/hypervisor/backups/original-ipv6.txt ]; then
        ip -6 addr show > /var/lib/hypervisor/backups/original-ipv6.txt
        echo "Original IPv6 configuration backed up" >&2
      fi
    '';
    
    # Monitoring and logging
    systemd.services.ipv6-monitor = lib.mkIf cfg.logChanges {
      description = "IPv6 Address Change Monitor";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStart = pkgs.writeShellScript "ipv6-monitor" ''
          #!/usr/bin/env bash
          
          # Monitor IPv6 address changes
          ip -6 monitor address | while read line; do
            echo "$line" | systemd-cat -t ipv6-monitor -p info
          done
        '';
      };
    };
    
    # Phase-aware logging
    system.activationScripts.ipv6-phase-info = ''
      echo "IPv6 Module Status:" >&2
      echo "  Phase: ${if isSetupPhase then "Setup (Permissive)" else "Hardened (Restrictive)"}" >&2
      echo "  Privacy Mode: ${cfg.privacy}" >&2
      echo "  Spoofing: ${if cfg.spoof.enable then "Enabled" else "Disabled"}" >&2
      echo "  Interfaces: ${toString (builtins.attrNames cfg.interfaces)}" >&2
    '';
  };
}
