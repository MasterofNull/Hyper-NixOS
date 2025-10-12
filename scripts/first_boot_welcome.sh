#!/usr/bin/env bash
#
# Hyper-NixOS First Boot Welcome Screen
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Lightweight orientation screen shown once on first boot
# Provides guidance without forcing workflow
#
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

VERSION="2.0"
: "${DIALOG:=whiptail}"

LOGFILE="/var/lib/hypervisor/logs/first_boot.log"
MARKER_FILE="/var/lib/hypervisor/.first_boot_welcome_shown"

mkdir -p "$(dirname "$LOGFILE")" "$(dirname "$MARKER_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# Check if already shown
if [ -f "$MARKER_FILE" ]; then
  log "Welcome screen already shown, skipping"
  exit 0
fi

log "=== First Boot Welcome Screen ==="

# Show welcome with helpful guidance
$DIALOG --title "Welcome to Hyper-NixOS!" --msgbox "╔══════════════════════════════════════════════════════════════════╗
║           Welcome to Hyper-NixOS v${VERSION} - First Boot!            ║
║                    © 2024-2025 MasterofNull                      ║
╚══════════════════════════════════════════════════════════════════╝

🎉 System is ready! Here's how to get started:

✨ RECOMMENDED: Select \"Install VMs\" from the main menu
   → Complete guided workflow for your first VM
   → Downloads verified OS ISOs (14+ distributions)
   → Configures network bridges automatically
   → Creates VM with validation and hints
   → Launches VM immediately with console access

💡 OR explore the menu options yourself:
   • Start VMs - Launch your existing virtual machines
   • ISO Manager - Download/import OS installation images
   • More Options - System tools, updates, diagnostics

📚 Documentation: /etc/hypervisor/docs
📝 Logs: /var/lib/hypervisor/logs
🔧 Support: https://github.com/MasterofNull/Hyper-NixOS/issues

💬 TIP: Press ESC or Cancel anytime to return to main menu

This welcome message will only appear once.
Proceeding to main menu in 3 seconds..." 30 72 || true

# Mark as shown
touch "$MARKER_FILE"
log "Welcome screen shown and marked complete"

# Small delay for user to read
sleep 3

exit 0
