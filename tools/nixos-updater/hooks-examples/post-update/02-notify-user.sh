#!/usr/bin/env bash
#
# Example Hook: Notify user after update
#
# Sends notification via multiple methods after update completes

set -euo pipefail

BACKUP_GEN="${1:-unknown}"
NEW_GEN=$(nixos-rebuild list-generations | tail -1 | awk '{print $1}')

# Try notify-send (desktop notification)
if command -v notify-send >/dev/null 2>&1; then
    notify-send "NixOS Update Complete" \
        "System updated successfully!\nNew generation: $NEW_GEN" \
        --icon=system-software-update \
        --urgency=normal
fi

# Try wall (system-wide message)
if command -v wall >/dev/null 2>&1; then
    echo "NixOS system update complete! Generation $NEW_GEN is now active." | wall
fi

# Log to syslog
if command -v logger >/dev/null 2>&1; then
    logger -t nixos-updater "System updated: generation $BACKUP_GEN -> $NEW_GEN"
fi

echo "✓ Notifications sent"
