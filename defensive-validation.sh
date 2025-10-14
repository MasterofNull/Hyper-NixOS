#!/bin/bash
# Defensive Security Validation Script
# Validates defenses against MaxOS-style penetration testing capabilities
# Version: 1.0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
pass_count=0
fail_count=0
warn_count=0

# Timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="security-validation-report-$TIMESTAMP.md"

echo -e "${BLUE}=== Security Defense Validation Checklist ===${NC}"
echo -e "${BLUE}Testing defenses against MaxOS pentesting capabilities...${NC}"
echo

# Initialize report
cat > $REPORT_FILE << EOF
# Security Validation Report
Generated: $(date)

## Executive Summary
This report validates our security defenses against the capabilities demonstrated in the MaxOS penetration testing framework.

## Test Results
EOF

# Helper functions
check_defense() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    local category="$4"
    
    echo -n "Checking: $test_name... "
    
    if eval "$test_command" 2>&1 | grep -q "$expected_result"; then
        echo -e "${GREEN}PASS${NC}"
        ((pass_count++))
        echo "- ✅ **$test_name**: PASS" >> $REPORT_FILE
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((fail_count++))
        echo "- ❌ **$test_name**: FAIL" >> $REPORT_FILE
        return 1
    fi
}

check_warning() {
    local test_name="$1"
    local test_command="$2"
    local category="$3"
    
    echo -n "Checking: $test_name... "
    
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}CONFIGURED${NC}"
        ((pass_count++))
        echo "- ✅ **$test_name**: CONFIGURED" >> $REPORT_FILE
    else
        echo -e "${YELLOW}WARNING${NC}"
        ((warn_count++))
        echo "- ⚠️  **$test_name**: NOT CONFIGURED (Warning)" >> $REPORT_FILE
    fi
}

# ============================================
# 1. NETWORK SCANNING DEFENSES
# ============================================
echo -e "\n${YELLOW}1. NETWORK SCANNING DEFENSES${NC}"
echo "==============================" >> $REPORT_FILE
echo -e "\n### Network Scanning Defenses" >> $REPORT_FILE

check_defense "Firewall Active" \
    "sudo ufw status 2>/dev/null | grep -i active || sudo iptables -L 2>/dev/null | grep -i chain" \
    "active\|Chain" \
    "network"

check_defense "IDS/IPS Active" \
    "systemctl is-active suricata 2>/dev/null || systemctl is-active snort 2>/dev/null || systemctl is-active fail2ban 2>/dev/null" \
    "active" \
    "network"

check_warning "Port Scan Detection" \
    "test -f /etc/suricata/suricata.yaml && grep -i 'portscan' /etc/suricata/suricata.yaml" \
    "network"

check_defense "Fail2ban Active" \
    "systemctl is-active fail2ban 2>/dev/null || systemctl status fail2ban 2>/dev/null | grep -i active" \
    "active" \
    "network"

# ============================================
# 2. AUTHENTICATION DEFENSES
# ============================================
echo -e "\n${YELLOW}2. AUTHENTICATION DEFENSES${NC}"
echo -e "\n### Authentication Defenses" >> $REPORT_FILE

check_defense "SSH Key-Only Auth" \
    "grep -i '^PasswordAuthentication no' /etc/ssh/sshd_config" \
    "no" \
    "auth"

check_defense "Password Complexity" \
    "test -f /etc/security/pwquality.conf && grep -E 'minlen|dcredit|ucredit' /etc/security/pwquality.conf" \
    "minlen\|credit" \
    "auth"

check_defense "Account Lockout Policy" \
    "grep -i 'pam_faillock\|pam_tally' /etc/pam.d/common-auth 2>/dev/null || grep -i 'pam_faillock\|pam_tally' /etc/pam.d/system-auth 2>/dev/null" \
    "pam_" \
    "auth"

check_warning "Multi-Factor Authentication" \
    "test -f /etc/pam.d/common-auth && grep -i 'pam_google\|pam_duo\|pam_oath' /etc/pam.d/common-auth" \
    "auth"

# ============================================
# 3. WEB APPLICATION DEFENSES
# ============================================
echo -e "\n${YELLOW}3. WEB APPLICATION DEFENSES${NC}"
echo -e "\n### Web Application Defenses" >> $REPORT_FILE

check_warning "Web Application Firewall" \
    "docker ps 2>/dev/null | grep -E 'modsecurity|waf|cloudflare' || systemctl status modsecurity 2>/dev/null | grep -i active" \
    "web"

check_defense "HTTPS Configuration" \
    "test -f /etc/nginx/nginx.conf && grep -i 'ssl_protocols' /etc/nginx/nginx.conf || test -f /etc/apache2/apache2.conf && grep -i 'SSLProtocol' /etc/apache2/apache2.conf" \
    "TLS\|SSL" \
    "web"

check_warning "Security Headers" \
    "test -f /etc/nginx/nginx.conf && grep -E 'X-Frame-Options|Content-Security-Policy|X-Content-Type-Options' /etc/nginx/nginx.conf" \
    "web"

check_defense "Rate Limiting" \
    "test -f /etc/nginx/nginx.conf && grep -E 'limit_req|rate_limit' /etc/nginx/nginx.conf || grep -i fail2ban /etc/fail2ban/jail.local 2>/dev/null" \
    "limit\|fail2ban" \
    "web"

# ============================================
# 4. ENDPOINT PROTECTION
# ============================================
echo -e "\n${YELLOW}4. ENDPOINT PROTECTION${NC}"
echo -e "\n### Endpoint Protection" >> $REPORT_FILE

check_defense "System Auditing (auditd)" \
    "systemctl is-active auditd 2>/dev/null || systemctl status auditd 2>/dev/null | grep -i active" \
    "active" \
    "endpoint"

check_warning "Antivirus/Anti-malware" \
    "systemctl is-active clamav-daemon 2>/dev/null || pgrep -f 'clamd|defender|antivirus' || command -v clamscan" \
    "endpoint"

check_warning "EDR Agent" \
    "pgrep -f 'falcon-sensor|crowdstrike|sentinelone|cb|defender' || systemctl status falcon-sensor 2>/dev/null | grep -i active" \
    "endpoint"

check_warning "File Integrity Monitoring" \
    "test -f /etc/aide/aide.conf || test -f /etc/tripwire/tw.cfg || command -v aide || command -v tripwire" \
    "endpoint"

# ============================================
# 5. CONTAINER SECURITY
# ============================================
echo -e "\n${YELLOW}5. CONTAINER SECURITY${NC}"
echo -e "\n### Container Security" >> $REPORT_FILE

if command -v docker &>/dev/null; then
    check_defense "Docker Daemon Security" \
        "ls -l /var/run/docker.sock 2>/dev/null | grep -E 'root.*docker'" \
        "root.*docker" \
        "container"
    
    check_warning "Container Runtime Security" \
        "docker ps 2>/dev/null | grep -E 'falco|sysdig|aqua|twistlock'" \
        "container"
    
    check_warning "Image Vulnerability Scanning" \
        "command -v trivy || command -v clair || command -v anchore || docker images | grep -i trivy" \
        "container"
    
    check_defense "User Namespace Remapping" \
        "test -f /etc/docker/daemon.json && grep -i 'userns-remap' /etc/docker/daemon.json" \
        "userns" \
        "container"
else
    echo -e "${YELLOW}Docker not installed - skipping container checks${NC}"
fi

# ============================================
# 6. LOGGING AND MONITORING
# ============================================
echo -e "\n${YELLOW}6. LOGGING AND MONITORING${NC}"
echo -e "\n### Logging and Monitoring" >> $REPORT_FILE

check_defense "System Logging Active" \
    "systemctl is-active rsyslog 2>/dev/null || systemctl is-active syslog-ng 2>/dev/null || journalctl --version" \
    "active\|systemd" \
    "logging"

check_defense "Log Rotation Configured" \
    "test -f /etc/logrotate.conf || test -d /etc/logrotate.d" \
    "0" \
    "logging"

check_warning "Centralized Logging" \
    "docker ps 2>/dev/null | grep -E 'elastic|splunk|graylog|fluentd' || pgrep -f 'filebeat|logstash|fluentd'" \
    "logging"

check_warning "SIEM Solution" \
    "docker ps 2>/dev/null | grep -E 'elastic.*kibana|splunk|qradar' || systemctl status elasticsearch 2>/dev/null | grep -i active" \
    "logging"

# ============================================
# 7. NETWORK SECURITY
# ============================================
echo -e "\n${YELLOW}7. NETWORK SECURITY${NC}"
echo -e "\n### Network Security" >> $REPORT_FILE

check_defense "Network Segmentation" \
    "ip route | grep -E 'vlan|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.'" \
    "10\.\|172\.\|192\.168\.\|vlan" \
    "network"

check_warning "VPN Configuration" \
    "test -f /etc/openvpn/server.conf || test -f /etc/wireguard/wg0.conf || systemctl status openvpn 2>/dev/null | grep -i active" \
    "network"

check_defense "SSH Hardening" \
    "grep -E '^Protocol 2|^PermitRootLogin no|^MaxAuthTries [1-3]' /etc/ssh/sshd_config" \
    "2\|no\|[1-3]" \
    "network"

# ============================================
# 8. PATCH MANAGEMENT
# ============================================
echo -e "\n${YELLOW}8. PATCH MANAGEMENT${NC}"
echo -e "\n### Patch Management" >> $REPORT_FILE

check_defense "Automatic Security Updates" \
    "grep -i 'APT::Periodic::Unattended-Upgrade \"1\"' /etc/apt/apt.conf.d/* 2>/dev/null || grep -i 'apply_updates = yes' /etc/yum/yum-cron.conf 2>/dev/null" \
    "1\|yes" \
    "patching"

check_warning "Vulnerability Scanner" \
    "command -v nessus || command -v openvas || command -v nexpose || docker ps 2>/dev/null | grep -i 'openvas\|nessus'" \
    "patching"

# ============================================
# SUMMARY
# ============================================
echo
echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}VALIDATION SUMMARY${NC}"
echo -e "${BLUE}==================================${NC}"

# Calculate score
total=$((pass_count + fail_count + warn_count))
if [ $total -eq 0 ]; then
    score=0
else
    score=$((pass_count * 100 / total))
fi

echo -e "Passed: ${GREEN}$pass_count${NC}"
echo -e "Failed: ${RED}$fail_count${NC}"
echo -e "Warnings: ${YELLOW}$warn_count${NC}"
echo
echo "Security Score: $score%"
echo

# Add summary to report
cat >> $REPORT_FILE << EOF

## Summary

| Metric | Count |
|--------|-------|
| ✅ Passed | $pass_count |
| ❌ Failed | $fail_count |
| ⚠️  Warnings | $warn_count |
| **Total Checks** | $total |
| **Security Score** | $score% |

## Risk Assessment
EOF

# Risk assessment
if [ $score -lt 50 ]; then
    echo -e "${RED}CRITICAL: Your defenses need immediate attention!${NC}"
    echo "**Risk Level: CRITICAL** - Immediate action required. System is vulnerable to most attack vectors demonstrated in MaxOS." >> $REPORT_FILE
elif [ $score -lt 70 ]; then
    echo -e "${YELLOW}WARNING: Several important defenses are missing.${NC}"
    echo "**Risk Level: HIGH** - Several critical defenses are missing. System is vulnerable to common attacks." >> $REPORT_FILE
elif [ $score -lt 90 ]; then
    echo -e "${GREEN}GOOD: Most defenses are in place, but there's room for improvement.${NC}"
    echo "**Risk Level: MEDIUM** - Basic defenses are in place but additional hardening recommended." >> $REPORT_FILE
else
    echo -e "${GREEN}EXCELLENT: Strong defensive posture against MaxOS-style attacks!${NC}"
    echo "**Risk Level: LOW** - Strong defensive posture with comprehensive security controls." >> $REPORT_FILE
fi

# Generate recommendations
echo -e "\n## Priority Recommendations\n" >> $REPORT_FILE

if [ $fail_count -gt 0 ]; then
    echo -e "\n### Critical Items to Address:" >> $REPORT_FILE
    grep "❌" $REPORT_FILE | while read -r line; do
        if [[ $line == *"SSH Key-Only Auth"* ]]; then
            echo "1. **Disable SSH Password Authentication**: Edit `/etc/ssh/sshd_config` and set `PasswordAuthentication no`" >> $REPORT_FILE
        elif [[ $line == *"Firewall Active"* ]]; then
            echo "2. **Enable Firewall**: Run `sudo ufw enable` or configure iptables" >> $REPORT_FILE
        elif [[ $line == *"IDS/IPS Active"* ]]; then
            echo "3. **Deploy IDS/IPS**: Install Suricata or Snort for network monitoring" >> $REPORT_FILE
        elif [[ $line == *"System Auditing"* ]]; then
            echo "4. **Enable Auditd**: Run `sudo systemctl enable --now auditd`" >> $REPORT_FILE
        fi
    done
fi

# Add next steps
cat >> $REPORT_FILE << EOF

## Next Steps

1. Address all critical (❌) findings immediately
2. Implement warning (⚠️) items based on your security requirements
3. Re-run this validation after implementing changes
4. Consider implementing the security improvements from the MaxOS analysis

## Additional Resources

- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Controls](https://www.cisecurity.org/controls)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---
Report generated by Security Validation Script v1.0
EOF

echo
echo -e "${BLUE}Detailed report saved to: ${GREEN}$REPORT_FILE${NC}"
echo
echo -e "${YELLOW}Run 'cat $REPORT_FILE' to view the full report${NC}"