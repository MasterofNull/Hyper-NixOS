#!/usr/bin/env bash
set -euo pipefail
: "${DIALOG:=whiptail}"

require() { for b in $DIALOG jq; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

$DIALOG --msgbox "Welcome to Hypervisor Suite Setup Wizard\n\nWe will configure a secure-by-default hypervisor with sensible features enabled. You can adjust any setting later." 14 78

# 1. Network bridge creation
if $DIALOG --yesno "Create a secure network bridge (recommended)?\n\nThis enables VM networking with isolation." 12 70 ; then
  /etc/hypervisor/scripts/bridge_helper.sh || true
fi

# 2. Download OS installer ISOs
if $DIALOG --yesno "Download and verify an OS installer ISO (recommended)?\n\nWe auto-fetch checksums/signatures and verify authenticity." 14 80 ; then
  /etc/hypervisor/scripts/iso_manager.sh || true
fi

# 3. Create your first VM
if $DIALOG --yesno "Create your first VM with secure defaults (recommended)?\n\nVirtio devices, Secure Boot (OVMF), and non-root QEMU will be used." 14 80 ; then
  /etc/hypervisor/scripts/create_vm_wizard.sh /var/lib/hypervisor/vm_profiles /var/lib/hypervisor/isos || true
fi

# Security toggles (recommended enabled)
if $DIALOG --yesno "Enable strict firewall (default-deny) and allow SSH + libvirt network?\n\nYou can widen rules later." 14 80 ; then
  $DIALOG --msgbox "To enable: set hypervisor.security.strictFirewall = true in configuration.nix" 10 70
fi

# VFIO and hardware detection
if $DIALOG --yesno "Detect hardware and prepare VFIO passthrough (optional)?\n\nWe will propose GPU/audio IDs and write a Nix snippet." 14 80 ; then
  /etc/hypervisor/scripts/vfio_workflow.sh || true
fi

# Preflight check and device integration
/etc/hypervisor/scripts/preflight_check.sh || true
/etc/hypervisor/scripts/detect_and_adjust.sh || true

$DIALOG --msgbox "Setup complete. You can revisit any step via the main menu.\n\nDocs: /etc/hypervisor/docs" 12 78

$DIALOG --msgbox "Setup complete. See /etc/hypervisor/docs for guides and warnings." 10 70
