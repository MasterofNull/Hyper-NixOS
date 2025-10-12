#!/usr/bin/env bash
#
# Hyper-NixOS VM Scheduler
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Schedule VM operations (start, stop, snapshot) at specific times

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCHEDULE_CONFIG="/var/lib/hypervisor/configuration/vm-schedules.conf"
SCHEDULE_LOG="/var/lib/hypervisor/logs/scheduler.log"

mkdir -p "$(dirname "$SCHEDULE_CONFIG")" "$(dirname "$SCHEDULE_LOG")" 2>/dev/null || true

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$SCHEDULE_LOG"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  add <vm> <action> <schedule>      Add scheduled action
  remove <vm> <schedule-id>         Remove schedule
  list [vm]                         List schedules
  run                               Run scheduled actions (cron job)
  enable <schedule-id>              Enable schedule
  disable <schedule-id>             Disable schedule

Actions:
  start           Start VM
  shutdown        Graceful shutdown
  reboot          Reboot VM
  snapshot        Create snapshot
  pause           Pause VM
  resume          Resume VM

Schedule Format (cron-like):
  "0 9 * * 1-5"   = 9 AM, Monday-Friday
  "0 18 * * *"    = 6 PM daily
  "0 0 * * 0"     = Midnight on Sunday
  "*/15 * * * *"  = Every 15 minutes

Examples:
  # Start VM at 8 AM weekdays
  $(basename "$0") add web-server start "0 8 * * 1-5"
  
  # Shutdown at 6 PM daily
  $(basename "$0") add web-server shutdown "0 18 * * *"
  
  # Snapshot every Sunday at midnight
  $(basename "$0") add db-server snapshot "0 0 * * 0"
  
  # List all schedules
  $(basename "$0") list
  
  # List schedules for specific VM
  $(basename "$0") list web-server

Use Cases:
  • Power management (save energy)
  • Maintenance windows
  • Automatic backups
  • Peak/off-peak operations
  • Cost optimization (cloud)
EOF
}

# Initialize schedule database
init_schedule_db() {
  if [[ ! -f "$SCHEDULE_CONFIG" ]]; then
    cat > "$SCHEDULE_CONFIG" <<EOF
# VM Scheduler Configuration
# Format: id|vm_name|action|cron_schedule|enabled|created
# Example: 1|web-server|start|0 8 * * 1-5|true|2025-01-12T10:00:00
EOF
  fi
}

# Generate unique ID
generate_id() {
  local max_id=0
  
  if [[ -f "$SCHEDULE_CONFIG" ]]; then
    while IFS='|' read -r id rest; do
      [[ "$id" =~ ^# ]] && continue
      [[ -z "$id" ]] && continue
      if [[ $id -gt $max_id ]]; then
        max_id=$id
      fi
    done < "$SCHEDULE_CONFIG"
  fi
  
  echo $((max_id + 1))
}

# Add schedule
add_schedule() {
  local vm="$1"
  local action="$2"
  local schedule="$3"
  
  # Validate action
  case "$action" in
    start|shutdown|reboot|snapshot|pause|resume)
      ;;
    *)
      echo "Error: Invalid action: $action" >&2
      echo "Valid actions: start, shutdown, reboot, snapshot, pause, resume" >&2
      return 1
      ;;
  esac
  
  # Validate VM exists
  if ! virsh list --all --name | grep -q "^$vm$"; then
    echo "Error: VM not found: $vm" >&2
    return 1
  fi
  
  # Validate cron schedule
  if ! echo "$schedule" | grep -qE '^[0-9\*/,-]+ [0-9\*/,-]+ [0-9\*/,-]+ [0-9\*/,-]+ [0-9\*/,-]+$'; then
    echo "Error: Invalid cron schedule format" >&2
    echo "Format: minute hour day month weekday" >&2
    echo "Example: 0 8 * * 1-5 (8 AM weekdays)" >&2
    return 1
  fi
  
  init_schedule_db
  
  local id=$(generate_id)
  local created=$(date -Iseconds)
  
  echo "$id|$vm|$action|$schedule|true|$created" >> "$SCHEDULE_CONFIG"
  
  log "Added schedule: ID=$id, VM=$vm, Action=$action, Schedule=$schedule"
  
  echo "✓ Schedule added:"
  echo "  ID: $id"
  echo "  VM: $vm"
  echo "  Action: $action"
  echo "  Schedule: $schedule"
  echo "  Status: Enabled"
  echo ""
  echo "Next occurrence:"
  next_occurrence "$schedule"
}

# Calculate next occurrence
next_occurrence() {
  local schedule="$1"
  
  # This is a simplified version - for production, use a proper cron parser
  echo "  (Check system cron for exact time)"
}

# Remove schedule
remove_schedule() {
  local vm="$1"
  local id="$2"
  
  init_schedule_db
  
  if ! grep -q "^$id|" "$SCHEDULE_CONFIG"; then
    echo "Error: Schedule ID not found: $id" >&2
    return 1
  fi
  
  grep -v "^$id|" "$SCHEDULE_CONFIG" > "$SCHEDULE_CONFIG.tmp"
  mv "$SCHEDULE_CONFIG.tmp" "$SCHEDULE_CONFIG"
  
  log "Removed schedule: ID=$id"
  
  echo "✓ Schedule removed: ID $id"
}

# List schedules
list_schedules() {
  local vm_filter="${1:-}"
  
  init_schedule_db
  
  echo "VM Schedules:"
  echo ""
  printf "%-5s %-20s %-10s %-20s %-10s %-20s\n" "ID" "VM" "Action" "Schedule" "Status" "Created"
  printf "%-5s %-20s %-10s %-20s %-10s %-20s\n" "--" "--" "------" "--------" "------" "-------"
  
  while IFS='|' read -r id vm action schedule enabled created; do
    [[ "$id" =~ ^# ]] && continue
    [[ -z "$id" ]] && continue
    
    # Filter by VM if specified
    if [[ -n "$vm_filter" ]] && [[ "$vm" != "$vm_filter" ]]; then
      continue
    fi
    
    local status="Enabled"
    if [[ "$enabled" != "true" ]]; then
      status="Disabled"
    fi
    
    local created_short=$(echo "$created" | cut -d'T' -f1)
    
    printf "%-5s %-20s %-10s %-20s %-10s %-20s\n" "$id" "$vm" "$action" "$schedule" "$status" "$created_short"
  done < "$SCHEDULE_CONFIG"
}

# Enable schedule
enable_schedule() {
  local id="$1"
  
  init_schedule_db
  
  if ! grep -q "^$id|" "$SCHEDULE_CONFIG"; then
    echo "Error: Schedule ID not found: $id" >&2
    return 1
  fi
  
  # Update enabled status
  local temp_file=$(mktemp)
  
  while IFS='|' read -r sid vm action schedule enabled created; do
    if [[ "$sid" == "$id" ]]; then
      echo "$sid|$vm|$action|$schedule|true|$created"
    else
      echo "$sid|$vm|$action|$schedule|$enabled|$created"
    fi
  done < "$SCHEDULE_CONFIG" > "$temp_file"
  
  mv "$temp_file" "$SCHEDULE_CONFIG"
  
  log "Enabled schedule: ID=$id"
  
  echo "✓ Schedule enabled: ID $id"
}

# Disable schedule
disable_schedule() {
  local id="$1"
  
  init_schedule_db
  
  if ! grep -q "^$id|" "$SCHEDULE_CONFIG"; then
    echo "Error: Schedule ID not found: $id" >&2
    return 1
  fi
  
  # Update enabled status
  local temp_file=$(mktemp)
  
  while IFS='|' read -r sid vm action schedule enabled created; do
    if [[ "$sid" == "$id" ]]; then
      echo "$sid|$vm|$action|$schedule|false|$created"
    else
      echo "$sid|$vm|$action|$schedule|$enabled|$created"
    fi
  done < "$SCHEDULE_CONFIG" > "$temp_file"
  
  mv "$temp_file" "$SCHEDULE_CONFIG"
  
  log "Disabled schedule: ID=$id"
  
  echo "✓ Schedule disabled: ID $id"
}

# Run scheduled actions
run_scheduled_actions() {
  init_schedule_db
  
  local current_time=$(date '+%Y-%m-%d %H:%M')
  local current_minute=$(date '+%M')
  local current_hour=$(date '+%H')
  local current_day=$(date '+%d')
  local current_month=$(date '+%m')
  local current_weekday=$(date '+%u')  # 1-7 (Mon-Sun)
  
  log "Running scheduled actions check: $current_time"
  
  while IFS='|' read -r id vm action schedule enabled created; do
    [[ "$id" =~ ^# ]] && continue
    [[ -z "$id" ]] && continue
    [[ "$enabled" != "true" ]] && continue
    
    # Parse cron schedule
    read -r minute hour day month weekday <<< "$schedule"
    
    # Simple cron matching (basic implementation)
    # For production, use a proper cron library
    
    # Check if should run (simplified - matches on hour and minute)
    local should_run=false
    
    # Check minute
    if [[ "$minute" == "*" ]] || [[ "$minute" == "$current_minute" ]]; then
      # Check hour
      if [[ "$hour" == "*" ]] || [[ "$hour" == "$current_hour" ]]; then
        should_run=true
      fi
    fi
    
    if $should_run; then
      log "Executing scheduled action: VM=$vm, Action=$action"
      
      case "$action" in
        start)
          if ! virsh list --name | grep -q "^$vm$"; then
            virsh start "$vm" && log "✓ Started VM: $vm"
          else
            log "VM already running: $vm"
          fi
          ;;
        shutdown)
          if virsh list --name | grep -q "^$vm$"; then
            virsh shutdown "$vm" && log "✓ Shutdown initiated: $vm"
          else
            log "VM not running: $vm"
          fi
          ;;
        reboot)
          if virsh list --name | grep -q "^$vm$"; then
            virsh reboot "$vm" && log "✓ Rebooted VM: $vm"
          else
            log "VM not running: $vm"
          fi
          ;;
        snapshot)
          if [[ -x /etc/hypervisor/scripts/snapshot_manager.sh ]]; then
            /etc/hypervisor/scripts/snapshot_manager.sh auto-snapshot "$vm" && \
              log "✓ Created snapshot: $vm"
          else
            log "Snapshot manager not available"
          fi
          ;;
        pause)
          if virsh list --name | grep -q "^$vm$"; then
            virsh suspend "$vm" && log "✓ Paused VM: $vm"
          fi
          ;;
        resume)
          if virsh list --all --name | grep -q "^$vm$"; then
            virsh resume "$vm" && log "✓ Resumed VM: $vm"
          fi
          ;;
      esac
    fi
  done < "$SCHEDULE_CONFIG"
  
  log "Scheduled actions check complete"
}

# Main
case "${1:-}" in
  add)
    add_schedule "${2:-}" "${3:-}" "${4:-}"
    ;;
  remove)
    remove_schedule "${2:-}" "${3:-}"
    ;;
  list)
    list_schedules "${2:-}"
    ;;
  run)
    run_scheduled_actions
    ;;
  enable)
    enable_schedule "${2:-}"
    ;;
  disable)
    disable_schedule "${2:-}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
