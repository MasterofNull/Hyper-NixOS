#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Alert Manager
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Sends notifications for critical system events
# Supports: Email (SMTP), Webhooks (Slack/Discord/Teams), Local logging
#

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ALERT_CONFIG="/var/lib/hypervisor/configuration/alerts.conf"
ALERT_LOG="/var/lib/hypervisor/logs/alerts.log"
ALERT_COOLDOWN_DIR="/var/lib/hypervisor/alert-cooldowns"

# Only create directories if writable
if [[ -w /var/lib/hypervisor ]] || [[ ! -e /var/lib/hypervisor ]]; then
  mkdir -p "$(dirname "$ALERT_LOG")" "$ALERT_COOLDOWN_DIR" 2>/dev/null || true
fi

# Default configuration (NO SECRETS HERE!)
EMAIL_ENABLED=false
EMAIL_TO=""
EMAIL_FROM="hypervisor@$(hostname)"
SMTP_SERVER=""
SMTP_PORT=587
SMTP_USER=""
SMTP_PASS=""  # Loaded from config file only

WEBHOOK_ENABLED=false
WEBHOOK_URL=""  # Loaded from config file only

# Load configuration if exists (this is where secrets come from)
if [[ -f "$ALERT_CONFIG" ]]; then
  # Source config file securely
  set +u  # Allow undefined variables from config
  source "$ALERT_CONFIG"
  set -u
fi

log_alert() {
  local timestamp=$(date -Iseconds)
  echo "[$timestamp] $*" >> "$ALERT_LOG"
}

# Check cooldown period
check_cooldown() {
  local alert_id="$1"
  local cooldown_seconds="${2:-300}"  # Default 5 minutes
  
  local cooldown_file="$ALERT_COOLDOWN_DIR/$alert_id"
  
  if [[ -f "$cooldown_file" ]]; then
    local last_alert=$(cat "$cooldown_file")
    local now=$(date +%s)
    local elapsed=$((now - last_alert))
    
    if [[ $elapsed -lt $cooldown_seconds ]]; then
      return 1  # Still in cooldown
    fi
  fi
  
  # Update cooldown timestamp
  date +%s > "$cooldown_file"
  return 0  # Not in cooldown, send alert
}

send_email() {
  local subject="$1"
  local body="$2"
  
  if ! $EMAIL_ENABLED || [[ -z "$EMAIL_TO" ]]; then
    return 0
  fi
  
  log_alert "Sending email: $subject"
  
  if command -v mail >/dev/null 2>&1; then
    echo "$body" | mail -s "$subject" "$EMAIL_TO"
  elif command -v sendmail >/dev/null 2>&1; then
    {
      echo "To: $EMAIL_TO"
      echo "From: $EMAIL_FROM"
      echo "Subject: $subject"
      echo ""
      echo "$body"
    } | sendmail -t
  elif command -v curl >/dev/null 2>&1 && [[ -n "$SMTP_SERVER" ]]; then
    # Use curl for SMTP
    local msg_file=$(mktemp)
    {
      echo "From: $EMAIL_FROM"
      echo "To: $EMAIL_TO"
      echo "Subject: $subject"
      echo ""
      echo "$body"
    } > "$msg_file"
    
    if [[ -n "$SMTP_USER" && -n "$SMTP_PASS" ]]; then
      curl --url "smtp://$SMTP_SERVER:$SMTP_PORT" \
           --mail-from "$EMAIL_FROM" \
           --mail-rcpt "$EMAIL_TO" \
           --upload-file "$msg_file" \
           --user "$SMTP_USER:$SMTP_PASS" \
           --ssl-reqd 2>/dev/null || true
    fi
    
    rm -f "$msg_file"
  fi
}

send_webhook() {
  local title="$1"
  local message="$2"
  local severity="${3:-warning}"
  
  if ! $WEBHOOK_ENABLED || [[ -z "$WEBHOOK_URL" ]]; then
    return 0
  fi
  
  log_alert "Sending webhook: $title"
  
  # Determine color based on severity
  local color="16776960"  # Yellow (warning)
  case "$severity" in
    critical) color="16711680";;  # Red
    warning) color="16776960";;   # Yellow
    info) color="65280";;         # Green
  esac
  
  # Detect webhook type and format accordingly
  if [[ "$WEBHOOK_URL" == *"slack.com"* ]]; then
    # Slack format
    local payload=$(cat <<EOF
{
  "text": "$title",
  "attachments": [
    {
      "color": "#$(printf '%06x' $color)",
      "text": "$message",
      "footer": "Hyper-NixOS on $(hostname)",
      "ts": $(date +%s)
    }
  ]
}
EOF
)
  elif [[ "$WEBHOOK_URL" == *"discord"* ]]; then
    # Discord format
    local payload=$(cat <<EOF
{
  "embeds": [
    {
      "title": "$title",
      "description": "$message",
      "color": $color,
      "footer": {
        "text": "Hyper-NixOS on $(hostname)"
      },
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
    }
  ]
}
EOF
)
  else
    # Generic webhook
    local payload=$(cat <<EOF
{
  "title": "$title",
  "message": "$message",
  "severity": "$severity",
  "hostname": "$(hostname)",
  "timestamp": "$(date -Iseconds)"
}
EOF
)
  fi
  
  curl -X POST "$WEBHOOK_URL" \
       -H "Content-Type: application/json" \
       -d "$payload" \
       2>/dev/null || true
}

send_alert() {
  local severity="$1"
  local title="$2"
  local message="$3"
  local alert_id="${4:-$(echo "$title" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')}"
  local cooldown="${5:-300}"
  
  # Check cooldown
  if ! check_cooldown "$alert_id" "$cooldown"; then
    log_alert "Alert $alert_id suppressed (cooldown)"
    return 0
  fi
  
  log_alert "[$severity] $title"
  
  # Format full message
  local full_message=$(cat <<EOF
$message

System: $(hostname)
Time: $(date)
Severity: $severity

--
Hyper-NixOS Alert System
EOF
)
  
  # Send via all enabled channels
  send_email "[Hyper-NixOS] $severity: $title" "$full_message"
  send_webhook "$title" "$message" "$severity"
}

# Convenience functions for common alerts
alert_critical() {
  send_alert "CRITICAL" "$1" "$2" "${3:-}" "${4:-300}"
}

alert_warning() {
  send_alert "WARNING" "$1" "$2" "${3:-}" "${4:-600}"
}

alert_info() {
  send_alert "INFO" "$1" "$2" "${3:-}" "${4:-3600}"
}

# Example usage
usage() {
  cat <<EOF
Usage: $(basename "$0") <severity> <title> <message> [alert_id] [cooldown_seconds]

Severity: critical, warning, info
Title: Short description
Message: Detailed information
Alert ID: Unique identifier for cooldown (optional)
Cooldown: Seconds between same alert (optional)

Examples:
  $(basename "$0") critical "VM Down" "VM web-server failed to start"
  $(basename "$0") warning "Low Disk Space" "Root filesystem at 85%"
  $(basename "$0") info "System Updated" "NixOS configuration updated successfully"

Configuration:
  Edit: $ALERT_CONFIG
  
  EMAIL_ENABLED=true
  EMAIL_TO="admin@example.com"
  SMTP_SERVER="smtp.gmail.com"
  SMTP_PORT=587
  SMTP_USER="your@email.com"
  SMTP_PASS='CHANGE_ME_ACTUAL_PASSWORD'
  
  WEBHOOK_ENABLED=true
  WEBHOOK_URL='https://hooks.slack.com/services/YOUR/WEBHOOK'
EOF
}

# Main
main() {
  if [[ $# -lt 3 ]]; then
    usage
    exit 1
  fi
  
  local severity="$1"
  local title="$2"
  local message="$3"
  local alert_id="${4:-}"
  local cooldown="${5:-}"
  
  case "$severity" in
    critical)
      alert_critical "$title" "$message" "$alert_id" "$cooldown"
      ;;
    warning)
      alert_warning "$title" "$message" "$alert_id" "$cooldown"
      ;;
    info)
      alert_info "$title" "$message" "$alert_id" "$cooldown"
      ;;
    *)
      echo "Error: Invalid severity: $severity" >&2
      usage
      exit 1
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
  main "$@"
fi
