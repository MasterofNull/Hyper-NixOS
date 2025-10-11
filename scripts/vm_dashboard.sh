#!/usr/bin/env bash
# VM Dashboard - Visual overview of all VMs with real-time status
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"
: "${REFRESH_INTERVAL:=5}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Clear screen and show header
show_header() {
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Hypervisor Dashboard - Real-time VM Status${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  System: $(hostname)  |  Time: $(date '+%Y-%m-%d %H:%M:%S')  |  Refresh: ${REFRESH_INTERVAL}s"
  echo ""
}

# Get host stats
get_host_stats() {
  local uptime=$(uptime -p | sed 's/up //')
  local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
  local mem_total=$(free -h | awk '/^Mem:/{print $2}')
  local mem_used=$(free -h | awk '/^Mem:/{print $3}')
  local mem_percent=$(free | awk '/^Mem:/{printf("%.0f", $3/$2*100)}')
  local disk_total=$(df -h /var/lib/hypervisor 2>/dev/null | tail -1 | awk '{print $2}' || echo "N/A")
  local disk_used=$(df -h /var/lib/hypervisor 2>/dev/null | tail -1 | awk '{print $3}' || echo "N/A")
  local disk_percent=$(df /var/lib/hypervisor 2>/dev/null | tail -1 | awk '{print $5}' || echo "N/A")
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  HOST RESOURCES"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  printf "  Uptime: %-20s  Load Avg: %s\n" "$uptime" "$load"
  printf "  Memory: %-8s / %-8s" "$mem_used" "$mem_total"
  
  # Memory usage bar
  local mem_bar_width=40
  local mem_filled=$((mem_percent * mem_bar_width / 100))
  printf " ["
  for ((i=0; i<mem_bar_width; i++)); do
    if [[ $i -lt $mem_filled ]]; then
      if [[ $mem_percent -gt 90 ]]; then
        printf "${RED}█${NC}"
      elif [[ $mem_percent -gt 70 ]]; then
        printf "${YELLOW}█${NC}"
      else
        printf "${GREEN}█${NC}"
      fi
    else
      printf "░"
    fi
  done
  printf "] %3d%%\n" "$mem_percent"
  
  printf "  Disk:   %-8s / %-8s (%s used)\n" "$disk_used" "$disk_total" "$disk_percent"
  echo ""
}

# Get VM list with stats
get_vm_stats() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  VIRTUAL MACHINES"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Header
  printf "  %-20s %-10s %6s %10s %10s %15s\n" \
    "NAME" "STATE" "vCPUs" "MEMORY" "DISK I/O" "NETWORK"
  printf "  %-20s %-10s %6s %10s %10s %15s\n" \
    "----" "-----" "-----" "------" "--------" "-------"
  
  local vm_count=0
  
  # Get all VMs (running and stopped)
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    ((vm_count++))
    
    local state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
    local state_color="$NC"
    local state_icon=" "
    
    case "$state" in
      running)
        state_color="$GREEN"
        state_icon="▶"
        ;;
      paused)
        state_color="$YELLOW"
        state_icon="⏸"
        ;;
      "shut off"|shutoff)
        state="stopped"
        state_color="$RED"
        state_icon="■"
        ;;
      *)
        state_color="$CYAN"
        state_icon="?"
        ;;
    esac
    
    if [[ "$state" == "running" ]]; then
      # Get detailed stats for running VMs
      local vcpus=$(virsh dominfo "$vm" 2>/dev/null | awk '/CPU\(s\):/ {print $2}' || echo "0")
      local mem_total=$(virsh dominfo "$vm" 2>/dev/null | awk '/Max memory:/ {print $3}' || echo "0")
      local mem_used=$(virsh dominfo "$vm" 2>/dev/null | awk '/Used memory:/ {print $3}' || echo "0")
      local mem_display
      
      if [[ "$mem_total" -gt 0 ]]; then
        local mem_percent=$((mem_used * 100 / mem_total))
        mem_display="${mem_used}K/${mem_total}K"
      else
        mem_display="N/A"
      fi
      
      # Simplified I/O stats
      local disk_io="Active"
      local net_io="Active"
      
      printf "  ${state_icon} %-18s ${state_color}%-10s${NC} %6s %10s %10s %15s\n" \
        "$vm" "$state" "$vcpus" "$mem_display" "$disk_io" "$net_io"
    else
      # Stopped VM
      printf "  ${state_icon} %-18s ${state_color}%-10s${NC} %6s %10s %10s %15s\n" \
        "$vm" "$state" "-" "-" "-" "-"
    fi
  done < <(virsh list --all --name 2>/dev/null | grep -v '^$' || true)
  
  if [[ $vm_count -eq 0 ]]; then
    echo "  No VMs found"
    echo ""
    echo "  Create your first VM with: Menu → More Options → Create VM (wizard)"
  fi
  
  echo ""
}

# Get quick actions menu
show_actions() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  QUICK ACTIONS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  [R] Refresh now  |  [S] Start all stopped VMs  |  [T] Stop all running VMs"
  echo "  [D] Diagnostics  |  [M] Main menu  |  [Q] Quit"
  echo ""
}

# Main dashboard display
display_dashboard() {
  while true; do
    show_header
    get_host_stats
    get_vm_stats
    show_actions
    
    # Wait for input with timeout
    echo -n "  Choose action (auto-refresh in ${REFRESH_INTERVAL}s): "
    if read -t "$REFRESH_INTERVAL" -n 1 action 2>/dev/null; then
      echo ""
      case "${action,,}" in
        r)
          # Refresh now
          continue
          ;;
        s)
          echo ""
          echo "Starting all stopped VMs..."
          virsh list --inactive --name 2>/dev/null | while read -r vm; do
            [[ -z "$vm" ]] && continue
            echo "  Starting: $vm"
            virsh start "$vm" 2>/dev/null || echo "  Failed to start $vm"
          done
          echo ""
          read -p "Press Enter to continue..." 
          ;;
        t)
          echo ""
          echo "Stopping all running VMs (graceful shutdown)..."
          virsh list --name 2>/dev/null | while read -r vm; do
            [[ -z "$vm" ]] && continue
            echo "  Stopping: $vm"
            virsh shutdown "$vm" 2>/dev/null || echo "  Failed to stop $vm"
          done
          echo ""
          echo "VMs are shutting down gracefully..."
          read -p "Press Enter to continue..."
          ;;
        d)
          clear
          /etc/hypervisor/scripts/diagnose.sh
          echo ""
          read -p "Press Enter to return to dashboard..."
          ;;
        m)
          exec /etc/hypervisor/scripts/menu.sh
          ;;
        q)
          echo ""
          echo "Exiting dashboard..."
          exit 0
          ;;
        *)
          # Unknown action, just refresh
          ;;
      esac
    else
      # Timeout - auto refresh
      echo ""
    fi
  done
}

# Help mode
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Hypervisor VM Dashboard"
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --interval SECONDS  Refresh interval (default: 5)"
  echo "  --help, -h          Show this help"
  echo ""
  echo "Environment variables:"
  echo "  REFRESH_INTERVAL    Refresh interval in seconds"
  echo ""
  echo "Interactive commands:"
  echo "  R - Refresh now"
  echo "  S - Start all stopped VMs"
  echo "  T - Stop all running VMs (graceful)"
  echo "  D - Run system diagnostics"
  echo "  M - Return to main menu"
  echo "  Q - Quit dashboard"
  exit 0
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      REFRESH_INTERVAL="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Run dashboard
display_dashboard
