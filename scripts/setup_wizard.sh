#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
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
  $DIALOG --msgbox "To enable: set hypervisor.security.strictFirewall = true in configuration.nix\nOptionally open migration ports: hypervisor.security.migrationTcp = true" 12 80
fi

# Performance trade-offs (optional)
if $DIALOG --yesno "Enable Hugepages (can improve performance, reduces flexibility)?" 10 78 ; then
  $DIALOG --msgbox "Set hypervisor.performance.enableHugepages = true in performance.nix" 10 78
fi
if $DIALOG --yesno "Disable SMT/Hyper-Threading (mitigation, may reduce throughput)?" 10 78 ; then
  $DIALOG --msgbox "Set hypervisor.performance.disableSMT = true in performance.nix" 10 78
fi

# VFIO and hardware detection
if $DIALOG --yesno "Detect hardware and prepare VFIO passthrough (optional)?\n\nWe will propose GPU/audio IDs and write a Nix snippet." 14 80 ; then
  /etc/hypervisor/scripts/vfio_workflow.sh || true
fi

# Preflight check and device integration
/etc/hypervisor/scripts/preflight_check.sh || true
/etc/hypervisor/scripts/detect_and_adjust.sh || true

$DIALOG --msgbox "Setup complete. You can revisit any step via the main menu.\n\nDocs: /etc/hypervisor/docs" 12 78

# Advanced mode (optional)
if $DIALOG --yesno "Advanced mode: apply best‑practice secure/performance settings now and optionally rebuild?\n\nDefaults favor security and robustness; you can override each choice." 14 78 ; then
  # Gather choices
  sf=1; mt=0; hp=1; smt=1
  $DIALOG --yesno "Enable strict firewall (default‑deny)?\nRecommended: Yes (secure)." 10 70 && sf=1 || sf=0
  $DIALOG --yesno "Open migration TCP ports (libvirt TCP migrations)?\nRecommended: No (keep closed unless needed)." 10 78 && mt=1 || mt=0
  $DIALOG --yesno "Enable Hugepages (can improve performance; reduces flexibility)?\nRecommended: Yes (most hosts)." 10 78 && hp=1 || hp=0
  $DIALOG --yesno "Disable SMT/Hyper‑Threading (mitigates side‑channels; may reduce throughput)?\nRecommended: Yes (secure); No (throughput)." 12 78 && smt=1 || smt=0

  mkdir -p /etc/hypervisor/configuration
  # Write security-local.nix
  cat > /etc/hypervisor/configuration/security-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.security.strictFirewall = $( [[ $sf == 1 ]] && echo true || echo false );
  hypervisor.security.migrationTcp = $( [[ $mt == 1 ]] && echo true || echo false );
}
NIX
  # Write perf-local.nix
  cat > /etc/hypervisor/configuration/perf-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.performance.enableHugepages = $( [[ $hp == 1 ]] && echo true || echo false );
  hypervisor.performance.disableSMT = $( [[ $smt == 1 ]] && echo true || echo false );
}
NIX

  if $DIALOG --yesno "Attempt to rebuild now (nixos-rebuild switch)?" 10 70 ; then
    if ! sudo nixos-rebuild switch; then
      $DIALOG --msgbox "Rebuild failed. Please review /etc/hypervisor/configuration/*.nix and try again." 10 70
    fi
  else
    $DIALOG --msgbox "Written: /etc/hypervisor/configuration/security-local.nix and perf-local.nix. Rebuild when ready." 10 78
  fi
fi

$DIALOG --msgbox "Setup complete. See /etc/hypervisor/docs for guides and warnings." 10 70
