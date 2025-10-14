#!/usr/bin/env bash
# Unified notification system

TITLE="$1"
MESSAGE="$2"
SEVERITY="${3:-info}"  # info, warning, error, critical

# Desktop notification
if command -v notify-send &> /dev/null && [[ -n "$DISPLAY" ]]; then
    case "$SEVERITY" in
        critical) ICON="dialog-error" ;;
        error) ICON="dialog-warning" ;;
        warning) ICON="dialog-information" ;;
        *) ICON="dialog-information" ;;
    esac
    
    notify-send "$TITLE" "$MESSAGE" -i "$ICON" -u "$SEVERITY"
fi

# System log
logger -t "security-notification" -p "user.$SEVERITY" "$TITLE: $MESSAGE"

# Webhook notification (if configured)
if [[ -f "$HOME/.config/security/webhooks.conf" ]]; then
    source "$HOME/.config/security/webhooks.conf"
    
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"$TITLE\",\"message\":\"$MESSAGE\",\"severity\":\"$SEVERITY\"}" \
            2>/dev/null
    fi
fi

# Email notification (if configured)
if command -v mail &> /dev/null && [[ -n "$SECURITY_EMAIL" ]]; then
    echo "$MESSAGE" | mail -s "[$SEVERITY] $TITLE" "$SECURITY_EMAIL"
fi
