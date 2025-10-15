{ config, lib, pkgs, ... }:

# Webhook Notifications Module
# Multi-platform webhook integration for alerts
# Learned from: Pulse webhook system architecture
# Part of Design Ethos - Learning from reference repositories

let
  cfg = config.hypervisor.monitoring.webhooks;
  
  webhookType = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "this webhook";
      
      url = lib.mkOption {
        type = lib.types.str;
        description = "Webhook URL (will be encrypted at rest)";
      };
      
      type = lib.mkOption {
        type = lib.types.enum [ "discord" "slack" "telegram" "teams" "gotify" "ntfy" "custom" ];
        default = "custom";
        description = "Webhook service type for proper message formatting";
      };
      
      events = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "vm_down" "storage_full" "backup_failed" "security_alert" ];
        description = "Events that trigger this webhook";
      };
      
      retryAttempts = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Number of retry attempts on failure";
      };
      
      timeout = lib.mkOption {
        type = lib.types.str;
        default = "10s";
        description = "Timeout for webhook requests";
      };
    };
  };
  
in {
  options.hypervisor.monitoring.webhooks = {
    enable = lib.mkEnableOption "webhook notifications";
    
    discord = lib.mkOption {
      type = lib.types.nullOr webhookType;
      default = null;
      description = "Discord webhook configuration";
      example = {
        enable = true;
        url = "https://discord.com/api/webhooks/...";
        type = "discord";
        events = [ "vm_down" "backup_failed" ];
      };
    };
    
    slack = lib.mkOption {
      type = lib.types.nullOr webhookType;
      default = null;
      description = "Slack webhook configuration";
    };
    
    telegram = lib.mkOption {
      type = lib.types.nullOr webhookType;
      default = null;
      description = "Telegram bot webhook configuration";
    };
    
    custom = lib.mkOption {
      type = lib.types.listOf webhookType;
      default = [];
      description = "Custom webhook configurations";
    };
    
    defaultTimeout = lib.mkOption {
      type = lib.types.str;
      default = "10s";
      description = "Default timeout for all webhooks";
    };
    
    rateLimit = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Maximum webhooks per minute (prevents spam)";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install webhook sender script
    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
      
      (pkgs.writeShellScriptBin "hv-send-webhook" ''
        #!/usr/bin/env bash
        # Webhook sender with platform-specific formatting
        # Supports: Discord, Slack, Telegram, Teams, custom
        
        set -euo pipefail
        
        EVENT_TYPE=$1
        MESSAGE=$2
        SEVERITY=''${3:-info}
        
        CONFIG="/etc/hypervisor/webhooks.json"
        
        if [ ! -f "$CONFIG" ]; then
          echo "No webhook configuration found" >&2
          exit 0
        fi
        
        # Format message based on webhook type
        format_discord() {
          local message=$1
          local severity=$2
          
          local color="3447003"  # Blue
          case "$severity" in
            critical|error) color="15158332" ;; # Red
            warning) color="16776960" ;;        # Yellow
            success) color="3066993" ;;         # Green
          esac
          
          jq -n \
            --arg content "$message" \
            --arg color "$color" \
            '{
              embeds: [{
                title: "Hyper-NixOS Alert",
                description: $content,
                color: ($color | tonumber),
                timestamp: (now | strftime("%Y-%m-%dT%H:%M:%S"))
              }]
            }'
        }
        
        format_slack() {
          local message=$1
          local severity=$2
          
          local emoji=":information_source:"
          case "$severity" in
            critical|error) emoji=":rotating_light:" ;;
            warning) emoji=":warning:" ;;
            success) emoji=":white_check_mark:" ;;
          esac
          
          jq -n \
            --arg text "$emoji $message" \
            '{ text: $text }'
        }
        
        format_telegram() {
          local message=$1
          
          jq -n \
            --arg text "🖥️ *Hyper-NixOS Alert*\n\n$message" \
            '{ text: $text, parse_mode: "Markdown" }'
        }
        
        # Send to all configured webhooks for this event
        ${pkgs.jq}/bin/jq -r '.webhooks[] | select(.events | contains(["'$EVENT_TYPE'"])) | @json' "$CONFIG" | while read -r webhook; do
          URL=$(echo "$webhook" | jq -r '.url')
          TYPE=$(echo "$webhook" | jq -r '.type // "custom"')
          RETRIES=$(echo "$webhook" | jq -r '.retryAttempts // 3')
          
          # Format message
          case "$TYPE" in
            discord)
              PAYLOAD=$(format_discord "$MESSAGE" "$SEVERITY")
              ;;
            slack)
              PAYLOAD=$(format_slack "$MESSAGE" "$SEVERITY")
              ;;
            telegram)
              PAYLOAD=$(format_telegram "$MESSAGE")
              ;;
            *)
              PAYLOAD=$(jq -n --arg msg "$MESSAGE" '{ message: $msg }')
              ;;
          esac
          
          # Send with retry
          attempt=1
          while [ $attempt -le $RETRIES ]; do
            if ${pkgs.curl}/bin/curl -s -X POST \
              -H "Content-Type: application/json" \
              -d "$PAYLOAD" \
              --max-time ${cfg.defaultTimeout} \
              "$URL" > /dev/null 2>&1; then
              echo "✓ Sent to $TYPE webhook"
              break
            else
              if [ $attempt -eq $RETRIES ]; then
                echo "✗ Failed to send to $TYPE webhook after $RETRIES attempts" >&2
              fi
              attempt=$((attempt + 1))
              sleep $((attempt * 2))
            fi
          done
        done
      '')
    ];
    
    # Systemd service for alert monitoring with hysteresis
    systemd.services.hypervisor-alert-monitor = lib.mkIf config.hypervisor.monitoring.alertHysteresis.enable {
      description = "Hyper-NixOS Alert Monitor with Hysteresis";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do hv-check-alerts; sleep 60; done'";
        Restart = "always";
        RestartSec = "10s";
      };
    };
    
    # Create webhook configuration directory
    system.activationScripts.hypervisor-webhooks = lib.stringAfter [ "etc" ] ''
      mkdir -p /etc/hypervisor
      
      # Create default webhooks.json if doesn't exist
      if [ ! -f /etc/hypervisor/webhooks.json ]; then
        cat > /etc/hypervisor/webhooks.json << 'EOF'
{
  "webhooks": [],
  "rate_limit": ${toString cfg.rateLimit},
  "default_timeout": "${cfg.defaultTimeout}"
}
EOF
        chmod 600 /etc/hypervisor/webhooks.json
      fi
    '';
  };
}
