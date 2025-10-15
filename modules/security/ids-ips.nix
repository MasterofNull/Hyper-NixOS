{ config, lib, pkgs, ... }:

# Intrusion Detection/Prevention System Module
# Provides Suricata-based network security monitoring

let
  cfg = config.hypervisor.security.idsIps;
in
{
  options.hypervisor.security.idsIps = {
    enable = lib.mkEnableOption "intrusion detection and prevention system";
    
    mode = lib.mkOption {
      type = lib.types.enum [ "ids" "ips" ];
      default = "ids";
      description = "Operating mode: IDS (detection only) or IPS (prevention)";
    };
    
    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "eth0" ];
      description = "Network interfaces to monitor";
    };
    
    rulesets = {
      emerging-threats = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Emerging Threats ruleset";
      };
      
      custom = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Custom Suricata rules";
      };
    };
    
    logging = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable detailed logging";
      };
      
      logFormat = lib.mkOption {
        type = lib.types.enum [ "json" "syslog" "both" ];
        default = "json";
        description = "Log output format";
      };
    };
    
    alerting = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable real-time alerting";
      };
      
      threshold = lib.mkOption {
        type = lib.types.enum [ "low" "medium" "high" ];
        default = "medium";
        description = "Alert threshold sensitivity";
      };
    };
    
    performance = {
      threads = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Number of worker threads";
      };
      
      memcap = lib.mkOption {
        type = lib.types.str;
        default = "256mb";
        description = "Memory cap for Suricata";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Suricata IDS/IPS
    services.suricata = {
      enable = true;
      
      settings = {
        vars = {
          address-groups = {
            HOME_NET = "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]";
            EXTERNAL_NET = "!$HOME_NET";
          };
        };
        
        # Performance tuning
        threading = {
          set-cpu-affinity = true;
          detect-thread-ratio = cfg.performance.threads;
        };
        
        # Capture settings
        af-packet = map (iface: {
          interface = iface;
          threads = cfg.performance.threads;
          defrag = true;
          use-mmap = true;
        }) cfg.interfaces;
        
        # Logging configuration
        outputs = lib.mkMerge [
          (lib.mkIf (cfg.logging.enable && (cfg.logging.logFormat == "json" || cfg.logging.logFormat == "both")) {
            eve-log = {
              enabled = true;
              filetype = "regular";
              filename = "/var/log/suricata/eve.json";
              
              types = [
                { alert = { enabled = true; }; }
                { http = { enabled = true; }; }
                { dns = { enabled = true; }; }
                { tls = { enabled = true; }; }
                { files = { enabled = true; }; }
                { smtp = { enabled = true; }; }
                { ssh = { enabled = true; }; }
                { stats = { enabled = true; totals = true; threads = true; }; }
              ];
            };
          })
          
          (lib.mkIf (cfg.logging.enable && (cfg.logging.logFormat == "syslog" || cfg.logging.logFormat == "both")) {
            syslog = {
              enabled = true;
              facility = "local5";
              level = "Info";
            };
          })
        ];
        
        # IPS mode configuration
        stream = lib.mkIf (cfg.mode == "ips") {
          inline = true;
          drop-invalid = true;
        };
        
        # Detection engine
        detect = {
          profile = if cfg.alerting.threshold == "high" then "high"
                   else if cfg.alerting.threshold == "low" then "low"
                   else "medium";
          
          custom-values = {
            toclient-groups = 3;
            toserver-groups = 25;
          };
        };
      };
    };
    
    # Rule management
    systemd.services.suricata-update = {
      description = "Update Suricata Rules";
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "suricata-update" ''
          #!${pkgs.bash}/bin/bash
          set -e
          
          echo "Updating Suricata rules..."
          
          ${lib.optionalString cfg.rulesets.emerging-threats ''
            echo "Fetching Emerging Threats ruleset..."
            # suricata-update will be configured to fetch ET rules
            ${pkgs.suricata}/bin/suricata-update || true
          ''}
          
          ${lib.optionalString (cfg.rulesets.custom != []) ''
            echo "Installing custom rules..."
            cat > /etc/suricata/rules/custom.rules <<EOF
            ${lib.concatStringsSep "\n" cfg.rulesets.custom}
            EOF
          ''}
          
          echo "Reloading Suricata..."
          systemctl reload suricata || systemctl restart suricata
          
          echo "Rule update complete"
        '';
        User = "root";
      };
    };
    
    systemd.timers.suricata-update = {
      description = "Suricata Rule Update Timer";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnBootSec = "15min";
        OnUnitActiveSec = "24h";
        Persistent = true;
      };
    };
    
    # Log rotation
    services.logrotate.settings.suricata = {
      files = "/var/log/suricata/*.log /var/log/suricata/*.json";
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      postrotate = "systemctl reload suricata";
    };
    
    # Alerting integration
    systemd.services.suricata-alert-monitor = lib.mkIf cfg.alerting.enable {
      description = "Suricata Alert Monitor";
      after = [ "suricata.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeScript "alert-monitor" ''
          #!${pkgs.bash}/bin/bash
          
          # Monitor eve.json for alerts
          ${pkgs.coreutils}/bin/tail -F /var/log/suricata/eve.json | while read line; do
            EVENT_TYPE=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.event_type' 2>/dev/null || echo "")
            
            if [ "$EVENT_TYPE" = "alert" ]; then
              SEVERITY=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.alert.severity' 2>/dev/null || echo "3")
              SIGNATURE=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.alert.signature' 2>/dev/null || echo "Unknown")
              SRC_IP=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.src_ip' 2>/dev/null || echo "unknown")
              DEST_IP=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.dest_ip' 2>/dev/null || echo "unknown")
              
              # Log to syslog for centralized monitoring
              logger -t suricata-ids -p security.warning "IDS Alert [Severity:$SEVERITY] $SIGNATURE ($SRC_IP -> $DEST_IP)"
              
              # High severity alerts (1 = critical, 2 = high)
              if [ "$SEVERITY" -le 2 ]; then
                logger -t suricata-ids -p security.crit "CRITICAL IDS Alert: $SIGNATURE ($SRC_IP -> $DEST_IP)"
                
                # Integration point for automated response
                # Could trigger threat response module
              fi
            fi
          done
        '';
        Restart = "always";
        RestartSec = "10s";
      };
    };
    
    # Directory setup
    systemd.tmpfiles.rules = [
      "d /var/log/suricata 0755 root root - -"
      "d /var/lib/suricata 0755 root root - -"
      "d /etc/suricata/rules 0755 root root - -"
    ];
    
    # Required packages
    environment.systemPackages = with pkgs; [
      pkgs.suricata
      pkgs.jq
    ];
    
    # Feature status
    environment.etc."hypervisor/features/ids-ips.conf".text = ''
      # IDS/IPS Configuration
      FEATURE_NAME="ids-ips"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
      
      MODE="${cfg.mode}"
      INTERFACES="${lib.concatStringsSep "," cfg.interfaces}"
      ALERT_THRESHOLD="${cfg.alerting.threshold}"
      WORKER_THREADS="${toString cfg.performance.threads}"
    '';
    
    # Management scripts
    environment.systemPackages = [
      (pkgs.writeScriptBin "ids-status" ''
        #!${pkgs.bash}/bin/bash
        echo "IDS/IPS Status"
        echo "=============="
        echo "Mode: ${cfg.mode}"
        echo "Interfaces: ${lib.concatStringsSep ", " cfg.interfaces}"
        echo ""
        
        if systemctl is-active --quiet suricata; then
          echo "Suricata: ✓ Running"
          echo ""
          echo "Statistics:"
          ${pkgs.suricata}/bin/suricatasc -c stats | ${pkgs.jq}/bin/jq '.message' 2>/dev/null || echo "Stats unavailable"
        else
          echo "Suricata: ✗ Not running"
        fi
      '')
      
      (pkgs.writeScriptBin "ids-alerts" ''
        #!${pkgs.bash}/bin/bash
        
        COUNT=''${1:-20}
        
        echo "Recent IDS Alerts (last $COUNT)"
        echo "=============================="
        
        if [ -f /var/log/suricata/eve.json ]; then
          ${pkgs.jq}/bin/jq -r 'select(.event_type == "alert") | 
            "\(.timestamp) [\(.alert.severity)] \(.alert.signature) (\(.src_ip) -> \(.dest_ip))"' \
            /var/log/suricata/eve.json | tail -n "$COUNT"
        else
          echo "No alert log found"
        fi
      '')
      
      (pkgs.writeScriptBin "ids-update-rules" ''
        #!${pkgs.bash}/bin/bash
        echo "Updating IDS/IPS rules..."
        sudo systemctl start suricata-update
        echo "Update started. Check logs with: journalctl -u suricata-update"
      '')
    ];
  };
}
