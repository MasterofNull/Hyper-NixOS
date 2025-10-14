#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Automated Backup Verification
# Runs weekly to verify backup integrity
# Non-interactive version of guided wizard
#

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

BACKUP_DIR="/var/lib/hypervisor/backups"
TEST_DIR="/tmp/backup-verify-auto-$$"
LOG_FILE="/var/lib/hypervisor/logs/backup-verification-auto-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="/var/lib/hypervisor/backup-verification-$(date +%Y%m%d).txt"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

cleanup() {
  [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}
trap cleanup EXIT

verify_backup() {
  local backup_file="$1"
  local filename=$(basename "$backup_file")
  
  log "Verifying: $filename"
  
  # Check file integrity
  if [[ ! -r "$backup_file" ]]; then
    log "ERROR: File not readable"
    return 1
  fi
  
  local size=$(stat -c%s "$backup_file" 2>/dev/null || echo 0)
  if [[ $size -eq 0 ]]; then
    log "ERROR: File is empty"
    return 1
  fi
  
  log "✓ File integrity OK"
  
  # Test restore
  mkdir -p "$TEST_DIR"
  
  if [[ "$backup_file" == *.qcow2 ]]; then
    if ! qemu-img check "$backup_file" >> "$LOG_FILE" 2>&1; then
      log "ERROR: QCOW2 image corrupt"
      return 1
    fi
    
    if ! cp "$backup_file" "$TEST_DIR/test.qcow2" 2>>"$LOG_FILE"; then
      log "ERROR: Restore failed"
      return 1
    fi
  elif [[ "$backup_file" == *.tar.gz ]]; then
    if ! tar -xzf "$backup_file" -C "$TEST_DIR" 2>>"$LOG_FILE"; then
      log "ERROR: Extraction failed"
      return 1
    fi
  fi
  
  log "✓ Restore OK"
  
  # Cleanup test files
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"
  
  log "✓ Backup verified: $filename"
  return 0
}

main() {
  log "=== Automated Backup Verification Started ==="
  
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log "ERROR: Backup directory not found: $BACKUP_DIR"
    exit 1
  fi
  
  local total=0
  local verified=0
  local failed=0
  local failed_backups=()
  
  # Find all recent backups (last 30 days)
  while IFS= read -r -d '' backup; do
    ((total++))
    
    if verify_backup "$backup"; then
      ((verified++))
    else
      ((failed++))
      failed_backups+=("$(basename "$backup")")
    fi
  done < <(find "$BACKUP_DIR" -type f \( -name "*.qcow2" -o -name "*.tar.gz" \) -mtime -30 -print0 2>/dev/null)
  
  # Generate report
  cat > "$REPORT_FILE" << EOF
BACKUP VERIFICATION REPORT
Generated: $(date)

SUMMARY:
  Total backups checked: $total
  Successfully verified: $verified
  Failed verification: $failed

STATUS: $(if [[ $failed -eq 0 ]]; then echo "✓ ALL BACKUPS VERIFIED"; else echo "⚠ SOME BACKUPS FAILED"; fi)

DETAILS:
$(if [[ $failed -gt 0 ]]; then
  echo "Failed backups:"
  for backup in "${failed_backups[@]}"; do
    echo "  - $backup"
  done
  echo ""
  echo "ACTION REQUIRED: Create new backups for failed items"
fi)

NEXT VERIFICATION: $(date -d "+7 days" +%Y-%m-%d)

Log: $LOG_FILE
EOF
  
  log "=== Verification Complete: $verified/$total verified ==="
  
  # Send alert if failures
  if [[ $failed -gt 0 ]] && [[ -x /etc/hypervisor/scripts/alert_manager.sh ]]; then
    /etc/hypervisor/scripts/alert_manager.sh critical \
      "Backup Verification Failed" \
      "$failed out of $total backups failed verification. Check $REPORT_FILE" \
      "backup_verification_failed" \
      86400
  elif [[ $verified -gt 0 ]] && [[ -x /etc/hypervisor/scripts/alert_manager.sh ]]; then
    /etc/hypervisor/scripts/alert_manager.sh info \
      "Backup Verification Successful" \
      "$verified backups verified successfully" \
      "backup_verification_success" \
      604800  # Weekly
  fi
  
  cat "$REPORT_FILE"
}

main "$@"
