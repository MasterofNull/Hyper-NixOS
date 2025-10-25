#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Automated Health Monitoring - Continuous VM and system health checks
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

HEALTH_LOG="/var/lib/hypervisor/logs/health_monitor.log"
HEALTH_STATE="/var/lib/hypervisor/health_state.json"
CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-60}"  # seconds
ALERT_SCRIPT="${HEALTH_ALERT_SCRIPT:-/etc/hypervisor/scripts/alert_handler.sh}"

mkdir -p "$(dirname "$HEALTH_LOG")"
mkdir -p "$(dirname "$HEALTH_STATE")"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$HEALTH_LOG"
}

# Check host health
check_host_health() {
  local issues=()
  
  # Check KVM
  if [[ ! -c /dev/kvm ]]; then
    issues+=("KVM device missing - virtualization disabled")
  fi
  
  # Check libvirtd
  if ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    issues+=("libvirtd service not running")
  fi
  
  # Check disk space
  local disk_usage=$(df /var/lib/hypervisor 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo 100)
  if [[ "$disk_usage" -gt 90 ]]; then
    issues+=("Critical: Disk usage at ${disk_usage}%")
  elif [[ "$disk_usage" -gt 80 ]]; then
    issues+=("Warning: Disk usage at ${disk_usage}%")
  fi
  
  # Check memory
  local mem_percent=$(free | awk '/^Mem:/{printf("%.0f", $3/$2*100)}')
  if [[ "$mem_percent" -gt 95 ]]; then
    issues+=("Critical: Memory usage at ${mem_percent}%")
  elif [[ "$mem_percent" -gt 85 ]]; then
    issues+=("Warning: Memory usage at ${mem_percent}%")
  fi
  
  # Return issues
  printf "%s\n" "${issues[@]}"
}

# Check individual VM health
check_vm_health() {
  local vm="$1"
  local issues=()
  
  # Check state
  local state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
  
  # Check if VM is supposed to be running (autostart enabled)
  local autostart=$(virsh dominfo "$vm" 2>/dev/null | awk '/Autostart:/ {print $2}' || echo "disable")
  
  if [[ "$autostart" == "enable" && "$state" != "running" ]]; then
    issues+=("VM configured for autostart but not running (state: $state)")
  fi
  
  # For running VMs, check resource usage
  if [[ "$state" == "running" ]]; then
    # Check if guest agent is responsive (if installed)
    if virsh dominfo "$vm" 2>/dev/null | grep -q "guest agent"; then
      if ! timeout 5 virsh qemu-agent-command "$vm" '{"execute":"guest-ping"}' >/dev/null 2>&1; then
        issues+=("Guest agent not responding")
      fi
    fi
    
    # Check memory balloon
    local mem_stats=$(virsh dommemstat "$vm" 2>/dev/null || true)
    if [[ -n "$mem_stats" ]]; then
      local unused=$(echo "$mem_stats" | awk '/^unused/ {print $2}' || echo 0)
      local actual=$(echo "$mem_stats" | awk '/^actual/ {print $2}' || echo 1)
      
      if [[ "$actual" -gt 0 ]]; then
        local usage_percent=$(( (actual - unused) * 100 / actual ))
        if [[ "$usage_percent" -gt 95 ]]; then
          issues+=("High memory usage: ${usage_percent}%")
        fi
      fi
    fi
  fi
  
  printf "%s\n" "${issues[@]}"
}

# Check all VMs
check_all_vms() {
  local all_issues=()
  
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    local vm_issues=$(check_vm_health "$vm")
    
    if [[ -n "$vm_issues" ]]; then
      while IFS= read -r issue; do
        all_issues+=("VM $vm: $issue")
      done <<< "$vm_issues"
    fi
  done < <(virsh list --all --name 2>/dev/null || true)
  
  printf "%s\n" "${all_issues[@]}"
}

# Generate health report
generate_health_report() {
  local timestamp=$(date -Iseconds)
  local host_issues=$(check_host_health)
  local vm_issues=$(check_all_vms)
  
  # Count issues by severity
  local critical_count=$(echo -e "${host_issues}\n${vm_issues}" | grep -c "Critical" || echo 0)
  local warning_count=$(echo -e "${host_issues}\n${vm_issues}" | grep -c "Warning" || echo 0)
  local info_count=$(( $(echo -e "${host_issues}\n${vm_issues}" | grep -v "^$" | wc -l) - critical_count - warning_count ))
  
  # Overall health status
  local health_status="healthy"
  [[ "$warning_count" -gt 0 ]] && health_status="degraded"
  [[ "$critical_count" -gt 0 ]] && health_status="critical"
  
  # Create JSON health state
  cat > "$HEALTH_STATE" <<EOF
{
  "timestamp": "$timestamp",
  "status": "$health_status",
  "issues": {
    "critical": $critical_count,
    "warning": $warning_count,
    "info": $info_count
  },
  "host_issues": $(echo "$host_issues" | jq -R . | jq -s . || echo "[]"),
  "vm_issues": $(echo "$vm_issues" | jq -R . | jq -s . || echo "[]")
}
EOF
  
  # Log health check
  log "Health check complete: $health_status (Critical: $critical_count, Warning: $warning_count, Info: $info_count)"
  
  # Send alerts if issues found
  if [[ "$critical_count" -gt 0 || "$warning_count" -gt 0 ]]; then
    log "Issues detected, triggering alerts..."
    
    # Call alert handler if it exists
    if [[ -x "$ALERT_SCRIPT" ]]; then
      "$ALERT_SCRIPT" "$health_status" "$HEALTH_STATE" || true
    fi
    
    # Log each issue
    while IFS= read -r issue; do
      [[ -z "$issue" ]] && continue
      log "ISSUE: $issue"
    done < <(echo -e "${host_issues}\n${vm_issues}")
  fi
  
  echo "$health_status"
}

# Daemon mode
daemon_mode() {
  log "Health monitor starting in daemon mode (interval: ${CHECK_INTERVAL}s)"
  
  while true; do
    health_status=$(generate_health_report)
    
    # Sleep until next check
    sleep "$CHECK_INTERVAL"
  done
}

# Single check mode
single_check() {
  health_status=$(generate_health_report)
  
  # Display results
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Health Check Results"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Overall Status: $health_status"
  echo ""
  
  # Show health state
  if [[ -f "$HEALTH_STATE" ]]; then
    jq -r '
      "Timestamp: \(.timestamp)",
      "Status: \(.status)",
      "",
      "Issue Counts:",
      "  Critical: \(.issues.critical)",
      "  Warning: \(.issues.warning)",
      "  Info: \(.issues.info)",
      "",
      "Host Issues:",
      (.host_issues[] | "  • \(.)"),
      "",
      "VM Issues:",
      (.vm_issues[] | "  • \(.)")
    ' "$HEALTH_STATE" 2>/dev/null || cat "$HEALTH_STATE"
  fi
}

# Main
case "${1:-check}" in
  daemon)
    daemon_mode
    ;;
  check|*)
    single_check
    ;;
esac
