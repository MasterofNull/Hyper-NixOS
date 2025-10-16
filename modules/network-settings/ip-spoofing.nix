{ config, lib, pkgs, ... }:

# IP Address Management and Spoofing Module
# Provides IP aliasing, rotation, and dynamic addressing capabilities
# ⚠️ WARNING: Use only for legitimate purposes (testing, load balancing, authorized pentesting)

let
  cfg = config.hypervisor.network.ipSpoof;
in
{
  options.hypervisor.network.ipSpoof = {
    enable = lib.mkEnableOption "IP address management and spoofing capabilities";
    
    mode = lib.mkOption {
      type = lib.types.enum [ "alias" "rotation" "dynamic" "proxy" "disabled" ];
      default = "disabled";
      description = ''
        IP management mode:
        - alias: Add multiple IP aliases to interfaces
        - rotation: Rotate through a pool of IPs periodically
        - dynamic: Generate random IPs within specified ranges
        - proxy: Route through proxy chains
        - disabled: No IP manipulation
      '';
    };
    
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable IP management for this interface";
          };
          
          aliases = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "List of IP addresses to add as aliases";
            example = [ "192.168.1.100/24" "192.168.1.101/24" ];
          };
          
          ipPool = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Pool of IPs to rotate through";
            example = [ "10.0.0.100" "10.0.0.101" "10.0.0.102" ];
          };
          
          dynamicRange = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "CIDR range for dynamic IP generation";
            example = "10.0.0.0/24";
          };
          
          rotationInterval = lib.mkOption {
            type = lib.types.int;
            default = 3600;
            description = "Seconds between IP rotations (for rotation mode)";
          };
        };
      });
      default = {};
      description = "Per-interface IP management configuration";
    };
    
    proxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable proxy chain routing";
      };
      
      proxies = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            type = lib.mkOption {
              type = lib.types.enum [ "socks5" "http" "https" ];
              description = "Proxy type";
            };
            host = lib.mkOption {
              type = lib.types.str;
              description = "Proxy host";
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "Proxy port";
            };
            username = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Proxy username";
            };
            password = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Proxy password";
            };
          };
        });
        default = [];
        description = "List of proxies to chain";
      };
      
      randomizeOrder = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Randomize proxy chain order";
      };
    };
    
    logChanges = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Log IP address changes to system journal";
    };
    
    avoidConflicts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically detect and avoid IP conflicts";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install IP management utilities
    environment.systemPackages = with pkgs; [
      iproute2
      iputils
      nmap
      proxychains-ng
    ];
    
    # IP alias management service
    systemd.services.ip-alias = lib.mkIf (cfg.mode == "alias") {
      description = "IP Address Alias Management";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "ip-alias-start" ''
          set -e
          
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (interface: icfg:
            lib.optionalString (icfg.enable && icfg.aliases != []) ''
              echo "Adding IP aliases to ${interface}..."
              
              ${lib.concatMapStringsSep "\n" (alias: ''
                # Add alias ${alias}
                ip addr add ${alias} dev ${interface} || echo "Warning: Could not add ${alias}"
                ${if cfg.logChanges then ''
                  echo "[$(date -Iseconds)] Added IP alias ${alias} to ${interface}" | \
                    systemd-cat -t ip-spoof -p info
                '' else ""}
              '') icfg.aliases}
            ''
          ) cfg.interfaces)}
          
          echo "IP aliases configured"
        '';
        
        ExecStop = pkgs.writeShellScript "ip-alias-stop" ''
          # Remove aliases on stop
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (interface: icfg:
            lib.optionalString (icfg.enable && icfg.aliases != []) ''
              ${lib.concatMapStringsSep "\n" (alias: ''
                ip addr del ${alias} dev ${interface} 2>/dev/null || true
              '') icfg.aliases}
            ''
          ) cfg.interfaces)}
        '';
      };
    };
    
    # IP rotation service
    systemd.services.ip-rotation = lib.mkIf (cfg.mode == "rotation") {
      description = "IP Address Rotation Service";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 10;
        ExecStart = pkgs.writeShellScript "ip-rotation" ''
          set -e
          
          rotate_ip() {
            local interface="$1"
            shift
            local ip_pool=("$@")
            
            if [ ''${#ip_pool[@]} -eq 0 ]; then
              echo "No IPs in pool for $interface"
              return
            fi
            
            # Select random IP from pool
            local random_ip="''${ip_pool[$RANDOM % ''${#ip_pool[@]}]}"
            
            # Remove current secondary IPs
            ip addr show "$interface" | grep "inet " | grep secondary | \
              awk '{print $2}' | while read -r ip; do
              ip addr del "$ip" dev "$interface" 2>/dev/null || true
            done
            
            # Add new IP
            ip addr add "$random_ip" dev "$interface" 2>/dev/null || true
            
            ${if cfg.logChanges then ''
              echo "[$(date -Iseconds)] Rotated IP on $interface to $random_ip" | \
                systemd-cat -t ip-rotation -p info
            '' else ""}
            
            echo "Rotated to IP: $random_ip on $interface"
          }
          
          while true; do
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (interface: icfg:
              lib.optionalString (icfg.enable && icfg.ipPool != []) ''
                rotate_ip "${interface}" ${lib.concatStringsSep " " icfg.ipPool}
                sleep ${toString icfg.rotationInterval}
              ''
            ) cfg.interfaces)}
            
            sleep 60
          done
        '';
      };
    };
    
    # Proxy chain configuration
    environment.etc."proxychains/proxychains.conf" = lib.mkIf cfg.proxy.enable {
      text = ''
        # ProxyChains configuration generated by Hyper-NixOS
        # ⚠️  Use only for legitimate purposes
        
        strict_chain
        proxy_dns
        tcp_read_time_out 15000
        tcp_connect_time_out 8000
        
        ${if cfg.proxy.randomizeOrder then "random_chain" else ""}
        
        [ProxyList]
        ${lib.concatMapStringsSep "\n" (proxy: 
          "${proxy.type} ${proxy.host} ${toString proxy.port}" + 
          (if proxy.username != null && proxy.password != null 
           then " ${proxy.username} ${proxy.password}" 
           else "")
        ) cfg.proxy.proxies}
      '';
    };
    
    # Warning in system logs
    system.activationScripts.ip-spoof-warning = lib.mkIf cfg.enable ''
      echo "⚠️  IP Address Management/Spoofing is ENABLED" | systemd-cat -t ip-spoof -p warning
      echo "⚠️  Use only for legitimate purposes (testing, load balancing, authorized security research)" | systemd-cat -t ip-spoof -p warning
      echo "⚠️  Unauthorized IP spoofing may violate network policies or laws" | systemd-cat -t ip-spoof -p warning
      echo "⚠️  May cause network connectivity issues if misconfigured" | systemd-cat -t ip-spoof -p warning
    '';
  };
}
