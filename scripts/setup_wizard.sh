#!/usr/bin/env bash
#
# Hyper-NixOS First-Boot Setup Wizard
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Guides users through initial system configuration:
# - Network bridge setup with optimization
# - ISO downloads with verification
# - First VM creation
# - Security and performance settings
#
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
: "${DIALOG:=whiptail}"

VERSION="2.0"

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

$DIALOG --msgbox "╔════════════════════════════════════════════════════════════════╗
║         Hyper-NixOS v${VERSION} - First-Boot Setup Wizard         ║
║                  © 2024-2025 MasterofNull                      ║
║                  Licensed under GPL v3.0                       ║
╚════════════════════════════════════════════════════════════════╝

Welcome! This wizard will help you configure your hypervisor:

✓ Foundational networking setup (REQUIRED FIRST)
✓ Network bridge with performance optimization
✓ OS installer download (14 verified distributions)
✓ First VM creation with secure defaults
✓ Security and performance tuning

IMPORTANT: Networking must be configured first!
Many processes depend on network availability:
  • ISO downloads require internet connectivity
  • Package installation needs network access
  • VM creation requires network bridges
  • Network discovery and DHCP configuration

Everything is optional - you can skip any step.
All settings can be changed later.

Logs: $LOGFILE" 26 78

# Track what was configured
CONFIGURED_ITEMS=()

# 0. FOUNDATIONAL NETWORKING - MUST BE FIRST
log "Step 0: Foundational Networking Setup (CRITICAL)"

# Check if networking is already configured
NETWORK_READY=false
if [[ -f /var/lib/hypervisor/.network_ready ]]; then
  log "Network readiness marker found, checking status..."
  if /etc/hypervisor/scripts/check_network_ready.sh -v 2>&1 | tee -a "$LOGFILE"; then
    NETWORK_READY=true
    log "Network foundation already configured"
    
    $DIALOG --yesno "Network Already Configured

The foundational networking setup has already been completed.

Would you like to:
  YES = Review/reconfigure networking
  NO  = Skip to next step (recommended)

Continue to networking setup?" 12 70 || {
      log "User chose to skip networking reconfiguration"
      CONFIGURED_ITEMS+=("✓ Network foundation: already configured")
    }
  else
    NETWORK_READY=false
    log "Network marker exists but validation failed, will reconfigure"
  fi
fi

# Run foundational networking setup if needed
if ! $NETWORK_READY; then
  $DIALOG --msgbox "STEP 1/4: FOUNDATIONAL NETWORKING SETUP
═══════════════════════════════════════════════════════

WHY THIS MUST BE FIRST:
────────────────────────────────────────────────────────

This is the CRITICAL foundation for everything else:

  ✓ Detects and validates network hardware
  ✓ Configures high-performance network bridge
  ✓ Automatically binds interfaces (no manual work!)
  ✓ Sets up libvirt networking
  ✓ Validates connectivity
  ✓ Creates readiness marker for other services

ALL of these depend on networking:
────────────────────────────────────────────────────────
  • Downloading ISOs
  • Installing packages
  • Creating VMs
  • Network discovery
  • DHCP configuration
  • Security zones

This wizard provides:
────────────────────────────────────────────────────────
  ✓ Automatic interface detection
  ✓ Intelligent binding recommendations
  ✓ Comprehensive guidance at every step
  ✓ Full automation with safe defaults
  ✓ Validation and connectivity testing

Let's set up your network foundation!" 34 76

  log "Running foundational networking setup..."
  if /etc/hypervisor/scripts/foundational_networking_setup.sh 2>&1 | tee -a "$LOGFILE"; then
    log "SUCCESS: Foundational networking configured"
    CONFIGURED_ITEMS+=("✓ Network foundation: configured successfully")
    NETWORK_READY=true
  else
    log "ERROR: Foundational networking setup failed"
    CONFIGURED_ITEMS+=("✗ Network foundation: FAILED")
    
    $DIALOG --msgbox "CRITICAL: Networking Setup Failed
═══════════════════════════════════════════════════════

The foundational networking setup did not complete successfully.

This is a CRITICAL step. Without networking:
  ✗ Cannot download ISOs
  ✗ Cannot install packages
  ✗ VMs will have no network connectivity
  ✗ Many features will not work

What to do:
────────────────────────────────────────────────────────
1. Review the log for errors:
   $LOGFILE

2. Try running setup manually:
   sudo /etc/hypervisor/scripts/foundational_networking_setup.sh

3. Check your network hardware:
   ip link show
   
4. Ensure physical connection (cable, WiFi, etc.)

You can continue the wizard, but many features
will not work without networking.

Press OK to continue anyway..." 28 76
  fi
fi

# Verify network readiness before proceeding
if $NETWORK_READY; then
  log "Network foundation verified, proceeding with wizard"
else
  log "WARNING: Proceeding without network foundation (limited functionality)"
fi

# 2. Download OS installer ISOs
if ! $NETWORK_READY; then
  log "Skipping ISO download due to missing network foundation"
  CONFIGURED_ITEMS+=("○ ISO download: skipped (no network)")
  $DIALOG --msgbox "Step 2/4: ISO Download - SKIPPED

ISO downloads require network connectivity.

Since networking was not successfully configured,
this step will be skipped.

You can download ISOs later from the main menu
after fixing network configuration." 14 70
elif $DIALOG --yesno "Step 2/4: ISO Download\n\nDownload and verify an OS installer ISO (recommended)?\n\nWe auto-fetch checksums/signatures and verify authenticity.\n\nNetwork is ready!" 16 80 ; then
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
if ! $NETWORK_READY; then
  log "Showing network warning before VM creation"
  $DIALOG --msgbox "Step 3/4: VM Creation - WARNING

VMs can be created, but they will have NO NETWORK ACCESS
without proper networking configuration.

You can still create VMs, but they will be isolated and
unable to reach the internet or other network devices.

Recommendation: Configure networking first!" 14 70
fi

if $DIALOG --yesno "Step 3/4: VM Creation\n\nCreate your first VM with secure defaults (recommended)?\n\nVirtio devices, Secure Boot (OVMF), and non-root QEMU will be used.\n\n$(if ! $NETWORK_READY; then echo 'WARNING: Network not ready - VMs will have no network access!'; fi)" 18 80 ; then
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

  mkdir -p /etc/hypervisor/src/modules
  # Write security-local.nix
  cat > /etc/hypervisor/src/modules/security-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.security.strictFirewall = $( [[ $sf == 1 ]] && echo true || echo false );
  hypervisor.security.migrationTcp = $( [[ $mt == 1 ]] && echo true || echo false );
}
NIX
  # Write perf-local.nix
  cat > /etc/hypervisor/src/modules/perf-local.nix <<NIX
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
      $DIALOG --msgbox "Rebuild failed!\n\nPlease review:\n- $LOGFILE\n- /etc/hypervisor/src/modules/*.nix\n\nYou can try again later from the main menu." 14 70
    fi
  else
    log "User skipped rebuild"
    CONFIGURED_ITEMS+=("⚠ Rebuild skipped - settings not yet active")
    $DIALOG --msgbox "Configuration written to:\n- /etc/hypervisor/src/modules/security-local.nix\n- /etc/hypervisor/src/modules/perf-local.nix\n\nRun 'sudo nixos-rebuild switch' to apply." 14 78
  fi
else
  log "User skipped advanced configuration"
fi

# Final summary
FINAL_SUMMARY=$(printf "%s\n" "${CONFIGURED_ITEMS[@]}")
log "=== Final Summary ==="
log "$FINAL_SUMMARY"
log "=== First-Boot Setup Wizard Completed ==="

$DIALOG --msgbox "╔════════════════════════════════════════════════════════════════╗
║              First-Boot Setup Complete!                        ║
╚════════════════════════════════════════════════════════════════╝

What was configured:
$FINAL_SUMMARY

Next steps:
• The main menu will now load automatically
• Create VMs from the console menu
• Access documentation: /etc/hypervisor/docs
• View logs: $LOGFILE

Hyper-NixOS v${VERSION}
https://github.com/MasterofNull/Hyper-NixOS" 24 78

# Launch the main menu instead of exiting
log "Launching main menu after wizard completion"
exec /etc/hypervisor/scripts/menu.sh
