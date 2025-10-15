{ config, lib, pkgs, ... }:

# Alert Hysteresis Module
# Prevents alert flapping with separate trigger/clear thresholds
# Learned from: Pulse monitoring system architecture
# Part of Design Ethos - Learning from reference repositories

let
  cfg = config.hypervisor.monitoring.alertHysteresis;
  
  # Define threshold type
  thresholdType = lib.types.submodule {
    options = {
      trigger = lib.mkOption {
        type = lib.types.float;
        description = "Value at which to trigger alert (e.g., 90 for 90% CPU)";
      };
      
      clear = lib.mkOption {
        type = lib.types.float;
        description = "Value at which to clear alert (e.g., 75 for 75% CPU, must be lower than trigger)";
      };
      
      delay = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "Delay before triggering alert (prevents transient spikes)";
        example = "5m";
      };
      
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this threshold is active";
      };
    };
  };
  
in {
  options.hypervisor.monitoring.alertHysteresis = {
    enable = lib.mkEnableOption "alert hysteresis (prevents alert flapping)";
    
    cpu = lib.mkOption {
      type = thresholdType;
      default = {
        trigger = 90.0;
        clear = 75.0;
        delay = "5m";
        enabled = true;
      };
      description = ''
        CPU usage alert thresholds with hysteresis.
        Alert triggers at 90%, clears at 75% to prevent flapping.
      '';
    };
    
    memory = lib.mkOption {
      type = thresholdType;
      default = {
        trigger = 85.0;
        clear = 70.0;
        delay = "5m";
        enabled = true;
      };
      description = ''
        Memory usage alert thresholds with hysteresis.
        Alert triggers at 85%, clears at 70%.
      '';
    };
    
    disk = lib.mkOption {
      type = thresholdType;
      default = {
        trigger = 85.0;
        clear = 75.0;
        delay = "10m";
        enabled = true;
      };
      description = ''
        Disk usage alert thresholds with hysteresis.
        Alert triggers at 85%, clears at 75%.
        Longer delay since disk usage changes slowly.
      '';
    };
    
    network = lib.mkOption {
      type = thresholdType;
      default = {
        trigger = 80.0;
        clear = 60.0;
        delay = "2m";
        enabled = true;
      };
      description = ''
        Network usage alert thresholds with hysteresis.
        Alert triggers at 80%, clears at 60%.
        Shorter delay for network issues.
      '';
    };
    
    vmDown = lib.mkOption {
      type = lib.types.submodule {
        options = {
          delay = lib.mkOption {
            type = lib.types.str;
            default = "1m";
            description = "Delay before alerting on VM down (prevents restart alerts)";
          };
          
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to alert on VM down";
          };
        };
      };
      default = {
        delay = "1m";
        enabled = true;
      };
      description = "VM down alert configuration with delay";
    };
    
    quietHours = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable quiet hours (suppress non-critical alerts)";
          };
          
          start = lib.mkOption {
            type = lib.types.str;
            default = "22:00";
            description = "Quiet hours start time (24h format)";
            example = "22:00";
          };
          
          end = lib.mkOption {
            type = lib.types.str;
            default = "08:00";
            description = "Quiet hours end time (24h format)";
            example = "08:00";
          };
          
          allowCritical = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Allow critical alerts during quiet hours";
          };
        };
      };
      default = {
        enable = false;
        start = "22:00";
        end = "08:00";
        allowCritical = true;
      };
      description = "Quiet hours configuration for alert suppression";
    };
    
    configFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/hypervisor/alert-thresholds.json";
      description = "Path to alert thresholds configuration file";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Create alert thresholds configuration
    environment.etc."hypervisor/alert-thresholds.json" = {
      text = builtins.toJSON {
        version = "1.0";
        hysteresis_enabled = true;
        
        thresholds = {
          cpu = {
            trigger = cfg.cpu.trigger;
            clear = cfg.cpu.clear;
            delay = cfg.cpu.delay;
            enabled = cfg.cpu.enabled;
          };
          
          memory = {
            trigger = cfg.memory.trigger;
            clear = cfg.memory.clear;
            delay = cfg.memory.delay;
            enabled = cfg.memory.enabled;
          };
          
          disk = {
            trigger = cfg.disk.trigger;
            clear = cfg.disk.clear;
            delay = cfg.disk.delay;
            enabled = cfg.disk.enabled;
          };
          
          network = {
            trigger = cfg.network.trigger;
            clear = cfg.network.clear;
            delay = cfg.network.delay;
            enabled = cfg.network.enabled;
          };
          
          vm_down = {
            delay = cfg.vmDown.delay;
            enabled = cfg.vmDown.enabled;
          };
        };
        
        quiet_hours = lib.mkIf cfg.quietHours.enable {
          enabled = cfg.quietHours.enable;
          start = cfg.quietHours.start;
          end = cfg.quietHours.end;
          allow_critical = cfg.quietHours.allowCritical;
        };
      };
      
      mode = "0644";
    };
    
    # Install hysteresis alert checker script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "hv-check-alerts" ''
        #!/usr/bin/env bash
        # Alert checker with hysteresis support
        # Reads thresholds from ${cfg.configFile}
        
        CONFIG="${cfg.configFile}"
        STATE_DIR="/var/lib/hypervisor/alert-state"
        mkdir -p "$STATE_DIR"
        
        # Load thresholds
        if [ ! -f "$CONFIG" ]; then
          echo "Error: Alert configuration not found: $CONFIG" >&2
          exit 1
        fi
        
        # Check CPU
        check_metric() {
          local metric=$1
          local current=$2
          
          local trigger=$(jq -r ".thresholds.$metric.trigger" "$CONFIG")
          local clear=$(jq -r ".thresholds.$metric.clear" "$CONFIG")
          local enabled=$(jq -r ".thresholds.$metric.enabled" "$CONFIG")
          
          [ "$enabled" = "false" ] && return 0
          
          local state_file="$STATE_DIR/$metric.state"
          local current_state="normal"
          [ -f "$state_file" ] && current_state=$(cat "$state_file")
          
          # Hysteresis logic
          if [ "$current_state" = "normal" ]; then
            if (( $(echo "$current > $trigger" | bc -l) )); then
              echo "alert" > "$state_file"
              echo "ALERT: $metric at $current% (trigger: $trigger%)"
              return 1
            fi
          else
            if (( $(echo "$current < $clear" | bc -l) )); then
              echo "normal" > "$state_file"
              echo "CLEAR: $metric at $current% (clear: $clear%)"
            else
              echo "CONTINUING: $metric at $current% (still above clear: $clear%)"
            fi
          fi
          
          return 0
        }
        
        # Example usage
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        check_metric "cpu" "$CPU_USAGE"
      '')
    ];
  };
}
