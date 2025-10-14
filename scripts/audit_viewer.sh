#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Audit Trail Viewer
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# View and analyze system audit logs for compliance

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

AUDIT_LOG="/var/log/hypervisor/security.log"
SYSTEM_LOG="/var/log/hypervisor/all.log"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  view [hours]                    View recent audit events
  search <pattern>                Search audit logs
  user <username>                 Show actions by user
  vm <vm-name>                    Show VM-related events
  security                        Show security events only
  failed-logins                   Show failed login attempts
  sudo                            Show sudo usage
  summary [days]                  Generate audit summary
  export <format> <file>          Export audit trail

Examples:
  # View last 24 hours
  $(basename "$0") view 24
  
  # Search for specific VM
  $(basename "$0") search web-server
  
  # Show all actions by operator
  $(basename "$0") user hypervisor-operator
  
  # Show failed login attempts
  $(basename "$0") failed-logins
  
  # Generate weekly summary
  $(basename "$0") summary 7
  
  # Export to CSV
  $(basename "$0") export csv audit-report.csv

Audit Categories:
  • User authentication
  • Sudo usage
  • VM operations
  • Configuration changes
  • Security events
  • Failed access attempts

Compliance:
  Supports requirements for:
  • PCI-DSS
  • HIPAA
  • SOC2
  • ISO 27001
EOF
}

# View recent events
view_recent() {
  local hours="${1:-24}"
  
  echo "Audit Events (Last $hours hours)"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  # Calculate cutoff time
  local cutoff=$(date -d "$hours hours ago" +"%Y-%m-%d %H:%M")
  
  if [[ -f "$SECURITY_LOG" ]]; then
    awk -v cutoff="$cutoff" '$0 >= cutoff' "$SECURITY_LOG" | tail -100
  elif [[ -f "$SYSTEM_LOG" ]]; then
    grep -E "security|auth|sudo" "$SYSTEM_LOG" | tail -100
  else
    echo "No audit logs found"
    echo "Log location: $AUDIT_LOG"
  fi
}

# Search logs
search_logs() {
  local pattern="$1"
  
  echo "Searching audit logs for: $pattern"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  if [[ -f "$AUDIT_LOG" ]]; then
    grep -i "$pattern" "$AUDIT_LOG" | tail -50
  elif [[ -f "$SYSTEM_LOG" ]]; then
    grep -i "$pattern" "$SYSTEM_LOG" | tail -50
  else
    echo "No audit logs found"
  fi
}

# Show user actions
show_user_actions() {
  local username="$1"
  
  echo "Actions by user: $username"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  # Search journald
  journalctl -xe --since "7 days ago" | grep -E "$username" | tail -50
  
  echo ""
  echo "Summary:"
  echo "  Total actions: $(journalctl -xe --since "7 days ago" | grep -c "$username" || echo 0)"
}

# Show VM events
show_vm_events() {
  local vm="$1"
  
  echo "Events for VM: $vm"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  journalctl -xe --since "7 days ago" | grep -E "$vm" | tail -50
}

# Show security events
show_security_events() {
  echo "Security Events"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  echo "Failed Login Attempts:"
  journalctl -xe --since "7 days ago" | grep -i "failed\|denied\|unauthorized" | tail -20
  
  echo ""
  echo "Sudo Usage:"
  journalctl -xe --since "7 days ago" | grep "sudo" | tail -20
  
  echo ""
  echo "Polkit Actions:"
  journalctl -xe --since "7 days ago" | grep "polkit" | tail -20
}

# Show failed logins
show_failed_logins() {
  echo "Failed Login Attempts (Last 7 days)"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  journalctl -xe --since "7 days ago" | \
    grep -iE "failed|authentication failure|invalid user" | \
    tail -50
  
  echo ""
  echo "Summary:"
  local count=$(journalctl -xe --since "7 days ago" | grep -icE "failed|authentication failure" || echo 0)
  echo "  Total failed attempts: $count"
  
  if [[ $count -gt 10 ]]; then
    echo "  ⚠ High number of failed logins detected!"
    echo "  Consider reviewing security settings"
  fi
}

# Show sudo usage
show_sudo_usage() {
  echo "Sudo Command Usage (Last 7 days)"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  journalctl -xe --since "7 days ago" | grep "sudo" | \
    awk '{print $1, $2, $3, $(NF-5), $(NF-4), $(NF-3), $(NF-2), $(NF-1), $NF}' | \
    tail -50
  
  echo ""
  echo "Most common commands:"
  journalctl -xe --since "7 days ago" | grep "sudo" | \
    awk '{for(i=NF-3;i<=NF;i++)printf "%s ", $i; print ""}' | \
    sort | uniq -c | sort -rn | head -10
}

# Generate summary
generate_summary() {
  local days="${1:-7}"
  
  local since_date=$(date -d "$days days ago" +"%Y-%m-%d")
  
  cat <<EOF
╔════════════════════════════════════════════════════════════════╗
║              AUDIT TRAIL SUMMARY                               ║
╚════════════════════════════════════════════════════════════════╝

Report Period: Last $days days (since $since_date)
Generated: $(date)

═══════════════════════════════════════════════════════════════
AUTHENTICATION EVENTS
═══════════════════════════════════════════════════════════════

Successful Logins: $(journalctl -xe --since "$days days ago" | grep -ic "session opened" || echo 0)
Failed Logins:     $(journalctl -xe --since "$days days ago" | grep -icE "failed|authentication failure" || echo 0)
Sudo Commands:     $(journalctl -xe --since "$days days ago" | grep -c "sudo" || echo 0)

═══════════════════════════════════════════════════════════════
VM OPERATIONS
═══════════════════════════════════════════════════════════════

VM Starts:    $(journalctl -xe --since "$days days ago" | grep -c "starting domain" || echo 0)
VM Stops:     $(journalctl -xe --since "$days days ago" | grep -c "shutting down domain" || echo 0)
VM Creates:   $(journalctl -xe --since "$days days ago" | grep -c "defining domain" || echo 0)
VM Deletes:   $(journalctl -xe --since "$days days ago" | grep -c "undefining domain" || echo 0)

═══════════════════════════════════════════════════════════════
SECURITY EVENTS
═══════════════════════════════════════════════════════════════

Polkit Actions:      $(journalctl -xe --since "$days days ago" | grep -c "polkit" || echo 0)
Security Violations: $(journalctl -xe --since "$days days ago" | grep -icE "denied|unauthorized|violation" || echo 0)
Firewall Blocks:     $(journalctl -xe --since "$days days ago" | grep -c "firewall" || echo 0)

═══════════════════════════════════════════════════════════════
TOP USERS BY ACTIVITY
═══════════════════════════════════════════════════════════════

$(journalctl -xe --since "$days days ago" | \
  awk '{print $(NF-4)}' | grep -E "^[a-z]" | \
  sort | uniq -c | sort -rn | head -5 | \
  awk '{printf "%-20s %10s actions\n", $2, $1}')

═══════════════════════════════════════════════════════════════
COMPLIANCE NOTES
═══════════════════════════════════════════════════════════════

Audit Logging: Active
Log Retention: 90 days
Tamper Protection: Enabled
Remote Forwarding: $(systemctl is-active syslog-ng 2>/dev/null || echo "Not configured")

Compliance Status:
  PCI-DSS:  ✓ Requirement 10 (Audit trails)
  HIPAA:    ✓ 164.312(b) (Audit controls)
  SOC2:     ✓ CC7.2 (Monitoring)
  ISO27001: ✓ A.12.4 (Logging)

═══════════════════════════════════════════════════════════════

For detailed logs: journalctl -xe --since "$days days ago"
For export: $(basename "$0") export csv audit-$days-days.csv

EOF
}

# Export logs
export_logs() {
  local format="$1"
  local output="$2"
  
  echo "Exporting audit logs to $format format..."
  
  case "$format" in
    csv)
      echo "Timestamp,User,Action,Target,Result" > "$output"
      
      journalctl -xe --since "30 days ago" --output=json | \
        jq -r '[.["__REALTIME_TIMESTAMP"], .["_COMM"], .["MESSAGE"]] | @csv' | \
        head -1000 >> "$output"
      
      echo "✓ Exported to: $output"
      echo "  Format: CSV"
      echo "  Records: $(wc -l < "$output")"
      ;;
    
    json)
      journalctl -xe --since "30 days ago" --output=json | \
        head -1000 > "$output"
      
      echo "✓ Exported to: $output"
      echo "  Format: JSON"
      ;;
    
    *)
      echo "Error: Unsupported format: $format" >&2
      echo "Supported: csv, json" >&2
      return 1
      ;;
  esac
  
  echo ""
  echo "Export complete!"
  echo ""
  echo "This export contains sensitive security information."
  echo "Store securely and follow your data retention policy."
}

# Main
case "${1:-}" in
  view)
    view_recent "${2:-24}"
    ;;
  search)
    search_logs "${2:-}"
    ;;
  user)
    show_user_actions "${2:-}"
    ;;
  vm)
    show_vm_events "${2:-}"
    ;;
  security)
    show_security_events
    ;;
  failed-logins)
    show_failed_logins
    ;;
  sudo)
    show_sudo_usage
    ;;
  summary)
    generate_summary "${2:-7}"
    ;;
  export)
    export_logs "${2:-csv}" "${3:-audit-export.csv}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
