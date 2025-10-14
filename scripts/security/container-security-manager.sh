#!/bin/bash
# Container Security Manager
# Comprehensive container security management interface

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="$SCRIPT_DIR/policies"
SCAN_RESULTS="/var/log/security/container-scans"

# Function to list running containers
list_containers() {
    echo -e "${BLUE}Running Containers:${NC}"
    echo
    
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" | while IFS= read -r line; do
        if [[ "$line" == CONTAINER* ]]; then
            echo -e "${YELLOW}$line${NC}"
        else
            echo "$line"
        fi
    done
}

# Function to scan a specific container
scan_container() {
    local container="$1"
    
    if [[ -z "$container" ]]; then
        list_containers
        echo
        read -p "Enter container ID or name: " container
    fi
    
    echo -e "${YELLOW}Scanning container: $container${NC}"
    python3 "$SCRIPT_DIR/container-security-automation.py" scan --container "$container"
}

# Function to scan all containers
scan_all_containers() {
    echo -e "${YELLOW}Scanning all running containers...${NC}"
    
    local container_ids=$(docker ps -q)
    local total=$(echo "$container_ids" | wc -l)
    local current=0
    
    for container_id in $container_ids; do
        ((current++))
        echo
        echo -e "${BLUE}[$current/$total] Scanning container $container_id${NC}"
        python3 "$SCRIPT_DIR/container-security-automation.py" scan --container "$container_id" 2>&1 | tee -a "$SCAN_RESULTS/batch_scan_$(date +%Y%m%d_%H%M%S).log"
    done
    
    echo
    echo -e "${GREEN}Batch scan complete!${NC}"
}

# Function to start monitoring
start_monitoring() {
    local policy_file=""
    
    echo -e "${BLUE}Available policies:${NC}"
    ls -1 "$POLICIES_DIR"/*.yaml 2>/dev/null | while read -r policy; do
        basename "$policy"
    done
    
    echo
    read -p "Select policy file (or press Enter for no enforcement): " policy_name
    
    if [[ -n "$policy_name" ]]; then
        policy_file="$POLICIES_DIR/$policy_name"
        
        if [[ ! -f "$policy_file" ]]; then
            echo -e "${RED}Policy file not found: $policy_file${NC}"
            return 1
        fi
    fi
    
    echo -e "${YELLOW}Starting container security monitoring...${NC}"
    
    # Create systemd service if not exists
    if [[ ! -f /etc/systemd/system/container-security-monitor.service ]]; then
        create_monitor_service "$policy_file"
    fi
    
    sudo systemctl start container-security-monitor
    sudo systemctl enable container-security-monitor
    
    echo -e "${GREEN}Monitoring started!${NC}"
    echo "View logs: sudo journalctl -u container-security-monitor -f"
}

# Function to stop monitoring
stop_monitoring() {
    echo -e "${YELLOW}Stopping container security monitoring...${NC}"
    sudo systemctl stop container-security-monitor
    echo -e "${GREEN}Monitoring stopped!${NC}"
}

# Function to create monitoring service
create_monitor_service() {
    local policy_file="$1"
    local policy_args=""
    
    if [[ -n "$policy_file" ]]; then
        policy_args="--policy $policy_file"
    fi
    
    cat > /tmp/container-security-monitor.service << EOF
[Unit]
Description=Container Security Monitor
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $SCRIPT_DIR/container-security-automation.py monitor $policy_args
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo mv /tmp/container-security-monitor.service /etc/systemd/system/
    sudo systemctl daemon-reload
}

# Function to show recent scan results
show_scan_results() {
    echo -e "${BLUE}Recent Container Scan Results:${NC}"
    echo
    
    if [[ ! -d "$SCAN_RESULTS" ]]; then
        echo "No scan results found"
        return
    fi
    
    # Show last 10 scan results
    ls -lt "$SCAN_RESULTS"/*.json 2>/dev/null | head -10 | while read -r line; do
        file=$(echo "$line" | awk '{print $NF}')
        
        if [[ -f "$file" ]]; then
            container_name=$(jq -r '.container_name' "$file" 2>/dev/null)
            risk_score=$(jq -r '.risk_score' "$file" 2>/dev/null)
            findings_count=$(jq -r '.findings_count' "$file" 2>/dev/null)
            timestamp=$(jq -r '.timestamp' "$file" 2>/dev/null)
            
            # Format timestamp
            date_str=$(date -d "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$timestamp")
            
            # Color based on risk score
            if [[ $risk_score -ge 75 ]]; then
                risk_color="${RED}"
            elif [[ $risk_score -ge 50 ]]; then
                risk_color="${YELLOW}"
            else
                risk_color="${GREEN}"
            fi
            
            echo -e "  $date_str | $container_name | Risk: ${risk_color}$risk_score${NC}/100 | Findings: $findings_count"
        fi
    done
    
    echo
    echo -e "${YELLOW}Full reports in: $SCAN_RESULTS${NC}"
}

# Function to generate security report
generate_report() {
    echo -e "${YELLOW}Generating container security report...${NC}"
    
    local report_file="/tmp/container-security-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Container Security Report"
        echo "Generated: $(date)"
        echo "========================"
        echo
        
        echo "Running Containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        echo
        
        echo "Recent High Risk Containers:"
        if [[ -d "$SCAN_RESULTS" ]]; then
            find "$SCAN_RESULTS" -name "*.json" -mtime -7 -exec jq -r 'select(.risk_score >= 75) | "\(.container_name)\t\(.risk_score)\t\(.timestamp)"' {} \; 2>/dev/null | sort -k2 -nr | head -10
        fi
        echo
        
        echo "Container Security Best Practices:"
        echo "1. Run containers as non-root user"
        echo "2. Limit container capabilities"
        echo "3. Use read-only root filesystem when possible"
        echo "4. Set resource limits (memory, CPU)"
        echo "5. Scan images for vulnerabilities regularly"
        echo "6. Use minimal base images"
        echo "7. Don't mount sensitive host paths"
        echo "8. Use security profiles (AppArmor, SELinux, seccomp)"
        
    } > "$report_file"
    
    echo -e "${GREEN}Report saved to: $report_file${NC}"
    
    # Display report
    less "$report_file"
}

# Function to quarantine a container
quarantine_container() {
    local container="$1"
    
    if [[ -z "$container" ]]; then
        list_containers
        echo
        read -p "Enter container ID or name to quarantine: " container
    fi
    
    echo -e "${YELLOW}Quarantining container: $container${NC}"
    
    # Create quarantine network if it doesn't exist
    if ! docker network ls | grep -q quarantine; then
        docker network create --internal --label security=quarantine quarantine
    fi
    
    # Get container's current networks
    local networks=$(docker inspect "$container" | jq -r '.[0].NetworkSettings.Networks | keys[]' 2>/dev/null)
    
    # Disconnect from all networks
    for network in $networks; do
        echo "Disconnecting from network: $network"
        docker network disconnect "$network" "$container" 2>/dev/null || true
    done
    
    # Connect to quarantine network
    docker network connect quarantine "$container"
    
    # Add label
    docker container update --label "security.status=quarantined" --label "security.quarantine_time=$(date -Iseconds)" "$container"
    
    echo -e "${GREEN}Container quarantined successfully!${NC}"
    echo "The container is now isolated in the 'quarantine' network with no external access."
}

# Function to create security policy
create_policy() {
    local policy_name="$1"
    
    if [[ -z "$policy_name" ]]; then
        read -p "Policy name: " policy_name
    fi
    
    local policy_file="$POLICIES_DIR/${policy_name}.yaml"
    
    if [[ -f "$policy_file" ]]; then
        echo -e "${RED}Policy already exists: $policy_name${NC}"
        return 1
    fi
    
    # Create policy template
    cat > "$policy_file" << 'EOF'
name: custom_policy
description: Custom container security policy

rules:
  - name: max_risk_score
    type: max_risk_score
    value: 75
    severity: high
    description: Maximum acceptable risk score
    
  - name: no_privileged
    type: forbidden_capability
    value: ['SYS_ADMIN']
    severity: critical
    description: Forbidden capabilities
    
  - name: vuln_limit
    type: max_vulnerabilities
    severity: high
    value: 10
    description: Maximum high severity vulnerabilities

enforcement: warn  # warn, block, or quarantine

exceptions: []
EOF
    
    echo -e "${GREEN}Created policy template: $policy_file${NC}"
    
    # Open in editor
    if [[ -n "$EDITOR" ]]; then
        "$EDITOR" "$policy_file"
    fi
}

# Main menu
show_menu() {
    echo -e "${BLUE}Container Security Manager${NC}"
    echo "========================="
    echo
    echo "1. List running containers"
    echo "2. Scan specific container"
    echo "3. Scan all containers"
    echo "4. Start continuous monitoring"
    echo "5. Stop monitoring"
    echo "6. Show scan results"
    echo "7. Generate security report"
    echo "8. Quarantine container"
    echo "9. Create security policy"
    echo "0. Exit"
    echo
}

# Main function
main() {
    # Create directories
    mkdir -p "$SCAN_RESULTS"
    
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1) list_containers ;;
                2) scan_container ;;
                3) scan_all_containers ;;
                4) start_monitoring ;;
                5) stop_monitoring ;;
                6) show_scan_results ;;
                7) generate_report ;;
                8) quarantine_container ;;
                9) create_policy ;;
                0) echo "Exiting..."; exit 0 ;;
                *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
            esac
            
            echo
            read -p "Press Enter to continue..."
        done
    else
        # Command line mode
        case "$1" in
            scan)
                shift
                scan_container "$@"
                ;;
            scan-all)
                scan_all_containers
                ;;
            monitor)
                start_monitoring
                ;;
            stop)
                stop_monitoring
                ;;
            results)
                show_scan_results
                ;;
            report)
                generate_report
                ;;
            quarantine)
                shift
                quarantine_container "$@"
                ;;
            *)
                echo "Usage: $0 [scan <container>|scan-all|monitor|stop|results|report|quarantine <container>]"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"