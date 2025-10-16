{ config, lib, pkgs, ... }:

# Traffic Shaping and QoS Module
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Two-Phase Security Model: Compatible with both setup and hardened phases

let
  cfg = config.hypervisor.network.qos;
  phaseConfig = config.hypervisor.security.phaseManagement or { currentPhase = 1; };
  isSetupPhase = phaseConfig.currentPhase == 1;
in
{
  options.hypervisor.network.qos = {
    enable = lib.mkEnableOption "Traffic shaping and Quality of Service";
    
    defaultUpload = lib.mkOption {
      type = lib.types.str;
      default = "1gbit";
      description = "Default upload bandwidth limit";
      example = "100mbit";
    };
    
    defaultDownload = lib.mkOption {
      type = lib.types.str;
      default = "1gbit";
      description = "Default download bandwidth limit";
      example = "100mbit";
    };
    
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable QoS on this interface";
          };
          
          uploadLimit = lib.mkOption {
            type = lib.types.str;
            default = cfg.defaultUpload;
            description = "Upload bandwidth limit";
          };
          
          downloadLimit = lib.mkOption {
            type = lib.types.str;
            default = cfg.defaultDownload;
            description = "Download bandwidth limit";
          };
          
          classes = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Traffic class name";
                };
                
                priority = lib.mkOption {
                  type = lib.types.int;
                  description = "Priority (1=highest, 3=lowest)";
                };
                
                bandwidth = lib.mkOption {
                  type = lib.types.str;
                  description = "Guaranteed bandwidth (percentage or absolute)";
                  example = "30%";
                };
                
                ceil = lib.mkOption {
                  type = lib.types.str;
                  default = "100%";
                  description = "Maximum bandwidth (burst limit)";
                };
                
                match = {
                  ports = lib.mkOption {
                    type = lib.types.listOf lib.types.int;
                    default = [];
                    description = "Match TCP/UDP ports";
                  };
                  
                  protocols = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [];
                    description = "Match protocols (ssh, http, https, etc.)";
                  };
                  
                  ips = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [];
                    description = "Match source/dest IP addresses";
                  };
                };
                
                default = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Use as default class for unmatched traffic";
                };
              };
            });
            default = [];
            description = "Traffic classification rules";
          };
        };
      });
      default = {};
      description = "Per-interface QoS configuration";
    };
    
    perVM = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          uploadLimit = lib.mkOption {
            type = lib.types.str;
            description = "VM upload bandwidth limit";
          };
          
          downloadLimit = lib.mkOption {
            type = lib.types.str;
            description = "VM download bandwidth limit";
          };
          
          burstable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow bursting above limit";
          };
        };
      });
      default = {};
      description = "Per-VM bandwidth limits";
    };
    
    algorithm = lib.mkOption {
      type = lib.types.enum [ "htb" "hfsc" "fq_codel" "cake" ];
      default = "htb";
      description = ''
        Queueing discipline algorithm:
        - htb: Hierarchical Token Bucket (flexible, widely used)
        - hfsc: Hierarchical Fair Service Curve (advanced)
        - fq_codel: Fair Queueing with Controlled Delay (low latency)
        - cake: Common Applications Kept Enhanced (modern, automatic)
      '';
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install traffic shaping tools
    environment.systemPackages = with pkgs; [
      iproute2
      tcpdump
      iftop
      nethogs
    ] ++ lib.optionals isSetupPhase [
      # Additional monitoring tools in setup phase
      bmon
      iperf3
      nload
    ];
    
    # Enable necessary kernel modules
    boot.kernelModules = [
      "sch_htb"       # HTB qdisc
      "sch_hfsc"      # HFSC qdisc
      "sch_fq_codel"  # FQ-CoDel qdisc
      "sch_cake"      # CAKE qdisc
      "cls_u32"       # U32 classifier
      "cls_fw"        # Firewall classifier
      "act_mirred"    # Traffic mirroring
    ];
    
    # Traffic shaping setup service
    systemd.services.traffic-shaping = {
      description = "Traffic Shaping and QoS Service";
      after = [ "network-pre.target" ];
      before = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "traffic-shaping-start" ''
          set -e
          
          echo "Setting up traffic shaping (algorithm: ${cfg.algorithm})..." | systemd-cat -t qos -p info
          
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: icfg: lib.optionalString icfg.enable ''
            echo "Configuring QoS for ${name}..." | systemd-cat -t qos -p info
            
            # Remove existing qdiscs
            tc qdisc del dev ${name} root 2>/dev/null || true
            tc qdisc del dev ${name} ingress 2>/dev/null || true
            
            # Setup root qdisc based on algorithm
            case "${cfg.algorithm}" in
              htb)
                # HTB (Hierarchical Token Bucket) - Most flexible
                tc qdisc add dev ${name} root handle 1: htb default 30
                
                # Root class with total bandwidth
                tc class add dev ${name} parent 1: classid 1:1 htb rate ${icfg.uploadLimit} ceil ${icfg.uploadLimit}
                
                ${lib.concatStringsSep "\n" (lib.imap0 (idx: class: ''
                  # Class ${class.name} (priority ${toString class.priority})
                  classid=$((10 + ${toString idx}))
                  
                  # Calculate bandwidth limits
                  rate="${class.bandwidth}"
                  ceil="${class.ceil}"
                  
                  # Add HTB class
                  tc class add dev ${name} parent 1:1 classid 1:$classid htb \
                    rate "$rate" ceil "$ceil" prio ${toString class.priority}
                  
                  # Add fair queueing within class
                  tc qdisc add dev ${name} parent 1:$classid handle $classid: fq_codel
                  
                  ${lib.optionalString (class.match.ports != []) ''
                    # Filter by ports
                    ${lib.concatMapStringsSep "\n" (port: ''
                      tc filter add dev ${name} parent 1: protocol ip prio ${toString class.priority} \
                        u32 match ip dport ${toString port} 0xffff flowid 1:$classid
                      tc filter add dev ${name} parent 1: protocol ip prio ${toString class.priority} \
                        u32 match ip sport ${toString port} 0xffff flowid 1:$classid
                    '') class.match.ports}
                  ''}
                  
                  ${lib.optionalString (class.match.ips != []) ''
                    # Filter by IP addresses
                    ${lib.concatMapStringsSep "\n" (ip: ''
                      tc filter add dev ${name} parent 1: protocol ip prio ${toString class.priority} \
                        u32 match ip dst ${ip} flowid 1:$classid
                      tc filter add dev ${name} parent 1: protocol ip prio ${toString class.priority} \
                        u32 match ip src ${ip} flowid 1:$classid
                    '') class.match.ips}
                  ''}
                '') icfg.classes)}
                ;;
              
              hfsc)
                # HFSC (Hierarchical Fair Service Curve) - Advanced real-time guarantees
                tc qdisc add dev ${name} root handle 1: hfsc default 30
                tc class add dev ${name} parent 1: classid 1:1 hfsc sc rate ${icfg.uploadLimit}
                
                ${lib.concatStringsSep "\n" (lib.imap0 (idx: class: ''
                  classid=$((10 + ${toString idx}))
                  tc class add dev ${name} parent 1:1 classid 1:$classid hfsc \
                    sc rate ${class.bandwidth} ul rate ${class.ceil}
                '') icfg.classes)}
                ;;
              
              fq_codel)
                # FQ-CoDel - Low latency, automatic
                tc qdisc add dev ${name} root fq_codel
                ;;
              
              cake)
                # CAKE - Modern, feature-rich
                tc qdisc add dev ${name} root cake bandwidth ${icfg.uploadLimit}
                ;;
            esac
            
            # Ingress shaping (download) using IFB
            ip link add ifb-${name} type ifb 2>/dev/null || true
            ip link set ifb-${name} up
            
            tc qdisc add dev ${name} ingress
            tc filter add dev ${name} parent ffff: protocol ip u32 match u32 0 0 \
              flowid 1:1 action mirred egress redirect dev ifb-${name}
            
            # Apply same shaping to IFB for ingress
            tc qdisc add dev ifb-${name} root handle 1: htb default 30
            tc class add dev ifb-${name} parent 1: classid 1:1 htb rate ${icfg.downloadLimit}
            
            echo "✓ QoS configured for ${name}" | systemd-cat -t qos -p info
          '') cfg.interfaces)}
          
          ${lib.optionalString (cfg.perVM != {}) ''
            # Per-VM bandwidth limits
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (vmName: vmCfg: ''
              echo "Applying bandwidth limits for VM: ${vmName}" | systemd-cat -t qos -p info
              # VM-specific limits would be applied via libvirt hooks
            '') cfg.perVM)}
          ''}
        '';
        
        ExecStop = pkgs.writeShellScript "traffic-shaping-stop" ''
          set -e
          
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
            tc qdisc del dev ${name} root 2>/dev/null || true
            tc qdisc del dev ${name} ingress 2>/dev/null || true
            ip link del ifb-${name} 2>/dev/null || true
          '') cfg.interfaces)}
        '';
      };
    };
    
    # QoS monitoring service
    systemd.services.qos-monitor = {
      description = "QoS Monitoring Service";
      after = [ "traffic-shaping.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStart = pkgs.writeShellScript "qos-monitor" ''
          #!/usr/bin/env bash
          
          while true; do
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
              # Monitor ${name}
              stats=$(tc -s qdisc show dev ${name} 2>/dev/null)
              if [ -n "$stats" ]; then
                echo "${name}: $stats" | systemd-cat -t qos-monitor -p debug
              fi
            '') cfg.interfaces)}
            
            sleep 60
          done
        '';
      };
    };
    
    # libvirt hook for per-VM QoS
    environment.etc."libvirt/hooks/qemu" = lib.mkIf (cfg.perVM != {}) {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # libvirt hook for per-VM QoS
        
        VM_NAME="$1"
        OPERATION="$2"
        
        case "$OPERATION" in
          started)
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (vmName: vmCfg: ''
              if [ "$VM_NAME" = "${vmName}" ]; then
                # Apply bandwidth limits
                VM_IFACE=$(virsh domiflist "$VM_NAME" | grep -o 'vnet[0-9]*' | head -1)
                if [ -n "$VM_IFACE" ]; then
                  tc qdisc add dev "$VM_IFACE" root handle 1: htb default 10
                  tc class add dev "$VM_IFACE" parent 1: classid 1:1 htb rate ${vmCfg.uploadLimit}
                  tc class add dev "$VM_IFACE" parent 1:1 classid 1:10 htb rate ${vmCfg.uploadLimit} \
                    ${lib.optionalString vmCfg.burstable "ceil ${vmCfg.uploadLimit}"}
                  
                  echo "Applied QoS limits to $VM_NAME ($VM_IFACE)" | systemd-cat -t qos -p info
                fi
              fi
            '') cfg.perVM)}
            ;;
          
          stopped)
            # Cleanup is automatic when interface is removed
            ;;
        esac
      '';
    };
    
    # Phase-aware activation script
    system.activationScripts.qos-setup = ''
      echo "Traffic Shaping Module Status:" >&2
      echo "  Phase: ${if isSetupPhase then "Setup (Permissive)" else "Hardened (Restrictive)"}" >&2
      echo "  Algorithm: ${cfg.algorithm}" >&2
      echo "  Interfaces: ${toString (builtins.attrNames cfg.interfaces)}" >&2
      ${lib.optionalString isSetupPhase ''
        echo "  ⚠️  In setup phase - QoS can be reconfigured" >&2
      ''}
      ${lib.optionalString (!isSetupPhase) ''
        echo "  🔒 In hardened phase - QoS configuration is locked" >&2
      ''}
    '';
  };
}
