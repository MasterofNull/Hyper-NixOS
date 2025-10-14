# Defensive Validation Checklist Against Advanced Attack Capabilities

## Quick Assessment Script

```bash
#!/bin/bash
# defensive-validation.sh
# Validates our defenses against advanced attacks

echo "=== Security Defense Validation Checklist ==="
echo "Testing defenses against advanced pentesting capabilities..."
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0
warn_count=0

check_defense() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -n "Checking: $test_name... "
    
    result=$(eval "$test_command" 2>&1)
    
    if [[ $result == *"$expected_result"* ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((pass_count++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Details: $result"
        ((fail_count++))
        return 1
    fi
}

check_warning() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Checking: $test_name... "
    
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}CONFIGURED${NC}"
        ((pass_count++))
    else
        echo -e "${YELLOW}WARNING${NC}"
        ((warn_count++))
    fi
}

echo "1. NETWORK SCANNING DEFENSES"
echo "=============================="
check_defense "IDS/IPS Active" "systemctl is-active suricata || systemctl is-active snort" "active"
check_defense "Fail2ban Active" "systemctl is-active fail2ban" "active"
check_warning "Port Scan Detection" "grep -i 'portscan' /etc/suricata/suricata.yaml 2>/dev/null"
check_defense "Firewall Active" "ufw status | grep -i active || iptables -L | grep -i chain" "active\|Chain"

echo
echo "2. AUTHENTICATION DEFENSES"
echo "=========================="
check_defense "Password Complexity" "grep -E 'minlen|dcredit|ucredit' /etc/security/pwquality.conf" "minlen"
check_defense "Account Lockout" "grep -i 'pam_faillock\|pam_tally' /etc/pam.d/common-auth" "pam_"
check_warning "MFA Configured" "test -f /etc/pam.d/common-auth && grep -i 'pam_google\|pam_duo' /etc/pam.d/common-auth"
check_defense "SSH Key Only" "grep -i 'PasswordAuthentication no' /etc/ssh/sshd_config" "no"

echo
echo "3. WEB APPLICATION DEFENSES"
echo "==========================="
check_warning "WAF Present" "docker ps | grep -E 'modsecurity|nginx.*waf|cloudflare'"
check_defense "HTTPS Enforced" "grep -i 'ssl_protocols' /etc/nginx/nginx.conf 2>/dev/null || grep -i 'SSLProtocol' /etc/apache2/apache2.conf 2>/dev/null" "TLS\|SSL"
check_warning "Security Headers" "test -f /etc/nginx/nginx.conf && grep -E 'X-Frame-Options|Content-Security-Policy' /etc/nginx/nginx.conf"
check_defense "Rate Limiting" "grep -E 'limit_req|rate_limit' /etc/nginx/nginx.conf 2>/dev/null" "limit"

echo
echo "4. ENDPOINT PROTECTION"
echo "======================"
check_defense "Antivirus Active" "systemctl is-active clamav-daemon || pgrep -f 'defender|antivirus'" "active\|[0-9]"
check_warning "EDR Agent" "pgrep -f 'falcon-sensor|crowdstrike|sentinelone|defender'"
check_defense "Auditd Active" "systemctl is-active auditd" "active"
check_warning "File Integrity Monitoring" "test -f /etc/aide/aide.conf || test -f /etc/tripwire/tw.cfg"

echo
echo "5. CONTAINER SECURITY"
echo "===================="
check_warning "Container Runtime Security" "docker ps | grep -E 'falco|sysdig|aqua'"
check_defense "Docker Socket Protected" "ls -l /var/run/docker.sock | grep -E 'root.*docker'" "root"
check_warning "Image Scanning" "which trivy || which clair || which anchore"
check_defense "User Namespaces" "grep -i 'userns-remap' /etc/docker/daemon.json 2>/dev/null" "userns"

echo
echo "6. LOGGING & MONITORING"
echo "======================="
check_defense "Centralized Logging" "systemctl is-active rsyslog || systemctl is-active syslog-ng || docker ps | grep -E 'elastic|splunk|graylog'" "active"
check_warning "SIEM Present" "docker ps | grep -E 'elastic.*kibana|splunk|qradar|sentinel'"
check_defense "Log Rotation" "test -f /etc/logrotate.conf" "0"
check_warning "Real-time Alerting" "test -f /etc/elastalert/config.yaml || pgrep -f 'alertmanager'"

echo
echo "7. NETWORK SECURITY"
echo "==================="
check_defense "Network Segmentation" "ip route | grep -E 'vlan|10\.|172\.|192\.'" "10\.\|172\.\|192\.\|vlan"
check_warning "VPN Configuration" "test -f /etc/openvpn/server.conf || test -f /etc/wireguard/wg0.conf"
check_defense "Encrypted Protocols" "grep -i 'ssl\|tls' /etc/services | wc -l | awk '{if($1>5)print\"configured\"}'" "configured"
check_warning "Network Anomaly Detection" "which zeek || which ntopng || pgrep -f 'netflow'"

echo
echo "8. PATCH MANAGEMENT"
echo "=================="
check_defense "Auto Updates" "grep -i 'APT::Periodic::Unattended-Upgrade \"1\"' /etc/apt/apt.conf.d/*" "1"
check_warning "Vulnerability Scanner" "which nessus || which openvas || which nexpose"
check_defense "Update Monitoring" "test -f /var/log/unattended-upgrades/unattended-upgrades.log" "0"

echo
echo "=================================="
echo "VALIDATION SUMMARY"
echo "=================================="
echo -e "Passed: ${GREEN}$pass_count${NC}"
echo -e "Failed: ${RED}$fail_count${NC}"
echo -e "Warnings: ${YELLOW}$warn_count${NC}"
echo

total=$((pass_count + fail_count + warn_count))
score=$((pass_count * 100 / total))

echo "Security Score: $score%"
echo

if [ $score -lt 50 ]; then
    echo -e "${RED}CRITICAL: Your defenses need immediate attention!${NC}"
elif [ $score -lt 70 ]; then
    echo -e "${YELLOW}WARNING: Several important defenses are missing.${NC}"
elif [ $score -lt 90 ]; then
    echo -e "${GREEN}GOOD: Most defenses are in place, but there's room for improvement.${NC}"
else
    echo -e "${GREEN}EXCELLENT: Strong defensive posture against advanced attacks!${NC}"
fi

# Generate detailed report
echo
echo "Generating detailed report..."
cat > security-validation-report-$(date +%Y%m%d).md << EOF
# Security Validation Report - $(date)

## Summary
- Total Checks: $total
- Passed: $pass_count
- Failed: $fail_count  
- Warnings: $warn_count
- Score: $score%

## Priority Remediations
EOF

if [ $fail_count -gt 0 ]; then
    echo "### Critical Failures Requiring Immediate Action:" >> security-validation-report-$(date +%Y%m%d).md
    # List specific failures and remediation steps
fi

echo
echo "Report saved to: security-validation-report-$(date +%Y%m%d).md"
```

## Automated Defense Testing

```python
# defense_validator.py
import subprocess
import json
import asyncio
from typing import Dict, List, Tuple
from datetime import datetime

class DefenseValidator:
    """Validates defensive measures against advanced attack capabilities"""
    
    def __init__(self):
        self.results = {
            "timestamp": datetime.now().isoformat(),
            "tests": [],
            "summary": {}
        }
    
    async def validate_all_defenses(self) -> Dict:
        """Run all defense validation tests"""
        
        # Network defenses
        await self.validate_network_defenses()
        
        # Authentication defenses
        await self.validate_auth_defenses()
        
        # Application defenses
        await self.validate_app_defenses()
        
        # Monitoring defenses
        await self.validate_monitoring()
        
        # Generate summary
        self.generate_summary()
        
        return self.results
    
    async def validate_network_defenses(self):
        """Test network-level defenses"""
        tests = [
            ("Port Scan Detection", self.test_port_scan_detection),
            ("DDoS Protection", self.test_ddos_protection),
            ("Network Segmentation", self.test_network_segmentation),
            ("Firewall Rules", self.test_firewall_rules),
        ]
        
        for test_name, test_func in tests:
            result = await test_func()
            self.results["tests"].append({
                "category": "network",
                "name": test_name,
                "result": result
            })
    
    async def test_port_scan_detection(self) -> Dict:
        """Simulate port scan and check if detected"""
        # Simulate slow port scan
        scan_cmd = "nmap -sS -T1 -p 1-100 localhost"
        
        # Start scan in background
        proc = await asyncio.create_subprocess_shell(
            scan_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        # Wait briefly then check logs
        await asyncio.sleep(5)
        
        # Check if detected in IDS logs
        detection_check = "grep -i 'port.*scan' /var/log/suricata/fast.log | tail -5"
        result = subprocess.run(detection_check, shell=True, capture_output=True, text=True)
        
        detected = len(result.stdout.strip()) > 0
        
        # Kill scan process
        proc.terminate()
        
        return {
            "passed": detected,
            "details": "Port scan detected in IDS logs" if detected else "Port scan not detected",
            "recommendation": "Enable port scan detection rules in IDS" if not detected else None
        }
    
    async def test_brute_force_protection(self) -> Dict:
        """Test brute force protection mechanisms"""
        # Simulate failed login attempts
        test_user = "testuser_security_validation"
        
        for i in range(6):
            subprocess.run(f"sshpass -p wrongpass ssh {test_user}@localhost exit", 
                         shell=True, capture_output=True)
        
        # Check if account is locked
        check_cmd = f"faillock --user {test_user}"
        result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
        
        locked = "attempts" in result.stdout
        
        return {
            "passed": locked,
            "details": "Account locked after failed attempts" if locked else "No account lockout detected",
            "recommendation": "Configure fail2ban or pam_faillock" if not locked else None
        }

# Usage
validator = DefenseValidator()
results = asyncio.run(validator.validate_all_defenses())
print(json.dumps(results, indent=2))
```

## Continuous Validation Pipeline

```yaml
# .gitlab-ci.yml or .github/workflows/security-validation.yml
name: Security Defense Validation

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  validate-defenses:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Defense Validation
        run: |
          chmod +x ./scripts/defensive-validation.sh
          ./scripts/defensive-validation.sh > validation-results.txt
      
      - name: Check Security Score
        run: |
          score=$(grep "Security Score:" validation-results.txt | awk '{print $3}' | tr -d '%')
          if [ $score -lt 70 ]; then
            echo "::error::Security score is below threshold: $score%"
            exit 1
          fi
      
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: security-validation-report
          path: security-validation-report-*.md
      
      - name: Notify on Failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Security validation failed! Check the report for details.'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

This validation framework ensures your defenses are properly configured and effective against the types of attacks that advanced security tools enable.