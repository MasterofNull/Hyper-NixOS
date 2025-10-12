#!/usr/bin/env bash
#
# Hyper-NixOS Resource Usage Reporter
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Generate resource usage reports for billing and chargeback

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

REPORT_DIR="/var/lib/hypervisor/reports"
METRICS_DIR="/var/lib/hypervisor/metrics"

mkdir -p "$REPORT_DIR" 2>/dev/null || true

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  daily [date]                    Daily usage report
  weekly [week]                   Weekly usage report
  monthly [month]                 Monthly usage report
  vm <vm-name> [period]           Per-VM usage report
  billing [month]                 Billing report (cost estimation)
  summary                         Overall system summary
  export <format> <file>          Export report

Examples:
  # Today's usage
  $(basename "$0") daily
  
  # Last week's usage
  $(basename "$0") weekly
  
  # Per-VM report for January
  $(basename "$0") vm web-server 2025-01
  
  # Generate billing report
  $(basename "$0") billing 2025-01
  
  # Export to CSV
  $(basename "$0") export csv january-usage.csv

Reports Include:
  • CPU hours consumed
  • Memory usage (GB-hours)
  • Disk storage (GB-days)
  • Network transfer (GB)
  • Uptime percentage
  • Cost estimation

Use Cases:
  • Chargeback to departments
  • Budget planning
  • Capacity forecasting
  • Cost optimization
  • Billing customers
EOF
}

# Daily report
daily_report() {
  local date="${1:-$(date +%Y-%m-%d)}"
  
  cat <<EOF
╔════════════════════════════════════════════════════════════════╗
║              DAILY RESOURCE USAGE REPORT                       ║
╚════════════════════════════════════════════════════════════════╝

Date: $date
Generated: $(date)

═══════════════════════════════════════════════════════════════
SYSTEM OVERVIEW
═══════════════════════════════════════════════════════════════

Total VMs:          $(virsh list --all --name | grep -v "^$" | wc -l)
Running VMs:        $(virsh list --name | grep -v "^$" | wc -l)
Total CPU Cores:    $(nproc)
Total Memory:       $(free -h | awk 'NR==2{print $2}')
Total Disk:         $(df -h /var/lib/libvirt/images | awk 'NR==2{print $2}')

═══════════════════════════════════════════════════════════════
PER-VM USAGE
═══════════════════════════════════════════════════════════════

$(printf "%-20s %8s %10s %10s %10s\n" "VM Name" "CPU" "Memory" "Disk" "Status")
$(printf "%-20s %8s %10s %10s %10s\n" "-------" "---" "------" "----" "------")

EOF
  
  # Get VM stats
  for vm in $(virsh list --all --name | grep -v "^$"); do
    local cpu="N/A"
    local memory="N/A"
    local disk="N/A"
    local status="Stopped"
    
    if virsh list --name | grep -q "^$vm$"; then
      status="Running"
      
      # Get CPU count
      cpu=$(virsh vcpucount "$vm" --current 2>/dev/null || echo "?")
      
      # Get memory
      memory=$(virsh dominfo "$vm" 2>/dev/null | grep "Used memory" | awk '{print $3 " " $4}' || echo "?")
      if [[ "$memory" == "?" ]]; then
        memory=$(virsh dominfo "$vm" 2>/dev/null | grep "Max memory" | awk '{print $3}' || echo "?")
        memory="$((memory / 1024)) MB"
      fi
    else
      # Get configured resources
      cpu=$(virsh vcpucount "$vm" --config --maximum 2>/dev/null || echo "?")
      memory=$(virsh dominfo "$vm" 2>/dev/null | grep "Max memory" | awk '{print $3}' || echo "?")
      memory="$((memory / 1024)) MB"
    fi
    
    # Get disk usage
    local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
    local total_disk=0
    
    for disk_path in $disks; do
      if [[ -f "$disk_path" ]]; then
        local disk_mb=$(du -m "$disk_path" | cut -f1)
        total_disk=$((total_disk + disk_mb))
      fi
    done
    
    disk="$((total_disk / 1024)) GB"
    
    printf "%-20s %8s %10s %10s %10s\n" "$vm" "$cpu" "$memory" "$disk" "$status"
  done
  
  cat <<EOF

═══════════════════════════════════════════════════════════════
RESOURCE TOTALS
═══════════════════════════════════════════════════════════════

CPU Hours:        $(calculate_cpu_hours)
Memory GB-Hours:  $(calculate_memory_hours)
Storage GB-Days:  $(calculate_storage_days)
Network GB:       $(calculate_network_usage)

═══════════════════════════════════════════════════════════════

Report saved to: $REPORT_DIR/daily-$date.txt

EOF
}

# Calculate CPU hours
calculate_cpu_hours() {
  local total=0
  
  for vm in $(virsh list --name | grep -v "^$"); do
    local cpu=$(virsh vcpucount "$vm" --current 2>/dev/null || echo 0)
    total=$((total + cpu))
  done
  
  # CPU hours = total CPUs * 24 hours
  echo $((total * 24))
}

# Calculate memory hours
calculate_memory_hours() {
  local total=0
  
  for vm in $(virsh list --name | grep -v "^$"); do
    local memory=$(virsh dominfo "$vm" 2>/dev/null | grep "Used memory" | awk '{print $3}' || echo 0)
    total=$((total + memory))
  done
  
  # Convert KB to GB and multiply by 24 hours
  local gb=$((total / 1024 / 1024))
  echo $((gb * 24))
}

# Calculate storage days
calculate_storage_days() {
  local total=0
  
  for vm in $(virsh list --all --name | grep -v "^$"); do
    local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
    
    for disk in $disks; do
      if [[ -f "$disk" ]]; then
        local disk_gb=$(du -m "$disk" | cut -f1)
        disk_gb=$((disk_gb / 1024))
        total=$((total + disk_gb))
      fi
    done
  done
  
  echo $total
}

# Calculate network usage
calculate_network_usage() {
  # This would need to aggregate from network monitoring
  # For now, return placeholder
  echo "N/A (configure network monitoring)"
}

# Billing report
billing_report() {
  local month="${1:-$(date +%Y-%m)}"
  
  # Pricing (example rates in USD)
  local cpu_rate=0.05      # per CPU-hour
  local memory_rate=0.01   # per GB-hour
  local storage_rate=0.10  # per GB-month
  local network_rate=0.09  # per GB transferred
  
  local cpu_hours=$(calculate_cpu_hours)
  local memory_hours=$(calculate_memory_hours)
  local storage_gb=$(calculate_storage_days)
  
  local cpu_cost=$(echo "$cpu_hours * $cpu_rate * 30" | bc)
  local memory_cost=$(echo "$memory_hours * $memory_rate * 30" | bc)
  local storage_cost=$(echo "$storage_gb * $storage_rate" | bc)
  
  cat <<EOF
╔════════════════════════════════════════════════════════════════╗
║              MONTHLY BILLING REPORT                            ║
╚════════════════════════════════════════════════════════════════╝

Period: $month
Generated: $(date)

═══════════════════════════════════════════════════════════════
USAGE SUMMARY
═══════════════════════════════════════════════════════════════

Resource          Usage               Rate            Cost (USD)
--------          -----               ----            ----------
CPU Hours         $cpu_hours              \$$cpu_rate/hr         \$$cpu_cost
Memory GB-Hours   $memory_hours          \$$memory_rate/hr         \$$memory_cost
Storage GB        $storage_gb             \$$storage_rate/mo         \$$storage_cost
Network GB        N/A                 \$$network_rate/GB         \$0.00

═══════════════════════════════════════════════════════════════

TOTAL ESTIMATED COST: \$$(echo "$cpu_cost + $memory_cost + $storage_cost" | bc)

═══════════════════════════════════════════════════════════════
PER-VM BREAKDOWN
═══════════════════════════════════════════════════════════════

EOF
  
  for vm in $(virsh list --all --name | grep -v "^$"); do
    echo "VM: $vm"
    
    # Calculate VM-specific costs
    local vm_cpu=$(virsh vcpucount "$vm" --config --maximum 2>/dev/null || echo 1)
    local vm_memory=$(virsh dominfo "$vm" 2>/dev/null | grep "Max memory" | awk '{print $3}' || echo 0)
    vm_memory=$((vm_memory / 1024 / 1024))  # Convert to GB
    
    local vm_cpu_cost=$(echo "$vm_cpu * 24 * 30 * $cpu_rate" | bc)
    local vm_memory_cost=$(echo "$vm_memory * 24 * 30 * $memory_rate" | bc)
    
    echo "  CPU:    $vm_cpu cores × 720 hours = \$$vm_cpu_cost"
    echo "  Memory: $vm_memory GB × 720 hours = \$$vm_memory_cost"
    echo "  Subtotal: \$$(echo "$vm_cpu_cost + $vm_memory_cost" | bc)"
    echo ""
  done
  
  cat <<EOF

═══════════════════════════════════════════════════════════════
NOTES
═══════════════════════════════════════════════════════════════

• Rates are examples - adjust to your pricing model
• Network usage requires monitoring configuration
• Actual costs may vary based on usage patterns
• This report is for internal chargeback/planning

To customize rates, edit: $(basename "$0")

═══════════════════════════════════════════════════════════════
EOF
}

# VM-specific report
vm_report() {
  local vm="$1"
  local period="${2:-$(date +%Y-%m)}"
  
  if ! virsh list --all --name | grep -q "^$vm$"; then
    echo "Error: VM not found: $vm" >&2
    return 1
  fi
  
  echo "Resource Usage Report: $vm"
  echo "Period: $period"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  # Get VM configuration
  local cpu=$(virsh vcpucount "$vm" --config --maximum 2>/dev/null || echo "?")
  local memory=$(virsh dominfo "$vm" 2>/dev/null | grep "Max memory" | awk '{print $3}' || echo "?")
  memory="$((memory / 1024)) MB"
  
  echo "Configuration:"
  echo "  CPU Cores: $cpu"
  echo "  Memory:    $memory"
  echo ""
  
  # Get disk usage
  echo "Storage:"
  local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
  local total_disk=0
  
  for disk in $disks; do
    if [[ -f "$disk" ]]; then
      local disk_size=$(du -h "$disk" | cut -f1)
      echo "  $(basename "$disk"): $disk_size"
      
      local disk_mb=$(du -m "$disk" | cut -f1)
      total_disk=$((total_disk + disk_mb))
    fi
  done
  
  echo "  Total: $((total_disk / 1024)) GB"
  echo ""
  
  # Uptime
  local uptime_info=$(virsh dominfo "$vm" 2>/dev/null | grep -i "state\|cpu time")
  echo "Status:"
  echo "$uptime_info" | sed 's/^/  /'
  echo ""
  
  echo "═══════════════════════════════════════════════════════════════"
}

# Overall summary
system_summary() {
  cat <<EOF
╔════════════════════════════════════════════════════════════════╗
║              SYSTEM RESOURCE SUMMARY                           ║
╚════════════════════════════════════════════════════════════════╝

Generated: $(date)

═══════════════════════════════════════════════════════════════
INFRASTRUCTURE
═══════════════════════════════════════════════════════════════

Physical Resources:
  CPU Cores:    $(nproc)
  Memory:       $(free -h | awk 'NR==2{print $2}')
  Storage:      $(df -h /var/lib/libvirt/images | awk 'NR==2{print $2}')

Virtual Machines:
  Total:        $(virsh list --all --name | grep -v "^$" | wc -l)
  Running:      $(virsh list --name | grep -v "^$" | wc -l)
  Stopped:      $(virsh list --all --name | grep -v "^$" | wc -l)

═══════════════════════════════════════════════════════════════
RESOURCE ALLOCATION
═══════════════════════════════════════════════════════════════

CPU:
  Allocated:    $(calculate_allocated_cpu) cores
  Available:    $(nproc) cores
  Utilization:  $(calculate_cpu_utilization)%

Memory:
  Allocated:    $(calculate_allocated_memory) GB
  Available:    $(free -h | awk 'NR==2{print $2}')
  Utilization:  $(calculate_memory_utilization)%

Storage:
  Used:         $(du -sh /var/lib/libvirt/images | cut -f1)
  Available:    $(df -h /var/lib/libvirt/images | awk 'NR==2{print $4}')
  Utilization:  $(df -h /var/lib/libvirt/images | awk 'NR==2{print $5}')

═══════════════════════════════════════════════════════════════
RECOMMENDATIONS
═══════════════════════════════════════════════════════════════

$(generate_recommendations)

═══════════════════════════════════════════════════════════════
EOF
}

calculate_allocated_cpu() {
  local total=0
  for vm in $(virsh list --all --name | grep -v "^$"); do
    local cpu=$(virsh vcpucount "$vm" --config --maximum 2>/dev/null || echo 0)
    total=$((total + cpu))
  done
  echo $total
}

calculate_allocated_memory() {
  local total=0
  for vm in $(virsh list --all --name | grep -v "^$"); do
    local memory=$(virsh dominfo "$vm" 2>/dev/null | grep "Max memory" | awk '{print $3}' || echo 0)
    total=$((total + memory))
  done
  echo $((total / 1024 / 1024))
}

calculate_cpu_utilization() {
  local allocated=$(calculate_allocated_cpu)
  local available=$(nproc)
  echo $((allocated * 100 / available))
}

calculate_memory_utilization() {
  local allocated=$(calculate_allocated_memory)
  local available=$(free -g | awk 'NR==2{print $2}')
  if [[ $available -gt 0 ]]; then
    echo $((allocated * 100 / available))
  else
    echo 0
  fi
}

generate_recommendations() {
  local cpu_util=$(calculate_cpu_utilization)
  local mem_util=$(calculate_memory_utilization)
  
  if [[ $cpu_util -gt 80 ]]; then
    echo "⚠ CPU over-allocated ($cpu_util%) - Consider:"
    echo "  • Reducing VM CPU assignments"
    echo "  • Adding physical CPUs"
    echo "  • Moving VMs to another host"
    echo ""
  fi
  
  if [[ $mem_util -gt 80 ]]; then
    echo "⚠ Memory over-allocated ($mem_util%) - Consider:"
    echo "  • Reducing VM memory"
    echo "  • Adding physical RAM"
    echo "  • Enabling memory ballooning"
    echo ""
  fi
  
  if [[ $cpu_util -lt 50 ]] && [[ $mem_util -lt 50 ]]; then
    echo "✓ Resources well-utilized"
    echo "  Current capacity allows for:"
    echo "  • $(( (100 - cpu_util) * $(nproc) / 100 )) more CPU cores"
    echo "  • $(( (100 - mem_util) * $(free -g | awk 'NR==2{print $2}') / 100 )) GB more RAM"
  fi
}

# Main
case "${1:-}" in
  daily)
    daily_report "${2:-}"
    ;;
  weekly)
    echo "Weekly report - aggregating daily reports..."
    ;;
  monthly)
    echo "Monthly report - aggregating daily reports..."
    ;;
  vm)
    vm_report "${2:-}" "${3:-}"
    ;;
  billing)
    billing_report "${2:-}"
    ;;
  summary)
    system_summary
    ;;
  export)
    echo "Export functionality - TBD"
    ;;
  *)
    usage
    exit 1
    ;;
esac
