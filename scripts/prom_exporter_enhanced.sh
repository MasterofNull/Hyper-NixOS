#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Enhanced Prometheus exporter for hypervisor metrics
# Exports comprehensive metrics about host and VMs

set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Configuration
METRICS_PORT="${PROM_PORT:-9090}"
OUTPUT_FILE="${1:-/var/lib/hypervisor/metrics/hypervisor.prom}"
INTERVAL="${PROM_INTERVAL:-15}"  # seconds

# Ensure metrics directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Helper functions
metric() { 
  printf "%s{%s} %s %s\n" "$1" "$2" "$3" "$4"
}

plain() { 
  printf "%s %s %s\n" "$1" "$2" "$3"
}

comment() {
  printf "# %s\n" "$1"
}

help_text() {
  printf "# HELP %s %s\n" "$1" "$2"
}

type_text() {
  printf "# TYPE %s %s\n" "$1" "$2"
}

# Collect metrics
collect_metrics() {
  local timestamp=$(date +%s%3N)
  local buf=$(mktemp)
  
  comment "Hypervisor Metrics - Generated $(date -Iseconds)" >> "$buf"
  echo "" >> "$buf"
  
  # ============================================================
  # HOST METRICS
  # ============================================================
  
  comment "=== Host System Metrics ===" >> "$buf"
  echo "" >> "$buf"
  
  # Uptime
  help_text "hypervisor_uptime_seconds" "System uptime in seconds" >> "$buf"
  type_text "hypervisor_uptime_seconds" "gauge" >> "$buf"
  local uptime_s=$(awk '{print int($1)}' /proc/uptime)
  plain "hypervisor_uptime_seconds" "$uptime_s" "$timestamp" >> "$buf"
  echo "" >> "$buf"
  
  # Memory metrics
  help_text "hypervisor_memory_bytes" "Host memory statistics" >> "$buf"
  type_text "hypervisor_memory_bytes" "gauge" >> "$buf"
  while IFS=: read -r key value; do
    key=$(echo "$key" | tr -d ' ')
    value=$(echo "$value" | awk '{print $1}')
    case "$key" in
      MemTotal)
        metric "hypervisor_memory_bytes" "type=\"total\"" "$((value * 1024))" "$timestamp" >> "$buf"
        ;;
      MemFree)
        metric "hypervisor_memory_bytes" "type=\"free\"" "$((value * 1024))" "$timestamp" >> "$buf"
        ;;
      MemAvailable)
        metric "hypervisor_memory_bytes" "type=\"available\"" "$((value * 1024))" "$timestamp" >> "$buf"
        ;;
      Buffers)
        metric "hypervisor_memory_bytes" "type=\"buffers\"" "$((value * 1024))" "$timestamp" >> "$buf"
        ;;
      Cached)
        metric "hypervisor_memory_bytes" "type=\"cached\"" "$((value * 1024))" "$timestamp" >> "$buf"
        ;;
    esac
  done < /proc/meminfo
  echo "" >> "$buf"
  
  # CPU metrics
  help_text "hypervisor_cpu_count" "Number of CPU cores" >> "$buf"
  type_text "hypervisor_cpu_count" "gauge" >> "$buf"
  local cpu_count=$(nproc)
  plain "hypervisor_cpu_count" "$cpu_count" "$timestamp" >> "$buf"
  echo "" >> "$buf"
  
  # Load average
  help_text "hypervisor_load_average" "System load average" >> "$buf"
  type_text "hypervisor_load_average" "gauge" >> "$buf"
  read -r load1 load5 load15 _ < /proc/loadavg
  metric "hypervisor_load_average" "period=\"1m\"" "$load1" "$timestamp" >> "$buf"
  metric "hypervisor_load_average" "period=\"5m\"" "$load5" "$timestamp" >> "$buf"
  metric "hypervisor_load_average" "period=\"15m\"" "$load15" "$timestamp" >> "$buf"
  echo "" >> "$buf"
  
  # Disk space
  help_text "hypervisor_disk_bytes" "Disk space statistics for hypervisor storage" >> "$buf"
  type_text "hypervisor_disk_bytes" "gauge" >> "$buf"
  if [[ -d /var/lib/hypervisor ]]; then
    local disk_info=$(df -B1 /var/lib/hypervisor | tail -1)
    local total=$(echo "$disk_info" | awk '{print $2}')
    local used=$(echo "$disk_info" | awk '{print $3}')
    local available=$(echo "$disk_info" | awk '{print $4}')
    local mount=$(echo "$disk_info" | awk '{print $6}')
    
    metric "hypervisor_disk_bytes" "type=\"total\",mount=\"$mount\"" "$total" "$timestamp" >> "$buf"
    metric "hypervisor_disk_bytes" "type=\"used\",mount=\"$mount\"" "$used" "$timestamp" >> "$buf"
    metric "hypervisor_disk_bytes" "type=\"available\",mount=\"$mount\"" "$available" "$timestamp" >> "$buf"
  fi
  echo "" >> "$buf"
  
  # ============================================================
  # LIBVIRT METRICS
  # ============================================================
  
  comment "=== Libvirt Status ===" >> "$buf"
  echo "" >> "$buf"
  
  help_text "hypervisor_libvirt_up" "Libvirt daemon status (1=up, 0=down)" >> "$buf"
  type_text "hypervisor_libvirt_up" "gauge" >> "$buf"
  if systemctl is-active --quiet libvirtd 2>/dev/null; then
    plain "hypervisor_libvirt_up" "1" "$timestamp" >> "$buf"
  else
    plain "hypervisor_libvirt_up" "0" "$timestamp" >> "$buf"
  fi
  echo "" >> "$buf"
  
  # ============================================================
  # VM METRICS
  # ============================================================
  
  comment "=== Virtual Machine Metrics ===" >> "$buf"
  echo "" >> "$buf"
  
  # VM counts by state
  help_text "hypervisor_vms_total" "Total number of VMs by state" >> "$buf"
  type_text "hypervisor_vms_total" "gauge" >> "$buf"
  
  local vms_running=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l || echo 0)
  local vms_stopped=$(virsh list --inactive --name 2>/dev/null | grep -v '^$' | wc -l || echo 0)
  local vms_total=$(( vms_running + vms_stopped ))
  
  metric "hypervisor_vms_total" "state=\"running\"" "$vms_running" "$timestamp" >> "$buf"
  metric "hypervisor_vms_total" "state=\"stopped\"" "$vms_stopped" "$timestamp" >> "$buf"
  metric "hypervisor_vms_total" "state=\"all\"" "$vms_total" "$timestamp" >> "$buf"
  echo "" >> "$buf"
  
  # Per-VM metrics
  help_text "vm_state" "VM state (1=running, 0=stopped)" >> "$buf"
  type_text "vm_state" "gauge" >> "$buf"
  
  help_text "vm_vcpu_count" "Number of virtual CPUs" >> "$buf"
  type_text "vm_vcpu_count" "gauge" >> "$buf"
  
  help_text "vm_memory_bytes" "VM memory statistics" >> "$buf"
  type_text "vm_memory_bytes" "gauge" >> "$buf"
  
  help_text "vm_cpu_time_seconds_total" "Total CPU time used" >> "$buf"
  type_text "vm_cpu_time_seconds_total" "counter" >> "$buf"
  
  help_text "vm_disk_read_bytes_total" "Total disk read bytes" >> "$buf"
  type_text "vm_disk_read_bytes_total" "counter" >> "$buf"
  
  help_text "vm_disk_write_bytes_total" "Total disk write bytes" >> "$buf"
  type_text "vm_disk_write_bytes_total" "counter" >> "$buf"
  
  help_text "vm_network_rx_bytes_total" "Total network received bytes" >> "$buf"
  type_text "vm_network_rx_bytes_total" "counter" >> "$buf"
  
  help_text "vm_network_tx_bytes_total" "Total network transmitted bytes" >> "$buf"
  type_text "vm_network_tx_bytes_total" "counter" >> "$buf"
  
  # Iterate over all VMs
  while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    
    # VM state
    local state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
    local state_val=0
    [[ "$state" == "running" ]] && state_val=1
    metric "vm_state" "vm=\"$vm\",state=\"$state\"" "$state_val" "$timestamp" >> "$buf"
    
    # Only collect detailed stats for running VMs
    if [[ "$state" == "running" ]]; then
      # vCPU count
      local vcpus=$(virsh dominfo "$vm" 2>/dev/null | awk '/CPU\(s\):/ {print $2}' || echo 0)
      metric "vm_vcpu_count" "vm=\"$vm\"" "$vcpus" "$timestamp" >> "$buf"
      
      # Memory stats
      local mem_total=$(virsh dominfo "$vm" 2>/dev/null | awk '/Max memory:/ {print $3}' || echo 0)
      local mem_used=$(virsh dominfo "$vm" 2>/dev/null | awk '/Used memory:/ {print $3}' || echo 0)
      metric "vm_memory_bytes" "vm=\"$vm\",type=\"total\"" "$((mem_total * 1024))" "$timestamp" >> "$buf"
      metric "vm_memory_bytes" "vm=\"$vm\",type=\"used\"" "$((mem_used * 1024))" "$timestamp" >> "$buf"
      
      # CPU time
      local cpu_time=$(virsh dominfo "$vm" 2>/dev/null | awk '/CPU time:/ {print $3}' | tr -d 's' || echo 0)
      metric "vm_cpu_time_seconds_total" "vm=\"$vm\"" "$cpu_time" "$timestamp" >> "$buf"
      
      # Disk I/O stats
      local disk_stats=$(virsh domstats "$vm" --block 2>/dev/null || true)
      if [[ -n "$disk_stats" ]]; then
        local read_bytes=$(echo "$disk_stats" | awk '/block.*rd.bytes=/ {sum+=$2} END {print sum+0}' FS='=')
        local write_bytes=$(echo "$disk_stats" | awk '/block.*wr.bytes=/ {sum+=$2} END {print sum+0}' FS='=')
        metric "vm_disk_read_bytes_total" "vm=\"$vm\"" "${read_bytes:-0}" "$timestamp" >> "$buf"
        metric "vm_disk_write_bytes_total" "vm=\"$vm\"" "${write_bytes:-0}" "$timestamp" >> "$buf"
      fi
      
      # Network I/O stats
      local net_stats=$(virsh domstats "$vm" --interface 2>/dev/null || true)
      if [[ -n "$net_stats" ]]; then
        local rx_bytes=$(echo "$net_stats" | awk '/net.*rx.bytes=/ {sum+=$2} END {print sum+0}' FS='=')
        local tx_bytes=$(echo "$net_stats" | awk '/net.*tx.bytes=/ {sum+=$2} END {print sum+0}' FS='=')
        metric "vm_network_rx_bytes_total" "vm=\"$vm\"" "${rx_bytes:-0}" "$timestamp" >> "$buf"
        metric "vm_network_tx_bytes_total" "vm=\"$vm\"" "${tx_bytes:-0}" "$timestamp" >> "$buf"
      fi
    fi
  done < <(virsh list --all --name 2>/dev/null || true)
  echo "" >> "$buf"
  
  # ============================================================
  # NETWORK METRICS
  # ============================================================
  
  comment "=== Network Metrics ===" >> "$buf"
  echo "" >> "$buf"
  
  help_text "hypervisor_network_up" "Libvirt network status (1=active, 0=inactive)" >> "$buf"
  type_text "hypervisor_network_up" "gauge" >> "$buf"
  
  while IFS= read -r network; do
    [[ -z "$network" ]] && continue
    local active=$(virsh net-info "$network" 2>/dev/null | awk '/Active:/ {print ($2=="yes")?1:0}')
    metric "hypervisor_network_up" "network=\"$network\"" "${active:-0}" "$timestamp" >> "$buf"
  done < <(virsh net-list --all --name 2>/dev/null || true)
  echo "" >> "$buf"
  
  # ============================================================
  # STORAGE POOL METRICS
  # ============================================================
  
  comment "=== Storage Pool Metrics ===" >> "$buf"
  echo "" >> "$buf"
  
  help_text "hypervisor_pool_capacity_bytes" "Storage pool capacity" >> "$buf"
  type_text "hypervisor_pool_capacity_bytes" "gauge" >> "$buf"
  
  help_text "hypervisor_pool_allocation_bytes" "Storage pool allocation" >> "$buf"
  type_text "hypervisor_pool_allocation_bytes" "gauge" >> "$buf"
  
  help_text "hypervisor_pool_available_bytes" "Storage pool available space" >> "$buf"
  type_text "hypervisor_pool_available_bytes" "gauge" >> "$buf"
  
  while IFS= read -r pool; do
    [[ -z "$pool" ]] && continue
    local pool_info=$(virsh pool-info "$pool" 2>/dev/null || true)
    if [[ -n "$pool_info" ]]; then
      local capacity=$(echo "$pool_info" | awk '/Capacity:/ {print $2}')
      local allocation=$(echo "$pool_info" | awk '/Allocation:/ {print $2}')
      local available=$(echo "$pool_info" | awk '/Available:/ {print $2}')
      
      # Convert to bytes (assuming GiB)
      [[ -n "$capacity" ]] && metric "hypervisor_pool_capacity_bytes" "pool=\"$pool\"" "$(echo "$capacity * 1073741824" | bc 2>/dev/null || echo 0)" "$timestamp" >> "$buf"
      [[ -n "$allocation" ]] && metric "hypervisor_pool_allocation_bytes" "pool=\"$pool\"" "$(echo "$allocation * 1073741824" | bc 2>/dev/null || echo 0)" "$timestamp" >> "$buf"
      [[ -n "$available" ]] && metric "hypervisor_pool_available_bytes" "pool=\"$pool\"" "$(echo "$available * 1073741824" | bc 2>/dev/null || echo 0)" "$timestamp" >> "$buf"
    fi
  done < <(virsh pool-list --all --name 2>/dev/null || true)
  echo "" >> "$buf"
  
  # Move temp file to output
  mv "$buf" "$OUTPUT_FILE"
  chmod 644 "$OUTPUT_FILE"
}

# Main loop or single run
if [[ "${PROM_DAEMON:-false}" == "true" ]]; then
  echo "Starting Prometheus exporter in daemon mode (interval: ${INTERVAL}s)"
  echo "Metrics file: $OUTPUT_FILE"
  echo ""
  
  while true; do
    collect_metrics
    echo "$(date -Iseconds): Metrics updated"
    sleep "$INTERVAL"
  done
else
  # Single run
  collect_metrics
fi
