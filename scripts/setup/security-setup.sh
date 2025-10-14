#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Security Setup Script
# Quick setup for the complete security framework

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]] && [[ "$1" != "--no-root" ]]; then
        echo -e "${YELLOW}Some operations require root privileges${NC}"
        echo "Run with sudo for full installation"
        echo "Or use --no-root for user-only setup"
        exit 1
    fi
}

# Function to backup files
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backed up $file${NC}"
    fi
}

# Function to create directory structure
create_directory_structure() {
    echo -e "\n${YELLOW}Creating directory structure...${NC}"
    
    local dirs=(
        "security"
        "security/scripts"
        "security/configs"
        "security/policies"
        "monitoring"
        "monitoring/dashboards"
        "automation"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        echo -e "${GREEN}✓ Created $dir${NC}"
    done
}

# Main execution
main() {
    clear
    echo -e "${BLUE}==================================${NC}"
    echo -e "${BLUE}    Security Framework Setup${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo
    
    check_root "$@"
    
    # Create directory structure
    create_directory_structure
    
    # Copy and rename scripts with better names
    echo -e "\n${YELLOW}Installing security tools...${NC}"
    
    # Main control center
    if [[ -f "$SCRIPT_DIR/../security/security-control.sh" ]]; then
        cp "$SCRIPT_DIR/../security/security-control.sh" security/sec-control
        chmod +x security/sec-control
    fi
    echo -e "${GREEN}✓ Installed sec-control${NC}"
    
    # SSH security
    cp "$SCRIPT_DIR/../security/ssh-monitor.sh" security/scripts/
    echo -e "${GREEN}✓ Installed SSH monitoring${NC}"
    
    # Container security
    cp "$SCRIPT_DIR/../security/container-security-manager.sh" security/sec-containers
    chmod +x security/sec-containers
    echo -e "${GREEN}✓ Installed sec-containers${NC}"
    
    # Network scanner
    cp "$SCRIPT_DIR/../security/advanced-network-scanner.py" security/scripts/net-scan
    chmod +x security/scripts/net-scan
    echo -e "${GREEN}✓ Installed net-scan${NC}"
    
    # Security pipelines
    cp "$SCRIPT_DIR/../security/run-security-pipeline.sh" security/sec-test
    chmod +x security/sec-test
    echo -e "${GREEN}✓ Installed sec-test${NC}"
    
    # Vulnerability management
    cp "$SCRIPT_DIR/../security/vulnerability-management-system.py" security/scripts/vuln-check
    chmod +x security/scripts/vuln-check
    echo -e "${GREEN}✓ Installed vuln-check${NC}"
    
    # Compliance
    cp "$SCRIPT_DIR/../security/compliance-manager.sh" security/sec-comply
    chmod +x security/sec-comply
    echo -e "${GREEN}✓ Installed sec-comply${NC}"
    
    # Copy supporting files
    echo -e "\n${YELLOW}Installing configurations...${NC}"
    cp -r "$SCRIPT_DIR/../security/policies" security/
    cp -r "$SCRIPT_DIR/../security/pipelines" security/
    cp -r "$SCRIPT_DIR/../monitoring/dashboards" monitoring/
    
    # Create simple aliases
    echo -e "\n${YELLOW}Creating command shortcuts...${NC}"
    
    cat > security/sec-aliases << 'EOF'
#!/bin/bash
# Security Command Shortcuts

# Main commands
alias sec='~/security/sec-control'
alias scan='~/security/scripts/net-scan'
alias vuln='~/security/scripts/vuln-check'
alias comply='~/security/sec-comply'
alias containers='~/security/sec-containers'
alias sec-test='~/security/sec-test'

# Quick actions
alias sec-scan-all='scan 192.168.1.0/24 -t smart'
alias sec-check='vuln scan --targets /'
alias sec-status='sec status'
alias sec-report='comply report markdown'

# Monitoring
alias sec-dash='xdg-open http://localhost:3000'
alias sec-metrics='xdg-open http://localhost:9090'
alias sec-logs='sudo journalctl -u security-monitor -f'

# Export functions
sec-help() {
    echo "Security Commands:"
    echo "  sec         - Main security control panel"
    echo "  scan        - Network security scanner"
    echo "  vuln        - Vulnerability checker"
    echo "  comply      - Compliance checker"
    echo "  containers  - Container security"
    echo "  sec-test    - Run security tests"
    echo
    echo "Quick Commands:"
    echo "  sec-status  - System security status"
    echo "  sec-scan-all- Scan local network"
    echo "  sec-check   - Check for vulnerabilities"
    echo "  sec-report  - Generate compliance report"
    echo "  sec-help    - Show this help"
}

export -f sec-help
EOF
    
    chmod +x security/sec-aliases
    
    # Add to shell initialization
    if [[ -f ~/.bashrc ]]; then
        if ! grep -q "sec-aliases" ~/.bashrc; then
            echo "source ~/security/sec-aliases" >> ~/.bashrc
            echo -e "${GREEN}✓ Added security aliases to .bashrc${NC}"
        fi
    fi
    
    if [[ -f ~/.zshrc ]]; then
        if ! grep -q "sec-aliases" ~/.zshrc; then
            echo "source ~/security/sec-aliases" >> ~/.zshrc
            echo -e "${GREEN}✓ Added security aliases to .zshrc${NC}"
        fi
    fi
    
    # Create main security command
    cat > /tmp/sec << 'EOF'
#!/bin/bash
# Main security command
exec ~/security/sec-control "$@"
EOF
    
    if [[ $EUID -eq 0 ]]; then
        mv /tmp/sec /usr/local/bin/sec
        chmod +x /usr/local/bin/sec
        echo -e "${GREEN}✓ Installed 'sec' command globally${NC}"
    else
        mkdir -p ~/.local/bin
        mv /tmp/sec ~/.local/bin/sec
        chmod +x ~/.local/bin/sec
        echo -e "${GREEN}✓ Installed 'sec' command locally${NC}"
        echo -e "${YELLOW}Add ~/.local/bin to your PATH if needed${NC}"
    fi
    
    echo
    echo -e "${GREEN}Security Framework Setup Complete!${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo
    echo "Quick Start:"
    echo "  1. Reload shell: source ~/.bashrc"
    echo "  2. Run: sec-help"
    echo "  3. Start with: sec"
    echo
    echo "Main Commands:"
    echo "  sec         - Security control panel"
    echo "  scan        - Network scanner"
    echo "  vuln        - Vulnerability checker"
    echo "  comply      - Compliance checker"
    echo "  containers  - Container security"
    echo
    echo -e "${BLUE}Type 'sec-help' after reloading shell for more info${NC}"
}

# Run main function
main "$@"