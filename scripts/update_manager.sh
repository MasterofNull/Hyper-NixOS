#!/usr/bin/env bash
# Comprehensive update management system for the hypervisor

set -Eeuo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG_FILE="/var/lib/hypervisor/logs/update-$(date +%Y%m%d-%H%M%S).log"
UPDATE_STATUS="/var/lib/hypervisor/update-status.json"
LAST_CHECK_FILE="/var/lib/hypervisor/.last-update-check"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Ensure git is available for flake operations
ensure_git_available() {
  if ! command -v git >/dev/null 2>&1; then
    # Try to add git from nix-env or system paths
    if [[ -d ~/.nix-profile/bin ]]; then
      export PATH="$HOME/.nix-profile/bin:$PATH"
    fi
    if [[ -d /run/current-system/sw/bin ]]; then
      export PATH="/run/current-system/sw/bin:$PATH"
    fi
    # Still not available?
    if ! command -v git >/dev/null 2>&1; then
      log "WARNING: Git is not in PATH - some operations may fail"
      log "Consider installing git: nix-env -iA nixos.git"
      return 1
    fi
  fi
  return 0
}

# Check for system updates
check_updates() {
  log "Checking for updates..."
  
  # Ensure git is available for update checks
  ensure_git_available || log "Proceeding without git - some checks may be skipped"
  
  # Check if flake needs updating
  local flake_dir="/etc/hypervisor"
  local updates_available=false
  
  if [[ -d "$flake_dir/.git" ]]; then
    if command -v git >/dev/null 2>&1; then
      cd "$flake_dir"
      git fetch origin >/dev/null 2>&1
    else
      log "Git not available - skipping git update check"
      cd "$flake_dir"
    fi
    
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master)
    
    if [[ "$local_commit" != "$remote_commit" ]]; then
      updates_available=true
      log "Updates available: $local_commit -> $remote_commit"
    else
      log "System is up to date"
    fi
  fi
  
  # Check NixOS channels
  if command -v nix-channel >/dev/null 2>&1; then
    log "Checking NixOS channels..."
    nix-channel --update 2>&1 | tee -a "$LOG_FILE"
  fi
  
  # Save check time
  date +%s > "$LAST_CHECK_FILE"
  
  # Generate status
  cat > "$UPDATE_STATUS" <<EOF
{
  "last_check": "$(date -Iseconds)",
  "updates_available": $updates_available,
  "local_commit": "${local_commit:-unknown}",
  "remote_commit": "${remote_commit:-unknown}"
}
EOF
  
  if $updates_available; then
    log "✓ Updates available"
    return 1
  else
    log "✓ System is up to date"
    return 0
  fi
}

# Apply updates
apply_updates() {
  local auto_reboot="${1:-false}"
  
  log "=== Applying Updates ==="
  
  # Ensure git is available for flake operations
  if ! ensure_git_available; then
    log "Git not available - attempting flake update with nix-shell"
    cd /etc/hypervisor
    if ! nix-shell -p git --run "nix flake update" 2>&1 | tee -a "$LOG_FILE"; then
      log "WARNING: Flake update failed - proceeding with current lock file"
    fi
  fi
  
  # Pre-update backup
  log "Creating pre-update backup..."
  if [[ -f /etc/hypervisor/scripts/automated_backup.sh ]]; then
    /etc/hypervisor/scripts/automated_backup.sh backup running 2>&1 | tee -a "$LOG_FILE"
  fi
  
  # Update flake inputs (if git is available, update normally)
  if command -v git >/dev/null 2>&1; then
    log "Updating flake inputs..."
    cd /etc/hypervisor
    nix flake update 2>&1 | tee -a "$LOG_FILE"
  else
    log "Skipping flake update - git not available"
  fi
  
  # Test build first
  log "Testing new configuration (dry-run)..."
  if ! nixos-rebuild dry-build --flake "/etc/hypervisor#$(hostname -s)" 2>&1 | tee -a "$LOG_FILE"; then
    log "ERROR: Build test failed - not applying updates"
    return 1
  fi
  
  # Apply updates
  log "Applying updates..."
  if nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)" 2>&1 | tee -a "$LOG_FILE"; then
    log "✓ Updates applied successfully"
    
    # Restart services if needed
    log "Restarting hypervisor services..."
    systemctl restart libvirtd || true
    systemctl restart hypervisor-menu || true
    
    if [[ "$auto_reboot" == "true" ]]; then
      log "Auto-reboot enabled - rebooting in 60 seconds..."
      shutdown -r +1 "System reboot for hypervisor updates" &
    fi
    
    return 0
  else
    log "ERROR: Update failed"
    log "System rolled back to previous generation"
    return 1
  fi
}

# Rollback to previous generation
rollback() {
  log "=== Rolling Back System ==="
  
  local current_gen=$(readlink /run/current-system | grep -oP 'system-\K\d+')
  local previous_gen=$((current_gen - 1))
  
  log "Current generation: $current_gen"
  log "Rolling back to: $previous_gen"
  
  if nixos-rebuild switch --rollback 2>&1 | tee -a "$LOG_FILE"; then
    log "✓ Rollback successful"
    systemctl restart libvirtd || true
    systemctl restart hypervisor-menu || true
    return 0
  else
    log "ERROR: Rollback failed"
    return 1
  fi
}

# List available generations
list_generations() {
  log "Available NixOS generations:"
  nixos-rebuild list-generations | while read line; do
    log "  $line"
  done
}

# Cleanup old generations
cleanup_old() {
  local keep_generations="${1:-5}"
  
  log "Cleaning up old generations (keeping $keep_generations)..."
  
  nix-env --delete-generations +$keep_generations 2>&1 | tee -a "$LOG_FILE"
  nix-collect-garbage -d 2>&1 | tee -a "$LOG_FILE"
  
  log "✓ Cleanup complete"
}

# Check update status
status() {
  if [[ -f "$UPDATE_STATUS" ]]; then
    cat "$UPDATE_STATUS"
  else
    echo '{"status": "unknown", "message": "Run update check first"}'
  fi
  
  # Show last check time
  if [[ -f "$LAST_CHECK_FILE" ]]; then
    local last_check=$(cat "$LAST_CHECK_FILE")
    local now=$(date +%s)
    local diff=$((now - last_check))
    local hours=$((diff / 3600))
    echo "Last checked: $hours hours ago"
  else
    echo "Never checked for updates"
  fi
  
  # Show current generation
  local current_gen=$(readlink /run/current-system | grep -oP 'system-\K\d+')
  echo "Current generation: $current_gen"
}

# Automatic update check (for cron/systemd timer)
auto_check() {
  # Check if we should run (once per day)
  if [[ -f "$LAST_CHECK_FILE" ]]; then
    local last_check=$(cat "$LAST_CHECK_FILE")
    local now=$(date +%s)
    local diff=$((now - last_check))
    
    # 24 hours = 86400 seconds
    if [[ $diff -lt 86400 ]]; then
      log "Skipping check (last check was $((diff / 3600)) hours ago)"
      return 0
    fi
  fi
  
  check_updates
}

# Main
case "${1:-help}" in
  check)
    check_updates
    status
    ;;
    
  update)
    AUTO_REBOOT="${2:-false}"
    if check_updates; then
      log "No updates available"
    else
      apply_updates "$AUTO_REBOOT"
    fi
    ;;
    
  rollback)
    rollback
    ;;
    
  status)
    status
    ;;
    
  list)
    list_generations
    ;;
    
  cleanup)
    KEEP="${2:-5}"
    cleanup_old "$KEEP"
    ;;
    
  auto-check)
    auto_check
    ;;
    
  *)
    cat <<EOF
Hypervisor Update Manager

Usage:
  $0 check
    Check for available updates
    
  $0 update [auto-reboot]
    Apply available updates
    Optional: auto-reboot=true to reboot after update
    
  $0 rollback
    Roll back to previous system generation
    
  $0 status
    Show current update status
    
  $0 list
    List available system generations
    
  $0 cleanup [keep-count]
    Clean up old generations (default: keep 5)
    
  $0 auto-check
    Automatic check (for systemd timer)

Examples:
  # Check for updates
  $0 check
  
  # Apply updates without reboot
  $0 update
  
  # Apply updates and reboot
  $0 update true
  
  # Rollback if something broke
  $0 rollback
  
  # Clean up old generations
  $0 cleanup 3

Logs: $LOG_FILE
EOF
    ;;
esac
