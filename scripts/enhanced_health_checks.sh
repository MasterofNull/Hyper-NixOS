#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; }
info() { printf "[INFO] %s\n" "$1"; }

# Enhanced health checks with more detail
comprehensive_checks() {
    local errors=0
    local warnings=0
    
    echo "=== Hypervisor Health Check Report ==="
    echo "Date: $(date -Is)"
    echo
    
    # System checks
    echo "## System Status"
    
    # CPU check
    local cpu_usage=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.1f", 100*(u-u1)/(t-t1); }' \
        <(grep 'cpu ' /proc/stat; sleep 1; grep 'cpu ' /proc/stat))
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        fail "CPU usage critical: ${cpu_usage}%"
        ((errors++))
    elif (( $(echo "$cpu_usage > 75" | bc -l) )); then
        warn "CPU usage high: ${cpu_usage}%"
        ((warnings++))
    else
        ok "CPU usage normal: ${cpu_usage}%"
    fi
    
    # Memory check
    local mem_info=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    if (( $(echo "$mem_info > 90" | bc -l) )); then
        fail "Memory usage critical: ${mem_info}%"
        ((errors++))
    elif (( $(echo "$mem_info > 80" | bc -l) )); then
        warn "Memory usage high: ${mem_info}%"
        ((warnings++))
    else
        ok "Memory usage normal: ${mem_info}%"
    fi
    
    # Disk space check
    echo
    echo "## Storage Status"
    while read -r line; do
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mount=$(echo "$line" | awk '{print $6}')
        if [[ $usage -gt 90 ]]; then
            fail "Disk space critical on $mount: ${usage}%"
            ((errors++))
        elif [[ $usage -gt 80 ]]; then
            warn "Disk space low on $mount: ${usage}%"
            ((warnings++))
        else
            ok "Disk space adequate on $mount: ${usage}%"
        fi
    done < <(df -h /var/lib/hypervisor /boot /nix/store 2>/dev/null | grep -v '^Filesystem')
    
    # Service checks
    echo
    echo "## Service Status"
    
    # Critical services
    for service in libvirtd sshd auditd apparmor; do
        if systemctl is-active --quiet "$service"; then
            ok "$service is active"
        else
            fail "$service is not active"
            ((errors++))
        fi
    done
    
    # Optional services
    for service in firewalld nftables; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            ok "$service is active"
        else
            info "$service is not active (optional)"
        fi
    done
    
    # Network checks
    echo
    echo "## Network Status"
    
    # Check bridges
    local bridge_count=0
    for br in $(jq -r '.network_zones[]?.bridge // empty' /etc/hypervisor/config.json 2>/dev/null); do
        if ip link show "$br" >/dev/null 2>&1; then
            ok "Bridge $br exists"
            ((bridge_count++))
        else
            warn "Bridge $br missing"
            ((warnings++))
        fi
    done
    
    if [[ $bridge_count -eq 0 ]]; then
        warn "No network bridges configured"
        ((warnings++))
    fi
    
    # VM checks
    echo
    echo "## Virtual Machine Status"
    
    local total_vms=0
    local running_vms=0
    local failed_vms=0
    
    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        ((total_vms++))
        
        local state=$(virsh domstate "$domain" 2>/dev/null || echo "error")
        case "$state" in
            running)
                ok "VM '$domain' is running"
                ((running_vms++))
                
                # Check VM resource usage
                local vm_cpu=$(virsh cpu-stats "$domain" --total 2>/dev/null | awk '/cpu_time/ {print $2}' || echo "N/A")
                local vm_mem=$(virsh dommemstat "$domain" 2>/dev/null | awk '/actual/ {print $2}' || echo "N/A")
                info "  CPU time: $vm_cpu, Memory: $vm_mem KB"
                ;;
            "shut off"|paused|idle)
                info "VM '$domain' is $state"
                ;;
            *)
                fail "VM '$domain' is in error state: $state"
                ((failed_vms++))
                ((errors++))
                ;;
        esac
    done < <(virsh list --all --name)
    
    echo
    info "Total VMs: $total_vms, Running: $running_vms, Failed: $failed_vms"
    
    # Security checks
    echo
    echo "## Security Status"
    
    # AppArmor profiles
    if command -v aa-status >/dev/null 2>&1; then
        local aa_profiles=$(aa-status --profiled 2>/dev/null | grep -o '[0-9]*' | head -1 || echo "0")
        if [[ $aa_profiles -gt 0 ]]; then
            ok "AppArmor active with $aa_profiles profiles"
        else
            warn "AppArmor active but no profiles loaded"
            ((warnings++))
        fi
    else
        fail "AppArmor not available"
        ((errors++))
    fi
    
    # Check for security updates
    if command -v nix >/dev/null 2>&1; then
        info "Checking for system updates..."
        # This is a simplified check - in practice you'd want more sophisticated update checking
        if nix flake metadata /etc/nixos 2>&1 | grep -q "Last modified.*days ago"; then
            warn "System configuration may be outdated"
            ((warnings++))
        fi
    fi
    
    # File permissions check
    echo
    echo "## File Permissions"
    
    # Check critical directories
    for dir in /var/lib/hypervisor /etc/hypervisor/src/modules; do
        if [[ -d "$dir" ]]; then
            local perms=$(stat -c %a "$dir")
            if [[ "$perms" =~ ^7[0-5][0-5]$ ]]; then
                ok "$dir permissions: $perms"
            else
                warn "$dir permissions may be too permissive: $perms"
                ((warnings++))
            fi
        fi
    done
    
    # Performance metrics
    echo
    echo "## Performance Metrics"
    
    # IOMMU groups (for VFIO)
    if [[ -d /sys/kernel/iommu_groups/ ]]; then
        local iommu_groups=$(find /sys/kernel/iommu_groups/ -maxdepth 1 -type d | wc -l)
        ok "IOMMU enabled with $((iommu_groups-1)) groups"
    else
        info "IOMMU not enabled (required for VFIO)"
    fi
    
    # Hugepages
    local hugepages=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    if [[ $hugepages -gt 0 ]]; then
        ok "Hugepages configured: $hugepages"
    else
        info "Hugepages not configured (optional performance feature)"
    fi
    
    # Summary
    echo
    echo "## Summary"
    echo "Errors: $errors"
    echo "Warnings: $warnings"
    echo
    
    if [[ $errors -gt 0 ]]; then
        fail "System has critical issues that need attention"
        return 1
    elif [[ $warnings -gt 0 ]]; then
        warn "System has warnings that should be reviewed"
        return 0
    else
        ok "All checks passed successfully"
        return 0
    fi
}

# Interactive menu
menu() {
    while true; do
        choice=$($DIALOG --title "Enhanced Health Checks" --menu "Select an option:" 15 60 7 \
            "full" "Run comprehensive health check" \
            "quick" "Quick system status" \
            "export" "Export report to file" \
            "monitor" "Continuous monitoring mode" \
            "fix" "Attempt to fix common issues" \
            "exit" "Exit" \
            3>&1 1>&2 2>&3)
        
        case "$choice" in
            full)
                out=$(mktemp)
                comprehensive_checks > "$out" 2>&1
                ${PAGER:-less} -R "$out"
                rm -f "$out"
                ;;
            quick)
                $DIALOG --msgbox "$(
                    echo "Quick Status:"
                    echo "CPU: $(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.1f%%", 100*(u-u1)/(t-t1); }' <(grep 'cpu ' /proc/stat; sleep 1; grep 'cpu ' /proc/stat))"
                    echo "Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
                    echo "Disk: $(df -h /var/lib/hypervisor | awk 'NR==2{print $5}')"
                    echo "VMs Running: $(virsh list --name | grep -v '^$' | wc -l)"
                    echo "Uptime: $(uptime -p)"
                )" 12 50
                ;;
            export)
                report_file="/var/lib/hypervisor/logs/health_report_$(date +%Y%m%d_%H%M%S).log"
                comprehensive_checks > "$report_file" 2>&1
                $DIALOG --msgbox "Report saved to:\n$report_file" 8 60
                ;;
            monitor)
                $DIALOG --msgbox "Starting continuous monitoring...\nPress Ctrl+C to stop" 8 50
                watch -n 5 -d "$(readlink -f "$0") --quick-status"
                ;;
            fix)
                $DIALOG --yesno "Attempt to fix common issues?\n\nThis will:\n- Restart failed services\n- Create missing directories\n- Fix file permissions" 12 50
                if [[ $? -eq 0 ]]; then
                    fix_common_issues
                fi
                ;;
            exit|"")
                break
                ;;
        esac
    done
}

# Quick status for monitoring mode
quick_status() {
    clear
    echo "=== Hypervisor Quick Status - $(date) ==="
    echo
    printf "CPU Usage: %.1f%%\n" "$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.1f", 100*(u-u1)/(t-t1); }' <(grep 'cpu ' /proc/stat; sleep 1; grep 'cpu ' /proc/stat))"
    printf "Memory: %s\n" "$(free -h | awk 'NR==2{printf "%s/%s (%.1f%%)", $3, $2, $3*100/$2}')"
    printf "Load Average: %s\n" "$(uptime | awk -F'load average:' '{print $2}')"
    echo
    echo "Services:"
    for svc in libvirtd sshd auditd; do
        printf "  %-12s %s\n" "$svc:" "$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")"
    done
    echo
    echo "VMs: $(virsh list --name | grep -v '^$' | wc -l) running / $(virsh list --all --name | grep -v '^$' | wc -l) total"
}

# Function to fix common issues
fix_common_issues() {
    echo "Attempting to fix common issues..."
    
    # Restart failed critical services
    for service in libvirtd sshd auditd; do
        if ! systemctl is-active --quiet "$service"; then
            echo "Restarting $service..."
            sudo systemctl restart "$service"
        fi
    done
    
    # Create missing directories
    for dir in /var/lib/hypervisor/{logs,disks,xml,vm-profiles,isos,backups}; do
        if [[ ! -d "$dir" ]]; then
            echo "Creating missing directory: $dir"
            sudo mkdir -p "$dir"
            sudo chown hypervisor:hypervisor "$dir"
            sudo chmod 750 "$dir"
        fi
    done
    
    # Fix permissions
    sudo chmod 750 /var/lib/hypervisor
    sudo chmod 700 /var/lib/hypervisor/gnupg 2>/dev/null || true
    
    echo "Fix attempt completed. Please run health check again."
}

# Main execution
case "${1:-}" in
    --quick-status)
        quick_status
        ;;
    --check)
        comprehensive_checks
        ;;
    *)
        menu
        ;;
esac