{ config, lib, pkgs, ... }:

# Hypervisor Automation Module
# Provides automated health checks, backups, updates, and monitoring

{
  # Automated health checks on boot and periodically
  systemd.services.hypervisor-health-check = {
    description = "Hypervisor System Health Check";
    after = [ "network-online.target" "libvirtd.service" ];
    wants = [ "network-online.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/system_health_check.sh";
      User = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Health check timer - run daily
  systemd.timers.hypervisor-health-check = {
    description = "Daily Hypervisor Health Check";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "5min";  # Also run 5 minutes after boot
      Persistent = true;
    };
  };

  # Automated backups
  systemd.services.hypervisor-backup = {
    description = "Automated VM Backup";
    after = [ "libvirtd.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/automated_backup.sh backup running";
      User = "root";
      StandardOutput = "journal";
      StandardError = "journal";
      
      # Backup configuration via environment
      Environment = [
        "BACKUP_DIR=/var/lib/hypervisor/backups"
        "RETENTION_DAYS=30"
        "MAX_BACKUPS_PER_VM=5"
        "COMPRESS_BACKUPS=true"
        "VERIFY_BACKUPS=true"
      ];
      
      # Resource limits for backup process
      Nice = 10;  # Lower priority
      IOSchedulingClass = "idle";  # Don't impact VM performance
    };
  };

  # Backup timer - run nightly at 2 AM
  systemd.timers.hypervisor-backup = {
    description = "Nightly VM Backup";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "02:00";  # 2 AM daily
      Persistent = true;
      RandomizedDelaySec = "30min";  # Randomize up to 30 minutes
    };
  };

  # Update checker
  systemd.services.hypervisor-update-check = {
    description = "Hypervisor Update Check";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/update_manager.sh auto-check";
      User = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Update check timer - run weekly
  systemd.timers.hypervisor-update-check = {
    description = "Weekly Update Check";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Storage cleanup service
  systemd.services.hypervisor-storage-cleanup = {
    description = "Hypervisor Storage Cleanup";
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "storage-cleanup" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        LOG="/var/lib/hypervisor/logs/cleanup-$(date +%Y%m%d).log"
        
        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
        }
        
        log "=== Storage Cleanup Started ==="
        
        # Clean up old logs (keep 90 days)
        log "Cleaning old logs..."
        find /var/lib/hypervisor/logs -name "*.log" -mtime +90 -delete 2>&1 | tee -a "$LOG"
        find /var/log/hypervisor -name "*.log" -mtime +90 -delete 2>&1 | tee -a "$LOG"
        
        # Clean up temporary files
        log "Cleaning temporary files..."
        find /var/lib/hypervisor -name ".partial-*" -mtime +1 -delete 2>&1 | tee -a "$LOG"
        find /var/lib/hypervisor -name "*.tmp" -mtime +1 -delete 2>&1 | tee -a "$LOG"
        
        # Report disk usage
        log "Current disk usage:"
        df -h /var/lib/hypervisor 2>&1 | tee -a "$LOG"
        
        # Warn if low disk space
        AVAIL_GB=$(df -BG /var/lib/hypervisor | awk 'NR==2 {print $4}' | tr -d 'G')
        if [[ $AVAIL_GB -lt 20 ]]; then
          # Note: ''${...} escapes Nix interpolation to keep Bash variable expansion
          log "WARNING: Low disk space (''${AVAIL_GB}GB available)"
          log "Consider:"
          log "  - Deleting old VMs: virsh undefine <vm>"
          log "  - Deleting old snapshots: virsh snapshot-delete <vm> <snapshot>"
          log "  - Cleaning old backups: find /var/lib/hypervisor/backups -mtime +60 -delete"
        fi
        
        log "=== Storage Cleanup Complete ==="
      '';
      
      User = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Storage cleanup timer - run weekly
  systemd.timers.hypervisor-storage-cleanup = {
    description = "Weekly Storage Cleanup";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Monitoring service - collects metrics
  systemd.services.hypervisor-metrics = {
    description = "Hypervisor Metrics Collection";
    after = [ "libvirtd.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "collect-metrics" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        METRICS_FILE="/var/lib/hypervisor/metrics-$(date +%Y%m%d-%H%M%S).json"
        
        # Collect system metrics
        cat > "$METRICS_FILE" <<EOF
        {
          "timestamp": "$(date -Iseconds)",
          "hostname": "$(hostname)",
          "cpu": {
            "total": $(nproc),
            "load_avg": "$(cat /proc/loadavg | awk '{print $1, $2, $3}')"
          },
          "memory": {
            "total_mb": $(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo),
            "available_mb": $(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo),
            "used_mb": $(( $(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo) - $(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo) ))
          },
          "disk": {
            "total_gb": $(df -BG /var/lib/hypervisor | awk 'NR==2 {print $2}' | tr -d 'G'),
            "used_gb": $(df -BG /var/lib/hypervisor | awk 'NR==2 {print $3}' | tr -d 'G'),
            "available_gb": $(df -BG /var/lib/hypervisor | awk 'NR==2 {print $4}' | tr -d 'G'),
            "used_percent": "$(df /var/lib/hypervisor | awk 'NR==2 {print $5}')"
          },
          "vms": {
            "total": $(virsh list --all --name | grep -v '^$' | wc -l),
            "running": $(virsh list --state-running --name | grep -v '^$' | wc -l),
            "stopped": $(virsh list --state-shutoff --name | grep -v '^$' | wc -l)
          }
        }
        EOF
        
        # Keep only last 7 days of metrics
        find /var/lib/hypervisor -name "metrics-*.json" -mtime +7 -delete
      '';
      
      User = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Metrics collection timer - run hourly
  systemd.timers.hypervisor-metrics = {
    description = "Hourly Metrics Collection";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  # Dead VM cleanup - remove crashed/failed VMs
  systemd.services.hypervisor-vm-cleanup = {
    description = "Cleanup Failed VMs";
    after = [ "libvirtd.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "vm-cleanup" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        LOG="/var/lib/hypervisor/logs/vm-cleanup-$(date +%Y%m%d).log"
        
        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
        }
        
        log "=== VM Cleanup Started ==="
        
        # Check for crashed VMs
        virsh list --all --name | while read vm; do
          [[ -z "$vm" ]] && continue
          
          state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
          
          if [[ "$state" == "crashed" ]]; then
            log "Found crashed VM: $vm"
            log "  Attempting to restart..."
            
            if virsh destroy "$vm" 2>/dev/null; then
              sleep 2
              if virsh start "$vm" 2>&1 | tee -a "$LOG"; then
                log "  ✓ VM restarted successfully"
              else
                log "  ✗ VM restart failed"
              fi
            fi
          fi
        done
        
        log "=== VM Cleanup Complete ==="
      '';
      
      User = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # VM cleanup timer - run every 6 hours
  systemd.timers.hypervisor-vm-cleanup = {
    description = "Periodic VM Cleanup";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "*-*-* 00,06,12,18:00:00";  # Every 6 hours
      Persistent = true;
    };
  };

  # Backup verification service
  systemd.services.hypervisor-backup-verification = {
    description = "Automated Backup Verification";
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/automated_backup_verification.sh";
      User = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
  
  systemd.timers.hypervisor-backup-verification = {
    description = "Weekly Backup Verification";
    wantedBy = [ "timers.target" ];
    
    timerConfig = {
      OnCalendar = "Sun 03:00";  # Sunday 3 AM
      Persistent = true;
    };
  };
  
  # Enable all timers by default
  systemd.targets.hypervisor-automation = {
    description = "Hypervisor Automation Target";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "hypervisor-health-check.timer"
      "hypervisor-backup.timer"
      "hypervisor-update-check.timer"
      "hypervisor-storage-cleanup.timer"
      "hypervisor-metrics.timer"
      "hypervisor-vm-cleanup.timer"
      "hypervisor-backup-verification.timer"
    ];
  };

  # Ensure log directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/hypervisor/logs 0770 root libvirtd - -"
    "d /var/lib/hypervisor/backups 0770 root libvirtd - -"
  ];
}
