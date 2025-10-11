#!/usr/bin/env bash
# Bulk VM Operations - Manage multiple VMs at once
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"
USER_PROFILES_DIR="/var/lib/hypervisor/vm_profiles"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a /var/lib/hypervisor/logs/bulk_operations.log
}

# Get all VMs with their current state
get_all_vms() {
  local vms=()
  
  # Get all defined VMs
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    local state=$(virsh domstate "$vm" 2>/dev/null || echo "undefined")
    local autostart=$(virsh dominfo "$vm" 2>/dev/null | awk '/Autostart:/ {print $2}' || echo "unknown")
    
    vms+=("$vm|$state|$autostart")
  done < <(virsh list --all --name 2>/dev/null || true)
  
  printf "%s\n" "${vms[@]}"
}

# Select multiple VMs
select_multiple_vms() {
  local title="$1"
  local all_vms=$(get_all_vms)
  
  [[ -z "$all_vms" ]] && {
    $DIALOG --msgbox "No VMs found." 8 40
    return 1
  }
  
  local items=()
  while IFS='|' read -r vm state autostart; do
    [[ -z "$vm" ]] && continue
    local status_text="$state"
    [[ "$autostart" == "enable" ]] && status_text="$status_text (autostart)"
    items+=("$vm" "$status_text" "off")
  done <<< "$all_vms"
  
  local selected
  selected=$($DIALOG --checklist "$title" 22 90 14 "${items[@]}" 3>&1 1>&2 2>&3 || echo "")
  
  [[ -z "$selected" ]] && return 1
  
  # Clean up selection (remove quotes)
  echo "$selected" | tr -d '"'
}

# Start multiple VMs
bulk_start() {
  log "Bulk start operation initiated"
  
  local vms
  vms=$(select_multiple_vms "Select VMs to START" | tr ' ' '\n') || return 1
  
  [[ -z "$vms" ]] && {
    $DIALOG --msgbox "No VMs selected." 8 40
    return 0
  }
  
  local results=""
  local success_count=0
  local fail_count=0
  
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    log "Starting VM: $vm"
    if virsh start "$vm" 2>&1 | grep -v "already active" >/dev/null; then
      results+="✓ $vm\n"
      ((success_count++))
      log "Successfully started: $vm"
    else
      results+="✗ $vm (failed or already running)\n"
      ((fail_count++))
      log "Failed to start: $vm"
    fi
  done <<< "$vms"
  
  $DIALOG --msgbox "Bulk Start Complete\n\n${results}\nSuccess: $success_count | Failed: $fail_count" 20 60
}

# Stop multiple VMs
bulk_stop() {
  log "Bulk stop operation initiated"
  
  # Only show running VMs
  local all_vms=$(get_all_vms)
  local running_vms=""
  
  while IFS='|' read -r vm state autostart; do
    [[ -z "$vm" ]] && continue
    [[ "$state" == "running" ]] && running_vms+="$vm|$state|$autostart\n"
  done <<< "$all_vms"
  
  [[ -z "$running_vms" ]] && {
    $DIALOG --msgbox "No running VMs found." 8 40
    return 0
  }
  
  local items=()
  while IFS='|' read -r vm state autostart; do
    [[ -z "$vm" ]] && continue
    items+=("$vm" "running" "off")
  done <<< "$running_vms"
  
  local selected
  selected=$($DIALOG --checklist "Select VMs to STOP (graceful shutdown)" 22 90 14 "${items[@]}" 3>&1 1>&2 2>&3 || echo "")
  
  [[ -z "$selected" ]] && return 1
  
  local vms=$(echo "$selected" | tr -d '"' | tr ' ' '\n')
  [[ -z "$vms" ]] && return 0
  
  local results=""
  local success_count=0
  local fail_count=0
  
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    log "Stopping VM: $vm"
    if virsh shutdown "$vm" 2>&1 >/dev/null; then
      results+="✓ $vm (shutdown signal sent)\n"
      ((success_count++))
      log "Shutdown signal sent: $vm"
    else
      results+="✗ $vm (failed)\n"
      ((fail_count++))
      log "Failed to stop: $vm"
    fi
  done <<< "$vms"
  
  $DIALOG --msgbox "Bulk Stop Complete\n\n${results}\nSuccess: $success_count | Failed: $fail_count\n\nNote: VMs are shutting down gracefully." 20 60
}

# Force stop multiple VMs
bulk_destroy() {
  log "Bulk force-stop operation initiated"
  
  $DIALOG --yesno "⚠️  WARNING: Force Stop\n\nThis will immediately stop VMs without graceful shutdown.\nThis may cause data loss in VMs.\n\nUse regular stop unless VMs are unresponsive.\n\nContinue with force stop?" 14 60 || return 1
  
  local vms
  vms=$(select_multiple_vms "Select VMs to FORCE STOP" | tr ' ' '\n') || return 1
  
  [[ -z "$vms" ]] && return 0
  
  local results=""
  local success_count=0
  local fail_count=0
  
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    log "Force stopping VM: $vm"
    if virsh destroy "$vm" 2>&1 >/dev/null; then
      results+="✓ $vm\n"
      ((success_count++))
      log "Force stopped: $vm"
    else
      results+="✗ $vm (failed or not running)\n"
      ((fail_count++))
      log "Failed to force stop: $vm"
    fi
  done <<< "$vms"
  
  $DIALOG --msgbox "Bulk Force Stop Complete\n\n${results}\nSuccess: $success_count | Failed: $fail_count" 20 60
}

# Snapshot multiple VMs
bulk_snapshot() {
  log "Bulk snapshot operation initiated"
  
  local vms
  vms=$(select_multiple_vms "Select VMs to SNAPSHOT" | tr ' ' '\n') || return 1
  
  [[ -z "$vms" ]] && return 0
  
  local snapshot_name
  snapshot_name=$($DIALOG --inputbox "Snapshot name:" 10 60 "snapshot-$(date +%Y%m%d-%H%M%S)" 3>&1 1>&2 2>&3) || return 1
  
  local description
  description=$($DIALOG --inputbox "Description (optional):" 10 60 "" 3>&1 1>&2 2>&3) || description=""
  
  local results=""
  local success_count=0
  local fail_count=0
  
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    log "Creating snapshot for VM: $vm (name: $snapshot_name)"
    if virsh snapshot-create-as "$vm" "$snapshot_name" "$description" 2>&1 >/dev/null; then
      results+="✓ $vm\n"
      ((success_count++))
      log "Snapshot created: $vm -> $snapshot_name"
    else
      results+="✗ $vm (failed)\n"
      ((fail_count++))
      log "Failed to snapshot: $vm"
    fi
  done <<< "$vms"
  
  $DIALOG --msgbox "Bulk Snapshot Complete\n\nSnapshot: $snapshot_name\n\n${results}\nSuccess: $success_count | Failed: $fail_count" 20 70
}

# Set autostart for multiple VMs
bulk_autostart() {
  log "Bulk autostart configuration initiated"
  
  local action
  action=$($DIALOG --menu "Autostart Configuration" 14 60 2 \
    "1" "Enable autostart" \
    "2" "Disable autostart" \
    3>&1 1>&2 2>&3) || return 1
  
  local vms
  vms=$(select_multiple_vms "Select VMs to configure autostart" | tr ' ' '\n') || return 1
  
  [[ -z "$vms" ]] && return 0
  
  local results=""
  local success_count=0
  local fail_count=0
  
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    if [[ "$action" == "1" ]]; then
      log "Enabling autostart for: $vm"
      if virsh autostart "$vm" 2>&1 >/dev/null; then
        results+="✓ $vm (autostart enabled)\n"
        ((success_count++))
        log "Autostart enabled: $vm"
      else
        results+="✗ $vm (failed)\n"
        ((fail_count++))
        log "Failed to enable autostart: $vm"
      fi
    else
      log "Disabling autostart for: $vm"
      if virsh autostart --disable "$vm" 2>&1 >/dev/null; then
        results+="✓ $vm (autostart disabled)\n"
        ((success_count++))
        log "Autostart disabled: $vm"
      else
        results+="✗ $vm (failed)\n"
        ((fail_count++))
        log "Failed to disable autostart: $vm"
      fi
    fi
  done <<< "$vms"
  
  $DIALOG --msgbox "Bulk Autostart Configuration Complete\n\n${results}\nSuccess: $success_count | Failed: $fail_count" 20 60
}

# Delete multiple VMs
bulk_delete() {
  log "Bulk delete operation initiated"
  
  $DIALOG --yesno "⚠️  WARNING: Bulk Delete\n\nThis will:\n• Stop selected VMs\n• Remove them from libvirt\n• Delete their disk images\n• Keep VM profiles\n\nThis action cannot be undone!\n\nContinue?" 16 60 || return 1
  
  local vms
  vms=$(select_multiple_vms "Select VMs to DELETE (⚠️ PERMANENT)" | tr ' ' '\n') || return 1
  
  [[ -z "$vms" ]] && return 0
  
  # Final confirmation with list
  local vm_list=$(echo "$vms" | tr '\n' ', ' | sed 's/,$//')
  $DIALOG --yesno "⚠️  FINAL CONFIRMATION\n\nYou are about to DELETE:\n\n$vm_list\n\nThis will permanently remove these VMs and their data.\n\nAre you absolutely sure?" 18 70 || return 1
  
  local results=""
  local success_count=0
  local fail_count=0
  
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    log "Deleting VM: $vm"
    
    # Stop VM first
    virsh destroy "$vm" 2>/dev/null || true
    
    # Undefine with storage removal
    if virsh undefine "$vm" --remove-all-storage 2>&1 >/dev/null; then
      results+="✓ $vm\n"
      ((success_count++))
      log "Deleted: $vm"
    else
      results+="✗ $vm (failed)\n"
      ((fail_count++))
      log "Failed to delete: $vm"
    fi
  done <<< "$vms"
  
  $DIALOG --msgbox "Bulk Delete Complete\n\n${results}\nDeleted: $success_count | Failed: $fail_count\n\nNote: VM profiles still exist in:\n/var/lib/hypervisor/vm_profiles/" 20 70
}

# Main menu
main_menu() {
  while true; do
    local choice
    choice=$($DIALOG --title "Bulk Operations" --menu "Manage multiple VMs at once" 20 80 9 \
      "1" "Start multiple VMs" \
      "2" "Stop multiple VMs (graceful)" \
      "3" "Force stop multiple VMs" \
      "4" "Snapshot multiple VMs" \
      "5" "Configure autostart for multiple VMs" \
      "6" "Delete multiple VMs (⚠️ permanent)" \
      "7" "Show all VM status" \
      "8" "Back to main menu" \
      3>&1 1>&2 2>&3) || break
    
    case "$choice" in
      1) bulk_start ;;
      2) bulk_stop ;;
      3) bulk_destroy ;;
      4) bulk_snapshot ;;
      5) bulk_autostart ;;
      6) bulk_delete ;;
      7)
        # Show status of all VMs
        local status_text=""
        while IFS= read -r vm; do
          [[ -z "$vm" ]] && continue
          local state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
          local autostart=$(virsh dominfo "$vm" 2>/dev/null | awk '/Autostart:/ {print $2}' || echo "?")
          status_text+="$vm: $state (autostart: $autostart)\n"
        done < <(virsh list --all --name 2>/dev/null || true)
        
        $DIALOG --msgbox "All VM Status:\n\n$status_text" 24 80
        ;;
      8|*) break ;;
    esac
  done
}

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Bulk VM Operations"
  echo ""
  echo "Usage: $0"
  echo ""
  echo "Interactive menu for managing multiple VMs at once:"
  echo "  • Start multiple VMs"
  echo "  • Stop multiple VMs (graceful shutdown)"
  echo "  • Force stop multiple VMs"
  echo "  • Create snapshots for multiple VMs"
  echo "  • Configure autostart for multiple VMs"
  echo "  • Delete multiple VMs (with confirmation)"
  echo ""
  echo "All operations are logged to:"
  echo "  /var/lib/hypervisor/logs/bulk_operations.log"
  exit 0
fi

# Run main menu
main_menu
