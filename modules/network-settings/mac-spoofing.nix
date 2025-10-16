{ config, lib, pkgs, ... }:

# MAC Address Spoofing Module
# Provides MAC address randomization and spoofing capabilities
# ⚠️ WARNING: Use only for legitimate purposes (privacy, testing, authorized pentesting)

let
  cfg = config.hypervisor.network.macSpoof;
in
{
  options.hypervisor.network.macSpoof = {
    enable = lib.mkEnableOption "MAC address spoofing capabilities";
    
    mode = lib.mkOption {
      type = lib.types.enum [ "manual" "random" "vendor-preserve" "disabled" ];
      default = "disabled";
      description = ''
        MAC spoofing mode:
        - manual: Use manually specified MAC addresses
        - random: Generate fully random MAC addresses on boot
        - vendor-preserve: Keep vendor prefix, randomize device part
        - disabled: No MAC spoofing
      '';
    };
    
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable MAC spoofing for this interface";
          };
          
          macAddress = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Manually specified MAC address (for manual mode)";
          };
          
          vendorPrefix = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Vendor OUI prefix to preserve (for vendor-preserve mode)";
          };
          
          randomizeOnBoot = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Generate new random MAC on each boot";
          };
        };
      });
      default = {};
      description = "Per-interface MAC spoofing configuration";
    };
    
    logChanges = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Log MAC address changes to system journal";
    };
    
    persistMACs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Store generated MACs in /var/lib/hypervisor/mac-spoof/";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install MAC spoofing utilities
    environment.systemPackages = with pkgs; [
      macchanger
      ethtool
      iproute2
    ];
    
    # Create MAC spoofing service
    systemd.services.mac-spoof = {
      description = "MAC Address Spoofing Service";
      after = [ "network-pre.target" ];
      before = [ "network.target" ];
      wants = [ "network-pre.target" ];
      wantedBy = [ "multi-user.target" ];
      
      path = with pkgs; [ macchanger iproute2 coreutils gnugrep gawk ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "mac-spoof-start" ''
          set -e
          
          # Function to generate random MAC
          generate_random_mac() {
            local prefix="$1"
            if [ -n "$prefix" ]; then
              # Preserve vendor prefix
              local suffix=$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' ')
              echo "$prefix:$suffix" | sed 's/\(..\)/\1:/g' | sed 's/:$//'
            else
              # Fully random MAC
              macchanger -r "$interface" 2>/dev/null | grep "New MAC" | awk '{print $3}'
            fi
          }
          
          # Log function
          log_mac_change() {
            local interface="$1"
            local old_mac="$2"
            local new_mac="$3"
            ${if cfg.logChanges then ''
              echo "[$(date -Iseconds)] MAC changed on $interface: $old_mac → $new_mac" | \
                systemd-cat -t mac-spoof -p info
            '' else ""}
          }
          
          # Storage directory
          MAC_STORAGE="/var/lib/hypervisor/mac-spoof"
          ${if cfg.persistMACs then ''
            mkdir -p "$MAC_STORAGE"
            chmod 700 "$MAC_STORAGE"
          '' else ""}
          
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (interface: icfg: 
            lib.optionalString icfg.enable ''
              # Process interface: ${interface}
              echo "Processing ${interface}..."
              
              # Get current MAC
              CURRENT_MAC=$(ip link show ${interface} 2>/dev/null | grep link/ether | awk '{print $2}' || echo "")
              
              if [ -z "$CURRENT_MAC" ]; then
                echo "Warning: Interface ${interface} not found, skipping..."
              else
                # Bring interface down
                ip link set ${interface} down
                
                NEW_MAC=""
                
                ${if icfg.macAddress != null then ''
                  # Manual mode: Use specified MAC
                  NEW_MAC="${icfg.macAddress}"
                  ip link set dev ${interface} address "$NEW_MAC"
                '' else if icfg.vendorPrefix != null then ''
                  # Vendor-preserve mode
                  NEW_MAC=$(generate_random_mac "${icfg.vendorPrefix}")
                  ip link set dev ${interface} address "$NEW_MAC"
                '' else if cfg.mode == "random" || icfg.randomizeOnBoot then ''
                  # Check if we have a stored MAC and not randomizeOnBoot
                  ${if cfg.persistMACs && !icfg.randomizeOnBoot then ''
                    if [ -f "$MAC_STORAGE/${interface}" ]; then
                      NEW_MAC=$(cat "$MAC_STORAGE/${interface}")
                      ip link set dev ${interface} address "$NEW_MAC"
                    else
                      # Generate new random MAC
                      macchanger -r ${interface} >/dev/null 2>&1
                      NEW_MAC=$(ip link show ${interface} | grep link/ether | awk '{print $2}')
                      echo "$NEW_MAC" > "$MAC_STORAGE/${interface}"
                    fi
                  '' else ''
                    # Generate new random MAC
                    macchanger -r ${interface} >/dev/null 2>&1
                    NEW_MAC=$(ip link show ${interface} | grep link/ether | awk '{print $2}')
                    ${if cfg.persistMACs then ''
                      echo "$NEW_MAC" > "$MAC_STORAGE/${interface}"
                    '' else ""}
                  ''}
                '' else ''
                  # No change mode
                  NEW_MAC="$CURRENT_MAC"
                ''}
                
                # Bring interface back up
                ip link set ${interface} up
                
                # Log the change
                log_mac_change "${interface}" "$CURRENT_MAC" "$NEW_MAC"
                
                echo "MAC address on ${interface}: $CURRENT_MAC → $NEW_MAC"
              fi
            ''
          ) cfg.interfaces)}
          
          echo "MAC spoofing completed"
        '';
        
        ExecStop = pkgs.writeShellScript "mac-spoof-stop" ''
          # Restore original MAC addresses on stop (optional)
          echo "MAC spoofing service stopped"
          # Note: Original MACs are restored on reboot automatically
        '';
      };
    };
    
    # Storage directory for persistent MACs
    systemd.tmpfiles.rules = lib.mkIf cfg.persistMACs [
      "d /var/lib/hypervisor/mac-spoof 0700 root root - -"
    ];
    
    # Warning in system logs
    system.activationScripts.mac-spoof-warning = lib.mkIf cfg.enable ''
      echo "⚠️  MAC Address Spoofing is ENABLED" | systemd-cat -t mac-spoof -p warning
      echo "⚠️  Use only for legitimate purposes (privacy, testing, authorized security research)" | systemd-cat -t mac-spoof -p warning
      echo "⚠️  Unauthorized MAC spoofing may violate network policies or laws" | systemd-cat -t mac-spoof -p warning
    '';
  };
}
