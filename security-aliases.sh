#!/bin/bash
# Security Aliases and Functions for Enhanced Security Operations
# Inspired by MaxOS security patterns
# Version: 1.0

# Color codes for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

echo -e "${BLUE}Loading security aliases and functions...${NC}"

# ============================================
# NETWORK SECURITY ALIASES
# ============================================

# Quick network overview
alias net-connections='ss -tunapl | grep ESTABLISHED'
alias net-listening='ss -tunl'
alias net-monitor='sudo nethogs'
alias net-traffic='sudo iftop -i any'

# Network scanning (defensive)
alias net-scan-local='echo -e "${YELLOW}Scanning local network...${NC}" && nmap -sn 192.168.1.0/24'
alias net-scan-ports='f() { echo -e "${YELLOW}Scanning ports on $1...${NC}" && nmap -p- -T4 $1; }; f'
alias net-vulns='f() { echo -e "${YELLOW}Checking vulnerabilities on $1...${NC}" && nmap -sV --script vuln $1; }; f'

# ============================================
# SECURITY MONITORING
# ============================================

# System monitoring
alias sec-processes='ps auxf | grep -v ]$ | less'
alias sec-connections='netstat -tulpn 2>/dev/null | grep LISTEN'
alias sec-failed-logins='sudo grep "Failed password" /var/log/auth.log | tail -20'
alias sec-last-logins='last -20'
alias sec-who='w'

# Log monitoring
alias logs-auth='sudo tail -f /var/log/auth.log'
alias logs-syslog='sudo tail -f /var/log/syslog'
alias logs-kern='sudo tail -f /var/log/kern.log'
alias logs-fail2ban='sudo tail -f /var/log/fail2ban.log'
alias logs-nginx='sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log'

# ============================================
# CONTAINER SECURITY
# ============================================

# Docker security scanning
alias docker-scan='f() { echo -e "${YELLOW}Scanning image $1...${NC}" && docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image $1; }; f'
alias docker-bench='docker run --rm --net host --pid host --cap-add audit_control -v /var/lib:/var/lib -v /var/run/docker.sock:/var/run/docker.sock -v /etc:/etc docker/docker-bench-security'
alias docker-secrets='f() { echo -e "${YELLOW}Scanning for secrets in $1...${NC}" && docker run --rm -v $(pwd):/src trufflesecurity/trufflehog:latest filesystem /src; }; f'

# Container inspection
alias docker-inspect-security='f() { docker inspect $1 | jq ".[0] | {SecurityOpt, CapAdd, CapDrop, Privileged, ReadonlyRootfs, User}"; }; f'
alias docker-processes='f() { docker top $1; }; f'
alias docker-ports='docker ps --format "table {{.Names}}\t{{.Ports}}"'

# ============================================
# QUICK SECURITY CHECKS
# ============================================

# System security status
alias security-status='f() { 
    echo -e "${BLUE}=== Security Status Check ===${NC}"
    echo -e "${YELLOW}Firewall:${NC}"
    sudo ufw status | head -5
    echo -e "\n${YELLOW}Failed login attempts (last 24h):${NC}"
    sudo grep "Failed password" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l
    echo -e "\n${YELLOW}Active connections:${NC}"
    ss -tuln | wc -l
    echo -e "\n${YELLOW}Running services:${NC}"
    systemctl list-units --type=service --state=running | grep -E "(ssh|nginx|apache|mysql|postgres|docker)" | wc -l
}; f'

# Quick vulnerability check
alias check-updates='f() {
    echo -e "${YELLOW}Checking for security updates...${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update &>/dev/null && apt list --upgradable 2>/dev/null | grep -i security
    elif command -v yum &> /dev/null; then
        sudo yum check-update --security
    fi
}; f'

# Check for rootkits
alias check-rootkits='f() {
    if command -v rkhunter &> /dev/null; then
        echo -e "${YELLOW}Running rootkit hunter...${NC}"
        sudo rkhunter --check --skip-keypress
    else
        echo -e "${RED}rkhunter not installed. Install with: sudo apt-get install rkhunter${NC}"
    fi
}; f'

# ============================================
# INCIDENT RESPONSE
# ============================================

# IR snapshot collection
alias ir-snapshot='f() {
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    DIR="/tmp/ir-snapshot-$TIMESTAMP"
    echo -e "${YELLOW}Creating IR snapshot in $DIR...${NC}"
    mkdir -p $DIR
    
    # System info
    ps auxf > $DIR/processes.txt
    netstat -tulpn > $DIR/network.txt 2>/dev/null
    w > $DIR/users.txt
    last -50 > $DIR/last-logins.txt
    
    # Logs
    sudo cp /var/log/auth.log $DIR/ 2>/dev/null
    sudo cp /var/log/syslog $DIR/ 2>/dev/null
    sudo journalctl -n 1000 > $DIR/journalctl.txt
    
    # Create archive
    tar -czf $DIR.tar.gz $DIR
    rm -rf $DIR
    echo -e "${GREEN}Snapshot saved to: $DIR.tar.gz${NC}"
}; f'

# Kill suspicious process
alias ir-kill='f() { 
    echo -e "${RED}Killing process $1...${NC}"
    sudo kill -9 $1
    echo -e "${YELLOW}Process $1 terminated${NC}"
}; f'

# Block IP address
alias ir-block-ip='f() {
    echo -e "${RED}Blocking IP $1...${NC}"
    sudo iptables -A INPUT -s $1 -j DROP
    echo -e "${YELLOW}IP $1 blocked${NC}"
}; f'

# ============================================
# SECURITY TOOLS DEPLOYMENT
# ============================================

# Quick security scanners
alias deploy-nikto='docker run --rm -v $(pwd):/tmp sullo/nikto -h'
alias deploy-wpscan='docker run --rm -v $(pwd):/tmp wpscanteam/wpscan --url'
alias deploy-nmap='docker run --rm --network host instrumentisto/nmap'

# Quick web server for testing
alias serve-here='f() {
    PORT=${1:-8000}
    echo -e "${YELLOW}Starting web server on port $PORT...${NC}"
    python3 -m http.server $PORT
}; f'

# ============================================
# FILE INTEGRITY
# ============================================

# Check file hashes
alias hash-dir='f() {
    echo -e "${YELLOW}Creating hash list for directory...${NC}"
    find ${1:-.} -type f -exec sha256sum {} \; > file-hashes-$(date +%Y%m%d).txt
    echo -e "${GREEN}Hashes saved to file-hashes-$(date +%Y%m%d).txt${NC}"
}; f'

# Compare file hashes
alias hash-check='f() {
    if [ -f "$1" ]; then
        echo -e "${YELLOW}Checking file integrity...${NC}"
        sha256sum -c $1
    else
        echo -e "${RED}Usage: hash-check <hash-file>${NC}"
    fi
}; f'

# ============================================
# HELPER FUNCTIONS
# ============================================

# Security report generator
security-report() {
    REPORT_FILE="security-report-$(date +%Y%m%d-%H%M%S).txt"
    echo "Security Report - $(date)" > $REPORT_FILE
    echo "=========================" >> $REPORT_FILE
    
    echo -e "${YELLOW}Generating security report...${NC}"
    
    echo -e "\n## System Information" >> $REPORT_FILE
    uname -a >> $REPORT_FILE
    
    echo -e "\n## Network Connections" >> $REPORT_FILE
    ss -tuln >> $REPORT_FILE
    
    echo -e "\n## Failed Logins (last 24h)" >> $REPORT_FILE
    sudo grep "Failed password" /var/log/auth.log | tail -20 >> $REPORT_FILE
    
    echo -e "\n## Running Services" >> $REPORT_FILE
    systemctl list-units --type=service --state=running >> $REPORT_FILE
    
    echo -e "\n## Firewall Status" >> $REPORT_FILE
    sudo ufw status verbose >> $REPORT_FILE 2>/dev/null || sudo iptables -L >> $REPORT_FILE
    
    echo -e "${GREEN}Report saved to: $REPORT_FILE${NC}"
}

# Quick security hardening check
harden-check() {
    echo -e "${BLUE}=== Security Hardening Checklist ===${NC}"
    
    # SSH hardening
    echo -n "SSH Password Auth Disabled: "
    grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    
    # Firewall
    echo -n "Firewall Enabled: "
    sudo ufw status | grep -q "Status: active" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    
    # Updates
    echo -n "Automatic Updates: "
    [ -f /etc/apt/apt.conf.d/50unattended-upgrades ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    
    # Fail2ban
    echo -n "Fail2ban Active: "
    systemctl is-active fail2ban &>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    
    # Auditd
    echo -n "Auditd Active: "
    systemctl is-active auditd &>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
}

# ============================================
# QUICK DEPLOYMENT HELPERS
# ============================================

# Deploy monitoring stack
deploy-monitoring() {
    echo -e "${YELLOW}Deploying monitoring stack...${NC}"
    cat > /tmp/monitoring-compose.yml << 'EOF'
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped

  node_exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
EOF
    
    echo -e "${GREEN}Monitoring stack configuration created at /tmp/monitoring-compose.yml${NC}"
    echo -e "${YELLOW}Deploy with: docker-compose -f /tmp/monitoring-compose.yml up -d${NC}"
}

# Load advanced security functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/advanced-security-functions.sh" ]] && source "$SCRIPT_DIR/advanced-security-functions.sh"
[[ -f "$SCRIPT_DIR/scripts/automation/parallel-framework.sh" ]] && source "$SCRIPT_DIR/scripts/automation/parallel-framework.sh"

echo -e "${GREEN}Security aliases loaded successfully!${NC}"
echo -e "${BLUE}Type 'alias | grep -E \"sec-|net-|ir-|docker-\"' to see all security aliases${NC}"
echo -e "${BLUE}Type 'harden-check' to run security hardening checklist${NC}"
echo -e "${BLUE}Type 'security-report' to generate a security report${NC}"
echo -e "${BLUE}Type 'help-security' to see advanced security functions${NC}"