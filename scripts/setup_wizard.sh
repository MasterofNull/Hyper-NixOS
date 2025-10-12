#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
: "${DIALOG:=whiptail}"

LOGFILE="/var/lib/hypervisor/logs/first_boot.log"
mkdir -p "$(dirname "$LOGFILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

require() { 
  for b in $DIALOG jq; do 
    if ! command -v "$b" >/dev/null 2>&1; then
      log "ERROR: Missing required command: $b"
      echo "Missing $b" >&2
      exit 1
    fi
  done
}
require

log "=== First-Boot Setup Wizard Started ==="

$DIALOG --msgbox "Welcome to Hypervisor Suite Setup Wizard\n\nWe will configure a secure-by-default hypervisor with sensible features enabled.\n\nYou can adjust any setting later or skip this wizard.\n\nLogs: $LOGFILE" 16 78

# Track what was configured
CONFIGURED_ITEMS=()

# 1. Network bridge creation
if $DIALOG --yesno "Step 1/3: Network Bridge\n\nCreate a secure network bridge (recommended)?\n\nThis enables VM networking with isolation." 14 70 ; then
  log "User chose to create network bridge"
  if /etc/hypervisor/scripts/bridge_helper.sh; then
    log "SUCCESS: Network bridge created"
    CONFIGURED_ITEMS+=("✓ Network bridge configured")
  else
    log "WARNING: Network bridge creation failed or was skipped"
    CONFIGURED_ITEMS+=("⚠ Network bridge: skipped/failed")
  fi
else
  log "User skipped network bridge creation"
  CONFIGURED_ITEMS+=("○ Network bridge: skipped by user")
fi

# 2. Download OS installer ISOs
if $DIALOG --yesno "Step 2/3: ISO Download\n\nDownload and verify an OS installer ISO (recommended)?\n\nWe auto-fetch checksums/signatures and verify authenticity." 16 80 ; then
  log "User chose to download ISO"
  if /etc/hypervisor/scripts/iso_manager.sh; then
    log "SUCCESS: ISO downloaded"
    CONFIGURED_ITEMS+=("✓ OS installer ISO downloaded")
  else
    log "WARNING: ISO download failed or was skipped"
    CONFIGURED_ITEMS+=("⚠ ISO download: skipped/failed")
  fi
else
  log "User skipped ISO download"
  CONFIGURED_ITEMS+=("○ ISO download: skipped by user")
fi

# 3. Create your first VM
if $DIALOG --yesno "Step 3/3: VM Creation\n\nCreate your first VM with secure defaults (recommended)?\n\nVirtio devices, Secure Boot (OVMF), and non-root QEMU will be used." 16 80 ; then
  log "User chose to create first VM"
  if /etc/hypervisor/scripts/create_vm_wizard.sh /var/lib/hypervisor/vm_profiles /var/lib/hypervisor/isos; then
    log "SUCCESS: First VM created"
    CONFIGURED_ITEMS+=("✓ First VM profile created")
  else
    log "WARNING: VM creation failed or was skipped"
    CONFIGURED_ITEMS+=("⚠ VM creation: skipped/failed")
  fi
else
  log "User skipped VM creation"
  CONFIGURED_ITEMS+=("○ VM creation: skipped by user")
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

# Show summary of what was configured
SUMMARY=$(printf "%s\n" "${CONFIGURED_ITEMS[@]}")
log "=== Setup Summary ==="
log "$SUMMARY"

$DIALOG --msgbox "Basic Setup Complete!\n\n$SUMMARY\n\nYou can revisit any step via the main menu.\n\nDocs: /etc/hypervisor/docs" 20 78

# Advanced mode (optional)
if $DIALOG --yesno "Advanced Configuration (Optional)\n\nApply best-practice security/performance settings now?\n\nDefaults favor security and robustness.\nYou can skip this and configure later." 16 78 ; then
  log "User chose advanced configuration"
  # Gather choices
  sf=1; mt=0; hp=1; smt=1
  $DIALOG --yesno "Enable strict firewall (default‑deny)?\nRecommended: Yes (secure)." 10 70 && sf=1 || sf=0
  $DIALOG --yesno "Open migration TCP ports (libvirt TCP migrations)?\nRecommended: No (keep closed unless needed)." 10 78 && mt=1 || mt=0
  $DIALOG --yesno "Enable Hugepages (can improve performance; reduces flexibility)?\nRecommended: Yes (most hosts)." 10 78 && hp=1 || hp=0
  $DIALOG --yesno "Disable SMT/Hyper‑Threading (mitigates side‑channels; may reduce throughput)?\nRecommended: Yes (secure); No (throughput)." 12 78 && smt=1 || smt=0

  mkdir -p /etc/hypervisor/src/configuration
  # Write security-local.nix
  cat > /etc/hypervisor/src/configuration/security-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.security.strictFirewall = $( [[ $sf == 1 ]] && echo true || echo false );
  hypervisor.security.migrationTcp = $( [[ $mt == 1 ]] && echo true || echo false );
}
NIX
  # Write perf-local.nix
  cat > /etc/hypervisor/src/configuration/perf-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.performance.enableHugepages = $( [[ $hp == 1 ]] && echo true || echo false );
  hypervisor.performance.disableSMT = $( [[ $smt == 1 ]] && echo true || echo false );
}
NIX

  log "Advanced settings written: sf=$sf mt=$mt hp=$hp smt=$smt"
  CONFIGURED_ITEMS+=("✓ Advanced security/performance configured")
  
  if $DIALOG --yesno "Attempt to rebuild now (nixos-rebuild switch)?\n\nThis will apply the new settings immediately." 12 70 ; then
    log "User chose to rebuild now"
    if sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)" 2>&1 | tee -a "$LOGFILE"; then
      log "SUCCESS: System rebuilt with new configuration"
      CONFIGURED_ITEMS+=("✓ System rebuilt successfully")
      $DIALOG --msgbox "Rebuild successful!\n\nNew configuration is now active." 10 70
    else
      log "ERROR: Rebuild failed"
      $DIALOG --msgbox "Rebuild failed!\n\nPlease review:\n- $LOGFILE\n- /etc/hypervisor/src/configuration/*.nix\n\nYou can try again later from the main menu." 14 70
    fi
  else
    log "User skipped rebuild"
    CONFIGURED_ITEMS+=("⚠ Rebuild skipped - settings not yet active")
    $DIALOG --msgbox "Configuration written to:\n- /etc/hypervisor/src/configuration/security-local.nix\n- /etc/hypervisor/src/configuration/perf-local.nix\n\nRun 'sudo nixos-rebuild switch' to apply." 14 78
  fi
else
  log "User skipped advanced configuration"
fi

# Final summary
FINAL_SUMMARY=$(printf "%s\n" "${CONFIGURED_ITEMS[@]}")
log "=== Final Summary ==="
log "$FINAL_SUMMARY"
log "=== First-Boot Setup Wizard Completed ==="

$DIALOG --msgbox "First-Boot Setup Complete!\n\nWhat was configured:\n$FINAL_SUMMARY\n\nNext steps:\n- The main menu will now load\n- Access docs at: /etc/hypervisor/docs\n- View logs at: $LOGFILE" 22 78
