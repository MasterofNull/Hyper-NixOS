#!/usr/bin/env bash
# Configuration Backup Library
# Automatic backup and rollback for configuration files
# Part of Design Ethos - Ease of Use (Pillar 1)

# Prevent multiple sourcing
[[ -n "${_CONFIG_BACKUP_LOADED:-}" ]] && return 0
readonly _CONFIG_BACKUP_LOADED=1

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
}

################################################################################
# Configuration
################################################################################

BACKUP_DIR="${HV_BACKUP_DIR:-/var/lib/hypervisor/config-backups}"
BACKUP_RETENTION_DAYS=${HV_BACKUP_RETENTION:-30}

# Create backup directory
mkdir -p "$BACKUP_DIR" 2>/dev/null || true

################################################################################
# Backup Functions
################################################################################

# Backup a configuration file
backup_config() {
    local config_file=$1
    local description=${2:-}
    
    if [ ! -f "$config_file" ]; then
        log_debug "No existing config to backup: ${config_file}"
        return 0
    fi
    
    # Generate backup filename
    local basename=$(basename "$config_file")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${basename}.${timestamp}.backup"
    
    # Copy file
    if cp "$config_file" "$backup_file"; then
        log_info "Backed up ${config_file} to ${backup_file}"
        
        # Create metadata file
        cat > "${backup_file}.meta" << EOF
{
  "original_file": "${config_file}",
  "backup_file": "${backup_file}",
  "timestamp": "${timestamp}",
  "date": "$(date -Iseconds)",
  "description": "${description}",
  "user": "${USER:-unknown}",
  "filesize": $(stat -c %s "$config_file" 2>/dev/null || echo 0)
}
EOF
        
        echo "$backup_file"
        return 0
    else
        log_error "Failed to backup ${config_file}"
        return 1
    fi
}

# List backups for a specific config file
list_backups() {
    local config_file=$1
    local basename=$(basename "$config_file")
    
    find "$BACKUP_DIR" -name "${basename}.*.backup" -type f 2>/dev/null | sort -r
}

# Get latest backup for a config file
get_latest_backup() {
    local config_file=$1
    list_backups "$config_file" | head -1
}

# Restore from backup
restore_backup() {
    local backup_file=$1
    local force=${2:-no}
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: ${backup_file}"
        return 1
    fi
    
    # Read metadata
    local meta_file="${backup_file}.meta"
    local original_file=""
    
    if [ -f "$meta_file" ]; then
        original_file=$(jq -r '.original_file' "$meta_file" 2>/dev/null || echo "")
    fi
    
    if [ -z "$original_file" ]; then
        log_error "Cannot determine original file from backup metadata"
        return 1
    fi
    
    # Backup current file before restoring
    if [ -f "$original_file" ] && [ "$force" != "yes" ]; then
        backup_config "$original_file" "Pre-restore backup"
    fi
    
    # Restore
    if cp "$backup_file" "$original_file"; then
        log_info "Restored ${original_file} from ${backup_file}"
        log_audit "config_restore" "$USER" "file=${original_file} from=${backup_file}"
        return 0
    else
        log_error "Failed to restore ${original_file}"
        return 1
    fi
}

# Show backup info
show_backup_info() {
    local backup_file=$1
    local meta_file="${backup_file}.meta"
    
    if [ -f "$meta_file" ]; then
        echo "Backup Information:"
        jq -r 'to_entries[] | "  \(.key): \(.value)"' "$meta_file"
    else
        echo "Backup: $backup_file"
        echo "  Created: $(stat -c %y "$backup_file" 2>/dev/null || echo 'unknown')"
        echo "  Size: $(stat -c %s "$backup_file" 2>/dev/null || echo 'unknown') bytes"
    fi
}

################################################################################
# Cleanup Functions
################################################################################

# Clean old backups
cleanup_old_backups() {
    local retention_days=${1:-$BACKUP_RETENTION_DAYS}
    
    log_info "Cleaning backups older than ${retention_days} days..."
    
    local count=0
    while IFS= read -r backup_file; do
        rm -f "$backup_file" "${backup_file}.meta"
        count=$((count + 1))
    done < <(find "$BACKUP_DIR" -name "*.backup" -type f -mtime +${retention_days} 2>/dev/null)
    
    if [ $count -gt 0 ]; then
        log_info "Cleaned ${count} old backup(s)"
    else
        log_debug "No old backups to clean"
    fi
}

# Get total backup size
get_backup_size() {
    du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo "0"
}

################################################################################
# Interactive Functions
################################################################################

# Interactive restore menu
interactive_restore() {
    local config_file=$1
    local basename=$(basename "$config_file")
    
    echo "Available backups for ${basename}:"
    echo ""
    
    local backups=($(list_backups "$config_file"))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo "No backups found"
        return 1
    fi
    
    local i=1
    for backup in "${backups[@]}"; do
        local timestamp=$(echo "$backup" | sed 's/.*\.\([0-9_]*\)\.backup/\1/')
        local date=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")
        echo "  $i) $date"
        
        # Show description if available
        local meta_file="${backup}.meta"
        if [ -f "$meta_file" ]; then
            local desc=$(jq -r '.description // ""' "$meta_file" 2>/dev/null)
            [ -n "$desc" ] && echo "     Description: $desc"
        fi
        
        i=$((i + 1))
    done
    
    echo ""
    read -r -p "Select backup to restore (1-${#backups[@]}), or 'q' to cancel: " choice
    
    if [ "$choice" = "q" ]; then
        echo "Cancelled"
        return 1
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        log_error "Invalid selection"
        return 1
    fi
    
    local selected_backup="${backups[$((choice - 1))]}"
    
    echo ""
    show_backup_info "$selected_backup"
    echo ""
    read -r -p "Restore this backup? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        restore_backup "$selected_backup"
    else
        echo "Cancelled"
        return 1
    fi
}

################################################################################
# Export functions
################################################################################

export -f backup_config
export -f list_backups
export -f get_latest_backup
export -f restore_backup
export -f show_backup_info
export -f cleanup_old_backups
export -f get_backup_size
export -f interactive_restore

export BACKUP_DIR
export BACKUP_RETENTION_DAYS
