#!/bin/bash
# Security Pipeline Runner
# Easy interface for running security testing pipelines

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$SCRIPT_DIR/pipelines"

# Function to list available pipelines
list_pipelines() {
    echo -e "${BLUE}Available Security Pipelines:${NC}"
    echo
    
    for pipeline in "$PIPELINE_DIR"/*.yaml; do
        if [[ -f "$pipeline" ]]; then
            name=$(basename "$pipeline" .yaml)
            description=$(grep "description:" "$pipeline" | cut -d: -f2- | xargs)
            echo -e "  ${GREEN}$name${NC}"
            echo -e "    $description"
            echo
        fi
    done
}

# Function to run a pipeline
run_pipeline() {
    local pipeline_name="$1"
    local pipeline_file="$PIPELINE_DIR/${pipeline_name}.yaml"
    
    if [[ ! -f "$pipeline_file" ]]; then
        echo -e "${RED}Error: Pipeline '$pipeline_name' not found${NC}"
        echo
        list_pipelines
        exit 1
    fi
    
    echo -e "${YELLOW}Running pipeline: $pipeline_name${NC}"
    echo
    
    # Check for required tools
    check_requirements
    
    # Run the pipeline
    python3 "$SCRIPT_DIR/security-testing-pipeline.py" "$pipeline_file" "${@:2}"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}Pipeline completed successfully!${NC}"
    else
        echo -e "${RED}Pipeline failed with exit code: $exit_code${NC}"
    fi
    
    return $exit_code
}

# Function to check requirements
check_requirements() {
    local missing_tools=()
    
    # Check for required tools
    for tool in python3 nmap trivy nuclei; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo
        echo "Install missing tools and try again."
        exit 1
    fi
}

# Function to create custom pipeline
create_pipeline() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        read -p "Pipeline name: " name
    fi
    
    local pipeline_file="$PIPELINE_DIR/${name}.yaml"
    
    if [[ -f "$pipeline_file" ]]; then
        echo -e "${RED}Pipeline '$name' already exists${NC}"
        exit 1
    fi
    
    # Create template
    cat > "$pipeline_file" << 'EOF'
name: custom_security_scan
description: Custom security testing pipeline

# Define targets to scan
targets:
  - https://example.com
  # - 192.168.1.0/24
  # - docker-image:tag

# Define tests to run
tests:
  - name: port_scan
    type: nmap
    enabled: true
    ports: "1-1000"
    scripts: "default"
    
  - name: web_scan
    type: nuclei
    enabled: false
    templates: "cves"
    severity: "critical,high"
    
  - name: container_scan
    type: trivy
    enabled: false
    scan_type: image
    severity: "CRITICAL,HIGH"

# Define failure thresholds
thresholds:
  critical: 0
  high: 5

# Configure notifications
notifications:
  always_notify: false
  webhook_url: "${WEBHOOK_URL}"

# Pipeline settings
parallel: true
stop_on_failure: false
EOF
    
    echo -e "${GREEN}Created pipeline template: $pipeline_file${NC}"
    echo "Edit the file to customize your pipeline"
    
    # Open in editor if available
    if [[ -n "$EDITOR" ]]; then
        read -p "Open in editor? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "$EDITOR" "$pipeline_file"
        fi
    fi
}

# Function to run scheduled pipelines
run_scheduled() {
    echo -e "${YELLOW}Running scheduled security pipelines...${NC}"
    
    # Define schedule
    local pipelines=(
        "web-security-pipeline"
        "infrastructure-pipeline"
        "container-pipeline"
    )
    
    local failed=0
    
    for pipeline in "${pipelines[@]}"; do
        echo
        echo -e "${BLUE}Running: $pipeline${NC}"
        
        if run_pipeline "$pipeline"; then
            echo -e "${GREEN}✓ $pipeline passed${NC}"
        else
            echo -e "${RED}✗ $pipeline failed${NC}"
            ((failed++))
        fi
        
        # Add delay between pipelines
        sleep 5
    done
    
    echo
    echo -e "${BLUE}Scheduled run complete${NC}"
    echo "  Total pipelines: ${#pipelines[@]}"
    echo "  Failed: $failed"
    
    return $failed
}

# Function to show recent results
show_results() {
    local results_dir="/var/log/security/pipeline-results"
    
    if [[ ! -d "$results_dir" ]]; then
        echo -e "${YELLOW}No results found${NC}"
        return
    fi
    
    echo -e "${BLUE}Recent Pipeline Results:${NC}"
    echo
    
    # Show last 10 results
    ls -lt "$results_dir"/*.json 2>/dev/null | head -10 | while read -r line; do
        file=$(echo "$line" | awk '{print $NF}')
        
        if [[ -f "$file" ]]; then
            # Extract summary from JSON
            pipeline=$(jq -r '.summary.pipeline' "$file" 2>/dev/null)
            status=$(jq -r '.summary.status' "$file" 2>/dev/null)
            findings=$(jq -r '.summary.total_findings' "$file" 2>/dev/null)
            timestamp=$(jq -r '.summary.timestamp' "$file" 2>/dev/null)
            
            # Format timestamp
            date_str=$(date -d "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$timestamp")
            
            # Color based on status
            if [[ "$status" == "passed" ]]; then
                status_color="${GREEN}PASS${NC}"
            else
                status_color="${RED}FAIL${NC}"
            fi
            
            echo -e "  $date_str | $pipeline | $status_color | Findings: $findings"
        fi
    done
    
    echo
    echo -e "${YELLOW}Full reports available in: $results_dir${NC}"
}

# Main menu
show_menu() {
    echo -e "${BLUE}Security Pipeline Runner${NC}"
    echo "======================="
    echo
    echo "1. List available pipelines"
    echo "2. Run a pipeline"
    echo "3. Create new pipeline"
    echo "4. Run scheduled pipelines"
    echo "5. Show recent results"
    echo "0. Exit"
    echo
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1)
                    list_pipelines
                    read -p "Press Enter to continue..."
                    ;;
                2)
                    list_pipelines
                    read -p "Enter pipeline name: " pipeline_name
                    run_pipeline "$pipeline_name"
                    read -p "Press Enter to continue..."
                    ;;
                3)
                    create_pipeline
                    read -p "Press Enter to continue..."
                    ;;
                4)
                    run_scheduled
                    read -p "Press Enter to continue..."
                    ;;
                5)
                    show_results
                    read -p "Press Enter to continue..."
                    ;;
                0)
                    echo "Exiting..."
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid option${NC}"
                    sleep 2
                    ;;
            esac
        done
    else
        # Command line mode
        case "$1" in
            list)
                list_pipelines
                ;;
            run)
                shift
                run_pipeline "$@"
                ;;
            create)
                shift
                create_pipeline "$@"
                ;;
            scheduled)
                run_scheduled
                ;;
            results)
                show_results
                ;;
            *)
                echo "Usage: $0 [list|run <pipeline>|create <name>|scheduled|results]"
                echo
                echo "Commands:"
                echo "  list              List available pipelines"
                echo "  run <pipeline>    Run a specific pipeline"
                echo "  create <name>     Create new pipeline"
                echo "  scheduled         Run all scheduled pipelines"
                echo "  results           Show recent results"
                echo
                echo "Run without arguments for interactive mode"
                exit 1
                ;;
        esac
    fi
}

# Create pipeline directory if it doesn't exist
mkdir -p "$PIPELINE_DIR"

# Run main function
main "$@"