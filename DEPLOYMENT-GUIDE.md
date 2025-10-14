# Security Framework Deployment Guide

## Prerequisites

1. NixOS system (or Linux with Nix installed)
2. Docker installed and running
3. Sudo privileges
4. At least 4GB RAM and 20GB disk space

## Deployment Steps

### 1. Initial Setup

```bash
# Clone or ensure you're in the project directory
cd /path/to/project

# Run the implementation script
./implement-all-suggestions.sh

# Source the new configurations
source ~/.bashrc  # or ~/.zshrc
```

### 2. NixOS Configuration

```bash
# Link the enhanced configuration
sudo ln -sf $(pwd)/configuration-enhanced.nix /etc/nixos/configuration.nix

# Rebuild the system
sudo nixos-rebuild switch
```

### 3. Deploy Security Stack

```bash
# Deploy monitoring and security tools
./scripts/tools/deploy-security-stack.sh

# Verify deployment
docker ps
```

### 4. Configure Notifications

```bash
# Create webhook configuration
mkdir -p ~/.config/security
cat > ~/.config/security/webhooks.conf << 'EOL'
WEBHOOK_URL="https://your.webhook.url"
SECURITY_EMAIL="security@example.com"
EOL
```

### 5. Run Initial Security Scan

```bash
# Create targets file
cat > targets.txt << 'EOL'
localhost
192.168.1.1
192.168.1.100
EOL

# Run security scan
./scripts/security/automated-security-scan.sh
```

### 6. Verify Installation

```bash
# Run integration tests
./tests/integration-test-security.sh

# Check system status
systemctl status ssh-monitor
systemctl status docker-security-scan.timer

# View logs
journalctl -u ssh-monitor -f
```

## Access Points

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **Node Exporter**: http://localhost:9100/metrics
- **cAdvisor**: http://localhost:8080
- **Logs**: `/var/log/security/`

## Daily Operations

1. **Check Security Dashboard**: Open Grafana and review the Security Overview
2. **Review Alerts**: Check Prometheus alerts for any security issues
3. **Monitor SSH Access**: `tail -f /var/log/ssh-monitor.log`
4. **Update Security Tools**: `./scripts/automation/parallel-git-update.sh`

## Troubleshooting

### SSH Monitoring Not Working
```bash
# Check service status
systemctl status ssh-monitor

# Test manually
source scripts/security/ssh-monitor.sh
```

### Docker Security Blocks Legitimate Operation
```bash
# Temporarily use standard docker
/usr/bin/docker run ...

# Or update security policy
vim configs/docker/security-policy.json
```

### Parallel Jobs Hanging
```bash
# Check job logs
ls -la /tmp/parallel-logs/

# Kill stuck jobs
pkill -f parallel_execute
```

## Maintenance

### Weekly Tasks
- Review security scan results
- Update security tool images
- Check for configuration updates

### Monthly Tasks
- Rotate logs
- Review and update whitelists
- Performance tuning
- Security audit

## Support

For issues or questions:
1. Check logs in `/var/log/security/`
2. Run integration tests
3. Review this guide
4. Check the documentation in `docs/`
