# Security Features User Guide

## Welcome to Your Enhanced Security System! 🛡️

This guide will walk you through all the new security features, from basic usage to advanced techniques. Whether you're new to security tools or an experienced administrator, you'll find valuable information here.

## Table of Contents
1. [Quick Start for Beginners](#quick-start-for-beginners)
2. [Understanding Your Security Tools](#understanding-your-security-tools)
3. [Daily Security Tasks](#daily-security-tasks)
4. [Advanced Features](#advanced-features)
5. [Troubleshooting](#troubleshooting)

---

## Quick Start for Beginners

### Your First Day with the Security System

Let's start with the basics. Open a terminal and follow along:

#### 1. **Check Your Security Status**
```bash
# This command shows you the current security status of your system
security-status

# What you'll see:
# - Firewall status (should be "active")
# - Recent login attempts
# - Active connections
# - Running services
```

**🎯 Learning Point**: This is like a health check for your system's security. Run it daily!

#### 2. **View Recent SSH Logins**
```bash
# See who has logged into your system
ssh_login_history

# You'll see something like:
# [2024-01-15 10:23:45] SSH Login - User: john, From: 192.168.1.100
```

**🎯 Learning Point**: Any IP address you don't recognize? That's worth investigating!

#### 3. **Run a Basic Security Scan**
```bash
# Check for common security issues
harden-check

# You'll see checkmarks (✓) for good configurations
# and X marks (✗) for things that need attention
```

### Your Security Command Center

We've created a simple menu system for you:

```bash
# Launch the security control center
./security-control.sh

# You'll see a menu like this:
# 1. Run Security Validation
# 2. Deploy Security Stack
# 3. Run Security Scan
# ...
```

**🎯 Pro Tip**: Start with option 1 (Security Validation) to see what needs attention!

---

## Understanding Your Security Tools

### 🔐 SSH Security Features

#### What It Does
- **Monitors every login** to your system
- **Alerts you** when someone connects from a new location
- **Automatically mounts** remote filesystems for easy access

#### How to Use It

**Basic SSH with Auto-Mount:**
```bash
# Instead of regular SSH, use our enhanced version
sshm user@remote-server

# What happens:
# 1. Creates a secure connection
# 2. Mounts the remote filesystem locally
# 3. You can browse remote files like they're on your computer!
# 4. Automatically unmounts when you disconnect
```

**Example Scenario:**
```bash
# Sarah needs to work on files on the company server
sshm sarah@company-server.com

# Now she can:
cd ~/mnt/company-server_*/home/sarah
ls  # See her remote files
cp important.doc ~/Desktop/  # Copy files easily!
```

#### Monitoring SSH Access

**Set Up Whitelisted IPs** (IPs that won't trigger alerts):
```bash
# Edit the whitelist
sudo nano /etc/ssh/whitelist.ips

# Add trusted IPs (one per line):
192.168.1.100  # Office network
10.0.0.50      # Home IP
```

**View SSH Activity Dashboard:**
```bash
# See login patterns and alerts
ssh_active_sessions  # Who's logged in right now
ssh_login_history 20  # Last 20 logins
```

### 🐳 Docker Security Features

#### What It Does
- **Prevents dangerous container operations**
- **Scans images for vulnerabilities**
- **Manages resources** to prevent system overload

#### Safe Docker Usage

**Running Containers Safely:**
```bash
# DON'T do this (unsafe):
docker run -v /:/host ubuntu

# DO this instead (safe):
docker-safe run -v ./data:/app/data ubuntu

# The system will block dangerous volume mounts!
```

**Scanning for Vulnerabilities:**
```bash
# Scan a specific image
docker-scan nginx:latest

# Scan all your images (coffee break time!)
for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
    docker-scan "$image"
done
```

**Smart Container Management:**
```bash
# Deploy with caching (saves time and bandwidth)
docker-cache "my-analysis" \
    "docker run analyzer:latest generate-data" \
    "docker run -d -p 8080:80 viewer:latest"

# Clean up test containers
docker-clean "test-*"  # Removes all containers starting with "test-"
```

### ⚡ Parallel Execution (Speed Boost!)

#### What It Does
- **Runs multiple tasks simultaneously**
- **Reduces waiting time by 60-80%**
- **Shows progress in real-time**

#### Basic Usage

**Example: Scanning Multiple Servers**
```bash
# Old way (one at a time): ~15 minutes
nmap server1
nmap server2
nmap server3

# New way (all at once): ~5 minutes!
cat > targets.txt << EOF
server1
server2
server3
EOF

parallel-scan targets.txt
```

**Example: Updating Multiple Git Repositories**
```bash
# Create a list of repositories
cat > repos.txt << EOF
https://github.com/security/tool1|/opt/tools/tool1
https://github.com/security/tool2|/opt/tools/tool2
EOF

# Update them all at once!
./scripts/automation/parallel-git-update.sh repos.txt
```

---

## Daily Security Tasks

### Morning Security Checklist ☀️

Here's a 5-minute routine to keep your system secure:

```bash
# 1. Check security status (30 seconds)
security-status

# 2. Review recent logins (1 minute)
ssh_login_history 10

# 3. Check for security updates (1 minute)
check-updates

# 4. Review active Docker containers (30 seconds)
docker ps

# 5. Quick validation (2 minutes)
./scripts/security/defensive-validation.sh | grep FAIL
```

### Weekly Security Maintenance 🔧

Every Monday morning:

```bash
# 1. Full security scan (runs in background)
./security-control.sh scan &

# 2. Update security tools
./security-control.sh update

# 3. Review the week's SSH activity
ssh_login_history 100 | grep -v "192.168"  # Hide local network

# 4. Clean up old logs and temporary files
cleanup-temp 7  # Remove files older than 7 days
```

### Responding to Alerts 🚨

When you get a security alert:

**Step 1: Don't Panic!**
Most alerts are informational. Take a breath.

**Step 2: Investigate**
```bash
# For SSH alerts
ssh_login_history | grep "WARNING\|CRITICAL"

# For Docker alerts
docker ps -a | grep -i privileged

# For general alerts
tail -f /var/log/security/alerts.log
```

**Step 3: Take Action**
```bash
# Block suspicious IP
ir-block-ip 185.234.567.89

# Stop suspicious container
docker stop suspicious-container
docker rm suspicious-container

# Generate incident report
./security-control.sh report
```

---

## Advanced Features

### Creating Custom Security Workflows

#### Automated Morning Report
```bash
# Create a script that runs every morning
cat > ~/morning-security-report.sh << 'EOF'
#!/bin/bash
echo "Security Report for $(date +%Y-%m-%d)"
echo "===================================="
echo
echo "Overnight SSH Activity:"
ssh_login_history 50 | grep "$(date +%Y-%m-%d)"
echo
echo "Container Health:"
docker ps --format "table {{.Names}}\t{{.Status}}"
echo
echo "Security Validation:"
./scripts/security/defensive-validation.sh | grep -E "PASS|FAIL" | tail -10
EOF

chmod +x ~/morning-security-report.sh

# Add to crontab
echo "0 8 * * * $HOME/morning-security-report.sh | mail -s 'Morning Security Report' you@email.com" | crontab -
```

#### Custom Parallel Workflows

**Example: Multi-Site Security Audit**
```bash
# Create audit script
cat > audit-all-sites.sh << 'EOF'
#!/bin/bash
source /opt/scripts/automation/parallel-framework.sh

# Define audit tasks
audit_tasks=(
    "nmap -sV site1.com -oA reports/site1"
    "nikto -h site1.com -o reports/site1-nikto.txt"
    "nmap -sV site2.com -oA reports/site2"
    "nikto -h site2.com -o reports/site2-nikto.txt"
    "testssl.sh site1.com > reports/site1-ssl.txt"
    "testssl.sh site2.com > reports/site2-ssl.txt"
)

# Run all audits in parallel (max 4 at once)
parallel_execute audit_tasks 4

echo "Audit complete! Check reports/ directory"
EOF
```

### Integrating with Other Tools

#### Slack Notifications
```bash
# Configure webhook
mkdir -p ~/.config/security
cat > ~/.config/security/webhooks.conf << EOF
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
SECURITY_EMAIL="security-team@company.com"
EOF

# Test notification
./scripts/automation/notify.sh "Test Alert" "Security system is configured!" "info"
```

#### Grafana Dashboards
```bash
# Access your security dashboards
echo "Open in your browser:"
echo "  http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin (change this!)"
echo ""
echo "Recommended dashboards to import:"
echo "  - Security Overview (ID: 13435)"
echo "  - Docker Monitor (ID: 893)"
echo "  - SSH Analytics (ID: 14037)"
```

---

## Troubleshooting

### Common Issues and Solutions

#### "Permission Denied" Errors
```bash
# Problem: Can't run security commands
# Solution: Add yourself to security groups
sudo usermod -aG docker $USER
sudo usermod -aG sudo $USER
# Log out and back in
```

#### SSH Monitoring Not Working
```bash
# Check if service is running
systemctl status ssh-monitor

# View logs
journalctl -u ssh-monitor -f

# Restart service
sudo systemctl restart ssh-monitor
```

#### Docker Commands Blocked
```bash
# Temporarily bypass security (use carefully!)
/usr/bin/docker run ...  # Uses original docker

# Or add directory to allowed list
sudo nano /etc/docker/allowed-paths.conf
# Add your working directory
```

#### Parallel Jobs Hanging
```bash
# See what's running
ps aux | grep parallel

# Check job logs
ls -la /tmp/parallel-logs/

# Kill stuck jobs
pkill -f parallel_execute
```

### Getting Help

1. **Built-in Help:**
   ```bash
   help-security  # Show all security commands
   man docker-safe  # Detailed command help
   ```

2. **Check Logs:**
   ```bash
   # Security logs
   sudo tail -f /var/log/security/*.log
   
   # System logs
   journalctl -f
   ```

3. **Generate Diagnostic Report:**
   ```bash
   ./security-control.sh report
   # Share this with support
   ```

---

## Best Practices Summary

### 🌟 Golden Rules

1. **Run `security-status` daily**
2. **Review SSH logins weekly**
3. **Keep tools updated monthly**
4. **Use `docker-safe` instead of `docker`**
5. **Investigate all alerts promptly**

### 📊 Recommended Defaults

```bash
# ~/.bashrc additions for convenience
alias ss='security-status'
alias ssh-log='ssh_login_history'
alias d='docker-safe'
alias scan='./security-control.sh scan'

# Default security settings
export PARALLEL_JOBS=4  # Good for most systems
export SECURITY_LOG_DAYS=30  # Keep logs for 30 days
export DOCKER_SCAN_ON_PULL=true  # Always scan new images
```

### 🎓 Learning Path

1. **Week 1**: Master basic commands (security-status, ssh monitoring)
2. **Week 2**: Learn Docker security features
3. **Week 3**: Start using parallel execution
4. **Week 4**: Create your first automated workflow
5. **Month 2**: Customize for your environment

---

## Quick Reference Card

Print this and keep it handy:

```
ESSENTIAL SECURITY COMMANDS
=========================
Daily Checks:
  security-status         - Overall security health
  ssh_login_history      - Recent SSH logins
  docker ps              - Running containers
  
Investigations:
  ir-snapshot            - Capture system state
  ir-block-ip <IP>      - Block suspicious IP
  docker-scan <image>    - Scan for vulnerabilities
  
Maintenance:
  check-updates          - Security updates available
  docker-clean "test-*"  - Clean up containers
  cleanup-temp 7         - Remove old temp files
  
Help:
  help-security          - Show all commands
  ./security-control.sh  - Interactive menu
```

Remember: Security is a journey, not a destination. Start small, be consistent, and gradually expand your usage of these tools. You've got this! 🚀