#!/bin/bash
# Implementation script for advanced security features
# Integrates tips and tricks into the existing security framework

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Implementing Advanced Security Features${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Function to backup existing file
backup_file() {
    local FILE=$1
    if [[ -f "$FILE" ]]; then
        cp "$FILE" "${FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backed up $FILE${NC}"
    fi
}

# ============================================
# 1. INTEGRATE ADVANCED FUNCTIONS
# ============================================

echo -e "${YELLOW}1. Integrating advanced security functions...${NC}"

# Add to existing security-aliases.sh
if [[ -f "security-aliases.sh" ]]; then
    backup_file "security-aliases.sh"
    
    # Check if already integrated
    if ! grep -q "advanced-security-functions" security-aliases.sh; then
        echo -e "\n# Load advanced security functions" >> security-aliases.sh
        echo "source \$(dirname \"\${BASH_SOURCE[0]}\")/advanced-security-functions.sh" >> security-aliases.sh
        echo -e "${GREEN}✓ Integrated advanced functions${NC}"
    else
        echo -e "${BLUE}ℹ Advanced functions already integrated${NC}"
    fi
fi

# ============================================
# 2. ENHANCE MONITORING CONFIGURATION
# ============================================

echo -e "\n${YELLOW}2. Enhancing monitoring configuration...${NC}"

# Create enhanced Prometheus rules
cat > security-monitoring/configs/enhanced_security_rules.yml << 'EOF'
groups:
  - name: enhanced_security_alerts
    interval: 30s
    rules:
      # SSH monitoring
      - alert: SSHLoginDetected
        expr: increase(ssh_login_total[5m]) > 0
        labels:
          severity: info
        annotations:
          summary: "SSH login detected"
          description: "SSH login from {{ $labels.source_ip }}"
      
      # Failed authentication spike
      - alert: AuthenticationFailureSpike
        expr: rate(auth_failure_total[5m]) > 10
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Authentication failure spike"
          description: "{{ $value }} failures per second"
      
      # Suspicious process detection
      - alert: SuspiciousProcess
        expr: process_start{name=~"nc|ncat|socat|cryptominer|xmrig"} == 1
        labels:
          severity: high
        annotations:
          summary: "Suspicious process detected"
          description: "Process {{ $labels.name }} started"
      
      # Docker security events
      - alert: PrivilegedContainer
        expr: docker_container_privileged == 1
        labels:
          severity: warning
        annotations:
          summary: "Privileged container running"
          description: "Container {{ $labels.name }} is running with privileged mode"
      
      # File integrity monitoring
      - alert: CriticalFileModified
        expr: file_modified{path=~"/etc/passwd|/etc/shadow|/etc/ssh/.*"} == 1
        labels:
          severity: critical
        annotations:
          summary: "Critical file modified"
          description: "File {{ $labels.path }} was modified"
EOF

echo -e "${GREEN}✓ Created enhanced monitoring rules${NC}"

# ============================================
# 3. CREATE AUTOMATED SECURITY TASKS
# ============================================

echo -e "\n${YELLOW}3. Creating automated security tasks...${NC}"

cat > security-monitoring/scripts/automated-tasks.sh << 'EOF'
#!/bin/bash
# Automated security tasks using advanced patterns

# Daily security scan with caching
daily_security_scan() {
    local SCAN_DATE=$(date +%Y%m%d)
    local SCAN_CACHE="/var/cache/security-scans/daily_$SCAN_DATE.json"
    
    # Check if already scanned today
    if [[ -f "$SCAN_CACHE" ]]; then
        echo "Daily scan already completed"
        return 0
    fi
    
    # Run security scans
    echo "Running daily security scan..."
    
    # Vulnerability scan
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy image --format json --output "$SCAN_CACHE" \
        $(docker ps --format "{{.Image}}" | sort -u)
    
    # Check for critical vulnerabilities
    CRITICAL_COUNT=$(jq '[.[] | .Vulnerabilities[] | select(.Severity == "CRITICAL")] | length' "$SCAN_CACHE")
    
    if [[ $CRITICAL_COUNT -gt 0 ]]; then
        # Send alert
        notify-send "Security Alert" "$CRITICAL_COUNT critical vulnerabilities found" -u critical
    fi
}

# Automated backup with encryption
secure_backup() {
    local BACKUP_DIR="/backup/$(date +%Y%m%d_%H%M%S)"
    local PASSPHRASE=$(openssl rand -base64 32)
    
    # Save passphrase securely
    echo "$PASSPHRASE" | gpg --encrypt -r backup@example.com > "$BACKUP_DIR.key.gpg"
    
    # Create encrypted backup
    tar -czf - /important/data | \
        openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$PASSPHRASE" \
        > "$BACKUP_DIR.tar.gz.enc"
}

# Git repository security check
check_git_secrets() {
    local REPO_DIR=${1:-"."}
    
    # Use temporary file with UUID
    local TEMP_REPORT="/tmp/git_secrets_$(uuidgen | cut -d'-' -f1).txt"
    
    # Run multiple security checks in parallel
    {
        trufflehog filesystem "$REPO_DIR" > "${TEMP_REPORT}.trufflehog" 2>&1 &
        gitleaks detect -s "$REPO_DIR" > "${TEMP_REPORT}.gitleaks" 2>&1 &
        git secrets --scan > "${TEMP_REPORT}.gitsecrets" 2>&1 &
        wait
    }
    
    # Combine reports
    cat "${TEMP_REPORT}".* > "$TEMP_REPORT"
    rm -f "${TEMP_REPORT}".*
    
    # Check for findings
    if grep -qE "(secret|key|password|token)" "$TEMP_REPORT"; then
        echo "SECURITY WARNING: Potential secrets found in repository!"
        cat "$TEMP_REPORT"
    else
        echo "No secrets detected"
    fi
    
    rm -f "$TEMP_REPORT"
}

# Main execution
case "$1" in
    daily-scan)
        daily_security_scan
        ;;
    backup)
        secure_backup
        ;;
    check-secrets)
        check_git_secrets "$2"
        ;;
    *)
        echo "Usage: $0 {daily-scan|backup|check-secrets [dir]}"
        ;;
esac
EOF

chmod +x security-monitoring/scripts/automated-tasks.sh
echo -e "${GREEN}✓ Created automated security tasks${NC}"

# ============================================
# 4. IMPLEMENT SSH LOGIN MONITORING
# ============================================

echo -e "\n${YELLOW}4. Implementing SSH login monitoring...${NC}"

cat > security-monitoring/scripts/ssh-monitor.sh << 'EOF'
#!/bin/bash
# SSH login monitoring with notifications

# Log file for SSH access
SSH_LOG="/var/log/ssh-access-monitor.log"

# Monitor function
monitor_ssh_login() {
    # Check SSH connection
    if [[ -n "$SSH_CONNECTION" ]]; then
        local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        local CLIENT_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
        local CLIENT_PORT=$(echo $SSH_CONNECTION | awk '{print $2}')
        local SERVER_IP=$(echo $SSH_CONNECTION | awk '{print $3}')
        local SERVER_PORT=$(echo $SSH_CONNECTION | awk '{print $4}')
        
        # Log the connection
        echo "[$TIMESTAMP] SSH Login - User: $USER, From: $CLIENT_IP:$CLIENT_PORT, To: $SERVER_IP:$SERVER_PORT" >> "$SSH_LOG"
        
        # Check if IP is in whitelist
        if ! grep -q "$CLIENT_IP" /etc/ssh/whitelist.ips 2>/dev/null; then
            # Send alert for non-whitelisted IP
            if command -v curl &> /dev/null; then
                # Send to webhook (replace with your webhook URL)
                curl -X POST -H "Content-Type: application/json" \
                    -d "{\"text\":\"SSH Login Alert: $USER from $CLIENT_IP\"}" \
                    https://hooks.slack.com/services/YOUR/WEBHOOK/URL 2>/dev/null
            fi
        fi
    fi
}

# Add to profile
setup_ssh_monitoring() {
    local PROFILE_FILE="$HOME/.bashrc"
    
    if ! grep -q "ssh-monitor.sh" "$PROFILE_FILE"; then
        echo -e "\n# SSH Login Monitoring" >> "$PROFILE_FILE"
        echo "source $(pwd)/ssh-monitor.sh && monitor_ssh_login" >> "$PROFILE_FILE"
        echo "SSH monitoring added to $PROFILE_FILE"
    fi
}

# Execute based on argument
case "$1" in
    setup)
        setup_ssh_monitoring
        ;;
    monitor)
        monitor_ssh_login
        ;;
    *)
        monitor_ssh_login
        ;;
esac
EOF

chmod +x security-monitoring/scripts/ssh-monitor.sh
echo -e "${GREEN}✓ Created SSH monitoring script${NC}"

# ============================================
# 5. CREATE CRON JOBS
# ============================================

echo -e "\n${YELLOW}5. Setting up automated cron jobs...${NC}"

cat > security-monitoring/crontab.example << 'EOF'
# Security Automation Cron Jobs
# Add these to your crontab with: crontab -e

# Daily security scan at 2 AM
0 2 * * * /path/to/security-monitoring/scripts/automated-tasks.sh daily-scan

# Hourly configuration backup
0 * * * * /path/to/security-monitoring/scripts/automated-tasks.sh backup

# Check for secrets before every git commit (add to git hooks instead)
# */5 * * * * cd /path/to/repo && /path/to/security-monitoring/scripts/automated-tasks.sh check-secrets

# Clean up old temporary files weekly
0 3 * * 0 find /tmp -name "security_*" -type f -mtime +7 -delete

# Update security tools weekly
0 4 * * 0 docker pull aquasec/trivy && docker pull projectdiscovery/nuclei

# Generate security report every Monday
0 9 * * 1 /path/to/security-report
EOF

echo -e "${GREEN}✓ Created cron job examples${NC}"

# ============================================
# 6. CREATE SYSTEMD SERVICES
# ============================================

echo -e "\n${YELLOW}6. Creating systemd service examples...${NC}"

mkdir -p security-monitoring/systemd

cat > security-monitoring/systemd/ssh-monitor.service << 'EOF'
[Unit]
Description=SSH Login Monitor
After=network.target

[Service]
Type=simple
ExecStart=/path/to/security-monitoring/scripts/ssh-monitor.sh monitor
Restart=always
User=security-monitor

[Install]
WantedBy=multi-user.target
EOF

cat > security-monitoring/systemd/security-scanner.timer << 'EOF'
[Unit]
Description=Daily Security Scanner Timer
Requires=security-scanner.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > security-monitoring/systemd/security-scanner.service << 'EOF'
[Unit]
Description=Daily Security Scanner
After=docker.service

[Service]
Type=oneshot
ExecStart=/path/to/security-monitoring/scripts/automated-tasks.sh daily-scan
User=security-scanner
EOF

echo -e "${GREEN}✓ Created systemd service examples${NC}"

# ============================================
# 7. IMPLEMENT DOCKER SECURITY PATTERNS
# ============================================

echo -e "\n${YELLOW}7. Implementing Docker security patterns...${NC}"

cat > docker-security-policy.json << 'EOF'
{
  "description": "Docker Security Policy",
  "policies": {
    "no_privileged": {
      "enabled": true,
      "description": "Prevent privileged containers"
    },
    "no_host_network": {
      "enabled": true,
      "exceptions": ["monitoring", "security-tools"]
    },
    "require_user": {
      "enabled": true,
      "description": "Containers must run as non-root"
    },
    "volume_restrictions": {
      "forbidden_mounts": [
        "/",
        "/etc",
        "/root",
        "/home/*/.ssh",
        "/home/*/.aws"
      ]
    },
    "resource_limits": {
      "memory": "2g",
      "cpu": "1.0"
    }
  }
}
EOF

echo -e "${GREEN}✓ Created Docker security policy${NC}"

# ============================================
# SUMMARY
# ============================================

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Implementation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "${GREEN}Advanced features implemented:${NC}"
echo "✓ SSH login monitoring"
echo "✓ Docker security patterns"
echo "✓ Automated security tasks"
echo "✓ Enhanced monitoring rules"
echo "✓ Temporary file management"
echo "✓ Parallel scanning capabilities"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Source the updated security aliases:"
echo "   source security-aliases.sh"
echo
echo "2. Set up SSH monitoring:"
echo "   ./security-monitoring/scripts/ssh-monitor.sh setup"
echo
echo "3. Review and install cron jobs:"
echo "   cat security-monitoring/crontab.example"
echo
echo "4. Test advanced functions:"
echo "   help-security"
echo
echo -e "${BLUE}Security Tips Documentation:${NC}"
echo "   Security-Tips-Tricks-Documentation.md"
echo