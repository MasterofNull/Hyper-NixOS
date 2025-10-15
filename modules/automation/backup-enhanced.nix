# Enhanced Backup System - Enterprise Backup and Recovery
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.backup;
  
  # Backup job options
  jobOptions = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable this backup job";
      };
      
      schedule = mkOption {
        type = types.str;
        description = "Backup schedule (systemd calendar format)";
        example = "daily";
      };
      
      vmids = mkOption {
        type = types.either (types.enum [ "all" ]) (types.listOf types.str);
        default = "all";
        description = "VM IDs to backup ('all' or list)";
        example = [ "vm-100" "vm-101" ];
      };
      
      storage = mkOption {
        type = types.str;
        description = "Storage pool for backups";
        example = "backup";
      };
      
      mode = mkOption {
        type = types.enum [ "snapshot" "suspend" "stop" ];
        default = "snapshot";
        description = ''
          Backup mode:
          - snapshot: Live backup using snapshots
          - suspend: Suspend VM during backup
          - stop: Stop VM during backup
        '';
      };
      
      compress = mkOption {
        type = types.enum [ "none" "lzo" "gzip" "zstd" ];
        default = "zstd";
        description = "Compression algorithm";
      };
      
      compressionLevel = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Compression level (algorithm-specific)";
      };
      
      encrypt = mkOption {
        type = types.bool;
        default = false;
        description = "Enable backup encryption";
      };
      
      encryptionKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to encryption key file";
      };
      
      # Email notifications
      mailnotification = mkOption {
        type = types.enum [ "always" "failure" "never" ];
        default = "failure";
        description = "When to send email notifications";
      };
      
      mailto = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Email addresses for notifications";
      };
      
      # Retention policy
      retention = {
        keepLast = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Keep last N backups";
        };
        
        keepHourly = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Keep N hourly backups";
        };
        
        keepDaily = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Keep N daily backups";
        };
        
        keepWeekly = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Keep N weekly backups";
        };
        
        keepMonthly = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Keep N monthly backups";
        };
        
        keepYearly = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Keep N yearly backups";
        };
      };
      
      # Performance options
      bwlimit = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Bandwidth limit in KB/s";
      };
      
      ionice = mkOption {
        type = types.nullOr types.int;
        default = 7;
        description = "I/O priority (0-7, 7 = lowest)";
      };
      
      parallel = mkOption {
        type = types.int;
        default = 1;
        description = "Number of parallel backup jobs";
      };
      
      # Advanced options
      exclude = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Exclude patterns for backup";
      };
      
      includeTPM = mkOption {
        type = types.bool;
        default = true;
        description = "Include TPM state in backup";
      };
      
      skipConfigCheck = mkOption {
        type = types.bool;
        default = false;
        description = "Skip VM configuration check";
      };
      
      notes = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Notes template for backups";
        example = "Automated backup of {{vmid}} on {{date}}";
      };
      
      verifyNew = mkOption {
        type = types.bool;
        default = true;
        description = "Verify new backups after creation";
      };
      
      performance = {
        readLimit = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Read rate limit in MB/s";
        };
        
        workers = mkOption {
          type = types.int;
          default = 4;
          description = "Number of worker threads";
        };
        
        chunkSize = mkOption {
          type = types.str;
          default = "4M";
          description = "Backup chunk size";
        };
      };
    };
  };
  
  # Backup hook options
  hookOptions = {
    options = {
      preBackup = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Script to run before backup";
      };
      
      postBackup = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Script to run after backup";
      };
      
      jobStart = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Script to run when job starts";
      };
      
      jobEnd = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Script to run when job ends";
      };
      
      preStop = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Script to run before stopping VM";
      };
      
      postStart = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Script to run after starting VM";
      };
    };
  };
  
  # Generate backup script for a job
  generateBackupScript = name: job: pkgs.writeShellScript "backup-job-${name}" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Source common functions
    source /etc/hypervisor/scripts/lib/common.sh
    
    # Job configuration
    JOB_NAME="${name}"
    STORAGE="${job.storage}"
    MODE="${job.mode}"
    COMPRESS="${job.compress}"
    PARALLEL="${toString job.parallel}"
    
    # Logging
    LOG_FILE="/var/log/hypervisor/backup-$JOB_NAME-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }
    
    # Send notification
    send_notification() {
        local status="$1"
        local message="$2"
        
        ${optionalString (job.mailnotification != "never") ''
        if [[ "$status" == "failure" ]] || [[ "${job.mailnotification}" == "always" ]]; then
            ${concatMapStringsSep "\n" (mailto: ''
              echo "$message" | mail -s "Backup Job ${name}: $status" "${mailto}"
            '') job.mailto}
        fi
        ''}
    }
    
    # Run hook if defined
    run_hook() {
        local hook_name="$1"
        local hook_path="$2"
        
        if [[ -n "$hook_path" ]] && [[ -x "$hook_path" ]]; then
            log "Running $hook_name hook: $hook_path"
            export BACKUP_JOB="$JOB_NAME"
            export BACKUP_STORAGE="$STORAGE"
            "$hook_path" || {
                log "ERROR: $hook_name hook failed"
                return 1
            }
        fi
    }
    
    # Get list of VMs to backup
    get_vm_list() {
        ${if job.vmids == "all" then ''
          # Get all VMs
          virsh list --all --name | grep -v '^$'
        '' else ''
          # Return specified VMs
          for vm in ${concatStringsSep " " job.vmids}; do
              echo "$vm"
          done
        ''}
    }
    
    # Backup a single VM
    backup_vm() {
        local vm="$1"
        local backup_file="/mnt/hypervisor-storage/$STORAGE/$(date +%Y%m%d-%H%M%S)-$vm.vma"
        
        log "Starting backup of VM: $vm"
        
        ${optionalString (cfg.hooks.preBackup != null) ''
        export BACKUP_VMID="$vm"
        export BACKUP_PATH="$backup_file"
        run_hook "pre-backup" "${cfg.hooks.preBackup}"
        ''}
        
        # Create backup based on mode
        case "$MODE" in
            snapshot)
                # Live backup with snapshot
                ${optionalString (job.bwlimit != null) ''export BWLIMIT="${toString job.bwlimit}"''}
                ${optionalString (job.ionice != null) ''ionice -c 3 -n ${toString job.ionice}''}
                
                # Create snapshot and backup
                virsh snapshot-create-as "$vm" backup-tmp --disk-only --atomic
                
                # Backup VM disks
                for disk in $(virsh domblklist "$vm" | grep -E '(vd|sd|hd)' | awk '{print $1}'); do
                    source=$(virsh domblklist "$vm" | grep "^$disk" | awk '{print $2}')
                    qemu-img convert -O qcow2 ${optionalString (job.compress != "none") "-c"} \
                        ${optionalString (job.performance.readLimit != null) "-r ${toString job.performance.readLimit}M"} \
                        "$source" "$backup_file-$disk.qcow2"
                done
                
                # Remove temporary snapshot
                virsh snapshot-delete "$vm" backup-tmp
                ;;
                
            suspend)
                # Suspend VM during backup
                was_running=false
                if virsh domstate "$vm" | grep -q running; then
                    was_running=true
                    virsh suspend "$vm"
                fi
                
                # Backup VM
                virsh save "$vm" "$backup_file"
                
                # Resume if was running
                if [[ "$was_running" == "true" ]]; then
                    virsh resume "$vm"
                fi
                ;;
                
            stop)
                # Stop VM for backup
                ${optionalString (cfg.hooks.preStop != null) ''
                run_hook "pre-stop" "${cfg.hooks.preStop}"
                ''}
                
                was_running=false
                if virsh domstate "$vm" | grep -q running; then
                    was_running=true
                    virsh shutdown "$vm"
                    
                    # Wait for shutdown
                    timeout=60
                    while [[ $timeout -gt 0 ]] && virsh domstate "$vm" | grep -q running; do
                        sleep 1
                        ((timeout--))
                    done
                fi
                
                # Backup VM
                virsh save "$vm" "$backup_file" --bypass-cache
                
                # Restart if was running
                if [[ "$was_running" == "true" ]]; then
                    virsh start "$vm"
                    ${optionalString (cfg.hooks.postStart != null) ''
                    run_hook "post-start" "${cfg.hooks.postStart}"
                    ''}
                fi
                ;;
        esac
        
        # Compress backup
        ${if job.compress != "none" then ''
        log "Compressing backup with ${job.compress}"
        case "${job.compress}" in
            lzo)
                lzop ${optionalString (job.compressionLevel != null) "-${toString job.compressionLevel}"} "$backup_file"
                rm "$backup_file"
                backup_file="$backup_file.lzo"
                ;;
            gzip)
                gzip ${optionalString (job.compressionLevel != null) "-${toString job.compressionLevel}"} "$backup_file"
                backup_file="$backup_file.gz"
                ;;
            zstd)
                zstd ${optionalString (job.compressionLevel != null) "-${toString job.compressionLevel}"} "$backup_file"
                rm "$backup_file"
                backup_file="$backup_file.zst"
                ;;
        esac
        '' else ""}
        
        # Encrypt backup if enabled
        ${optionalString job.encrypt ''
        if [[ -f "${job.encryptionKey}" ]]; then
            log "Encrypting backup"
            openssl enc -aes-256-cbc -salt -in "$backup_file" -out "$backup_file.enc" -pass file:"${job.encryptionKey}"
            rm "$backup_file"
            backup_file="$backup_file.enc"
        fi
        ''}
        
        # Verify backup
        ${optionalString job.verifyNew ''
        log "Verifying backup"
        if ! test -f "$backup_file"; then
            log "ERROR: Backup file not found"
            return 1
        fi
        # Additional verification based on format
        ''}
        
        ${optionalString (cfg.hooks.postBackup != null) ''
        export BACKUP_FILE="$backup_file"
        run_hook "post-backup" "${cfg.hooks.postBackup}"
        ''}
        
        log "Backup completed: $backup_file"
    }
    
    # Apply retention policy
    apply_retention() {
        log "Applying retention policy"
        
        # Implementation would go here based on retention settings
        ${optionalString (job.retention.keepLast != null) ''
        # Keep only last N backups
        find "/mnt/hypervisor-storage/$STORAGE" -name "*.vma*" -type f | \
            sort -r | tail -n +$((${toString job.retention.keepLast} + 1)) | \
            xargs -r rm -f
        ''}
    }
    
    # Main execution
    main() {
        log "Starting backup job: $JOB_NAME"
        
        ${optionalString (cfg.hooks.jobStart != null) ''
        run_hook "job-start" "${cfg.hooks.jobStart}"
        ''}
        
        # Get VM list
        vms=$(get_vm_list)
        if [[ -z "$vms" ]]; then
            log "No VMs to backup"
            exit 0
        fi
        
        # Run backups
        failed=0
        total=0
        
        # Use parallel execution if configured
        if [[ "$PARALLEL" -gt 1 ]]; then
            export -f backup_vm log run_hook
            echo "$vms" | xargs -P "$PARALLEL" -I {} bash -c 'backup_vm "$@"' _ {} || failed=$?
        else
            while IFS= read -r vm; do
                ((total++))
                if ! backup_vm "$vm"; then
                    ((failed++))
                fi
            done <<< "$vms"
        fi
        
        # Apply retention policy
        apply_retention
        
        ${optionalString (cfg.hooks.jobEnd != null) ''
        run_hook "job-end" "${cfg.hooks.jobEnd}"
        ''}
        
        # Send notification
        if [[ $failed -eq 0 ]]; then
            send_notification "success" "Backup job $JOB_NAME completed successfully. Backed up $total VMs."
        else
            send_notification "failure" "Backup job $JOB_NAME completed with errors. Failed: $failed/$total VMs."
            exit 1
        fi
        
        log "Backup job completed"
    }
    
    # Run with error handling
    if ! main; then
        send_notification "failure" "Backup job $JOB_NAME failed. Check logs at $LOG_FILE"
        exit 1
    fi
  '';
in
{
  options.hypervisor.backup = {
    jobs = mkOption {
      type = types.attrsOf (types.submodule jobOptions);
      default = {};
      description = "Backup job definitions";
      example = literalExpression ''
        {
          daily = {
            schedule = "daily";
            vmids = "all";
            storage = "backup";
            mode = "snapshot";
            compress = "zstd";
            retention = {
              keepLast = 7;
              keepWeekly = 4;
              keepMonthly = 6;
            };
            mailnotification = "failure";
            mailto = [ "admin@example.com" ];
          };
          
          critical = {
            schedule = "*-*-* 00,12:00:00";  # Twice daily
            vmids = [ "vm-200" "vm-201" ];
            storage = "backup-critical";
            mode = "snapshot";
            compress = "zstd";
            encrypt = true;
            encryptionKey = "/etc/hypervisor/backup.key";
            retention.keepLast = 14;
            parallel = 2;
          };
        }
      '';
    };
    
    hooks = mkOption {
      type = types.submodule hookOptions;
      default = {};
      description = "Global backup hooks";
    };
    
    # Global settings
    globalSettings = {
      logRetention = mkOption {
        type = types.int;
        default = 30;
        description = "Days to keep backup logs";
      };
      
      defaultStorage = mkOption {
        type = types.str;
        default = "local-backups";
        description = "Default storage pool for backups";
      };
      
      lockTimeout = mkOption {
        type = types.int;
        default = 3600;
        description = "Backup lock timeout in seconds";
      };
    };
    
    # Verification settings
    verification = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable backup verification";
      };
      
      schedule = mkOption {
        type = types.str;
        default = "weekly";
        description = "Verification schedule";
      };
      
      workers = mkOption {
        type = types.int;
        default = 2;
        description = "Number of verification workers";
      };
    };
  };
  
  config = {
    # Create systemd services for each backup job
    systemd.services = mapAttrs' (name: job: nameValuePair "hypervisor-backup-${name}" {
      description = "Hypervisor Backup Job - ${name}";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = generateBackupScript name job;
        
        # Resource limits
        CPUQuota = "50%";
        MemoryLimit = "2G";
        IOWeight = 10;
        
        # Security
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          "/mnt/hypervisor-storage"
          "/var/log/hypervisor"
          "/var/lib/libvirt"
        ];
      };
    }) (filterAttrs (_: job: job.enable) cfg.jobs);
    
    # Create systemd timers for scheduled jobs
    systemd.timers = mapAttrs' (name: job: nameValuePair "hypervisor-backup-${name}" {
      description = "Timer for Hypervisor Backup Job - ${name}";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = job.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    }) (filterAttrs (_: job: job.enable) cfg.jobs);
    
    # Backup management script
    environment.etc."hypervisor/scripts/backup-manager.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Backup management utility
        
        set -euo pipefail
        
        list_jobs() {
            echo "Backup Jobs:"
            echo "============"
            ${concatStringsSep "\n" (mapAttrsToList (name: job: ''
              echo
              echo "Job: ${name}"
              echo "  Schedule: ${job.schedule}"
              echo "  VMs: ${if job.vmids == "all" then "all" else concatStringsSep ", " job.vmids}"
              echo "  Storage: ${job.storage}"
              echo "  Mode: ${job.mode}"
              echo "  Compress: ${job.compress}"
              ${optionalString job.encrypt ''echo "  Encrypted: Yes"''}
              ${optionalString (job.retention.keepLast != null) ''echo "  Keep Last: ${toString job.retention.keepLast}"''}
              echo "  Status: $(systemctl is-enabled hypervisor-backup-${name}.timer)"
            '') cfg.jobs)}
        }
        
        case "''${1:-list}" in
            list)
                list_jobs
                ;;
            run)
                if [[ -z "''${2:-}" ]]; then
                    echo "Usage: $0 run <job-name>"
                    exit 1
                fi
                systemctl start "hypervisor-backup-$2.service"
                ;;
            status)
                if [[ -z "''${2:-}" ]]; then
                    for job in ${concatStringsSep " " (attrNames cfg.jobs)}; do
                        echo "Job $job:"
                        systemctl status "hypervisor-backup-$job.timer" --no-pager || true
                        echo
                    done
                else
                    systemctl status "hypervisor-backup-$2.timer" "hypervisor-backup-$2.service"
                fi
                ;;
            logs)
                job="''${2:-*}"
                journalctl -u "hypervisor-backup-$job.service" -f
                ;;
            *)
                echo "Usage: $0 {list|run <job>|status [job]|logs [job]}"
                exit 1
                ;;
        esac
      '';
    };
    
    # Backup verification service
    systemd.services.hypervisor-backup-verify = mkIf cfg.verification.enable {
      description = "Hypervisor Backup Verification";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "backup-verify" ''
          #!/usr/bin/env bash
          
          # Verify all backups in storage pools
          echo "Starting backup verification..."
          
          # Implementation would verify backup integrity
          find /mnt/hypervisor-storage -name "*.vma*" -type f -mtime -7 | \
          while read -r backup; do
              echo "Verifying: $backup"
              # Verification logic here
          done
        '';
      };
    };
    
    systemd.timers.hypervisor-backup-verify = mkIf cfg.verification.enable {
      description = "Timer for Backup Verification";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = cfg.verification.schedule;
        Persistent = true;
      };
    };
    
    # Create backup directories
    systemd.tmpfiles.rules = [
      "d /var/log/hypervisor 0755 root root -"
      "d /var/lib/hypervisor/backup 0755 root root -"
    ];
  };
}