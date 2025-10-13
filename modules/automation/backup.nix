{ config, lib, pkgs, ... }:
{
  options.hypervisor.backup = {
    enable = lib.mkEnableOption "Enable automated VM backup system";
    
    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Backup schedule (daily, weekly, or custom systemd calendar format)";
    };
    
    retention = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = {
        daily = 7;
        weekly = 4;
        monthly = 3;
      };
      description = "Backup retention policy";
    };
    
    destination = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/hypervisor/backups";
      description = "Backup destination directory";
    };
    
    encrypt = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Encrypt backups using GPG";
    };
    
    compression = lib.mkOption {
      type = lib.types.enum [ "none" "gzip" "bzip2" "xz" "zstd" ];
      default = "zstd";
      description = "Compression algorithm for backups";
    };
  };

  config = lib.mkIf config.hypervisor.backup.enable {
    # Create backup script
    environment.etc."hypervisor/scripts/automated_backup.sh" = {
      mode = "0750";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        BACKUP_DIR="${config.hypervisor.backup.destination}"
        COMPRESS="${config.hypervisor.backup.compression}"
        ENCRYPT="${lib.boolToString config.hypervisor.backup.encrypt}"
        DATE=$(date +%Y%m%d_%H%M%S)
        LOG_FILE="/var/lib/hypervisor/logs/backup_$DATE.log"
        
        log() {
          echo "[$(date -Is)] $*" | tee -a "$LOG_FILE"
        }
        
        backup_vm() {
          local domain="$1"
          local backup_name="$domain-$DATE"
          local backup_path="$BACKUP_DIR/$backup_name"
          
          log "Starting backup of VM: $domain"
          
          # Check if VM exists
          if ! virsh dominfo "$domain" &>/dev/null; then
            log "ERROR: VM $domain not found"
            return 1
          fi
          
          # Create snapshot
          local snapshot_name="backup-$DATE"
          if virsh snapshot-create-as "$domain" "$snapshot_name" \
               --description "Automated backup snapshot" \
               --disk-only --atomic &>/dev/null; then
            log "Created snapshot: $snapshot_name"
          else
            log "ERROR: Failed to create snapshot for $domain"
            return 1
          fi
          
          # Get disk paths
          local disks=$(virsh domblklist "$domain" --details | \
                        awk '$2=="disk" && $3!="cdrom" {print $4}')
          
          # Create backup directory
          mkdir -p "$backup_path"
          
          # Backup each disk
          for disk in $disks; do
            if [[ ! -f "$disk" ]]; then
              log "WARNING: Disk $disk not found"
              continue
            fi
            
            local disk_name=$(basename "$disk")
            local backup_file="$backup_path/$disk_name"
            
            # Create backup with selected compression
            case "$COMPRESS" in
              none)
                cp -a "$disk" "$backup_file"
                ;;
              gzip)
                gzip -c "$disk" > "$backup_file.gz"
                backup_file="$backup_file.gz"
                ;;
              bzip2)
                bzip2 -c "$disk" > "$backup_file.bz2"
                backup_file="$backup_file.bz2"
                ;;
              xz)
                xz -c "$disk" > "$backup_file.xz"
                backup_file="$backup_file.xz"
                ;;
              zstd)
                zstd -T0 -c "$disk" > "$backup_file.zst"
                backup_file="$backup_file.zst"
                ;;
            esac
            
            # Encrypt if enabled
            if [[ "$ENCRYPT" == "true" ]]; then
              gpg --homedir /var/lib/hypervisor/gnupg \
                  --trust-model always \
                  --encrypt -r backup@hypervisor \
                  --cipher-algo AES256 \
                  --output "$backup_file.gpg" \
                  "$backup_file"
              rm -f "$backup_file"
              backup_file="$backup_file.gpg"
            fi
            
            log "Backed up disk: $disk_name -> $backup_file"
          done
          
          # Backup VM configuration
          virsh dumpxml "$domain" > "$backup_path/domain.xml"
          
          # Copy VM profile if exists
          local profile="/var/lib/hypervisor/vm_profiles/$domain.json"
          if [[ -f "$profile" ]]; then
            cp -a "$profile" "$backup_path/"
          fi
          
          # Remove snapshot
          virsh snapshot-delete "$domain" "$snapshot_name" &>/dev/null || \
            log "WARNING: Failed to delete snapshot $snapshot_name"
          
          # Create backup metadata
          cat > "$backup_path/metadata.json" <<EOF
        {
          "domain": "$domain",
          "date": "$DATE",
          "type": "automated",
          "compression": "$COMPRESS",
          "encrypted": $ENCRYPT,
          "disks": $(printf '%s\n' "$disks" | jq -R . | jq -s .),
          "snapshot": "$snapshot_name"
        }
        EOF
          
          log "Completed backup of VM: $domain"
        }
        
        apply_retention() {
          log "Applying retention policy..."
          
          # Daily backups
          local daily_keep=${toString config.hypervisor.backup.retention.daily}
          find "$BACKUP_DIR" -name "*-*_*" -type d -mtime +$daily_keep -exec rm -rf {} + 2>/dev/null || true
          
          # Weekly backups (keep one per week)
          local weekly_keep=${toString config.hypervisor.backup.retention.weekly}
          if [[ $weekly_keep -gt 0 ]]; then
            find "$backup_dir" -name "weekly-*.tar.gz" -type f -printf '%T@ %p\n' | \
              sort -rn | tail -n +$((weekly_keep + 1)) | cut -d' ' -f2- | \
              xargs -r rm -f
            log "Kept $weekly_keep most recent weekly backups"
          fi
          
          # Monthly backups (keep one per month)
          local monthly_keep=${config.hypervisor.backup.retention.monthly}
          if [[ $monthly_keep -gt 0 ]]; then
            find "$backup_dir" -name "monthly-*.tar.gz" -type f -printf '%T@ %p\n' | \
              sort -rn | tail -n +$((monthly_keep + 1)) | cut -d' ' -f2- | \
              xargs -r rm -f
            log "Kept $monthly_keep most recent monthly backups"
          fi
          
          log "Retention policy applied"
        }
        
        # Main execution
        log "Starting automated backup run"
        
        # Ensure backup directory exists
        mkdir -p "$BACKUP_DIR"
        
        # Initialize GPG if needed
        if [[ "$ENCRYPT" == "true" ]] && [[ ! -d /var/lib/hypervisor/gnupg ]]; then
          log "Initializing GPG for backup encryption"
          mkdir -p /var/lib/hypervisor/gnupg
          chmod 700 /var/lib/hypervisor/gnupg
          
          # Generate key if not exists
          if ! gpg --homedir /var/lib/hypervisor/gnupg --list-keys backup@hypervisor &>/dev/null; then
            gpg --homedir /var/lib/hypervisor/gnupg --batch --generate-key <<EOF
        %echo Generating backup encryption key
        Key-Type: RSA
        Key-Length: 4096
        Name-Real: Hypervisor Backup
        Name-Email: backup@hypervisor
        Expire-Date: 0
        %no-protection
        %commit
        EOF
          fi
        fi
        
        # Backup all VMs
        success=0
        failed=0
        for domain in $(virsh list --all --name); do
          [[ -z "$domain" ]] && continue
          
          if backup_vm "$domain"; then
            ((success++))
          else
            ((failed++))
          fi
        done
        
        # Apply retention policy
        apply_retention
        
        # Summary
        log "Backup run completed. Success: $success, Failed: $failed"
        
        # Send notification if configured
        if command -v notify-send &>/dev/null; then
          notify-send "Hypervisor Backup" "Completed: $success successful, $failed failed"
        fi
        
        exit $([ $failed -eq 0 ] && echo 0 || echo 1)
      '';
    };
    
    # Create systemd service
    systemd.services.hypervisor-backup = {
      description = "Automated VM backup";
      after = [ "libvirtd.service" ];
      requires = [ "libvirtd.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/automated_backup.sh";
        User = "root";
        
        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ 
          config.hypervisor.backup.destination
          "/var/lib/hypervisor"
          "/var/log/hypervisor"
        ];
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        
        # Resource limits
        CPUQuota = "50%";
        MemoryHigh = "2G";
        IOWeight = 10;  # Low priority I/O
      };
    };
    
    # Create systemd timer
    systemd.timers.hypervisor-backup = {
      description = "Automated VM backup timer";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = config.hypervisor.backup.schedule;
        Persistent = true;  # Run if missed
        RandomizedDelaySec = "1h";  # Spread load
      };
    };
    
    # Backup restore helper script
    environment.etc."hypervisor/scripts/restore_backup.sh" = {
      mode = "0750";
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        : "''${DIALOG:=whiptail}"
        
        show_backups() {
          find "${config.hypervisor.backup.destination}" -name metadata.json -type f | \
            while read -r meta; do
              backup_dir=$(dirname "$meta")
              domain=$(jq -r .domain "$meta")
              date=$(jq -r .date "$meta")
              echo "$backup_dir" "$domain - $date"
            done
        }
        
        restore_vm() {
          local backup_dir="$1"
          local metadata="$backup_dir/metadata.json"
          
          if [[ ! -f "$metadata" ]]; then
            echo "ERROR: Invalid backup directory"
            return 1
          fi
          
          local domain=$(jq -r .domain "$metadata")
          local encrypted=$(jq -r .encrypted "$metadata")
          local compression=$(jq -r .compression "$metadata")
          
          # Check if VM already exists
          if virsh dominfo "$domain" &>/dev/null; then
            if ! $DIALOG --yesno "VM $domain already exists. Overwrite?" 8 50; then
              return 1
            fi
            virsh destroy "$domain" &>/dev/null || true
            virsh undefine "$domain" --remove-all-storage || true
          fi
          
          echo "Restoring VM: $domain"
          
          # Restore disks
          jq -r '.disks[]' "$metadata" | while read -r disk_path; do
            local disk_name=$(basename "$disk_path")
            local backup_file="$backup_dir/$disk_name"
            
            # Handle compression and encryption
            if [[ "$encrypted" == "true" ]]; then
              backup_file="$backup_file.gpg"
              # Decrypt first
              gpg --homedir /var/lib/hypervisor/gnupg \
                  --decrypt "$backup_file" > "$disk_path.$compression"
              backup_file="$disk_path.$compression"
            else
              case "$compression" in
                gzip) backup_file="$backup_file.gz" ;;
                bzip2) backup_file="$backup_file.bz2" ;;
                xz) backup_file="$backup_file.xz" ;;
                zstd) backup_file="$backup_file.zst" ;;
              esac
            fi
            
            # Decompress
            case "$compression" in
              none) cp -a "$backup_file" "$disk_path" ;;
              gzip) gunzip -c "$backup_file" > "$disk_path" ;;
              bzip2) bunzip2 -c "$backup_file" > "$disk_path" ;;
              xz) unxz -c "$backup_file" > "$disk_path" ;;
              zstd) unzstd -c "$backup_file" > "$disk_path" ;;
            esac
            
            echo "Restored disk: $disk_name"
          done
          
          # Restore VM definition
          virsh define "$backup_dir/domain.xml"
          
          # Restore VM profile
          if [[ -f "$backup_dir/$domain.json" ]]; then
            cp -a "$backup_dir/$domain.json" "/var/lib/hypervisor/vm_profiles/"
          fi
          
          echo "VM $domain restored successfully"
        }
        
        # Interactive restore
        entries=($(show_backups))
        if [[ "''${#entries[@]}" -eq 0 ]]; then
          $DIALOG --msgbox "No backups found" 8 40
          exit 0
        fi
        
        backup=$($DIALOG --menu "Select backup to restore:" 20 70 12 "''${entries[@]}" 3>&1 1>&2 2>&3) || exit 0
        
        restore_vm "$backup"
      '';
    };
    
    # Ensure backup directory exists
    systemd.tmpfiles.rules = [
      "d ${config.hypervisor.backup.destination} 0750 root root - -"
    ];
  };
}