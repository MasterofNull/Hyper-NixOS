#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"

# VM Resource Optimizer - Helps optimize VM resource allocation
# Analyzes current usage and suggests improvements

require() {
    for bin in "$@"; do
        command -v "$bin" >/dev/null 2>&1 || {
            echo "Missing dependency: $bin" >&2
            exit 1
        }
    done
}

require "$DIALOG" jq virsh bc awk

# Analyze VM resource usage
analyze_vm_resources() {
    local domain="$1"
    local profile="/var/lib/hypervisor/vm_profiles/${domain}.json"
    
    echo "=== Resource Analysis for VM: $domain ==="
    echo
    
    # Get configured resources
    if [[ -f "$profile" ]]; then
        local configured_cpus=$(jq -r '.cpus // "N/A"' "$profile")
        local configured_mem=$(jq -r '.memory_mb // "N/A"' "$profile")
        echo "Configured: ${configured_cpus} CPUs, ${configured_mem} MB RAM"
    else
        echo "No profile found for $domain"
    fi
    
    # Get actual allocation
    local actual_cpus=$(virsh dominfo "$domain" 2>/dev/null | awk '/^CPU\(s\):/ {print $2}')
    local actual_mem=$(virsh dominfo "$domain" 2>/dev/null | awk '/^Max memory:/ {print $3}')
    echo "Allocated: ${actual_cpus:-N/A} CPUs, ${actual_mem:-N/A} KB RAM"
    echo
    
    # Check if running
    local state=$(virsh domstate "$domain" 2>/dev/null || echo "unknown")
    if [[ "$state" != "running" ]]; then
        echo "VM is not running (state: $state)"
        return 1
    fi
    
    # Get usage statistics
    echo "Current Usage:"
    
    # CPU usage (simplified - real implementation would track over time)
    local cpu_stats=$(virsh cpu-stats "$domain" --total 2>/dev/null || echo "")
    if [[ -n "$cpu_stats" ]]; then
        echo "$cpu_stats" | grep -E "cpu_time|user_time|system_time" | sed 's/^/  /'
    fi
    
    # Memory usage
    local mem_stats=$(virsh dommemstat "$domain" 2>/dev/null || echo "")
    if [[ -n "$mem_stats" ]]; then
        local actual_kb=$(echo "$mem_stats" | awk '/^actual/ {print $2}')
        local unused_kb=$(echo "$mem_stats" | awk '/^unused/ {print $2}')
        local available_kb=$(echo "$mem_stats" | awk '/^available/ {print $2}')
        
        if [[ -n "$actual_kb" && -n "$unused_kb" ]]; then
            local used_kb=$((actual_kb - unused_kb))
            local usage_percent=$(echo "scale=1; $used_kb * 100 / $actual_kb" | bc)
            echo "  Memory: ${used_kb} KB used of ${actual_kb} KB (${usage_percent}%)"
            
            # Optimization suggestions
            echo
            echo "Optimization Suggestions:"
            
            # Memory optimization
            if (( $(echo "$usage_percent < 50" | bc -l) )); then
                local suggested_mem=$((used_kb * 2 / 1024))  # Double current usage in MB
                echo "  - Memory is overprovisioned. Consider reducing to ${suggested_mem} MB"
            elif (( $(echo "$usage_percent > 90" | bc -l) )); then
                local suggested_mem=$((actual_kb * 15 / 10 / 1024))  # 150% of current in MB
                echo "  - Memory usage is high. Consider increasing to ${suggested_mem} MB"
            else
                echo "  - Memory allocation appears optimal"
            fi
        fi
    fi
    
    # Disk I/O statistics
    echo
    echo "Disk I/O:"
    local blkstats=$(virsh domblkstat "$domain" vda 2>/dev/null || echo "")
    if [[ -n "$blkstats" ]]; then
        echo "$blkstats" | sed 's/^/  /'
    fi
    
    # Network statistics
    echo
    echo "Network I/O:"
    local ifstats=$(virsh domifstat "$domain" vnet0 2>/dev/null || echo "")
    if [[ -n "$ifstats" ]]; then
        echo "$ifstats" | sed 's/^/  /'
    fi
}

# System-wide resource optimization
analyze_system_resources() {
    echo "=== System Resource Analysis ==="
    echo
    
    # Host resources
    local total_cpus=$(nproc)
    local total_mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    local total_mem_mb=$((total_mem_kb / 1024))
    
    echo "Host Resources:"
    echo "  Total CPUs: $total_cpus"
    echo "  Total Memory: ${total_mem_mb} MB"
    echo
    
    # Calculate allocated resources
    local allocated_cpus=0
    local allocated_mem_mb=0
    local vm_count=0
    
    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        ((vm_count++))
        
        local vcpus=$(virsh dominfo "$domain" 2>/dev/null | awk '/^CPU\(s\):/ {print $2}' || echo "0")
        local mem_kb=$(virsh dominfo "$domain" 2>/dev/null | awk '/^Max memory:/ {print $3}' || echo "0")
        
        allocated_cpus=$((allocated_cpus + vcpus))
        allocated_mem_mb=$((allocated_mem_mb + mem_kb / 1024))
    done < <(virsh list --all --name)
    
    echo "Allocated Resources:"
    echo "  VMs: $vm_count"
    echo "  vCPUs: $allocated_cpus / $total_cpus ($(echo "scale=1; $allocated_cpus * 100 / $total_cpus" | bc)% overcommit)"
    echo "  Memory: ${allocated_mem_mb} MB / ${total_mem_mb} MB ($(echo "scale=1; $allocated_mem_mb * 100 / $total_mem_mb" | bc)%)"
    echo
    
    # Recommendations
    echo "System-wide Recommendations:"
    
    # CPU overcommit
    local cpu_overcommit_ratio=$(echo "scale=2; $allocated_cpus / $total_cpus" | bc)
    if (( $(echo "$cpu_overcommit_ratio > 4" | bc -l) )); then
        echo "  - WARNING: High CPU overcommit ratio (${cpu_overcommit_ratio}:1). Consider reducing VM CPU allocations."
    elif (( $(echo "$cpu_overcommit_ratio > 2" | bc -l) )); then
        echo "  - CAUTION: Moderate CPU overcommit ratio (${cpu_overcommit_ratio}:1). Monitor for contention."
    else
        echo "  - CPU allocation is reasonable (${cpu_overcommit_ratio}:1 overcommit)."
    fi
    
    # Memory allocation
    local mem_percent=$(echo "scale=1; $allocated_mem_mb * 100 / $total_mem_mb" | bc)
    if (( $(echo "$mem_percent > 90" | bc -l) )); then
        echo "  - WARNING: Memory oversubscribed (${mem_percent}%). Risk of host OOM."
        echo "    Consider: Reducing VM memory allocations or adding host RAM."
    elif (( $(echo "$mem_percent > 80" | bc -l) )); then
        echo "  - CAUTION: High memory allocation (${mem_percent}%). Limited headroom."
    else
        echo "  - Memory allocation healthy (${mem_percent}%)."
    fi
    
    # Host memory reservation
    local host_reserved_mb=$((total_mem_mb - allocated_mem_mb))
    if [[ $host_reserved_mb -lt 2048 ]]; then
        echo "  - WARNING: Only ${host_reserved_mb} MB reserved for host. Recommend at least 2GB."
    fi
    
    # Performance features
    echo
    echo "Performance Features:"
    
    # Hugepages
    local hugepages=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    if [[ $hugepages -gt 0 ]]; then
        echo "  - Hugepages: Enabled ($hugepages pages)"
    else
        echo "  - Hugepages: Disabled (consider enabling for better performance)"
    fi
    
    # CPU governor
    local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    case "$governor" in
        performance)
            echo "  - CPU Governor: performance (optimal for VMs)"
            ;;
        ondemand|schedutil)
            echo "  - CPU Governor: $governor (consider 'performance' for VMs)"
            ;;
        *)
            echo "  - CPU Governor: $governor"
            ;;
    esac
    
    # NUMA
    if [[ -d /sys/devices/system/node/node1 ]]; then
        echo "  - NUMA: Multi-node system detected (consider NUMA pinning)"
    fi
}

# Generate optimization script
generate_optimization_script() {
    local output_file="/var/lib/hypervisor/optimization_$(date +%Y%m%d_%H%M%S).sh"
    
    cat > "$output_file" << 'EOF'
#!/usr/bin/env bash
# VM Resource Optimization Script
# Generated: $(date)
set -euo pipefail

echo "Applying VM resource optimizations..."

# Example optimizations based on analysis
# Uncomment and modify as needed:

# 1. Adjust VM memory allocation
# virsh setmaxmem DOMAIN SIZE --config
# virsh setmem DOMAIN SIZE --config

# 2. Adjust VM CPU allocation
# virsh setvcpus DOMAIN COUNT --config

# 3. Enable CPU pinning for critical VMs
# virsh vcpupin DOMAIN VCPU CPULIST --config

# 4. Configure hugepages
# echo 1024 > /proc/sys/vm/nr_hugepages
# virsh edit DOMAIN
# Add: <memoryBacking><hugepages/></memoryBacking>

# 5. Set CPU governor to performance
# for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
#     echo performance > "$cpu"
# done

# 6. Apply systemd slice limits
# Update /var/lib/hypervisor/vm_profiles/DOMAIN.json with:
# "limits": {
#     "cpu_quota_percent": 200,
#     "memory_max_mb": 8192
# }

echo "Optimization script template generated."
echo "Edit and customize based on your analysis."
EOF
    
    chmod +x "$output_file"
    echo "$output_file"
}

# Interactive menu
menu() {
    while true; do
        choice=$($DIALOG --title "VM Resource Optimizer" --menu "Select an option:" 18 70 10 \
            "analyze_vm" "Analyze specific VM resources" \
            "analyze_all" "Analyze all VM resources" \
            "system" "System-wide resource analysis" \
            "optimize" "Generate optimization script" \
            "monitor" "Real-time resource monitor" \
            "help" "Optimization guidelines" \
            "exit" "Exit" \
            3>&1 1>&2 2>&3)
        
        case "$choice" in
            analyze_vm)
                # Select VM
                local entries=()
                while IFS= read -r domain; do
                    [[ -z "$domain" ]] && continue
                    entries+=("$domain" "$(virsh domstate "$domain" 2>/dev/null || echo "unknown")")
                done < <(virsh list --all --name)
                
                if [[ ${#entries[@]} -eq 0 ]]; then
                    $DIALOG --msgbox "No VMs found" 8 40
                    continue
                fi
                
                domain=$($DIALOG --menu "Select VM to analyze:" 20 60 12 "${entries[@]}" 3>&1 1>&2 2>&3) || continue
                
                out=$(mktemp)
                analyze_vm_resources "$domain" > "$out" 2>&1
                ${PAGER:-less} "$out"
                rm -f "$out"
                ;;
                
            analyze_all)
                out=$(mktemp)
                while IFS= read -r domain; do
                    [[ -z "$domain" ]] && continue
                    analyze_vm_resources "$domain" >> "$out" 2>&1
                    echo -e "\n---\n" >> "$out"
                done < <(virsh list --all --name)
                ${PAGER:-less} "$out"
                rm -f "$out"
                ;;
                
            system)
                out=$(mktemp)
                analyze_system_resources > "$out" 2>&1
                ${PAGER:-less} "$out"
                rm -f "$out"
                ;;
                
            optimize)
                script_file=$(generate_optimization_script)
                $DIALOG --msgbox "Optimization script generated:\n\n$script_file\n\nEdit this script to apply recommended optimizations." 12 70
                ;;
                
            monitor)
                $DIALOG --msgbox "Starting resource monitor...\nPress Ctrl+C to stop" 8 50
                watch -n 2 "virsh list --name | xargs -I {} sh -c 'echo === {} ===; virsh domstats {} --cpu-total --balloon --vcpu --interface --block'"
                ;;
                
            help)
                $DIALOG --msgbox "Resource Optimization Guidelines:

1. CPU Allocation:
   - Overcommit ratio 2:1 to 4:1 is typical
   - Pin critical VMs to specific CPUs
   - Use 'performance' CPU governor

2. Memory:
   - Reserve 2-4GB for host OS
   - Enable hugepages for large VMs
   - Monitor for memory pressure

3. Storage:
   - Use virtio-scsi for best performance
   - Consider cache='none' for databases
   - Monitor I/O wait times

4. Network:
   - Use virtio-net with vhost
   - Enable multiqueue for high traffic
   - Consider SR-IOV for critical VMs" 20 70
                ;;
                
            exit|"")
                break
                ;;
        esac
    done
}

# Main execution
menu