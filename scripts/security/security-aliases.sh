#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Security Framework Aliases
# Safe, simple command shortcuts

# Avoid conflicts by using sec- prefix for all commands
# This ensures no collision with existing system commands

# Main security commands
alias sec-status='sec status'
alias sec-report='sec report'
alias sec-fix='sec fix'
alias sec-monitor='sec monitor'
alias sec-help='sec help'

# Scanning commands
alias sec-scan='python3 ~/security/scripts/sec-scan'
alias sec-scan-quick='sec-scan --mode quick'
alias sec-scan-full='sec-scan --mode full'
alias sec-scan-web='sec-scan --mode web'

# Security checking
alias sec-check='python3 ~/security/scripts/sec-check'
alias sec-check-quick='sec-check --quick'
alias sec-check-system='sec-check system'
alias sec-check-docker='sec-check containers'

# Container security
alias sec-containers='~/security/sec-containers'
alias sec-docker-scan='sec-containers scan-all'
alias sec-docker-monitor='sec-containers monitor'

# Compliance checking
alias sec-comply='~/security/sec-comply'
alias sec-comply-scan='sec-comply scan'
alias sec-comply-report='sec-comply report'

# Vulnerability management
alias sec-vuln='python3 ~/security/scripts/vuln-check'
alias sec-vuln-scan='sec-vuln scan --targets /'
alias sec-vuln-fix='sec-vuln remediate'

# Quick actions
alias sec-update='sudo apt update && sudo apt upgrade'
alias sec-firewall-status='sudo ufw status verbose'
alias sec-firewall-enable='sudo ufw enable'
alias sec-services='systemctl list-units --type=service --state=running'

# Monitoring shortcuts
alias sec-logs='sudo journalctl -u security-monitor -f'
alias sec-events='tail -f /var/log/security/events.json 2>/dev/null | jq .'
alias sec-dashboard='xdg-open http://localhost:3000 2>/dev/null || echo "Open http://localhost:3000"'

# Testing shortcuts
alias sec-test='~/security/sec-test'
alias sec-test-web='sec-test run web-security-pipeline'
alias sec-test-infra='sec-test run infrastructure-pipeline'

# Functions for more complex operations

# Show security summary
sec-summary() {
    echo "=== Security Summary ==="
    echo
    echo "System Status:"
    sec-check system --quick 2>/dev/null | grep -E "(✅|❌|⚠️)" | head -10
    echo
    echo "Recent Events:"
    tail -5 /var/log/security/events.json 2>/dev/null | jq -r '.timestamp + " - " + .type' 2>/dev/null || echo "No recent events"
    echo
    echo "Active Services:"
    systemctl is-active ssh-monitor docker security-monitor 2>/dev/null | nl
}

# Quick security audit
sec-audit() {
    local target="${1:-.}"
    echo "Running security audit on $target..."
    
    # Run multiple checks in sequence
    echo "1. Scanning for vulnerabilities..."
    sec-vuln scan "$target"
    
    echo -e "\n2. Checking compliance..."
    sec-comply scan
    
    echo -e "\n3. Checking system security..."
    sec-check --quick
    
    echo -e "\nAudit complete. Check individual reports for details."
}

# Fix common issues
sec-fix-common() {
    echo "Fixing common security issues..."
    
    # Update system
    echo "1. Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    
    # Enable firewall if not active
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "2. Enabling firewall..."
        sudo ufw enable
    fi
    
    # Set secure file permissions
    echo "3. Setting secure file permissions..."
    sudo chmod 600 /etc/ssh/sshd_config 2>/dev/null
    sudo chmod 640 /etc/shadow 2>/dev/null
    sudo chmod 644 /etc/passwd 2>/dev/null
    
    echo "Common fixes applied. Run 'sec-check' to verify."
}

# Show all security commands
sec-commands() {
    echo "Security Framework Commands:"
    echo "==========================="
    echo
    echo "Main Commands:"
    echo "  sec              - Main control panel"
    echo "  sec-status       - Quick security status"
    echo "  sec-help         - Show help"
    echo
    echo "Scanning:"
    echo "  sec-scan         - Network scanner"
    echo "  sec-scan-quick   - Quick network scan"
    echo "  sec-scan-full    - Full port scan"
    echo "  sec-scan-web     - Web service scan"
    echo
    echo "Checking:"
    echo "  sec-check        - Security checker"
    echo "  sec-check-quick  - Quick security check"
    echo "  sec-check-system - System security only"
    echo "  sec-check-docker - Container security only"
    echo
    echo "Other Tools:"
    echo "  sec-comply       - Compliance checker"
    echo "  sec-containers   - Container security"
    echo "  sec-vuln         - Vulnerability scanner"
    echo "  sec-test         - Security testing"
    echo
    echo "Quick Actions:"
    echo "  sec-summary      - Security summary"
    echo "  sec-audit        - Full security audit"
    echo "  sec-fix-common   - Fix common issues"
    echo "  sec-update       - Update system"
    echo
    echo "Monitoring:"
    echo "  sec-logs         - View security logs"
    echo "  sec-events       - View security events"
    echo "  sec-dashboard    - Open Grafana dashboard"
}

# Export functions
export -f sec-summary
export -f sec-audit
export -f sec-fix-common
export -f sec-commands

# Show available commands on load
echo "Security tools loaded. Type 'sec-commands' to see all available commands."