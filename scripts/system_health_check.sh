#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS System Health Check
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Comprehensive system health check and diagnostic tool
# Runs on boot and on-demand to ensure system is ready for operations
# Validates hardware, services, network, storage, VMs, security, and performance
#
set -Eeuo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

HEALTH_LOG="/var/lib/hypervisor/logs/health-$(date +%Y%m%d-%H%M%S).log"
HEALTH_STATUS="/var/lib/hypervisor/health-status.json"

# Only create directories if we have permission
if [[ -w /var/lib/hypervisor ]] || [[ ! -e /var/lib/hypervisor ]]; then
  mkdir -p "$(dirname "$HEALTH_LOG")" 2>/dev/null || true
else
  # Fallback to /tmp if we can't write to /var/lib
  HEALTH_LOG="/tmp/health-$(date +%Y%m%d-%H%M%S).log"
  HEALTH_STATUS="/tmp/health-status.json"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$HEALTH_LOG"
}

status() {
  local level="$1"
  shift
  case "$level" in
    OK)     echo -e "${GREEN}✓${NC} $*" | tee -a "$HEALTH_LOG" ;;
    WARN)   echo -e "${YELLOW}⚠${NC} $*" | tee -a "$HEALTH_LOG" ;;
    ERROR)  echo -e "${RED}✗${NC} $*" | tee -a "$HEALTH_LOG" ;;
    INFO)   echo -e "${BLUE}ℹ${NC} $*" | tee -a "$HEALTH_LOG" ;;
  esac
}

# Initialize results
declare -A RESULTS
OVERALL_STATUS="OK"
CRITICAL_ERRORS=0
WARNINGS=0

check_start() {
  echo ""
  log "=== $1 ==="
}

check_result() {
  local name="$1"
  local status="$2"
  local message="$3"
  
  RESULTS["$name"]="$status:$message"
  
  case "$status" in
    ERROR)
      CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
      OVERALL_STATUS="ERROR"
      status ERROR "$message"
      ;;
    WARN)
      WARNINGS=$((WARNINGS + 1))
      [[ "$OVERALL_STATUS" == "OK" ]] && OVERALL_STATUS="WARN"
      status WARN "$message"
      ;;
    OK)
      status OK "$message"
      ;;
  esac
}

#==============================================================================
# HARDWARE CHECKS
#==============================================================================

check_hardware() {
  check_start "Hardware Checks"
  
  # CPU Check
  local cpu_count=$(nproc 2>/dev/null || echo 0)
  if [[ $cpu_count -ge 4 ]]; then
    check_result "cpu_count" "OK" "CPU cores: $cpu_count (sufficient)"
  elif [[ $cpu_count -ge 2 ]]; then
    check_result "cpu_count" "WARN" "CPU cores: $cpu_count (minimum, consider more for multiple VMs)"
  else
    check_result "cpu_count" "ERROR" "CPU cores: $cpu_count (insufficient, need at least 2)"
  fi
  
  # Check CPU virtualization support
  if grep -qE 'vmx|svm' /proc/cpuinfo; then
    local virt_type=$(grep -oE 'vmx|svm' /proc/cpuinfo | head -1)
    check_result "cpu_virt" "OK" "CPU virtualization: $virt_type (enabled)"
  else
    check_result "cpu_virt" "ERROR" "CPU virtualization: NOT supported or disabled in BIOS"
  fi
  
  # Memory Check
  local total_mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  local total_mem_gb=$((total_mem_kb / 1024 / 1024))
  local avail_mem_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  local avail_mem_gb=$((avail_mem_kb / 1024 / 1024))
  
  if [[ $total_mem_gb -ge 32 ]]; then
    check_result "memory_total" "OK" "Total memory: ${total_mem_gb}GB (excellent)"
  elif [[ $total_mem_gb -ge 16 ]]; then
    check_result "memory_total" "OK" "Total memory: ${total_mem_gb}GB (good)"
  elif [[ $total_mem_gb -ge 8 ]]; then
    check_result "memory_total" "WARN" "Total memory: ${total_mem_gb}GB (minimum, limit concurrent VMs)"
  else
    check_result "memory_total" "ERROR" "Total memory: ${total_mem_gb}GB (insufficient, need at least 8GB)"
  fi
  
  check_result "memory_available" "INFO" "Available memory: ${avail_mem_gb}GB"
  
  # Disk Space Check
  local disk_total=$(df -BG /var/lib/hypervisor 2>/dev/null | awk 'NR==2 {print $2}' | tr -d 'G')
  local disk_avail=$(df -BG /var/lib/hypervisor 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
  local disk_used_pct=$(df /var/lib/hypervisor 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
  
  if [[ $disk_avail -ge 100 ]]; then
    check_result "disk_space" "OK" "Disk space: ${disk_avail}GB available (${disk_used_pct}% used)"
  elif [[ $disk_avail -ge 50 ]]; then
    check_result "disk_space" "WARN" "Disk space: ${disk_avail}GB available (${disk_used_pct}% used) - consider adding more"
  elif [[ $disk_avail -ge 20 ]]; then
    check_result "disk_space" "WARN" "Disk space: ${disk_avail}GB available (${disk_used_pct}% used) - running low!"
  else
    check_result "disk_space" "ERROR" "Disk space: ${disk_avail}GB available (${disk_used_pct}% used) - critically low!"
  fi
  
  # Check /dev/kvm
  if [[ -e /dev/kvm ]]; then
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
      check_result "dev_kvm" "OK" "/dev/kvm: accessible"
    else
      check_result "dev_kvm" "ERROR" "/dev/kvm: exists but not accessible (check permissions)"
    fi
  else
    check_result "dev_kvm" "ERROR" "/dev/kvm: not found (KVM module not loaded)"
  fi
  
  # Check IOMMU (for PCIe passthrough)
  if dmesg | grep -qi "IOMMU enabled"; then
    check_result "iommu" "OK" "IOMMU: enabled (PCIe passthrough available)"
  else
    check_result "iommu" "INFO" "IOMMU: not enabled (PCIe passthrough unavailable)"
  fi
}

#==============================================================================
# SERVICE CHECKS
#==============================================================================

check_services() {
  check_start "Service Checks"
  
  # Libvirt daemon
  if systemctl is-active --quiet libvirtd; then
    check_result "libvirtd" "OK" "libvirtd: running"
  else
    check_result "libvirtd" "ERROR" "libvirtd: not running"
  fi
  
  # Check libvirt connection
  if virsh list >/dev/null 2>&1; then
    check_result "libvirt_connect" "OK" "libvirt connection: working"
  else
    check_result "libvirt_connect" "ERROR" "libvirt connection: failed"
  fi
  
  # SSH
  if systemctl is-active --quiet sshd; then
    check_result "sshd" "OK" "SSH: running"
  else
    check_result "sshd" "WARN" "SSH: not running (remote access unavailable)"
  fi
  
  # Auditd
  if systemctl is-active --quiet auditd; then
    check_result "auditd" "OK" "Audit logging: enabled"
  else
    check_result "auditd" "WARN" "Audit logging: disabled (compliance issue)"
  fi
  
  # Networkd
  if systemctl is-active --quiet systemd-networkd; then
    check_result "networkd" "OK" "Network management: systemd-networkd active"
  else
    check_result "networkd" "INFO" "Network management: not using systemd-networkd"
  fi
}

#==============================================================================
# NETWORK CHECKS
#==============================================================================

check_network() {
  check_start "Network Checks"
  
  # Check internet connectivity
  if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    check_result "internet" "OK" "Internet connectivity: working"
  else
    check_result "internet" "WARN" "Internet connectivity: failed (ISO downloads unavailable)"
  fi
  
  # Check DNS
  if ping -c 1 -W 2 google.com >/dev/null 2>&1; then
    check_result "dns" "OK" "DNS resolution: working"
  else
    check_result "dns" "WARN" "DNS resolution: failed"
  fi
  
  # Check default bridge
  if ip link show br0 >/dev/null 2>&1; then
    local br_status=$(ip link show br0 | grep -oP 'state \K\w+')
    if [[ "$br_status" == "UP" ]]; then
      check_result "bridge" "OK" "Network bridge br0: UP"
    else
      check_result "bridge" "WARN" "Network bridge br0: DOWN"
    fi
  else
    check_result "bridge" "INFO" "Network bridge br0: not configured (using NAT)"
  fi
  
  # Check firewall
  if systemctl is-active --quiet firewalld || iptables -L >/dev/null 2>&1; then
    check_result "firewall" "OK" "Firewall: enabled"
  else
    check_result "firewall" "WARN" "Firewall: disabled (security risk)"
  fi
}

#==============================================================================
# STORAGE CHECKS
#==============================================================================

check_storage() {
  check_start "Storage Checks"
  
  # Check required directories
  local required_dirs=(
    "/var/lib/hypervisor"
    "/var/lib/hypervisor/isos"
    "/var/lib/hypervisor/disks"
    "/var/lib/hypervisor/xml"
    "/var/lib/hypervisor/vm_profiles"
  )
  
  for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      check_result "dir_${dir//\//_}" "OK" "Directory $dir: exists"
    else
      check_result "dir_${dir//\//_}" "ERROR" "Directory $dir: missing"
    fi
  done
  
  # Check storage pool
  if virsh pool-list --all 2>/dev/null | grep -q "default"; then
    local pool_state=$(virsh pool-info default 2>/dev/null | awk '/State:/ {print $2}')
    if [[ "$pool_state" == "running" ]]; then
      check_result "storage_pool" "OK" "Storage pool 'default': active"
    else
      check_result "storage_pool" "WARN" "Storage pool 'default': inactive"
    fi
  else
    check_result "storage_pool" "INFO" "Storage pool 'default': not configured"
  fi
  
  # Check disk I/O performance (simple test)
  local io_test_file="/var/lib/hypervisor/.io-test-$$"
  local io_speed=$(dd if=/dev/zero of="$io_test_file" bs=1M count=100 2>&1 | grep -oP '\d+\.?\d* MB/s' || echo "unknown")
  rm -f "$io_test_file"
  
  if [[ "$io_speed" != "unknown" ]]; then
    local speed_num=$(echo "$io_speed" | grep -oP '^\d+')
    if [[ $speed_num -ge 500 ]]; then
      check_result "disk_io" "OK" "Disk I/O: ${io_speed} (excellent)"
    elif [[ $speed_num -ge 100 ]]; then
      check_result "disk_io" "OK" "Disk I/O: ${io_speed} (good)"
    else
      check_result "disk_io" "WARN" "Disk I/O: ${io_speed} (slow, consider SSD)"
    fi
  else
    check_result "disk_io" "INFO" "Disk I/O: benchmark failed"
  fi
}

#==============================================================================
# VM CHECKS
#==============================================================================

check_vms() {
  check_start "VM Status"
  
  # Count VMs
  local total_vms=$(virsh list --all --name 2>/dev/null | grep -v '^$' | wc -l)
  local running_vms=$(virsh list --state-running --name 2>/dev/null | grep -v '^$' | wc -l)
  
  check_result "vm_count" "INFO" "Total VMs: $total_vms (running: $running_vms)"
  
  # Check for VMs with issues
  if [[ $total_vms -gt 0 ]]; then
    local crashed_vms=$(virsh list --all --name 2>/dev/null | while read vm; do
      [[ -z "$vm" ]] && continue
      local state=$(virsh domstate "$vm" 2>/dev/null)
      if [[ "$state" == "crashed" ]]; then
        echo "$vm"
      fi
    done)
    
    if [[ -n "$crashed_vms" ]]; then
      check_result "vm_crashed" "WARN" "Crashed VMs detected: $crashed_vms"
    fi
  fi
  
  # Resource usage by VMs
  if [[ $running_vms -gt 0 ]]; then
    local total_vm_mem=0
    local total_vm_cpus=0
    
    while read vm; do
      [[ -z "$vm" ]] && continue
      local mem=$(virsh dominfo "$vm" 2>/dev/null | awk '/Max memory:/ {print $3}')
      local cpus=$(virsh dominfo "$vm" 2>/dev/null | awk '/CPU\(s\):/ {print $2}')
      total_vm_mem=$((total_vm_mem + mem))
      total_vm_cpus=$((total_vm_cpus + cpus))
    done < <(virsh list --state-running --name 2>/dev/null)
    
    local total_vm_mem_gb=$((total_vm_mem / 1024 / 1024))
    check_result "vm_resources" "INFO" "VM resources: ${total_vm_cpus} vCPUs, ${total_vm_mem_gb}GB memory"
  fi
}

#==============================================================================
# SECURITY CHECKS
#==============================================================================

check_security() {
  check_start "Security Checks"
  
  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    check_result "root_check" "INFO" "Running as root (expected for system checks)"
  fi
  
  # Check AppArmor
  if command -v aa-status >/dev/null 2>&1; then
    if aa-status >/dev/null 2>&1; then
      check_result "apparmor" "OK" "AppArmor: enabled"
    else
      check_result "apparmor" "WARN" "AppArmor: installed but not running"
    fi
  else
    check_result "apparmor" "WARN" "AppArmor: not installed"
  fi
  
  # Check if passwordless sudo is disabled for security
  if sudo -n -l 2>/dev/null | grep -q "NOPASSWD"; then
    # Check if it's only for specific commands
    local nopasswd_cmds=$(sudo -l 2>/dev/null | grep NOPASSWD | wc -l)
    if [[ $nopasswd_cmds -gt 0 ]]; then
      check_result "sudo_config" "OK" "Sudo: granular NOPASSWD rules ($nopasswd_cmds commands)"
    fi
  else
    check_result "sudo_config" "OK" "Sudo: password required (secure)"
  fi
  
  # Check SSH config
  if [[ -f /etc/ssh/sshd_config ]]; then
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
      check_result "ssh_password" "OK" "SSH: password authentication disabled (secure)"
    else
      check_result "ssh_password" "WARN" "SSH: password authentication enabled (consider key-only)"
    fi
    
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
      check_result "ssh_root" "OK" "SSH: root login disabled (secure)"
    else
      check_result "ssh_root" "WARN" "SSH: root login enabled (security risk)"
    fi
  fi
  
  # Check for unencrypted VM disks
  local vm_disks=$(find /var/lib/hypervisor/disks -name "*.qcow2" 2>/dev/null | wc -l)
  if [[ $vm_disks -gt 0 ]]; then
    check_result "disk_encryption" "WARN" "VM disk encryption: not configured (consider enabling)"
  fi
}

#==============================================================================
# CONFIGURATION CHECKS
#==============================================================================

check_configuration() {
  check_start "Configuration Checks"
  
  # Check if configuration files exist
  local config_files=(
    "/etc/hypervisor/config.json"
    "/etc/nixos/flake.nix"
    "/etc/hypervisor/flake.nix"
  )
  
  for cfg in "${config_files[@]}"; do
    if [[ -f "$cfg" ]]; then
      check_result "config_${cfg//\//_}" "OK" "Config $cfg: exists"
      
      # Validate JSON
      if [[ "$cfg" == *.json ]]; then
        if jq empty "$cfg" 2>/dev/null; then
          check_result "config_${cfg//\//_}_valid" "OK" "Config $cfg: valid JSON"
        else
          check_result "config_${cfg//\//_}_valid" "ERROR" "Config $cfg: invalid JSON"
        fi
      fi
    else
      check_result "config_${cfg//\//_}" "WARN" "Config $cfg: missing"
    fi
  done
  
  # Check NixOS generation
  local current_gen=$(readlink /run/current-system | grep -oP 'system-\K\d+')
  local latest_gen=$(ls -d /nix/var/nix/profiles/system-*-link 2>/dev/null | grep -oP 'system-\K\d+' | sort -n | tail -1)
  
  if [[ "$current_gen" == "$latest_gen" ]]; then
    check_result "nixos_gen" "OK" "NixOS generation: current (gen-$current_gen)"
  else
    check_result "nixos_gen" "WARN" "NixOS generation: not latest (current: $current_gen, latest: $latest_gen) - reboot pending?"
  fi
}

#==============================================================================
# OPTIMIZATION CHECKS
#==============================================================================

check_optimization() {
  check_start "Optimization Checks"
  
  # Check if hugepages are enabled
  local hugepages=$(cat /proc/sys/vm/nr_hugepages 2>/dev/null || echo 0)
  if [[ $hugepages -gt 0 ]]; then
    check_result "hugepages" "OK" "Hugepages: enabled ($hugepages pages)"
  else
    check_result "hugepages" "INFO" "Hugepages: disabled (enable for better performance)"
  fi
  
  # Check CPU governor
  local cpu_gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
  if [[ "$cpu_gov" == "performance" ]]; then
    check_result "cpu_governor" "OK" "CPU governor: performance"
  elif [[ "$cpu_gov" == "powersave" ]]; then
    check_result "cpu_governor" "WARN" "CPU governor: powersave (consider 'performance' for VMs)"
  else
    check_result "cpu_governor" "INFO" "CPU governor: $cpu_gov"
  fi
  
  # Check swappiness
  local swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 60)
  if [[ $swappiness -le 10 ]]; then
    check_result "swappiness" "OK" "Swappiness: $swappiness (optimal for hypervisor)"
  elif [[ $swappiness -le 60 ]]; then
    check_result "swappiness" "INFO" "Swappiness: $swappiness (consider lowering to 10)"
  else
    check_result "swappiness" "WARN" "Swappiness: $swappiness (too high, lower to 10)"
  fi
  
  # Check transparent hugepages
  local thp_status=$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -oP '\[\K\w+' || echo "unknown")
  if [[ "$thp_status" == "always" || "$thp_status" == "madvise" ]]; then
    check_result "thp" "OK" "Transparent Hugepages: $thp_status"
  else
    check_result "thp" "INFO" "Transparent Hugepages: $thp_status (consider enabling)"
  fi
}

#==============================================================================
# REPORT GENERATION
#==============================================================================

generate_report() {
  echo ""
  echo "========================================================================"
  echo "                    SYSTEM HEALTH REPORT"
  echo "========================================================================"
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Hostname:  $(hostname)"
  echo "Status:    $OVERALL_STATUS"
  echo "------------------------------------------------------------------------"
  echo "Critical Errors: $CRITICAL_ERRORS"
  echo "Warnings:        $WARNINGS"
  echo "========================================================================"
  echo ""
  
  if [[ $CRITICAL_ERRORS -gt 0 ]]; then
    echo "⚠️  CRITICAL ISSUES DETECTED - System may not function correctly!"
    echo ""
  elif [[ $WARNINGS -gt 0 ]]; then
    echo "⚠️  Warnings detected - Review recommendations below"
    echo ""
  else
    echo "✓ All checks passed - System is healthy"
    echo ""
  fi
  
  # Generate JSON status
  cat > "$HEALTH_STATUS" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "overall_status": "$OVERALL_STATUS",
  "critical_errors": $CRITICAL_ERRORS,
  "warnings": $WARNINGS,
  "checks": {
EOF
  
  local first=true
  for check in "${!RESULTS[@]}"; do
    if ! $first; then
      echo "," >> "$HEALTH_STATUS"
    fi
    first=false
    
    local status_msg="${RESULTS[$check]}"
    local status="${status_msg%%:*}"
    local message="${status_msg#*:}"
    
    echo -n "    \"$check\": {\"status\": \"$status\", \"message\": \"$message\"}" >> "$HEALTH_STATUS"
  done
  
  cat >> "$HEALTH_STATUS" <<EOF

  }
}
EOF
  
  echo "Full report: $HEALTH_LOG"
  echo "JSON status: $HEALTH_STATUS"
}

#==============================================================================
# RECOMMENDATIONS
#==============================================================================

show_recommendations() {
  echo ""
  echo "========================================================================"
  echo "                      RECOMMENDATIONS"
  echo "========================================================================"
  
  local has_recommendations=false
  
  # Hardware recommendations
  if [[ $CRITICAL_ERRORS -gt 0 ]] || [[ $WARNINGS -gt 0 ]]; then
    for check in "${!RESULTS[@]}"; do
      local status_msg="${RESULTS[$check]}"
      local status="${status_msg%%:*}"
      
      if [[ "$status" == "ERROR" ]] || [[ "$status" == "WARN" ]]; then
        case "$check" in
          cpu_count)
            echo "• Upgrade CPU or reduce concurrent VMs"
            has_recommendations=true
            ;;
          cpu_virt)
            echo "• Enable VT-x/AMD-V in BIOS settings"
            has_recommendations=true
            ;;
          memory_total)
            echo "• Add more RAM for better VM performance"
            echo "  Recommended: 16GB minimum, 32GB+ for multiple VMs"
            has_recommendations=true
            ;;
          disk_space)
            echo "• Add more storage or clean up old VMs/snapshots"
            echo "  Run: virsh snapshot-list --tree <vm>"
            echo "  Delete old: virsh snapshot-delete <vm> <snapshot>"
            has_recommendations=true
            ;;
          dev_kvm)
            echo "• Load KVM module: sudo modprobe kvm kvm_intel (or kvm_amd)"
            has_recommendations=true
            ;;
          libvirtd)
            echo "• Start libvirtd: sudo systemctl start libvirtd"
            has_recommendations=true
            ;;
          internet)
            echo "• Check network configuration and routing"
            has_recommendations=true
            ;;
          disk_encryption)
            echo "• Enable VM disk encryption for security"
            echo "  See: docs/SECURITY_CONSIDERATIONS.md"
            has_recommendations=true
            ;;
          cpu_governor)
            echo "• Set CPU governor to performance:"
            echo "  echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
            has_recommendations=true
            ;;
          swappiness)
            echo "• Lower swappiness for better VM performance:"
            echo "  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf"
            echo "  sudo sysctl -p"
            has_recommendations=true
            ;;
        esac
      fi
    done
  fi
  
  if ! $has_recommendations; then
    echo "No specific recommendations - system is well configured!"
  fi
  
  echo "========================================================================"
}

#==============================================================================
# MAIN
#==============================================================================

main() {
  log "Starting system health check..."
  
  check_hardware
  check_services
  check_network
  check_storage
  check_vms
  check_security
  check_configuration
  check_optimization
  
  generate_report
  show_recommendations
  
  log "Health check complete. Status: $OVERALL_STATUS"
  
  # Send alerts if critical errors found
  if [[ $CRITICAL_ERRORS -gt 0 ]] && [[ -x /etc/hypervisor/scripts/alert_manager.sh ]]; then
    local alert_msg="Health check found $CRITICAL_ERRORS critical error(s)"
    /etc/hypervisor/scripts/alert_manager.sh critical \
      "System Health Check Failed" \
      "$alert_msg - Check $HEALTH_LOG for details" \
      "health_check_critical" \
      300
  elif [[ $WARNINGS -gt 0 ]] && [[ -x /etc/hypervisor/scripts/alert_manager.sh ]]; then
    /etc/hypervisor/scripts/alert_manager.sh warning \
      "System Health Warnings" \
      "Health check found $WARNINGS warning(s) - Check $HEALTH_LOG" \
      "health_check_warning" \
      3600
  fi
  
  # Exit code based on status
  case "$OVERALL_STATUS" in
    OK)     exit 0 ;;
    WARN)   exit 1 ;;
    ERROR)  exit 2 ;;
  esac
}

main "$@"
