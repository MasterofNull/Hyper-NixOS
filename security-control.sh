#!/usr/bin/env bash
# Master Security Control Script
# Central command interface for all security operations

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load functions
source "$SCRIPT_DIR/scripts/automation/parallel-framework.sh" 2>/dev/null || true

# Main menu
show_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Security Framework Control Center${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo "1. Run Security Validation"
    echo "2. Deploy Security Stack"
    echo "3. Run Security Scan"
    echo "4. Update Security Tools"
    echo "5. Monitor SSH Logins"
    echo "6. Check System Status"
    echo "7. Generate Security Report"
    echo "8. Run Parallel Updates"
    echo "9. Configure Notifications"
    echo "10. View Documentation"
    echo "11. Incident Response Status"
    echo "12. View Security Events"
    echo "13. Test Incident Response"
    echo "0. Exit"
    echo
}

# Run security validation
run_validation() {
    echo -e "${YELLOW}Running security validation...${NC}"
    "$SCRIPT_DIR/defensive-validation.sh"
    echo
    read -p "Press Enter to continue..."
}

# Deploy security stack
deploy_stack() {
    echo -e "${YELLOW}Deploying security stack...${NC}"
    if [[ -x "$SCRIPT_DIR/scripts/tools/deploy-security-stack.sh" ]]; then
        "$SCRIPT_DIR/scripts/tools/deploy-security-stack.sh"
    else
        echo -e "${RED}Deployment script not found${NC}"
    fi
    echo
    read -p "Press Enter to continue..."
}

# Run security scan
run_scan() {
    echo -e "${YELLOW}Running comprehensive security scan...${NC}"
    if [[ -x "$SCRIPT_DIR/scripts/security/automated-security-scan.sh" ]]; then
        "$SCRIPT_DIR/scripts/security/automated-security-scan.sh"
    else
        echo -e "${RED}Security scan script not found${NC}"
    fi
    echo
    read -p "Press Enter to continue..."
}

# Update security tools
update_tools() {
    echo -e "${YELLOW}Updating security tools...${NC}"
    
    # Update git repositories
    if [[ -x "$SCRIPT_DIR/scripts/automation/parallel-git-update.sh" ]]; then
        "$SCRIPT_DIR/scripts/automation/parallel-git-update.sh"
    fi
    
    # Update Docker images
    echo -e "${YELLOW}Updating Docker security images...${NC}"
    docker_images=(
        "aquasec/trivy:latest"
        "prom/prometheus:latest"
        "grafana/grafana:latest"
        "prom/node-exporter:latest"
    )
    
    for image in "${docker_images[@]}"; do
        echo "Pulling $image..."
        docker pull "$image"
    done
    
    echo
    read -p "Press Enter to continue..."
}

# Monitor SSH logins
monitor_ssh() {
    echo -e "${YELLOW}SSH Login Monitor${NC}"
    echo
    
    # Show recent logins
    if [[ -f "/var/log/security/ssh-monitor.log" ]]; then
        echo "Recent SSH logins:"
        sudo tail -20 /var/log/security/ssh-monitor.log
    else
        echo "No SSH login history found."
    fi
    
    echo
    echo "Active SSH sessions:"
    who | grep -E 'pts/|tty'
    
    echo
    read -p "Press Enter to continue..."
}

# Check system status
check_status() {
    echo -e "${YELLOW}System Security Status${NC}"
    echo
    
    # Check services
    echo "Security Services:"
    for service in ssh-monitor docker prometheus grafana; do
        if systemctl is-active "$service" &>/dev/null; then
            echo -e "  $service: ${GREEN}active${NC}"
        else
            echo -e "  $service: ${RED}inactive${NC}"
        fi
    done
    
    echo
    echo "Docker Containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running"
    
    echo
    echo "Security Metrics:"
    echo "  Failed SSH attempts (last 24h): $(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l || echo "0")"
    echo "  Active connections: $(ss -tun | wc -l)"
    echo "  Firewall status: $(sudo ufw status 2>/dev/null | grep -o "Status: .*" || echo "Not configured")"
    
    echo
    read -p "Press Enter to continue..."
}

# Generate security report
generate_report() {
    echo -e "${YELLOW}Generating security report...${NC}"
    
    REPORT_FILE="security-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Security Report - $(date)"
        echo "======================================"
        echo
        
        echo "## System Information"
        uname -a
        echo
        
        echo "## Security Status"
        "$SCRIPT_DIR/defensive-validation.sh" 2>&1 | tail -20
        echo
        
        echo "## Recent Security Events"
        sudo grep -E "(Failed|Accepted)" /var/log/auth.log 2>/dev/null | tail -10 || echo "No auth logs available"
        echo
        
        echo "## Running Services"
        systemctl list-units --type=service --state=running | grep -E "(ssh|docker|security)"
        echo
        
        echo "## Network Connections"
        ss -tun | head -20
        
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}Report saved to: $REPORT_FILE${NC}"
    echo
    read -p "Press Enter to continue..."
}

# Run parallel updates
run_parallel_updates() {
    echo -e "${YELLOW}Running parallel updates...${NC}"
    
    # Example: Update multiple git repositories
    cat > /tmp/repos.txt << EOF
https://github.com/aquasecurity/trivy|/opt/tools/trivy
https://github.com/projectdiscovery/nuclei|/opt/tools/nuclei
https://github.com/OWASP/CheatSheetSeries|/opt/docs/owasp-cheatsheets
EOF
    
    if [[ -x "$SCRIPT_DIR/scripts/automation/parallel-git-update.sh" ]]; then
        "$SCRIPT_DIR/scripts/automation/parallel-git-update.sh" /tmp/repos.txt
    else
        echo -e "${RED}Parallel update script not found${NC}"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Configure notifications
configure_notifications() {
    echo -e "${YELLOW}Configure Notifications${NC}"
    echo
    
    CONFIG_DIR="$HOME/.config/security"
    CONFIG_FILE="$CONFIG_DIR/webhooks.conf"
    
    mkdir -p "$CONFIG_DIR"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Current configuration:"
        cat "$CONFIG_FILE"
        echo
    fi
    
    read -p "Enter webhook URL (or press Enter to skip): " webhook_url
    read -p "Enter security email (or press Enter to skip): " security_email
    
    if [[ -n "$webhook_url" ]] || [[ -n "$security_email" ]]; then
        {
            [[ -n "$webhook_url" ]] && echo "WEBHOOK_URL=\"$webhook_url\""
            [[ -n "$security_email" ]] && echo "SECURITY_EMAIL=\"$security_email\""
        } > "$CONFIG_FILE"
        
        echo -e "${GREEN}Configuration saved${NC}"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# View documentation
view_docs() {
    echo -e "${YELLOW}Available Documentation${NC}"
    echo
    echo "1. Deployment Guide"
    echo "2. Security Tips & Tricks"
    echo "3. Integration Guide"
    echo "4. Quick Start Guide"
    echo "5. AI Development Best Practices"
    echo "0. Back to main menu"
    echo
    
    read -p "Select document: " doc_choice
    
    case $doc_choice in
        1) less "$SCRIPT_DIR/DEPLOYMENT-GUIDE.md" ;;
        2) less "$SCRIPT_DIR/Security-Tips-Tricks-Documentation.md" ;;
        3) less "$SCRIPT_DIR/ADVANCED-PATTERNS-INTEGRATION-GUIDE.md" ;;
        4) less "$SCRIPT_DIR/SECURITY-QUICKSTART.md" ;;
        5) less "$SCRIPT_DIR/AI-Development-Best-Practices.md" ;;
        *) return ;;
    esac
}

# Incident Response Status
ir_status() {
    echo -e "${YELLOW}Incident Response Status${NC}"
    echo
    
    # Check if service is running
    if systemctl is-active --quiet security-monitor 2>/dev/null; then
        echo -e "${GREEN}✓ Security Monitor: Active${NC}"
        echo
        systemctl status security-monitor --no-pager | head -15
    else
        echo -e "${RED}✗ Security Monitor: Inactive${NC}"
        echo
        echo "Start with: ir-start or systemctl start security-monitor"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# View Security Events
ir_events() {
    echo -e "${YELLOW}Recent Security Events${NC}"
    echo
    
    local events_file="/var/log/security/events.json"
    if [[ -f "$events_file" ]]; then
        # Show last 20 events
        tail -n 20 "$events_file" 2>/dev/null | while read line; do
            echo "$line" | jq -r '"\(.timestamp) [\(.type)] \(.source_ip // "N/A") -> \(.target_ip // "localhost")"' 2>/dev/null || echo "$line"
        done
    else
        echo "No events logged yet"
    fi
    
    echo
    echo "Full event log: $events_file"
    echo
    read -p "Press Enter to continue..."
}

# Test Incident Response Menu
ir_test_menu() {
    echo -e "${YELLOW}Test Incident Response${NC}"
    echo
    echo "1. Test All Playbooks"
    echo "2. Test Brute Force Response"
    echo "3. Test Port Scan Response"
    echo "4. Test Malware Response"
    echo "5. Test Container Compromise"
    echo "6. Trigger Custom Event"
    echo "0. Back to main menu"
    echo
    
    read -p "Select test: " test_choice
    
    case $test_choice in
        1) 
            if [[ -x "$SCRIPT_DIR/scripts/security/test-incident-response.py" ]]; then
                sudo python3 "$SCRIPT_DIR/scripts/security/test-incident-response.py"
            else
                echo -e "${RED}Test script not found${NC}"
            fi
            ;;
        2) 
            sudo python3 "$SCRIPT_DIR/scripts/security/test-incident-response.py" brute_force
            ;;
        3) 
            sudo python3 "$SCRIPT_DIR/scripts/security/test-incident-response.py" port_scan
            ;;
        4) 
            sudo python3 "$SCRIPT_DIR/scripts/security/test-incident-response.py" malware
            ;;
        5) 
            sudo python3 "$SCRIPT_DIR/scripts/security/test-incident-response.py" container
            ;;
        6)
            read -p "Event type (brute_force/port_scan/malware/container_compromise): " event_type
            read -p "Source IP (default: 10.10.10.10): " source_ip
            source_ip=${source_ip:-"10.10.10.10"}
            
            python3 -c "
import asyncio
import sys
sys.path.append('$SCRIPT_DIR/scripts/security')
from playbook_executor import PlaybookExecutor, SecurityEvent

async def trigger():
    event = SecurityEvent(
        event_type='$event_type',
        source_ip='$source_ip',
        details={'manual_trigger': True}
    )
    
    executor = PlaybookExecutor()
    playbook = executor.match_event_to_playbook(event)
    if playbook:
        await executor.execute_playbook(playbook, event)
        print(f'Executed playbook: {playbook}')
    else:
        print(f'No playbook found for event type: $event_type')

asyncio.run(trigger())
"
            ;;
        *) return ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) run_validation ;;
            2) deploy_stack ;;
            3) run_scan ;;
            4) update_tools ;;
            5) monitor_ssh ;;
            6) check_status ;;
            7) generate_report ;;
            8) run_parallel_updates ;;
            9) configure_notifications ;;
            10) view_docs ;;
            11) ir_status ;;
            12) ir_events ;;
            13) ir_test_menu ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Check if running with arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        validate) run_validation ;;
        deploy) deploy_stack ;;
        scan) run_scan ;;
        update) update_tools ;;
        status) check_status ;;
        report) generate_report ;;
        help) 
            echo "Usage: $0 [command]"
            echo "Commands:"
            echo "  validate  - Run security validation"
            echo "  deploy    - Deploy security stack"
            echo "  scan      - Run security scan"
            echo "  update    - Update security tools"
            echo "  status    - Check system status"
            echo "  report    - Generate security report"
            echo "  help      - Show this help"
            echo
            echo "Run without arguments for interactive menu"
            ;;
        *) echo "Unknown command: $1"; exit 1 ;;
    esac
else
    # Run interactive menu
    main
fi