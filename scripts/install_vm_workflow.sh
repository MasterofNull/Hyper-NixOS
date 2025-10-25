#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS: Comprehensive VM Installation Workflow
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Complete guided workflow for VM creation:
# - ISO download/selection with 14+ verified distributions
# - Network bridge setup (if needed)
# - VM configuration with validation
# - Automatic VM launch after creation
# - Return to main menu at any time
#
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

VERSION="2.0"
: "${DIALOG:=whiptail}"
export DIALOG

LOGFILE="/var/lib/hypervisor/logs/install_vm.log"
mkdir -p "$(dirname "$LOGFILE")"

PROFILES_DIR="/var/lib/hypervisor/vm-profiles"
ISOS_DIR="/var/lib/hypervisor/isos"
STATE_DIR="/var/lib/hypervisor"
WORKFLOW_STATE="$STATE_DIR/workflows/install_vm_state.json"

mkdir -p "$PROFILES_DIR" "$ISOS_DIR" "$STATE_DIR/workflows"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

require() { 
  for b in "$@"; do 
    command -v "$b" >/dev/null 2>&1 || {
      log "ERROR: Missing required command: $b"
      echo "Missing $b" >&2
      exit 1
    }
  done
}
require "$DIALOG" jq virsh

# Show welcome screen with comprehensive information
show_welcome() {
  $DIALOG --title "Install VMs - Complete Workflow" --msgbox "╔════════════════════════════════════════════════════════════════╗
║          Hyper-NixOS v${VERSION} - VM Installation Workflow        ║
║                  © 2024-2025 MasterofNull                      ║
║                  Licensed under GPL v3.0                       ║
╚════════════════════════════════════════════════════════════════╝

Welcome to the comprehensive VM installation workflow!

This wizard will guide you through:

✓ ISO Download (14+ verified distributions with auto-verification)
✓ Network Bridge Setup (intelligent detection & optimization)
✓ VM Configuration (CPU, memory, disk, advanced options)
✓ Automatic VM Launch (start immediately after creation)

💡 TIPS:
• Press ESC or Cancel anytime to return to main menu
• All steps are optional - skip what you don't need
• Settings are validated before proceeding
• Progress is saved - you can resume if interrupted

📚 Features:
• Auto-checksum & GPG signature verification
• 14 OS presets: Ubuntu, Fedora, Debian, Arch, NixOS, Rocky,
  Alma, openSUSE, FreeBSD, OpenBSD, NetBSD, Kali, CentOS
• Network performance profiles (Standard/Jumbo frames)
• Cloud-init support for automated provisioning
• Hardware passthrough (VFIO) configuration

Logs: $LOGFILE

Press OK to begin!" 35 78 || return 1
}

# Enhanced ISO selection with status display
select_or_download_iso() {
  log "=== ISO Selection/Download Phase ==="
  
  # Count existing ISOs
  shopt -s nullglob
  local iso_files=( "$ISOS_DIR"/*.iso )
  shopt -u nullglob
  local iso_count=${#iso_files[@]}
  
  local choice
  if [ $iso_count -eq 0 ]; then
    if $DIALOG --title "No ISOs Found" --yesno "No ISOs are currently available in $ISOS_DIR

Would you like to:
• Download a verified OS installer (14 presets)
• Import from local storage
• Mount network share and import

Select YES to open ISO Manager, or NO to skip." 16 70; then
      /etc/hypervisor/scripts/iso_manager.sh || {
        log "ISO manager exited"
        return 1
      }
    else
      log "User skipped ISO download"
      return 1
    fi
  else
    # Show existing ISOs with option to download more
    choice=$($DIALOG --title "ISO Selection ($iso_count available)" --menu \
"Choose an option:

Available ISOs: $iso_count
Location: $ISOS_DIR

💡 TIP: Downloaded ISOs are cached for reuse" 20 76 4 \
      "select" "Select from existing ISOs ($iso_count found)" \
      "download" "Download more ISOs (14+ verified distributions)" \
      "import" "Import ISOs from local storage/network" \
      "skip" "Skip - configure VM without ISO" 3>&1 1>&2 2>&3) || return 1
    
    case "$choice" in
      select)
        # Let user pick an ISO
        local items=()
        for f in "${iso_files[@]}"; do
          local size=$(du -h "$f" | cut -f1)
          local verified=""
          [ -f "$f.sha256.verified" ] && verified=" ✓"
          items+=("$f" "$(basename "$f") [$size]$verified")
        done
        ISO_PATH=$($DIALOG --title "Select ISO" --menu "Select an ISO to use:" 24 78 14 "${items[@]}" 3>&1 1>&2 2>&3) || return 1
        log "Selected existing ISO: $ISO_PATH"
        ;;
      download|import)
        /etc/hypervisor/scripts/iso_manager.sh || return 1
        # After ISO manager, try to select
        iso_files=( "$ISOS_DIR"/*.iso )
        if [ ${#iso_files[@]} -gt 0 ]; then
          local items=()
          for f in "${iso_files[@]}"; do
            local size=$(du -h "$f" | cut -f1)
            local verified=""
            [ -f "$f.sha256.verified" ] && verified=" ✓"
            items+=("$f" "$(basename "$f") [$size]$verified")
          done
          ISO_PATH=$($DIALOG --title "Select ISO" --menu "Select the downloaded ISO:" 24 78 14 "${items[@]}" 3>&1 1>&2 2>&3) || return 1
          log "Selected ISO after download: $ISO_PATH"
        fi
        ;;
      skip)
        log "User skipped ISO selection"
        ISO_PATH=""
        ;;
    esac
  fi
  return 0
}

# Network bridge setup with status display
setup_network_bridge() {
  log "=== Network Bridge Setup Phase ==="
  
  # Check if bridge already exists
  local existing_bridges=$(ip link show type bridge 2>/dev/null | grep -oP '^\d+: \K[^:]+' || true)
  
  if [ -n "$existing_bridges" ]; then
    if $DIALOG --title "Network Bridge" --yesno "Existing bridges found:
$existing_bridges

Do you want to:
• Create a new bridge
• Use existing bridge

Choose YES to create new, NO to use existing." 14 70; then
      /etc/hypervisor/scripts/bridge_helper.sh || {
        log "Bridge helper exited"
        return 0
      }
    else
      log "User chose to use existing bridge"
    fi
  else
    if $DIALOG --title "Network Bridge" --yesno "No network bridge detected.

A bridge is recommended for VM networking. It provides:
✓ VM internet access
✓ Network isolation
✓ Performance optimization

Create network bridge now?

💡 TIP: You can always create it later from System Tools" 16 70; then
      /etc/hypervisor/scripts/bridge_helper.sh || {
        log "Bridge helper failed or was cancelled"
        return 0
      }
    else
      log "User skipped bridge creation"
    fi
  fi
  return 0
}

# Enhanced VM creation with validation and hints
create_vm_profile() {
  log "=== VM Profile Creation Phase ==="
  
  # Get system resources for smart defaults
  local total_mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 8388608)
  local total_mem_mb=$((total_mem_kb / 1024))
  local avail_mem_mb=$((total_mem_mb / 4)) # Suggest 25% of RAM
  local total_cpus=$(nproc 2>/dev/null || echo 2)
  local suggest_cpus=$((total_cpus / 2))
  [ $suggest_cpus -lt 2 ] && suggest_cpus=2
  
  $DIALOG --title "VM Configuration" --msgbox "System Resources Detected:

💻 CPUs: $total_cpus
🧠 Total RAM: ${total_mem_mb} MiB
📊 Suggested VM RAM: ${avail_mem_mb} MiB (25% of total)
⚙️  Suggested vCPUs: $suggest_cpus

💡 TIPS:
• Don't over-allocate resources (leave headroom for host)
• Start conservative, increase later if needed
• 2 vCPUs and 4GB RAM works for most desktop Linux/Windows
• Server VMs may need more RAM, desktop VMs need more CPU" 20 76
  
  # Pass preselected ISO if we have one
  if [ -n "${ISO_PATH:-}" ]; then
    export PRESELECT_ISO="$ISO_PATH"
  fi
  
  # Create temporary file to get output path
  local out_file=$(mktemp)
  export WIZ_OUT_FILE="$out_file"
  
  /etc/hypervisor/scripts/create_vm_wizard.sh "$PROFILES_DIR" "$ISOS_DIR" || {
    rm -f "$out_file"
    log "VM wizard cancelled or failed"
    return 1
  }
  
  # Get created profile path
  if [ -s "$out_file" ]; then
    VM_PROFILE=$(cat "$out_file")
    rm -f "$out_file"
    log "VM profile created: $VM_PROFILE"
    return 0
  else
    rm -f "$out_file"
    log "No VM profile was created"
    return 1
  fi
}

# Launch VM with feedback
launch_vm() {
  local profile="$1"
  log "=== VM Launch Phase ==="
  
  if [ ! -f "$profile" ]; then
    log "ERROR: Profile not found: $profile"
    return 1
  fi
  
  local vm_name=$(jq -r '.name' "$profile")
  
  if $DIALOG --title "Launch VM" --yesno "VM Profile Created Successfully!

VM Name: $vm_name
Profile: $(basename "$profile")

Would you like to:
✓ Start the VM now
✓ View console output
✓ Begin installation

Choose YES to launch now, NO to launch manually later.

💡 TIP: You can always start/stop VMs from the main menu" 18 70; then
    log "Launching VM: $vm_name"
    
    # Generate and define VM using existing script
    if /etc/hypervisor/scripts/generate_libvirt_xml.sh "$profile" /tmp/vm-${vm_name}.xml; then
      if sudo virsh define /tmp/vm-${vm_name}.xml; then
        rm -f /tmp/vm-${vm_name}.xml
        if sudo virsh start "$vm_name"; then
          log "SUCCESS: VM $vm_name started"
          
          if $DIALOG --title "VM Started" --yesno "✅ VM '$vm_name' is now running!

Would you like to connect to the console now?

Choose YES for console, NO to return to menu.

💡 Console Tips:
• Press Ctrl+] to exit console
• Use arrow keys for navigation
• Connect anytime from main menu" 16 70; then
            $DIALOG --title "Connecting to Console" --msgbox "Connecting to VM console...

Press Ctrl+] to disconnect and return to menu

The console will open in 2 seconds..." 12 70
            sleep 2
            sudo virsh console "$vm_name" || true
          fi
          return 0
        else
          log "ERROR: Failed to start VM $vm_name"
          $DIALOG --title "Error" --msgbox "❌ Failed to start VM

Check logs:
• $LOGFILE
• sudo journalctl -u libvirtd

The VM profile was saved - you can try starting it manually from the main menu." 14 70
          return 1
        fi
      else
        log "ERROR: Failed to define VM"
        $DIALOG --title "Error" --msgbox "❌ Failed to define VM in libvirt

Check logs for details:
• $LOGFILE
• sudo journalctl -u libvirtd" 12 70
        return 1
      fi
    else
      log "ERROR: Failed to generate libvirt XML"
      $DIALOG --title "Error" --msgbox "❌ Failed to generate VM configuration

Check the profile for errors:
$profile" 10 70
      return 1
    fi
  else
    log "User chose not to launch VM"
    $DIALOG --title "VM Ready" --msgbox "✅ VM profile created successfully!

VM Name: $vm_name
Profile: $(basename "$profile")

The VM is ready but not started.

To start it:
• Main Menu → Start VMs → Select '$vm_name'
• Or run: sudo virsh start $vm_name" 16 70
    return 0
  fi
}

# Main workflow
main() {
  log "=== VM Installation Workflow Started ==="
  
  # Welcome screen
  show_welcome || {
    log "User cancelled at welcome screen"
    return 0
  }
  
  # Phase 1: ISO Selection/Download
  ISO_PATH=""
  select_or_download_iso || {
    if ! $DIALOG --title "Continue?" --yesno "ISO selection was cancelled or skipped.

You can:
• Continue without ISO (manual setup later)
• Return to main menu

Continue anyway?" 12 70; then
      log "User cancelled workflow after ISO phase"
      return 0
    fi
  }
  
  # Phase 2: Network Bridge
  setup_network_bridge || true
  
  # Phase 3: VM Configuration
  VM_PROFILE=""
  create_vm_profile || {
    log "VM creation cancelled or failed"
    $DIALOG --title "Workflow Cancelled" --msgbox "VM creation was cancelled.

No changes were made.

Returning to main menu..." 10 70
    return 0
  }
  
  # Phase 4: Launch VM
  if [ -n "$VM_PROFILE" ]; then
    launch_vm "$VM_PROFILE" || {
      log "VM launch failed or was skipped"
    }
  fi
  
  # Completion summary
  log "=== VM Installation Workflow Completed ==="
  $DIALOG --title "Workflow Complete" --msgbox "✅ VM Installation Workflow Complete!

Summary:
• ISO: ${ISO_PATH:+✓ Selected}${ISO_PATH:-○ Skipped}
• Network: ✓ Configured
• VM Profile: ${VM_PROFILE:+✓ Created}${VM_PROFILE:-○ Failed}

Logs: $LOGFILE

Returning to main menu..." 16 70
  
  log "Returning to main menu"
}

# Run main workflow
main

# Always return to main menu
log "Launching main menu"
exec /etc/hypervisor/scripts/menu.sh
