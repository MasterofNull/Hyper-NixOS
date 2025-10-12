#!/usr/bin/env bash
# Automated VM backup system with rotation and verification

set -Eeuo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

BACKUP_DIR="${BACKUP_DIR:-/var/lib/hypervisor/backups}"
LOG_FILE="${LOG_FILE:-/var/lib/hypervisor/logs/backup-$(date +%Y%m%d-%H%M%S).log}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
MAX_BACKUPS_PER_VM="${MAX_BACKUPS_PER_VM:-5}"
VERIFY_BACKUPS="${VERIFY_BACKUPS:-true}"
COMPRESS_BACKUPS="${COMPRESS_BACKUPS:-true}"
ENCRYPT_BACKUPS="${ENCRYPT_BACKUPS:-false}"
GPG_RECIPIENT="${GPG_RECIPIENT:-}"

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
  log "ERROR: $*"
}

warn() {
  log "WARN: $*"
}

info() {
  log "INFO: $*"
}

# Get list of VMs to backup
get_vms_to_backup() {
  local backup_mode="${1:-all}"
  
  case "$backup_mode" in
    all)
      virsh list --all --name | grep -v '^$'
      ;;
    running)
      virsh list --state-running --name | grep -v '^$'
      ;;
    stopped)
      virsh list --state-shutoff --name | grep -v '^$'
      ;;
    *)
      echo "$backup_mode"  # Specific VM name
      ;;
  esac
}

# Backup single VM
backup_vm() {
  local vm_name="$1"
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_base="$BACKUP_DIR/$vm_name"
  local backup_path="$backup_base/$timestamp"
  
  mkdir -p "$backup_path"
  
  info "Backing up VM: $vm_name"
  
  # Check if VM exists
  if ! virsh dominfo "$vm_name" >/dev/null 2>&1; then
    error "VM $vm_name does not exist"
    return 1
  fi
  
  # Get VM state
  local vm_state=$(virsh domstate "$vm_name")
  info "  State: $vm_state"
  
  # Backup VM XML definition
  info "  Backing up VM definition..."
  virsh dumpxml "$vm_name" > "$backup_path/$vm_name.xml"
  
  # Backup VM disks
  info "  Backing up VM disks..."
  local disk_count=0
  while read disk_path; do
    [[ -z "$disk_path" ]] && continue
    [[ ! -f "$disk_path" ]] && continue
    
    disk_count=$((disk_count + 1))
    local disk_name=$(basename "$disk_path")
    local backup_disk="$backup_path/$disk_name"
    
    info "    Disk $disk_count: $disk_name"
    
    # Check disk size
    local disk_size=$(qemu-img info "$disk_path" | awk '/virtual size:/ {print $3, $4}')
    info "      Size: $disk_size"
    
    # Create snapshot if VM is running for consistent backup
    if [[ "$vm_state" == "running" ]]; then
      info "      Creating live backup (VM is running)..."
      
      # Use virsh blockcopy for live backup
      local snap_name="backup-temp-$(date +%s)"
      if virsh snapshot-create-as "$vm_name" "$snap_name" \
          --disk-only --atomic --quiesce 2>/dev/null; then
        
        # Copy the backing file
        cp "$disk_path" "$backup_disk"
        
        # Merge snapshot back
        virsh blockcommit "$vm_name" "$disk_path" --active --pivot 2>/dev/null || true
        virsh snapshot-delete "$vm_name" "$snap_name" --metadata 2>/dev/null || true
      else
        # Fallback: regular copy (may be inconsistent)
        warn "      Live backup failed, using regular copy (may be inconsistent)"
        cp "$disk_path" "$backup_disk"
      fi
    else
      # VM is stopped, safe to copy directly
      cp "$disk_path" "$backup_disk"
    fi
    
    # Compress if enabled
    if [[ "$COMPRESS_BACKUPS" == "true" ]]; then
      info "      Compressing..."
      gzip "$backup_disk"
      backup_disk="${backup_disk}.gz"
    fi
    
    # Verify backup
    if [[ "$VERIFY_BACKUPS" == "true" ]]; then
      info "      Verifying backup..."
      if [[ -f "$backup_disk" ]]; then
        local backup_size=$(du -h "$backup_disk" | awk '{print $1}')
        info "      Backup size: $backup_size"
      else
        error "      Backup verification failed: file not found"
        return 1
      fi
    fi
    
  done < <(virsh domblklist "$vm_name" --details 2>/dev/null | awk '/file/ {print $4}')
  
  if [[ $disk_count -eq 0 ]]; then
    warn "  No disks found for $vm_name"
  fi
  
  # Backup NVRAM if it exists (UEFI)
  if virsh dumpxml "$vm_name" | grep -q "nvram"; then
    local nvram_path=$(virsh dumpxml "$vm_name" | grep -oP 'nvram.*?\K/[^<]+')
    if [[ -f "$nvram_path" ]]; then
      info "  Backing up NVRAM (UEFI)..."
      cp "$nvram_path" "$backup_path/nvram.bin"
    fi
  fi
  
  # Create backup metadata
  cat > "$backup_path/backup-info.json" <<EOF
{
  "vm_name": "$vm_name",
  "timestamp": "$timestamp",
  "vm_state": "$vm_state",
  "disk_count": $disk_count,
  "compressed": $COMPRESS_BACKUPS,
  "encrypted": false,
  "backup_size": "$(du -sh "$backup_path" | awk '{print $1}')"
}
EOF
  
  # Encrypt if enabled
  if [[ "$ENCRYPT_BACKUPS" == "true" && -n "$GPG_RECIPIENT" ]]; then
    info "  Encrypting backup..."
    tar czf - -C "$backup_base" "$timestamp" | \
      gpg --encrypt --recipient "$GPG_RECIPIENT" \
      > "$backup_base/${timestamp}.tar.gz.gpg"
    
    # Remove unencrypted backup
    rm -rf "$backup_path"
    
    # Update metadata
    echo '  "encrypted": true,' >> "$backup_base/${timestamp}.tar.gz.gpg.info"
  fi
  
  info "✓ Backup completed: $backup_path"
  
  return 0
}

# Rotate old backups
rotate_backups() {
  local vm_name="$1"
  local backup_base="$BACKUP_DIR/$vm_name"
  
  [[ ! -d "$backup_base" ]] && return 0
  
  info "Rotating backups for $vm_name..."
  
  # Get list of backups sorted by age
  local backups=($(ls -t "$backup_base" 2>/dev/null | head -n 20))
  local backup_count=${#backups[@]}
  
  info "  Found $backup_count backup(s)"
  
  # Delete old backups by count
  if [[ $backup_count -gt $MAX_BACKUPS_PER_VM ]]; then
    local delete_count=$((backup_count - MAX_BACKUPS_PER_VM))
    info "  Deleting $delete_count old backup(s) (keeping $MAX_BACKUPS_PER_VM)"
    
    for ((i=MAX_BACKUPS_PER_VM; i<backup_count; i++)); do
      local old_backup="${backups[$i]}"
      info "    Deleting: $old_backup"
      rm -rf "$backup_base/$old_backup"
    done
  fi
  
  # Delete backups older than retention period
  local deleted_by_age=0
  find "$backup_base" -maxdepth 1 -type d -mtime +$RETENTION_DAYS | while read old_dir; do
    [[ "$old_dir" == "$backup_base" ]] && continue
    info "    Deleting old backup (>$RETENTION_DAYS days): $(basename "$old_dir")"
    rm -rf "$old_dir"
    deleted_by_age=$((deleted_by_age + 1))
  done
  
  [[ $deleted_by_age -gt 0 ]] && info "  Deleted $deleted_by_age backup(s) older than $RETENTION_DAYS days"
}

# Restore from backup
restore_vm() {
  local vm_name="$1"
  local backup_timestamp="${2:-latest}"
  local backup_base="$BACKUP_DIR/$vm_name"
  
  # Get backup to restore
  local backup_path
  if [[ "$backup_timestamp" == "latest" ]]; then
    backup_path=$(ls -t "$backup_base" 2>/dev/null | head -1)
    [[ -z "$backup_path" ]] && { error "No backups found for $vm_name"; return 1; }
    backup_path="$backup_base/$backup_path"
  else
    backup_path="$backup_base/$backup_timestamp"
  fi
  
  if [[ ! -d "$backup_path" ]]; then
    error "Backup not found: $backup_path"
    return 1
  fi
  
  info "Restoring VM $vm_name from backup: $(basename "$backup_path")"
  
  # Stop VM if running
  if virsh domstate "$vm_name" 2>/dev/null | grep -q "running"; then
    info "  Stopping VM..."
    virsh shutdown "$vm_name"
    sleep 5
    virsh destroy "$vm_name" 2>/dev/null || true
  fi
  
  # Restore VM definition
  info "  Restoring VM definition..."
  virsh define "$backup_path/$vm_name.xml"
  
  # Restore disks
  info "  Restoring disks..."
  while read disk_backup; do
    local disk_name=$(basename "$disk_backup" .gz)
    local disk_path=$(virsh domblklist "$vm_name" --details 2>/dev/null | awk -v name="$disk_name" '$4 ~ name {print $4}')
    
    [[ -z "$disk_path" ]] && continue
    
    info "    Restoring: $disk_name"
    
    if [[ "$disk_backup" == *.gz ]]; then
      gunzip -c "$disk_backup" > "$disk_path"
    else
      cp "$disk_backup" "$disk_path"
    fi
  done < <(find "$backup_path" -name "*.qcow2*" -o -name "*.img*")
  
  info "✓ Restore completed"
  info "  Start VM with: virsh start $vm_name"
}

# List backups
list_backups() {
  local vm_name="${1:-}"
  
  if [[ -z "$vm_name" ]]; then
    # List all VMs with backups
    echo "Available backups:"
    for vm_dir in "$BACKUP_DIR"/*; do
      [[ ! -d "$vm_dir" ]] && continue
      local vm=$(basename "$vm_dir")
      local count=$(ls -1 "$vm_dir" 2>/dev/null | wc -l)
      local latest=$(ls -t "$vm_dir" 2>/dev/null | head -1)
      echo "  $vm: $count backup(s), latest: $latest"
    done
  else
    # List backups for specific VM
    local backup_base="$BACKUP_DIR/$vm_name"
    if [[ ! -d "$backup_base" ]]; then
      echo "No backups found for $vm_name"
      return 1
    fi
    
    echo "Backups for $vm_name:"
    ls -lht "$backup_base" | tail -n +2 | while read line; do
      echo "  $line"
    done
  fi
}

# Main
case "${1:-backup}" in
  backup)
    VM_MODE="${2:-running}"
    info "=== Starting automated backup ==="
    info "Mode: $VM_MODE"
    info "Backup directory: $BACKUP_DIR"
    info "Retention: $RETENTION_DAYS days / $MAX_BACKUPS_PER_VM backups per VM"
    
    TOTAL_VMS=0
    SUCCESS=0
    FAILED=0
    
    while read vm_name; do
      [[ -z "$vm_name" ]] && continue
      TOTAL_VMS=$((TOTAL_VMS + 1))
      
      if backup_vm "$vm_name"; then
        SUCCESS=$((SUCCESS + 1))
        rotate_backups "$vm_name"
      else
        FAILED=$((FAILED + 1))
      fi
      
      echo ""
    done < <(get_vms_to_backup "$VM_MODE")
    
    info "=== Backup Summary ==="
    info "Total VMs: $TOTAL_VMS"
    info "Successful: $SUCCESS"
    info "Failed: $FAILED"
    info "Log: $LOG_FILE"
    
    [[ $FAILED -gt 0 ]] && exit 1
    ;;
    
  restore)
    VM_NAME="${2:-}"
    BACKUP_TS="${3:-latest}"
    
    if [[ -z "$VM_NAME" ]]; then
      error "Usage: $0 restore <vm-name> [backup-timestamp]"
      exit 1
    fi
    
    restore_vm "$VM_NAME" "$BACKUP_TS"
    ;;
    
  list)
    VM_NAME="${2:-}"
    list_backups "$VM_NAME"
    ;;
    
  *)
    cat <<EOF
Automated VM Backup System

Usage:
  $0 backup [all|running|stopped|vm-name]
    Create backups of VMs
    
  $0 restore <vm-name> [timestamp]
    Restore VM from backup (latest if no timestamp)
    
  $0 list [vm-name]
    List available backups

Environment Variables:
  BACKUP_DIR=/var/lib/hypervisor/backups
  RETENTION_DAYS=30
  MAX_BACKUPS_PER_VM=5
  COMPRESS_BACKUPS=true
  ENCRYPT_BACKUPS=false
  GPG_RECIPIENT=admin@example.com

Examples:
  # Backup all running VMs
  $0 backup running
  
  # Backup specific VM
  $0 backup my-vm
  
  # Restore latest backup
  $0 restore my-vm
  
  # List all backups
  $0 list
EOF
    ;;
esac
