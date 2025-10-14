# Hands-On Security Tutorial 🎓

## Learn By Doing: From Zero to Security Hero

This tutorial takes you through real security scenarios, teaching you to use the tools effectively. Each lesson builds on the previous one, with clear objectives and practical exercises.

---

## 🎯 Tutorial Overview

**Time Required**: 2-3 hours  
**Skill Level**: Beginner to Intermediate  
**What You'll Learn**:
- Monitor and respond to security events
- Automate repetitive security tasks
- Deploy and manage security tools
- Create custom security workflows

---

## 📚 Lesson 1: Your First Security Check (15 minutes)

### Objective
Learn basic security monitoring and understand your system's security posture.

### Step-by-Step Guide

#### 1.1 Check System Security Status
```bash
# Open a terminal and run:
security-status

# You should see output like:
# === Security Status Check ===
# Firewall: active
# Failed login attempts (last 24h): 3
# Active connections: 47
# Running services: 12
```

**🤔 Understanding the Output:**
- **Firewall: active** - Good! Your firewall is protecting you
- **Failed login attempts** - Normal to see a few, worry if > 50/day
- **Active connections** - Number of network connections
- **Running services** - Services that could be attack targets

#### 1.2 Check Who's Been Logging In
```bash
# View recent SSH logins
ssh_login_history 5

# You might see:
# [2024-01-15 09:23:45] SSH Login - User: john, From: 192.168.1.100
# [2024-01-15 10:15:22] SSH Login - User: admin, From: 10.0.0.50
```

**🚨 Action Item**: Do you recognize all these IPs? If not, investigate!

#### 1.3 Run Security Validation
```bash
# Check your defenses
./scripts/security/defensive-validation.sh | head -20

# Look for patterns:
# ✓ (checkmark) = Good
# ✗ (X) = Needs attention
# ⚠ (warning) = Optional but recommended
```

### 📝 Exercise 1
1. Run `security-status` and note your firewall status
2. Check if you have any failed login attempts
3. Run `harden-check` and identify one "FAIL" item to fix

### ✅ Checkpoint
Before continuing, you should:
- Know how to check security status
- Understand how to view login history
- Have identified at least one security improvement

---

## 📚 Lesson 2: SSH Security and Monitoring (20 minutes)

### Objective
Set up SSH monitoring and learn to use enhanced SSH features.

### Step-by-Step Guide

#### 2.1 Set Up SSH Monitoring
```bash
# First, let's see current SSH sessions
who

# Now set up monitoring for future logins
echo "source /opt/scripts/security/ssh-monitor.sh" >> ~/.bashrc
source ~/.bashrc
```

#### 2.2 Configure Whitelisted IPs
```bash
# Create whitelist for trusted IPs (won't trigger alerts)
sudo nano /etc/ssh/whitelist.ips

# Add your trusted IPs (one per line):
192.168.1.100  # Your home IP
10.0.0.50      # Office VPN
# Save and exit (Ctrl+X, Y, Enter)
```

#### 2.3 Test SSH Monitoring
```bash
# In one terminal, watch the logs:
tail -f /var/log/security/ssh-monitor.log

# In another terminal, SSH to localhost:
ssh localhost
# (Enter your password or use key)

# You should see a log entry appear!
```

#### 2.4 Use Enhanced SSH with Auto-Mount
```bash
# Traditional SSH (basic):
ssh user@remote-server
ls /remote/files  # Can't access easily
exit

# Enhanced SSH (with auto-mount):
sshm user@remote-server
# Remote filesystem is now mounted!
ls ~/mnt/remote-server_*/  # Browse remote files locally!
cp ~/mnt/remote-server_*/important.doc ~/Desktop/
exit  # Automatically unmounts
```

### 📝 Exercise 2
1. Add your current IP to the whitelist
2. SSH into your own machine and verify logging works
3. If you have access to another server, try `sshm` to connect

### 💡 Pro Tips
- Use `ssh-keygen` to create SSH keys for passwordless login
- Monitor `/var/log/auth.log` for all authentication events
- Set up `fail2ban` for automatic IP blocking

---

## 📚 Lesson 3: Docker Security (25 minutes)

### Objective
Learn to run containers securely and scan for vulnerabilities.

### Step-by-Step Guide

#### 3.1 Understanding Docker Security Risks
```bash
# DANGEROUS - Don't actually run this!
# docker run -v /:/host ubuntu  # Mounts entire system!

# Let's see what our security wrapper prevents:
docker-safe run -v /:/host ubuntu

# You should see:
# ERROR: Cannot mount / - security policy violation
```

#### 3.2 Running Containers Safely
```bash
# Create a safe working directory
mkdir ~/docker-work
cd ~/docker-work
echo "Hello from container" > test.txt

# Safe container with limited access
docker-safe run -v $(pwd):/work -it ubuntu bash

# Inside container:
ls /work  # You can see test.txt
cat /work/test.txt
exit
```

#### 3.3 Scanning for Vulnerabilities
```bash
# Pull a test image
docker pull nginx:latest

# Scan it for vulnerabilities
docker-scan nginx:latest

# You'll see output like:
# nginx:latest (debian 11.6)
# ==========================
# Total: 142 (HIGH: 7, CRITICAL: 0)
```

#### 3.4 Smart Container Management
```bash
# Deploy with caching (saves bandwidth)
docker-cache "demo-nginx" \
    "docker run -d --name demo-nginx -p 8080:80 nginx" \
    "echo 'Nginx already running'"

# Visit http://localhost:8080 to see it working

# Clean up when done
docker-clean "demo-*"  # Removes all containers starting with "demo-"
```

### 📝 Exercise 3
1. Try to run a container that mounts `/etc` (it should fail)
2. Scan the `ubuntu:latest` image for vulnerabilities
3. Create a container using `docker-cache` and verify it works

### 🔒 Security Best Practices
- Never mount system directories (/, /etc, /root)
- Always scan images before production use
- Use specific image tags, not `latest`
- Run containers as non-root when possible

---

## 📚 Lesson 4: Parallel Processing Power (20 minutes)

### Objective
Speed up security tasks using parallel execution.

### Step-by-Step Guide

#### 4.1 Understanding Parallel Execution
```bash
# Traditional way (slow):
echo "Scanning servers one by one..."
time (
    nmap -p 22 192.168.1.1
    nmap -p 22 192.168.1.2
    nmap -p 22 192.168.1.3
)
# Takes about 30 seconds

# Parallel way (fast):
source scripts/automation/parallel-framework.sh

scan_tasks=(
    "nmap -p 22 192.168.1.1"
    "nmap -p 22 192.168.1.2"
    "nmap -p 22 192.168.1.3"
)

echo "Scanning servers in parallel..."
time parallel_execute scan_tasks 3
# Takes about 10 seconds!
```

#### 4.2 Parallel Git Updates
```bash
# Create a list of repositories to update
cat > ~/repos.txt << EOF
https://github.com/aquasecurity/trivy|~/tools/trivy
https://github.com/OWASP/CheatSheetSeries|~/docs/owasp-cheatsheets
https://github.com/danielmiessler/SecLists|~/tools/seclists
EOF

# Update all repositories at once
./scripts/automation/parallel-git-update.sh ~/repos.txt

# Watch the progress bar!
```

#### 4.3 Parallel Security Scans
```bash
# Create list of targets
cat > ~/scan-targets.txt << EOF
localhost
192.168.1.1
google.com
EOF

# Create scanning script
cat > ~/parallel-scan.sh << 'EOF'
#!/bin/bash
source scripts/automation/parallel-framework.sh

# Read targets
mapfile -t targets < ~/scan-targets.txt

# Create scan tasks
tasks=()
for target in "${targets[@]}"; do
    tasks+=("echo 'Scanning $target...' && nmap -p 80,443 $target")
done

# Run scans
parallel_execute tasks 3
EOF

chmod +x ~/parallel-scan.sh
./parallel-scan.sh
```

### 📝 Exercise 4
1. Create a list of 5 websites to scan
2. Use parallel execution to check if port 443 is open on each
3. Compare the time with sequential scanning

### ⚡ Performance Tips
- Use `MAX_PARALLEL_JOBS` based on CPU cores
- Group similar tasks together
- Monitor system load during execution

---

## 📚 Lesson 5: Automated Security Workflows (30 minutes)

### Objective
Create automated workflows that combine multiple security tools.

### Step-by-Step Guide

#### 5.1 Morning Security Check Automation
```bash
# Create your personal morning security script
cat > ~/morning-security.sh << 'EOF'
#!/bin/bash
# My automated morning security check

echo "☀️ Good Morning! Running security checks..."
echo "========================================"
echo

# 1. System Status
echo "📊 System Status:"
security-status | grep -E "Score|Failed|active"
echo

# 2. Overnight Activity
echo "🌙 Overnight SSH Activity:"
ssh_login_history 10 | grep "$(date +%Y-%m-%d)" || echo "No logins today"
echo

# 3. Container Health
echo "🐳 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}" || echo "No containers running"
echo

# 4. Disk Space
echo "💾 Disk Usage:"
df -h / | tail -1
echo

# 5. Check for updates
echo "🔄 Security Updates:"
check-updates | grep -i security | head -5 || echo "System up to date"

echo
echo "✅ Morning check complete at $(date +%H:%M:%S)"
EOF

chmod +x ~/morning-security.sh

# Run it!
~/morning-security.sh
```

#### 5.2 Automated Incident Response
```bash
# Create an incident response script
cat > ~/respond-to-attack.sh << 'EOF'
#!/bin/bash
# Automated response to detected attack

SUSPICIOUS_IP=$1

if [ -z "$SUSPICIOUS_IP" ]; then
    echo "Usage: $0 <suspicious-ip>"
    exit 1
fi

echo "🚨 Responding to threat from $SUSPICIOUS_IP"

# 1. Block immediately
echo "🛡️ Blocking IP..."
ir-block-ip $SUSPICIOUS_IP

# 2. Capture evidence
echo "📸 Capturing evidence..."
ir-snapshot
mkdir -p ~/incidents/$(date +%Y%m%d)
mv /tmp/ir-snapshot-*.tar.gz ~/incidents/$(date +%Y%m%d)/

# 3. Check what they did
echo "🔍 Checking activity from $SUSPICIOUS_IP..."
grep "$SUSPICIOUS_IP" /var/log/auth.log | tail -20 > ~/incidents/$(date +%Y%m%d)/activity.log

# 4. Notify
echo "📧 Sending notification..."
./scripts/automation/notify.sh \
    "Security Incident" \
    "Blocked and investigated $SUSPICIOUS_IP" \
    "critical"

echo "✅ Response complete. Evidence in ~/incidents/$(date +%Y%m%d)/"
EOF

chmod +x ~/respond-to-attack.sh

# Test with a fake IP (won't actually block)
~/respond-to-attack.sh 10.99.99.99
```

#### 5.3 Weekly Security Audit Automation
```bash
# Create comprehensive weekly audit
cat > ~/weekly-audit.sh << 'EOF'
#!/bin/bash
source scripts/automation/parallel-framework.sh

AUDIT_DIR=~/audits/week-$(date +%U)
mkdir -p $AUDIT_DIR

echo "📊 Weekly Security Audit - $(date)"
echo "===================================="

# Parallel audit tasks
audit_tasks=(
    "docker images -q | xargs -I {} docker-scan {} > $AUDIT_DIR/docker-vulns.txt 2>&1"
    "./scripts/security/defensive-validation.sh > $AUDIT_DIR/validation.txt 2>&1"
    "lynis audit system --quick > $AUDIT_DIR/lynis.txt 2>&1"
    "ss -tulpn > $AUDIT_DIR/open-ports.txt 2>&1"
    "last -100 > $AUDIT_DIR/login-history.txt"
)

echo "Running audit tasks in parallel..."
parallel_execute audit_tasks 3

# Generate summary
cat > $AUDIT_DIR/summary.md << EOL
# Weekly Security Audit Summary
Date: $(date)

## Key Findings
- Docker vulnerabilities: $(grep -c "CRITICAL\|HIGH" $AUDIT_DIR/docker-vulns.txt 2>/dev/null || echo 0)
- Failed validations: $(grep -c "FAIL" $AUDIT_DIR/validation.txt 2>/dev/null || echo 0)
- Open ports: $(grep -c "LISTEN" $AUDIT_DIR/open-ports.txt 2>/dev/null || echo 0)
- Unique users logged in: $(cut -d' ' -f1 $AUDIT_DIR/login-history.txt | sort -u | wc -l)

## Action Items
1. Review high-priority vulnerabilities
2. Fix failed validations
3. Close unnecessary ports
EOL

echo "✅ Audit complete! Results in $AUDIT_DIR/"
echo "📄 Summary: $AUDIT_DIR/summary.md"
EOF

chmod +x ~/weekly-audit.sh

# Run the audit
~/weekly-audit.sh
```

### 📝 Exercise 5
1. Customize the morning security script for your needs
2. Run the weekly audit and review the results
3. Create your own automated workflow for a repetitive task

---

## 📚 Lesson 6: Building Your Security Dashboard (20 minutes)

### Objective
Deploy and customize your security monitoring dashboard.

### Step-by-Step Guide

#### 6.1 Deploy the Monitoring Stack
```bash
# Deploy everything with one command
./scripts/tools/deploy-security-stack.sh

# Wait for services to start (about 30 seconds)
sleep 30

# Verify everything is running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

#### 6.2 Access Your Dashboards
```bash
# Open Grafana in your browser
echo "Open: http://localhost:3000"
echo "Username: admin"
echo "Password: admin"

# First login will ask you to change password
```

#### 6.3 Import Security Dashboard
In Grafana:
1. Click "+" → "Import"
2. Enter ID: `1860` (Node Exporter Full)
3. Click "Load"
4. Select "Prometheus" as data source
5. Click "Import"

#### 6.4 Create Custom Alerts
```bash
# Add custom alert rule
cat >> monitoring/rules/my-alerts.yml << 'EOF'
groups:
  - name: my_security_alerts
    rules:
      - alert: TooManySSHFailures
        expr: rate(ssh_auth_failures[5m]) > 0.1
        for: 5m
        annotations:
          summary: "High rate of SSH failures"
          
      - alert: DiskSpaceLow
        expr: disk_free_percent < 10
        for: 5m
        annotations:
          summary: "Disk space below 10%"
EOF

# Restart Prometheus to load new rules
docker restart prometheus
```

### 📝 Exercise 6
1. Access Grafana and change the default password
2. Import at least one dashboard
3. Create a custom alert for high CPU usage

---

## 🎓 Final Project: Complete Security Integration (30 minutes)

### Objective
Combine everything you've learned into a comprehensive security system.

### Your Mission
Create a complete security monitoring and response system for a fictional company.

#### Step 1: Set Up the Environment
```bash
# Create project structure
mkdir -p ~/security-project/{scripts,configs,reports,incidents}
cd ~/security-project
```

#### Step 2: Create Master Security Script
```bash
cat > scripts/master-security.sh << 'EOF'
#!/bin/bash
# Master Security Control Script

source /opt/scripts/automation/parallel-framework.sh

# Configuration
COMPANY_NAME="AcmeCorp"
CRITICAL_SERVICES=("web-server" "database" "api-gateway")
MONITORED_IPS=("192.168.1.100" "192.168.1.101" "192.168.1.102")

# Function: Daily security check
daily_check() {
    echo "🔒 $COMPANY_NAME Daily Security Check"
    echo "===================================="
    
    # Check all critical services
    echo "Checking critical services..."
    for service in "${CRITICAL_SERVICES[@]}"; do
        if docker ps | grep -q "$service"; then
            echo "✅ $service: Running"
        else
            echo "❌ $service: DOWN - CRITICAL!"
            ./scripts/automation/notify.sh "Service Down" "$service is not running!" "critical"
        fi
    done
    
    # Security validation
    ./scripts/security/defensive-validation.sh | grep -E "Score|FAIL"
    
    # Generate report
    {
        echo "# Daily Security Report - $(date)"
        echo "Company: $COMPANY_NAME"
        echo
        security-status
        echo
        ssh_login_history 20
    } > reports/daily-$(date +%Y%m%d).md
}

# Function: Respond to threat
respond_to_threat() {
    local threat_ip=$1
    local threat_type=$2
    
    echo "🚨 Responding to $threat_type from $threat_ip"
    
    # Immediate response
    ir-block-ip "$threat_ip"
    ir-snapshot
    
    # Document incident
    local incident_id="INC$(date +%Y%m%d%H%M%S)"
    mkdir -p incidents/$incident_id
    
    # Parallel evidence collection
    evidence_tasks=(
        "grep '$threat_ip' /var/log/auth.log > incidents/$incident_id/auth.log"
        "docker logs web-server 2>&1 | grep '$threat_ip' > incidents/$incident_id/web.log"
        "netstat -an | grep '$threat_ip' > incidents/$incident_id/connections.txt"
    )
    
    parallel_execute evidence_tasks 3
    
    echo "✅ Incident $incident_id documented"
}

# Main menu
case "$1" in
    check) daily_check ;;
    threat) respond_to_threat "$2" "$3" ;;
    monitor) watch -n 60 "$0 check" ;;
    *) echo "Usage: $0 {check|threat <ip> <type>|monitor}" ;;
esac
EOF

chmod +x scripts/master-security.sh
```

#### Step 3: Set Up Automation
```bash
# Schedule daily checks
(crontab -l 2>/dev/null; echo "0 6 * * * $HOME/security-project/scripts/master-security.sh check") | crontab -

# Set up monitoring
screen -dmS security-monitor ~/security-project/scripts/master-security.sh monitor
```

#### Step 4: Test Your System
```bash
# Run daily check
./scripts/master-security.sh check

# Simulate threat response
./scripts/master-security.sh threat 10.0.0.99 "brute-force"

# Check monitoring
screen -r security-monitor  # Press Ctrl+A, D to detach
```

### 📝 Final Exercise
1. Customize the master script for your environment
2. Add at least one new security check
3. Create a report summarizing your security posture

---

## 🎉 Congratulations!

You've completed the hands-on security tutorial! You now know how to:

✅ Monitor system security  
✅ Detect and respond to SSH intrusions  
✅ Run containers securely  
✅ Use parallel processing for speed  
✅ Create automated security workflows  
✅ Deploy monitoring dashboards  

### 🚀 Next Steps

1. **Practice Daily**: Run `security-status` every morning
2. **Automate More**: Create scripts for repetitive tasks
3. **Stay Updated**: Run tool updates weekly
4. **Learn Continuously**: Try new security tools
5. **Share Knowledge**: Teach others what you've learned

### 📚 Additional Resources

- **Advanced Guide**: `AUTOMATION-COOKBOOK.md`
- **Quick Reference**: `SECURITY-QUICK-REFERENCE.md`
- **Troubleshooting**: `SECURITY-FEATURES-USER-GUIDE.md`

### 🆘 Getting Help

Remember:
- Use `help-security` for command help
- Check logs in `/var/log/security/`
- Review documentation in `docs/`
- Test in safe environments first

You're now equipped to maintain a secure environment. Keep learning, stay vigilant, and happy securing! 🛡️