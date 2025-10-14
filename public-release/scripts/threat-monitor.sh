#!/usr/bin/env bash
#
# Real-time Threat Monitoring Dashboard
# Provides live view of threats, sensors, and system security status
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Terminal setup
readonly TERM_COLS=$(tput cols)
readonly TERM_LINES=$(tput lines)

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Unicode characters
readonly CHECK="✓"
readonly CROSS="✗"
readonly WARNING="⚠"
readonly ARROW="→"
readonly DOT="•"

# Global state
THREATS_ACTIVE=0
THREATS_TOTAL=0
ALERTS_QUEUE=()
SENSOR_STATUS=()
UPDATE_INTERVAL=1

# Initialize screen
init_screen() {
    clear
    tput civis  # Hide cursor
    stty -echo  # Disable echo
}

# Cleanup on exit
cleanup() {
    tput cnorm  # Show cursor
    stty echo   # Enable echo
    clear
}
trap cleanup EXIT

# Draw header
draw_header() {
    local time=$(date '+%Y-%m-%d %H:%M:%S')
    tput cup 0 0
    echo -ne "${BOLD}${WHITE}"
    printf "%-*s" "$TERM_COLS" "Hyper-NixOS Threat Monitor - $time"
    echo -ne "${NC}"
}

# Draw threat summary box
draw_threat_summary() {
    local row=2
    tput cup $row 0
    
    echo -e "${BOLD}═══ Threat Summary ═══${NC}"
    row=$((row + 1))
    
    # Active threats
    tput cup $row 0
    if [[ $THREATS_ACTIVE -eq 0 ]]; then
        echo -e "${GREEN}${CHECK} No Active Threats${NC}"
    else
        echo -e "${RED}${WARNING} Active Threats: $THREATS_ACTIVE${NC}"
    fi
    row=$((row + 1))
    
    # Total threats today
    tput cup $row 0
    echo -e "Total Threats (24h): ${YELLOW}$THREATS_TOTAL${NC}"
    row=$((row + 1))
    
    # Security posture
    local posture="SECURE"
    local posture_color="$GREEN"
    if [[ $THREATS_ACTIVE -gt 0 ]]; then
        posture="AT RISK"
        posture_color="$RED"
    elif [[ $THREATS_TOTAL -gt 10 ]]; then
        posture="ELEVATED"
        posture_color="$YELLOW"
    fi
    
    tput cup $row 0
    echo -e "Security Posture: ${posture_color}${BOLD}$posture${NC}"
}

# Draw sensor status
draw_sensor_status() {
    local row=8
    tput cup $row 0
    echo -e "${BOLD}═══ Sensor Status ═══${NC}"
    row=$((row + 1))
    
    # Define sensors
    local sensors=(
        "Network Monitor:network:active"
        "System Monitor:system:active"
        "File Integrity:files:active"
        "VM Monitor:vms:active"
        "Memory Analysis:memory:active"
        "ML Engine:ml:starting"
    )
    
    for sensor in "${sensors[@]}"; do
        IFS=':' read -r name id status <<< "$sensor"
        tput cup $row 0
        
        case "$status" in
            active)
                echo -e "${GREEN}${CHECK}${NC} $name"
                ;;
            starting)
                echo -e "${YELLOW}◐${NC} $name"
                ;;
            error)
                echo -e "${RED}${CROSS}${NC} $name"
                ;;
        esac
        row=$((row + 1))
    done
}

# Draw recent alerts
draw_alerts() {
    local row=17
    local max_alerts=8
    
    tput cup $row 0
    echo -e "${BOLD}═══ Recent Alerts ═══${NC}"
    row=$((row + 1))
    
    # Show recent alerts
    local alert_count=${#ALERTS_QUEUE[@]}
    local start_idx=0
    
    if [[ $alert_count -gt $max_alerts ]]; then
        start_idx=$((alert_count - max_alerts))
    fi
    
    if [[ $alert_count -eq 0 ]]; then
        tput cup $row 0
        echo -e "${DIM}No recent alerts${NC}"
    else
        for ((i=start_idx; i<alert_count; i++)); do
            local alert="${ALERTS_QUEUE[$i]}"
            tput cup $row 0
            
            # Parse alert format: TIME|SEVERITY|MESSAGE
            IFS='|' read -r time severity message <<< "$alert"
            
            # Color based on severity
            case "$severity" in
                CRITICAL)
                    echo -e "${RED}$time [$severity] $message${NC}"
                    ;;
                HIGH)
                    echo -e "${YELLOW}$time [$severity] $message${NC}"
                    ;;
                MEDIUM)
                    echo -e "${BLUE}$time [$severity] $message${NC}"
                    ;;
                *)
                    echo -e "${DIM}$time [$severity] $message${NC}"
                    ;;
            esac
            
            row=$((row + 1))
            if [[ $row -ge $((TERM_LINES - 5)) ]]; then
                break
            fi
        done
    fi
}

# Draw real-time metrics
draw_metrics() {
    local col=$((TERM_COLS / 2 + 5))
    local row=8
    
    tput cup $row $col
    echo -e "${BOLD}═══ Live Metrics ═══${NC}"
    row=$((row + 1))
    
    # Network traffic
    local net_in=$(cat /proc/net/dev | grep -E "eth0|ens" | awk '{print $2}' | head -1)
    local net_out=$(cat /proc/net/dev | grep -E "eth0|ens" | awk '{print $10}' | head -1)
    tput cup $row $col
    echo -e "Network In:  ${CYAN}$(numfmt --to=iec $net_in)/s${NC}"
    row=$((row + 1))
    
    tput cup $row $col
    echo -e "Network Out: ${CYAN}$(numfmt --to=iec $net_out)/s${NC}"
    row=$((row + 1))
    
    # System load
    local load=$(uptime | awk -F'load average:' '{print $2}')
    tput cup $row $col
    echo -e "Load Average:${YELLOW}$load${NC}"
    row=$((row + 1))
    
    # Active connections
    local connections=$(ss -s | grep estab | awk '{print $2}')
    tput cup $row $col
    echo -e "Connections: ${GREEN}$connections${NC}"
    row=$((row + 1))
    
    # VM count
    local vm_count=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l)
    tput cup $row $col
    echo -e "Active VMs:  ${BLUE}$vm_count${NC}"
}

# Draw threat indicators
draw_threat_indicators() {
    local col=$((TERM_COLS / 2 + 5))
    local row=15
    
    tput cup $row $col
    echo -e "${BOLD}═══ Threat Indicators ═══${NC}"
    row=$((row + 1))
    
    # Check various threat indicators
    local indicators=(
        "Port Scan:$(check_port_scan):medium"
        "Brute Force:$(check_brute_force):high"
        "VM Escape:$(check_vm_escape):critical"
        "Crypto Mining:$(check_crypto_mining):medium"
        "Data Exfil:$(check_data_exfil):high"
        "Privilege Esc:$(check_priv_esc):high"
    )
    
    for indicator in "${indicators[@]}"; do
        IFS=':' read -r name detected severity <<< "$indicator"
        tput cup $row $col
        
        if [[ "$detected" == "true" ]]; then
            case "$severity" in
                critical)
                    echo -e "${RED}${WARNING} $name DETECTED${NC}"
                    ;;
                high)
                    echo -e "${YELLOW}${WARNING} $name detected${NC}"
                    ;;
                *)
                    echo -e "${BLUE}${DOT} $name activity${NC}"
                    ;;
            esac
        else
            echo -e "${GREEN}${CHECK} $name${NC}"
        fi
        row=$((row + 1))
    done
}

# Check functions for threat indicators
check_port_scan() {
    # Check for port scanning in logs
    local scan_count=$(journalctl -u hypervisor-threat-detector --since "5 minutes ago" 2>/dev/null | grep -c "PORT-SCAN" || echo "0")
    [[ $scan_count -gt 5 ]] && echo "true" || echo "false"
}

check_brute_force() {
    # Check for failed auth attempts
    local failed_auth=$(journalctl -u sshd --since "5 minutes ago" 2>/dev/null | grep -c "Failed password" || echo "0")
    [[ $failed_auth -gt 10 ]] && echo "true" || echo "false"
}

check_vm_escape() {
    # Check for VM escape attempts
    local escape_attempts=$(journalctl -u libvirtd --since "5 minutes ago" 2>/dev/null | grep -c -E "VMEXIT|hypervisor.*violation" || echo "0")
    [[ $escape_attempts -gt 0 ]] && echo "true" || echo "false"
}

check_crypto_mining() {
    # Check for crypto mining indicators
    local high_cpu_vms=$(virsh list --name 2>/dev/null | xargs -I {} sh -c 'virsh domstats {} --cpu-total 2>/dev/null | grep cpu.time' | awk '{if($2>90) print}' | wc -l)
    [[ $high_cpu_vms -gt 2 ]] && echo "true" || echo "false"
}

check_data_exfil() {
    # Check for unusual data transfer
    local high_transfer=$(netstat -i 2>/dev/null | awk '{if(NR>2 && $4>1000000000) print}' | wc -l)
    [[ $high_transfer -gt 0 ]] && echo "true" || echo "false"
}

check_priv_esc() {
    # Check for privilege escalation
    local sudo_abuse=$(journalctl --since "5 minutes ago" 2>/dev/null | grep -c "sudo.*COMMAND" || echo "0")
    [[ $sudo_abuse -gt 20 ]] && echo "true" || echo "false"
}

# Generate mock alerts for demo
generate_mock_alert() {
    local severities=("INFO" "MEDIUM" "HIGH" "CRITICAL")
    local messages=(
        "Unusual network activity from VM 'webserver'"
        "Failed SSH login attempts from 192.168.1.100"
        "High CPU usage detected on VM 'database'"
        "Potential port scan detected from external IP"
        "New VM 'test-vm' started by user 'alice'"
        "Suspicious process detected in VM 'app-server'"
        "Unexpected outbound connection to unknown IP"
        "File integrity check passed for system files"
    )
    
    local severity="${severities[$((RANDOM % ${#severities[@]}))]}"
    local message="${messages[$((RANDOM % ${#messages[@]}))]}"
    local time=$(date '+%H:%M:%S')
    
    ALERTS_QUEUE+=("$time|$severity|$message")
    
    # Update threat counts
    if [[ "$severity" == "HIGH" ]] || [[ "$severity" == "CRITICAL" ]]; then
        THREATS_ACTIVE=$((THREATS_ACTIVE + 1))
    fi
    THREATS_TOTAL=$((THREATS_TOTAL + 1))
    
    # Keep queue size manageable
    if [[ ${#ALERTS_QUEUE[@]} -gt 100 ]]; then
        ALERTS_QUEUE=("${ALERTS_QUEUE[@]:1}")
    fi
}

# Draw footer with controls
draw_footer() {
    local row=$((TERM_LINES - 2))
    tput cup $row 0
    
    echo -ne "${DIM}"
    printf "%-*s" "$TERM_COLS" "[Q]uit | [P]ause | [C]lear Alerts | [D]etails | [R]esponse Mode | [H]elp"
    echo -ne "${NC}"
}

# Handle user input
handle_input() {
    read -t 0.1 -n 1 key || true
    
    case "$key" in
        q|Q)
            cleanup
            exit 0
            ;;
        p|P)
            read -p "Paused. Press Enter to continue..." -n 1
            ;;
        c|C)
            ALERTS_QUEUE=()
            THREATS_ACTIVE=0
            ;;
        d|D)
            show_threat_details
            ;;
        r|R)
            show_response_options
            ;;
        h|H)
            show_help
            ;;
    esac
}

# Show detailed threat information
show_threat_details() {
    clear
    echo -e "${BOLD}Threat Details${NC}"
    echo "═══════════════════════════════════════════"
    
    if [[ ${#ALERTS_QUEUE[@]} -eq 0 ]]; then
        echo "No threats to display"
    else
        # Show last 20 alerts with details
        local start=$((${#ALERTS_QUEUE[@]} - 20))
        [[ $start -lt 0 ]] && start=0
        
        for ((i=start; i<${#ALERTS_QUEUE[@]}; i++)); do
            IFS='|' read -r time severity message <<< "${ALERTS_QUEUE[$i]}"
            echo
            echo "Time: $time"
            echo "Severity: $severity"
            echo "Alert: $message"
            echo "─────────────────────────────"
        done
    fi
    
    echo
    read -p "Press Enter to return to monitor..." -n 1
}

# Show response options
show_response_options() {
    clear
    echo -e "${BOLD}Automated Response Options${NC}"
    echo "═══════════════════════════════════════════"
    echo
    echo "1) Isolate affected VM"
    echo "2) Block suspicious IP"
    echo "3) Enable enhanced monitoring"
    echo "4) Snapshot all VMs"
    echo "5) Generate forensic report"
    echo "6) Return to monitor"
    echo
    read -p "Select option (1-6): " option
    
    case "$option" in
        1) echo "Isolating VM..." ;;
        2) echo "Blocking IP..." ;;
        3) echo "Enabling enhanced monitoring..." ;;
        4) echo "Creating snapshots..." ;;
        5) echo "Generating report..." ;;
    esac
    
    [[ "$option" != "6" ]] && read -p "Press Enter to continue..." -n 1
}

# Show help
show_help() {
    clear
    echo -e "${BOLD}Threat Monitor Help${NC}"
    echo "═══════════════════════════════════════════"
    echo
    echo "This dashboard shows real-time threat information:"
    echo
    echo "• Threat Summary: Overall security status"
    echo "• Sensor Status: Health of detection systems"
    echo "• Recent Alerts: Latest security events"
    echo "• Live Metrics: System performance data"
    echo "• Threat Indicators: Specific threat detection"
    echo
    echo "Keyboard Controls:"
    echo "  Q - Quit monitor"
    echo "  P - Pause updates"
    echo "  C - Clear alert queue"
    echo "  D - Show threat details"
    echo "  R - Response options"
    echo "  H - This help screen"
    echo
    read -p "Press Enter to return to monitor..." -n 1
}

# Main monitoring loop
main_loop() {
    local counter=0
    
    while true; do
        # Draw all components
        draw_header
        draw_threat_summary
        draw_sensor_status
        draw_alerts
        draw_metrics
        draw_threat_indicators
        draw_footer
        
        # Generate mock alert occasionally (for demo)
        if [[ $((counter % 10)) -eq 0 ]]; then
            [[ $((RANDOM % 100)) -lt 30 ]] && generate_mock_alert
        fi
        
        # Handle user input
        handle_input
        
        # Update counter
        counter=$((counter + 1))
        
        # Decay active threats
        if [[ $((counter % 60)) -eq 0 ]] && [[ $THREATS_ACTIVE -gt 0 ]]; then
            THREATS_ACTIVE=$((THREATS_ACTIVE - 1))
        fi
        
        sleep $UPDATE_INTERVAL
    done
}

# Main execution
main() {
    init_screen
    
    # Check if threat detection is enabled
    if ! systemctl is-active hypervisor-threat-detector &>/dev/null; then
        echo -e "${YELLOW}Warning: Threat detection service is not running${NC}"
        echo "Start it with: sudo systemctl start hypervisor-threat-detector"
        echo
        read -p "Continue anyway? (y/N): " continue
        [[ "$continue" != "y" ]] && exit 0
    fi
    
    main_loop
}

main "$@"