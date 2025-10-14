# Security Framework Quick Reference

## Command Cheat Sheet

### 🔍 Security Status & Validation
```bash
security-status                    # Overall security health check
./scripts/security/defensive-validation.sh          # Comprehensive defense validation
./scripts/security/defensive-validation.sh | grep FAIL  # Show only failures
harden-check                      # Security hardening checklist
```

### 🔐 SSH Security
```bash
sshm user@host                    # SSH with auto-mount
ssh_login_history [count]         # View recent SSH logins
ssh_active_sessions              # Show current SSH sessions
ir-block-ip <IP>                 # Block suspicious IP immediately

# Whitelist management
echo "192.168.1.100" | sudo tee -a /etc/ssh/whitelist.ips
```

### 🐳 Docker Security
```bash
docker-safe run -v ./data:/data image    # Safe docker run
docker-scan <image>                      # Scan single image
docker-scan $(docker images -q | head -1) # Scan latest image
docker-cache <name> <generate> <serve>   # Smart caching
docker-clean <pattern>                   # Clean by pattern

# Scan all images
docker images --format "{{.Repository}}:{{.Tag}}" | xargs -I {} docker-scan {}
```

### ⚡ Parallel Execution
```bash
# Source framework
source scripts/automation/parallel-framework.sh

# Define and run tasks
tasks=("cmd1" "cmd2" "cmd3")
parallel_execute tasks 5          # Max 5 concurrent

# Parallel map
parallel_map "gzip -9" *.log     # Compress all logs

# Git updates
./scripts/automation/parallel-git-update.sh repos.txt
```

### 🚨 Incident Response
```bash
ir-snapshot                       # Capture system state
ir-block-ip <IP>                 # Block malicious IP
ir-kill <PID>                    # Kill suspicious process
security-report                  # Generate security report

# Full IR workflow
./scripts/security/incident-response-workflow.sh
```

### 📊 Monitoring & Alerts
```bash
# Deploy monitoring stack
./scripts/tools/deploy-security-stack.sh

# Configure notifications
mkdir -p ~/.config/security
echo 'WEBHOOK_URL="https://..."' > ~/.config/security/webhooks.conf

# Test notification
./scripts/automation/notify.sh "Test" "Message" "info"
```

### 🔄 Automation
```bash
# Security scan
./scripts/security/automated-security-scan.sh

# Update all tools
./security-control.sh update

# Container updates
./scripts/automation/docker-update-all.sh
```

## Configuration Files

### SSH Enhanced Module
```nix
# /etc/nixos/configuration.nix
security.ssh.enhanced = {
  enable = true;
  autoMount = true;
  loginMonitoring = true;
  webhookUrl = "https://hooks.slack.com/...";
  whitelistIPs = [ "10.0.0.0/8" ];
};
```

### Docker Enhanced Module
```nix
security.docker.enhanced = {
  enable = true;
  volumeRestrictions = [ "/" "/etc" "/root" ];
  securityScanning = true;
  resourceLimits = {
    memory = "4g";
    cpus = "2.0";
  };
};
```

## Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc
export MAX_PARALLEL_JOBS=5
export SECURITY_LOG_DAYS=30
export DOCKER_SCAN_ON_PULL=true
export SSH_MONITOR_ALERTS=true

# Aliases
alias ss='security-status'
alias sshlog='ssh_login_history'
alias dscan='docker-scan'
alias pexec='parallel_execute'
```

## Service Management

```bash
# SSH Monitor
sudo systemctl status ssh-monitor
sudo systemctl restart ssh-monitor
journalctl -u ssh-monitor -f

# Docker Security Scan
sudo systemctl status docker-security-scan.timer
sudo systemctl start docker-security-scan.service

# Security services
for svc in prometheus grafana node-exporter; do
  sudo systemctl status $svc
done
```

## Common Patterns

### Parallel Security Scan
```bash
#!/bin/bash
source scripts/automation/parallel-framework.sh

targets=($(cat targets.txt))
scan_tasks=()

for target in "${targets[@]}"; do
    scan_tasks+=("nmap -sV $target -oA scans/$target")
done

parallel_execute scan_tasks 5
```

### Automated Backup
```bash
#!/bin/bash
source scripts/automation/parallel-framework.sh

backup_tasks=(
    "rsync -av /important/ /backup/important/"
    "docker exec mysql mysqldump -u root -p db > /backup/db.sql"
    "tar -czf /backup/configs.tar.gz /etc/"
)

parallel_execute backup_tasks 3
```

### Container Deploy Pipeline
```bash
#!/bin/bash
IMAGE="myapp:latest"

# Build
docker build -t $IMAGE .

# Scan
if docker-scan $IMAGE | grep -q CRITICAL; then
    echo "Critical vulnerabilities found!"
    exit 1
fi

# Deploy
docker-safe run -d --name myapp -p 8080:80 $IMAGE
```

## Troubleshooting

### Quick Fixes
```bash
# SSH monitoring not working
sudo systemctl restart ssh-monitor
tail -f /var/log/security/ssh-monitor.log

# Docker commands blocked
/usr/bin/docker run ...  # Bypass wrapper
vim configs/docker/security-policy.json  # Edit policy

# Parallel jobs stuck
pkill -f parallel_execute
rm -f /tmp/parallel-logs/*

# Monitoring down
docker-compose -f monitoring/docker-compose.yml restart

# No notifications
test -f ~/.config/security/webhooks.conf || echo "Configure webhooks!"
```

### Debug Commands
```bash
# System state
ss -tulpn | grep LISTEN
ps auxf | grep -E "security|monitor"
docker ps --format "table {{.Names}}\t{{.Status}}"

# Logs
tail -f /var/log/security/*.log
journalctl -f -u ssh-monitor
docker logs -f prometheus

# Performance
top -b -n 1 | head -20
df -h
free -h
```

## Performance Tuning

```bash
# Parallel execution
export MAX_PARALLEL_JOBS=8  # For 8+ core systems

# Docker limits
cat >> configs/docker/daemon.json << EOF
{
  "default-ulimits": {
    "nofile": {
      "Hard": 128000,
      "Soft": 128000
    }
  }
}
EOF

# System limits
echo "* soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65535" | sudo tee -a /etc/security/limits.conf
```

## Integration Examples

### Slack Integration
```bash
#!/bin/bash
WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"

send_slack() {
    curl -X POST $WEBHOOK_URL \
        -H 'Content-type: application/json' \
        -d "{\"text\":\"$1\"}"
}

# Use in scripts
ssh_login_history | grep -v whitelist | while read line; do
    send_slack "SSH Login: $line"
done
```

### Prometheus Metrics
```bash
# Custom metric
echo "security_scan_duration_seconds{target=\"$TARGET\"} $DURATION" \
    | curl --data-binary @- http://localhost:9091/metrics/job/security_scan
```

### CI/CD Integration
```yaml
# .gitlab-ci.yml
security-scan:
  script:
    - docker-scan $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - ./scripts/security/defensive-validation.sh
  only:
    - master
```

## Advanced Tips

1. **Chain commands**: `security-status && docker ps && ssh_login_history`
2. **Background monitoring**: `nohup ./monitor.sh > monitor.log 2>&1 &`
3. **Cron automation**: `*/5 * * * * /opt/scripts/security-check.sh`
4. **Remote execution**: `ssh server 'bash -s' < local-script.sh`
5. **Bulk operations**: `cat servers.txt | xargs -P 5 -I {} ssh {} 'command'`

## Quick Links

- Control Center: `./security-control.sh`
- Full Documentation: `docs/user-guides/`
- Automation Recipes: `docs/user-guides/AUTOMATION-COOKBOOK.md`
- Troubleshooting: `docs/user-guides/SECURITY-FEATURES-USER-GUIDE.md#troubleshooting`