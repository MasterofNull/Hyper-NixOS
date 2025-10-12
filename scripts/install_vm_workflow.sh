#!/usr/bin/env bash
#
# Hyper-NixOS Comprehensive VM Installation Workflow
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Complete guided workflow for installing VMs with all options:
# - ISO download/import with 14+ verified distributions
# - Network bridge setup (if needed)
# - VM creation with full configuration
# - Automatic validation and hints
# - Launch VM immediately after creation
# - Return to main menu at any time
#
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'cleanup; exit $?' EXIT HUP INT TERM

VERSION="2.1"
LOGFILE="/var/lib/hypervisor/logs/install_vm.log"
mkdir -p "$(dirname "$LOGFILE")"

: "${DIALOG:=whiptail}"
export DIALOG

ISOS_DIR="/var/lib/hypervisor/isos"
PROFILES_DIR="/var/lib/hypervisor/vm_profiles"
CONFIG_JSON="/etc/hypervisor/config.json"
STATE_FILE="/var/lib/hypervisor/workflows/install_vm_state.json"

mkdir -p "$(dirname "$STATE_FILE")" "$ISOS_DIR" "$PROFILES_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

cleanup() {
  # Clean up any temporary files
  rm -f /tmp/install_vm_*.tmp 2>/dev/null || true
}

require() { 
  for b in $DIALOG jq virsh; do 
    if ! command -v "$b" >/dev/null 2>&1; then
      log "ERROR: Missing required command: $b"
      echo "Missing $b" >&2
      exit 1
    fi
  done
}
require

# Global state for tracking progress
COMPLETED_STEPS=()
CREATED_VM_NAME=""
CREATED_VM_PROFILE=""

show_welcome() {
  local iso_count
  iso_count=$(find "$ISOS_DIR" -maxdepth 1 -name "*.iso" 2>/dev/null | wc -l)
  
  local bridge_status="⚠ Not configured"
  if ip link show br0 >/dev/null 2>&1 || ip link show virbr0 >/dev/null 2>&1; then
    bridge_status="✓ Bridge detected"
  fi
  
  $DIALOG --title "Install VMs - Comprehensive Workflow" --msgbox "╔═══════════════════════════════════════════════════════════════╗
║        Hyper-NixOS v${VERSION} - Install VMs Workflow            ║
║                  © 2024-2025 MasterofNull                     ║
╚═══════════════════════════════════════════════════════════════╝

Welcome to the comprehensive VM installation workflow!

This guided process will help you:
  ✓ Download/import OS installer ISOs (14+ verified distros)
  ✓ Configure network bridges (if needed)
  ✓ Create and configure your VM
  ✓ Launch your VM immediately

Current System Status:
  • ISO Library: $iso_count ISO(s) available
  • Network: $bridge_status
  • VM Profiles: $(find "$PROFILES_DIR" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l) existing VM(s)

💡 TIP: You can exit to main menu at any time by selecting Cancel

📋 All actions are logged to: $LOGFILE

Press OK to begin..." 28 70
}

check_network_bridge() {
  log "Checking network bridge configuration"
  
  # Check for common bridges
  if ip link show br0 >/dev/null 2>&1; then
    log "Found bridge: br0"
    return 0
  elif ip link show virbr0 >/dev/null 2>&1; then
    log "Found bridge: virbr0 (libvirt default)"
    return 0
  else
    log "No bridge found"
    return 1
  fi
}

setup_network_bridge() {
  if check_network_bridge; then
    if $DIALOG --yesno "Network Bridge Detected\n\nA network bridge is already configured.\n\nWould you like to:\n- Reconfigure it (select Yes)\n- Skip and use existing (select No)" 14 70; then
      log "User chose to reconfigure network bridge"
    else
      COMPLETED_STEPS+=("○ Network: Using existing bridge")
      return 0
    fi
  else
    if ! $DIALOG --yesno "Network Bridge Setup\n\n⚠ No network bridge detected.\n\nVMs need a network bridge to access the network.\n\n💡 TIP: Choose 'Standard' profile for most use cases\n   (1500 MTU, hardware offloading enabled)\n\nConfigure network bridge now?" 16 70; then
      COMPLETED_STEPS+=("⚠ Network: Skipped (VMs may not have network)")
      log "User skipped network bridge setup"
      return 0
    fi
  fi
  
  log "Starting bridge_helper.sh"
  if /etc/hypervisor/scripts/bridge_helper.sh; then
    COMPLETED_STEPS+=("✓ Network: Bridge configured")
    log "SUCCESS: Network bridge configured"
    $DIALOG --msgbox "✓ Network Bridge Configured\n\nYour VMs can now access the network!" 10 60
  else
    COMPLETED_STEPS+=("⚠ Network: Configuration failed/cancelled")
    log "WARNING: Bridge setup failed or was cancelled"
    if ! $DIALOG --yesno "Network bridge setup was cancelled or failed.\n\nVMs may not have network connectivity.\n\nContinue anyway?" 12 70; then
      log "User chose to abort due to network issue"
      exit 1
    fi
  fi
}

download_or_import_iso() {
  local iso_count
  iso_count=$(find "$ISOS_DIR" -maxdepth 1 -name "*.iso" 2>/dev/null | wc -l)
  
  if [[ $iso_count -gt 0 ]]; then
    if ! $DIALOG --yesno "ISO Library Status\n\n✓ You have $iso_count ISO(s) in your library\n\nWould you like to:\n- Download/import more ISOs (select Yes)\n- Use existing ISOs (select No)\n\n💡 TIP: You can always add more ISOs later from the main menu" 16 70; then
      COMPLETED_STEPS+=("○ ISO: Using existing library ($iso_count ISO(s))")
      log "User chose to use existing ISOs"
      return 0
    fi
  fi
  
  local choice
  choice=$($DIALOG --title "ISO Download/Import" --menu "Choose how to get your OS installer ISO:\n\n💡 TIP: Option 1 includes 14 verified distributions\n   with automatic checksum/signature verification" 20 75 10 \
    "1" "Download ISO from 14+ verified presets (RECOMMENDED)" \
    "2" "Import ISO from local storage (USB/disk)" \
    "3" "Import from network share (NFS/CIFS)" \
    "4" "Enter custom ISO URL" \
    "5" "Skip (use existing ISOs)" \
    3>&1 1>&2 2>&3) || {
      log "User cancelled ISO selection"
      return 1
    }
  
  case "$choice" in
    1)
      log "User chose: Download from presets"
      $DIALOG --msgbox "ISO Download Process\n\n1. Select channel (stable/unstable)\n2. Choose from 14+ distributions:\n   • Ubuntu, Fedora, Debian, Arch\n   • NixOS, Rocky, Alma, openSUSE\n   • FreeBSD, OpenBSD, NetBSD\n   • Kali Linux, CentOS Stream\n3. Automatic checksum/signature verification\n4. Download with progress\n\nPress OK to continue..." 18 70
      
      if /etc/hypervisor/scripts/iso_manager.sh; then
        COMPLETED_STEPS+=("✓ ISO: Downloaded and verified")
        log "SUCCESS: ISO downloaded"
      else
        COMPLETED_STEPS+=("⚠ ISO: Download cancelled/failed")
        log "WARNING: ISO download cancelled"
      fi
      ;;
    2)
      log "User chose: Import from local storage"
      /etc/hypervisor/scripts/iso_manager.sh
      ;;
    3)
      log "User chose: Import from network"
      /etc/hypervisor/scripts/iso_manager.sh
      ;;
    4)
      log "User chose: Custom URL"
      /etc/hypervisor/scripts/iso_manager.sh
      ;;
    5)
      COMPLETED_STEPS+=("○ ISO: Skipped")
      log "User skipped ISO download"
      ;;
  esac
}

validate_prerequisites() {
  local issues=()
  
  # Check for ISOs
  local iso_count
  iso_count=$(find "$ISOS_DIR" -maxdepth 1 -name "*.iso" 2>/dev/null | wc -l)
  if [[ $iso_count -eq 0 ]]; then
    issues+=("⚠ No ISOs available - you'll need to provide your own ISO path")
  fi
  
  # Check network
  if ! check_network_bridge; then
    issues+=("⚠ No network bridge - VM may not have network access")
  fi
  
  # Check libvirt
  if ! systemctl is-active --quiet libvirtd; then
    issues+=("⚠ libvirtd service not running")
  fi
  
  if [[ ${#issues[@]} -gt 0 ]]; then
    local msg="Pre-flight Check\n\nDetected potential issues:\n\n"
    for issue in "${issues[@]}"; do
      msg+="$issue\n"
    done
    msg+="\nYou can still create the VM, but you may need to address these later.\n\nContinue?"
    
    if ! $DIALOG --yesno "$msg" 18 75; then
      return 1
    fi
  fi
  
  return 0
}

create_vm_guided() {
  log "Starting VM creation wizard"
  
  $DIALOG --msgbox "VM Creation Wizard\n\nYou'll configure:\n\n1. Basic settings (name, CPU, memory, disk)\n2. Architecture (x86_64, aarch64, etc.)\n3. ISO selection\n4. Advanced options (optional):\n   • Audio/video configuration\n   • Network zones\n   • Hugepages, memory options\n   • Autostart behavior\n\n💡 TIP: All settings can be changed later\n   Default values work well for most cases\n\nPress OK to begin configuration..." 22 70
  
  # Run the VM creation wizard
  if /etc/hypervisor/scripts/create_vm_wizard.sh "$PROFILES_DIR" "$ISOS_DIR"; then
    COMPLETED_STEPS+=("✓ VM: Profile created")
    log "SUCCESS: VM profile created"
    
    # Find the most recently created profile
    CREATED_VM_PROFILE=$(find "$PROFILES_DIR" -maxdepth 1 -name "*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    if [[ -n "$CREATED_VM_PROFILE" ]]; then
      CREATED_VM_NAME=$(jq -r '.name // empty' "$CREATED_VM_PROFILE" 2>/dev/null || basename "$CREATED_VM_PROFILE" .json)
      log "Created VM profile: $CREATED_VM_PROFILE (name: $CREATED_VM_NAME)"
    fi
    return 0
  else
    COMPLETED_STEPS+=("⚠ VM: Creation cancelled/failed")
    log "WARNING: VM creation cancelled or failed"
    return 1
  fi
}

launch_vm_after_creation() {
  if [[ -z "$CREATED_VM_NAME" || -z "$CREATED_VM_PROFILE" ]]; then
    log "No VM was created, skipping launch"
    return 0
  fi
  
  if ! $DIALOG --yesno "VM Created Successfully!\n\nVM Name: $CREATED_VM_NAME\nProfile: $CREATED_VM_PROFILE\n\nWould you like to:\n\n✓ Start the VM now (Recommended)\n  Launch and open console\n\n○ Return to main menu\n  Start manually later\n\n💡 TIP: You can always access the VM\n   from the main menu" 20 70; then
    log "User chose not to launch VM"
    COMPLETED_STEPS+=("○ Launch: Deferred to later")
    return 0
  fi
  
  log "Starting VM: $CREATED_VM_NAME"
  
  # Use the vm_manager to start the VM
  if /etc/hypervisor/scripts/vm_manager.sh "$CREATED_VM_PROFILE" start; then
    COMPLETED_STEPS+=("✓ Launch: VM started successfully")
    log "SUCCESS: VM $CREATED_VM_NAME started"
    
    if $DIALOG --yesno "VM Started!\n\n✓ $CREATED_VM_NAME is now running\n\nWould you like to:\n\n• Open VM console (select Yes)\n• Return to main menu (select No)\n\n💡 TIP: Console allows you to interact with the VM\n   Press Ctrl+] to exit console" 18 70; then
      log "Opening console for VM: $CREATED_VM_NAME"
      $DIALOG --msgbox "Opening VM Console\n\nPress Ctrl+] to exit the console\nand return to the menu.\n\nPress OK to continue..." 12 60
      virsh console "$CREATED_VM_NAME" || true
    fi
  else
    COMPLETED_STEPS+=("⚠ Launch: Failed to start VM")
    log "ERROR: Failed to start VM $CREATED_VM_NAME"
    $DIALOG --msgbox "Failed to Start VM\n\n⚠ Could not start $CREATED_VM_NAME\n\nCheck logs: $LOGFILE\n\nYou can try starting it manually from the main menu." 14 70
  fi
}

show_summary() {
  local summary="╔═══════════════════════════════════════════════════════════════╗
║              Installation Workflow Complete!                 ║
╚═══════════════════════════════════════════════════════════════╝

What was configured:\n\n"
  
  for step in "${COMPLETED_STEPS[@]}"; do
    summary+="$step\n"
  done
  
  if [[ -n "$CREATED_VM_NAME" ]]; then
    summary+="\n📋 VM Details:\n"
    summary+="   Name: $CREATED_VM_NAME\n"
    summary+="   Profile: $(basename "$CREATED_VM_PROFILE")\n"
    
    # Check if VM is running
    if virsh list --name 2>/dev/null | grep -q "^${CREATED_VM_NAME}$"; then
      summary+="\n✓ VM is currently RUNNING\n"
    else
      summary+="\n○ VM is stopped (start from main menu)\n"
    fi
  fi
  
  summary+="\n📍 Next Steps:\n"
  summary+="   • View all VMs from main menu\n"
  summary+="   • Download more ISOs: Main Menu → ISO Manager\n"
  summary+="   • System docs: /etc/hypervisor/docs\n"
  summary+="\n📝 Logs: $LOGFILE\n"
  
  log "=== Installation Workflow Summary ==="
  for step in "${COMPLETED_STEPS[@]}"; do
    log "  $step"
  done
  
  $DIALOG --msgbox "$summary" 28 70
}

# Main workflow
main() {
  log "=== Install VMs Workflow Started ==="
  log "Version: $VERSION"
  
  # Show welcome
  show_welcome
  
  # Step 1: Network Bridge Setup
  if ! setup_network_bridge; then
    log "Workflow cancelled at network bridge step"
    return 1
  fi
  
  # Step 2: ISO Download/Import
  if ! download_or_import_iso; then
    if ! $DIALOG --yesno "ISO step was cancelled.\n\nContinue anyway?\n\n⚠ You'll need ISOs to install VMs" 12 60; then
      log "Workflow cancelled at ISO step"
      return 1
    fi
  fi
  
  # Step 3: Pre-flight validation
  if ! validate_prerequisites; then
    log "User cancelled after pre-flight check"
    return 1
  fi
  
  # Step 4: Create VM
  if ! create_vm_guided; then
    log "Workflow cancelled at VM creation step"
    $DIALOG --msgbox "VM creation was cancelled.\n\nReturning to main menu.\n\n💡 TIP: Run 'Install VMs' again when ready" 12 60
    return 1
  fi
  
  # Step 5: Launch VM
  launch_vm_after_creation
  
  # Step 6: Show summary
  show_summary
  
  log "=== Install VMs Workflow Completed Successfully ==="
  
  # Return to main menu (script exits, systemd service returns to menu)
  return 0
}

# Run main workflow
main
exit $?
