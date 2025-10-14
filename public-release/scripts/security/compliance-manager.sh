#!/bin/bash
# Security Compliance Manager
# Interface for managing compliance checks and reports

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLIANCE_DIR="/var/log/security/compliance"
POLICIES_DIR="$SCRIPT_DIR/compliance-policies"

# Function to run compliance scan
run_compliance_scan() {
    local framework="${1:-cis}"
    
    echo -e "${YELLOW}Running compliance scan for ${framework}...${NC}"
    
    # Create output directory
    mkdir -p "$COMPLIANCE_DIR"
    
    # Run the scan
    output_file="$COMPLIANCE_DIR/scan_${framework}_$(date +%Y%m%d_%H%M%S).json"
    
    if python3 "$SCRIPT_DIR/compliance-checking-framework.py" \
        --framework "$framework" \
        --output json \
        --output-file "$output_file"; then
        
        echo -e "${GREEN}✓ Compliance scan completed${NC}"
        
        # Show summary
        score=$(jq -r '.compliance_score' "$output_file")
        passed=$(jq -r '.summary.passed' "$output_file")
        failed=$(jq -r '.summary.failed' "$output_file")
        
        echo
        echo "Summary:"
        echo -e "  Compliance Score: ${BLUE}${score}%${NC}"
        echo -e "  Passed Checks: ${GREEN}${passed}${NC}"
        echo -e "  Failed Checks: ${RED}${failed}${NC}"
        
        # Show critical failures
        critical=$(jq -r '.critical_failures[]' "$output_file" 2>/dev/null)
        if [[ -n "$critical" ]]; then
            echo
            echo -e "${RED}Critical Failures:${NC}"
            echo "$critical" | while read -r failure; do
                echo "  - $failure"
            done
        fi
        
        echo
        echo "Full report: $output_file"
    else
        echo -e "${RED}✗ Compliance scan failed${NC}"
    fi
}

# Function to generate compliance report
generate_compliance_report() {
    local format="${1:-markdown}"
    local framework="${2:-cis}"
    
    echo -e "${YELLOW}Generating compliance report...${NC}"
    
    # Find latest scan
    latest_scan=$(ls -t "$COMPLIANCE_DIR"/scan_${framework}_*.json 2>/dev/null | head -1)
    
    if [[ -z "$latest_scan" ]]; then
        echo -e "${RED}No scan results found for ${framework}${NC}"
        echo "Run a scan first with: $0 scan $framework"
        return 1
    fi
    
    # Generate report
    output_file="$COMPLIANCE_DIR/report_${framework}_$(date +%Y%m%d_%H%M%S).${format}"
    
    if [[ "$format" == "html" ]]; then
        python3 "$SCRIPT_DIR/compliance-checking-framework.py" \
            --framework "$framework" \
            --output html \
            --output-file "$output_file"
        
        echo -e "${GREEN}HTML report generated: $output_file${NC}"
        
        # Open in browser if available
        if command -v xdg-open &> /dev/null; then
            xdg-open "$output_file"
        fi
    elif [[ "$format" == "markdown" ]]; then
        python3 "$SCRIPT_DIR/compliance-checking-framework.py" \
            --framework "$framework" \
            --output markdown \
            --output-file "$output_file"
        
        echo -e "${GREEN}Markdown report generated: $output_file${NC}"
        
        # Display report
        cat "$output_file"
    else
        echo -e "${RED}Unknown format: $format${NC}"
        return 1
    fi
}

# Function to show compliance trends
show_compliance_trends() {
    echo -e "${BLUE}Compliance Score Trends${NC}"
    echo "======================="
    
    if [[ ! -f "$COMPLIANCE_DIR/compliance_history.csv" ]]; then
        echo "No historical data available"
        return
    fi
    
    # Show last 10 scans
    echo
    echo "Recent Scans:"
    tail -n 10 "$COMPLIANCE_DIR/compliance_history.csv" | column -t -s ','
    
    # Calculate average score
    avg_score=$(tail -n 10 "$COMPLIANCE_DIR/compliance_history.csv" | \
                awk -F',' 'NR>1 {sum+=$6; count++} END {if(count>0) printf "%.1f", sum/count}')
    
    echo
    echo -e "Average Score (last 10 scans): ${BLUE}${avg_score}%${NC}"
    
    # Show trend
    first_score=$(tail -n 10 "$COMPLIANCE_DIR/compliance_history.csv" | \
                  awk -F',' 'NR==2 {print $6}')
    last_score=$(tail -n 1 "$COMPLIANCE_DIR/compliance_history.csv" | \
                 awk -F',' '{print $6}')
    
    if (( $(echo "$last_score > $first_score" | bc -l) )); then
        echo -e "Trend: ${GREEN}↑ Improving${NC}"
    elif (( $(echo "$last_score < $first_score" | bc -l) )); then
        echo -e "Trend: ${RED}↓ Declining${NC}"
    else
        echo -e "Trend: ${YELLOW}→ Stable${NC}"
    fi
}

# Function to remediate failures
remediate_failures() {
    local framework="${1:-cis}"
    local auto="${2:-false}"
    
    echo -e "${YELLOW}Analyzing failed compliance checks...${NC}"
    
    # Find latest scan
    latest_scan=$(ls -t "$COMPLIANCE_DIR"/scan_${framework}_*.json 2>/dev/null | head -1)
    
    if [[ -z "$latest_scan" ]]; then
        echo -e "${RED}No scan results found${NC}"
        return 1
    fi
    
    # Extract failed checks
    failed_checks=$(python3 -c "
import json
with open('$latest_scan', 'r') as f:
    data = json.load(f)
    for result in data.get('results', []):
        if result['status'] == 'fail':
            print(f\"{result['check_id']}|{result['evidence']}\")
")
    
    if [[ -z "$failed_checks" ]]; then
        echo -e "${GREEN}No failed checks to remediate!${NC}"
        return 0
    fi
    
    echo "Failed Checks:"
    echo "$failed_checks" | while IFS='|' read -r check_id evidence; do
        echo -e "  ${RED}$check_id${NC}: $evidence"
    done
    
    if [[ "$auto" == "true" ]]; then
        echo
        echo -e "${YELLOW}Auto-remediating failed checks...${NC}"
        echo -e "${RED}WARNING: This will make system changes!${NC}"
        read -p "Continue? (y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Implement auto-remediation logic here
            echo "Auto-remediation not yet implemented"
        fi
    else
        echo
        echo "To view remediation steps, check the full report"
    fi
}

# Function to create custom policy
create_custom_policy() {
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
name: Custom Policy Template
description: Add your policy description here
framework: custom
version: 1.0

categories:
  - Security
  - Compliance

checks:
  - id: CUSTOM-001
    title: Example check title
    description: Detailed description of what this check validates
    category: Security
    severity: medium  # critical, high, medium, low
    check_type: command  # file, command, package, service, configuration
    check_command: "echo 'test'"
    expected_result: "test"
    remediation: |
      Steps to fix if this check fails
EOF
    
    echo -e "${GREEN}Created policy template: $policy_file${NC}"
    
    # Open in editor
    if [[ -n "$EDITOR" ]]; then
        "$EDITOR" "$policy_file"
    fi
}

# Function to schedule compliance scans
schedule_compliance_scans() {
    echo -e "${YELLOW}Setting up scheduled compliance scans...${NC}"
    
    # Create systemd timer
    cat > /tmp/compliance-scan.service << EOF
[Unit]
Description=Security Compliance Scan
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/compliance-manager.sh scan all
StandardOutput=journal
StandardError=journal
EOF
    
    cat > /tmp/compliance-scan.timer << EOF
[Unit]
Description=Run Security Compliance Scan daily
Requires=compliance-scan.service

[Timer]
OnCalendar=daily
OnBootSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Install systemd units
    sudo mv /tmp/compliance-scan.service /etc/systemd/system/
    sudo mv /tmp/compliance-scan.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable compliance-scan.timer
    sudo systemctl start compliance-scan.timer
    
    echo -e "${GREEN}✓ Scheduled daily compliance scans${NC}"
    echo "View schedule: systemctl list-timers compliance-scan"
}

# Main menu
show_menu() {
    echo -e "${BLUE}Security Compliance Manager${NC}"
    echo "=========================="
    echo
    echo "1. Run compliance scan"
    echo "2. Generate compliance report"
    echo "3. Show compliance trends"
    echo "4. Analyze failed checks"
    echo "5. Create custom policy"
    echo "6. Schedule automated scans"
    echo "7. Compare scan results"
    echo "0. Exit"
    echo
}

# Function to compare scan results
compare_scan_results() {
    echo -e "${BLUE}Compare Compliance Scans${NC}"
    echo
    
    # List available scans
    scans=($(ls -t "$COMPLIANCE_DIR"/scan_*.json 2>/dev/null | head -10))
    
    if [[ ${#scans[@]} -lt 2 ]]; then
        echo -e "${RED}Need at least 2 scans to compare${NC}"
        return 1
    fi
    
    echo "Available scans:"
    for i in "${!scans[@]}"; do
        scan_date=$(basename "${scans[$i]}" | sed 's/scan_.*_\(.*\)\.json/\1/')
        framework=$(basename "${scans[$i]}" | sed 's/scan_\(.*\)_.*\.json/\1/')
        score=$(jq -r '.compliance_score' "${scans[$i]}" 2>/dev/null || echo "N/A")
        echo "  $((i+1)). $framework - $scan_date (Score: $score%)"
    done
    
    echo
    read -p "Select first scan (1-${#scans[@]}): " scan1_idx
    read -p "Select second scan (1-${#scans[@]}): " scan2_idx
    
    scan1="${scans[$((scan1_idx-1))]}"
    scan2="${scans[$((scan2_idx-1))]}"
    
    # Compare scores
    score1=$(jq -r '.compliance_score' "$scan1")
    score2=$(jq -r '.compliance_score' "$scan2")
    
    echo
    echo "Comparison Results:"
    echo -e "  Scan 1 Score: ${BLUE}${score1}%${NC}"
    echo -e "  Scan 2 Score: ${BLUE}${score2}%${NC}"
    
    if (( $(echo "$score2 > $score1" | bc -l) )); then
        improvement=$(echo "$score2 - $score1" | bc)
        echo -e "  Change: ${GREEN}+${improvement}% improvement${NC}"
    elif (( $(echo "$score2 < $score1" | bc -l) )); then
        decline=$(echo "$score1 - $score2" | bc)
        echo -e "  Change: ${RED}-${decline}% decline${NC}"
    else
        echo -e "  Change: ${YELLOW}No change${NC}"
    fi
    
    # Show newly failed/passed checks
    echo
    echo "Detailed comparison saved to: $COMPLIANCE_DIR/comparison_$(date +%Y%m%d_%H%M%S).txt"
}

# Main function
main() {
    # Create directories
    mkdir -p "$COMPLIANCE_DIR"
    mkdir -p "$POLICIES_DIR"
    
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1)
                    echo "Select framework:"
                    echo "  1. CIS Benchmark"
                    echo "  2. Custom Baseline"
                    echo "  3. All frameworks"
                    read -p "Choice: " fw_choice
                    
                    case $fw_choice in
                        1) run_compliance_scan "cis" ;;
                        2) run_compliance_scan "custom" ;;
                        3) 
                            run_compliance_scan "cis"
                            run_compliance_scan "custom"
                            ;;
                        *) echo -e "${RED}Invalid choice${NC}" ;;
                    esac
                    ;;
                2)
                    read -p "Report format (html/markdown): " format
                    read -p "Framework (cis/custom): " framework
                    generate_compliance_report "$format" "$framework"
                    ;;
                3)
                    show_compliance_trends
                    ;;
                4)
                    read -p "Framework (cis/custom): " framework
                    read -p "Auto-remediate? (y/n): " auto_rem
                    [[ "$auto_rem" == "y" ]] && auto="true" || auto="false"
                    remediate_failures "$framework" "$auto"
                    ;;
                5)
                    create_custom_policy
                    ;;
                6)
                    schedule_compliance_scans
                    ;;
                7)
                    compare_scan_results
                    ;;
                0)
                    echo "Exiting..."
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid option${NC}"
                    ;;
            esac
            
            echo
            read -p "Press Enter to continue..."
        done
    else
        # Command line mode
        case "$1" in
            scan)
                shift
                run_compliance_scan "$@"
                ;;
            report)
                shift
                generate_compliance_report "$@"
                ;;
            trends)
                show_compliance_trends
                ;;
            remediate)
                shift
                remediate_failures "$@"
                ;;
            create-policy)
                shift
                create_custom_policy "$@"
                ;;
            schedule)
                schedule_compliance_scans
                ;;
            *)
                echo "Usage: $0 [scan|report|trends|remediate|create-policy|schedule]"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"