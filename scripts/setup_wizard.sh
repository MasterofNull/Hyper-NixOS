#!/usr/bin/env bash
set -euo pipefail
: "${DIALOG:=whiptail}"

require() { for b in $DIALOG jq; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

$DIALOG --msgbox "Welcome to Hypervisor Suite Setup Wizard\n\nThis will guide you through essential steps." 12 70

# 1. Network bridge creation
if $DIALOG --yesno "Create a network bridge now?" 10 60 ; then
  /etc/hypervisor/scripts/bridge_helper.sh || true
fi

# 2. Download OS installer ISOs
if $DIALOG --yesno "Download an OS installer ISO now?" 10 60 ; then
  /etc/hypervisor/scripts/iso_manager.sh || true
fi

# 3. Create your first VM
if $DIALOG --yesno "Create your first VM now?" 10 60 ; then
  /etc/hypervisor/scripts/create_vm_wizard.sh /var/lib/hypervisor/vm_profiles /var/lib/hypervisor/isos || true
fi

$DIALOG --msgbox "Setup complete. See /etc/hypervisor/docs for guides and warnings." 10 70
