#!/bin/bash
# Master Security Framework Setup Script
# Implements comprehensive security following best practices

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Security Framework Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    local missing=0
    
    # Check for required commands
    for cmd in docker docker-compose python3 pip3 git; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}✗ $cmd is not installed${NC}"
            missing=1
        else
            echo -e "${GREEN}✓ $cmd is installed${NC}"
        fi
    done
    
    # Check Docker daemon
    if ! docker ps &> /dev/null; then
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ Docker daemon is running${NC}"
    fi
    
    if [ $missing -eq 1 ]; then
        echo -e "\n${RED}Please install missing prerequisites before continuing${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All prerequisites satisfied!${NC}\n"
}

# Function to setup security aliases
setup_aliases() {
    echo -e "${YELLOW}Setting up security aliases...${NC}"
    
    if [ -f "$HOME/.bashrc" ]; then
        # Check if already sourced
        if ! grep -q "security-aliases.sh" "$HOME/.bashrc"; then
            echo "# Security aliases" >> "$HOME/.bashrc"
            echo "source $SCRIPT_DIR/security-aliases.sh" >> "$HOME/.bashrc"
            echo -e "${GREEN}✓ Added security aliases to .bashrc${NC}"
        else
            echo -e "${BLUE}ℹ Security aliases already configured${NC}"
        fi
    fi
    
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "security-aliases.sh" "$HOME/.zshrc"; then
            echo "# Security aliases" >> "$HOME/.zshrc"
            echo "source $SCRIPT_DIR/security-aliases.sh" >> "$HOME/.zshrc"
            echo -e "${GREEN}✓ Added security aliases to .zshrc${NC}"
        else
            echo -e "${BLUE}ℹ Security aliases already configured${NC}"
        fi
    fi
}

# Function to run defensive validation
run_validation() {
    echo -e "\n${YELLOW}Running defensive security validation...${NC}"
    
    if [ -x "$SCRIPT_DIR/defensive-validation.sh" ]; then
        $SCRIPT_DIR/defensive-validation.sh
    else
        echo -e "${RED}Validation script not found or not executable${NC}"
    fi
}

# Function to setup monitoring
setup_monitoring() {
    echo -e "\n${YELLOW}Setting up security monitoring...${NC}"
    
    if [ -x "$SCRIPT_DIR/security-monitoring-setup.sh" ]; then
        $SCRIPT_DIR/security-monitoring-setup.sh
    else
        echo -e "${RED}Monitoring setup script not found${NC}"
    fi
}

# Function to install Python dependencies
install_python_deps() {
    echo -e "\n${YELLOW}Installing Python dependencies...${NC}"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        echo -e "${GREEN}✓ Created virtual environment${NC}"
    fi
    
    # Activate and install requirements
    source venv/bin/activate
    
    cat > requirements.txt << EOF
docker==6.1.3
pyyaml==6.0
aiofiles==23.2.1
prometheus-client==0.18.0
asyncio==3.4.3
EOF
    
    pip install -r requirements.txt
    echo -e "${GREEN}✓ Installed Python dependencies${NC}"
}

# Function to create directory structure
create_directories() {
    echo -e "\n${YELLOW}Creating directory structure...${NC}"
    
    directories=(
        "security-monitoring/configs"
        "security-monitoring/logs"
        "security-monitoring/reports"
        "security-monitoring/playbooks"
        "incident-reports"
        "security-configs"
        "security-data"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        echo -e "${GREEN}✓ Created $dir${NC}"
    done
}

# Function to generate example configurations
generate_configs() {
    echo -e "\n${YELLOW}Generating example configurations...${NC}"
    
    # Create example playbook
    cat > security-monitoring/playbooks/example-playbook.yaml << 'EOF'
---
name: SSH Brute Force Response
description: Automated response to SSH brute force attempts
trigger:
  type: authentication_failure
  threshold: 5
  window: 300  # 5 minutes

actions:
  - type: block_ip
    duration: 3600  # 1 hour
    
  - type: collect_logs
    sources:
      - /var/log/auth.log
      - /var/log/secure
    lines: 100
    
  - type: notify
    channels:
      - email
      - slack
    severity: high
    
  - type: update_firewall
    rule: deny
    
post_actions:
  - type: report
    format: json
    destination: /var/log/incident_reports/
EOF
    
    echo -e "${GREEN}✓ Generated example playbook${NC}"
    
    # Create monitoring configuration
    cat > security-monitoring/configs/monitoring.yaml << 'EOF'
---
monitoring:
  prometheus:
    retention: 30d
    scrape_interval: 15s
    
  alerts:
    - name: high_cpu_usage
      expr: "cpu_usage > 80"
      for: 5m
      severity: warning
      
    - name: disk_space_low  
      expr: "disk_free_percent < 10"
      for: 10m
      severity: critical
      
    - name: unusual_network_traffic
      expr: "rate(network_bytes_total[5m]) > 100000000"
      for: 5m
      severity: warning

logging:
  level: INFO
  retention_days: 90
  
security_checks:
  - name: port_scan_detection
    enabled: true
    sensitivity: medium
    
  - name: brute_force_detection
    enabled: true
    threshold: 5
    window: 300
EOF
    
    echo -e "${GREEN}✓ Generated monitoring configuration${NC}"
}

# Function to display next steps
show_next_steps() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Setup Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo -e "${GREEN}Next Steps:${NC}"
    echo "1. Source your shell configuration:"
    echo "   source ~/.bashrc  # or ~/.zshrc"
    echo
    echo "2. Review the security validation report"
    echo
    echo "3. Start the monitoring stack:"
    echo "   cd security-monitoring"
    echo "   ./start-monitoring.sh"
    echo
    echo "4. Deploy security tools:"
    echo "   python3 security-tool-deployment.py"
    echo
    echo "5. Test incident response:"
    echo "   python3 incident-response-automation.py"
    echo
    echo -e "${YELLOW}Important Commands:${NC}"
    echo "- security-status    # Check security status"
    echo "- harden-check      # Run hardening checklist"
    echo "- security-report   # Generate security report"
    echo "- deploy-monitoring # Deploy monitoring stack"
    echo
    echo -e "${BLUE}Documentation:${NC}"
    echo "- AI-Development-Best-Practices.md"
    echo "- security-countermeasures-analysis.md"
    echo "- system-improvement-implementation.md"
    echo
}

# Main execution
main() {
    echo "Starting security framework setup..."
    echo "This will configure a comprehensive security environment"
    echo
    
    # Run setup steps
    check_prerequisites
    create_directories
    setup_aliases
    install_python_deps
    generate_configs
    setup_monitoring
    
    # Run initial validation
    echo
    read -p "Run security validation now? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        run_validation
    fi
    
    # Show completion message
    show_next_steps
}

# Run main function
main