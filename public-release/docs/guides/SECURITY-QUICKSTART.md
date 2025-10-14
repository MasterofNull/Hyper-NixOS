# Security Platform Quick Start Guide

Get up and running with the security platform in minutes!

## 🚀 5-Minute Setup

### 1. Install (1 minute)
```bash
# Deploy with auto-detection
sudo ./security-platform-deploy.sh
./profile-selector.sh --auto
```

### 2. Activate Console (30 seconds)
```bash
# Enable enhanced terminal features
source /opt/security-platform/console/activate.sh
```

### 3. First Security Check (1 minute)
```bash
# Run comprehensive check
sec check
```

### 4. Start Monitoring (30 seconds)
```bash
# Begin real-time monitoring
sec monitor start
```

### 5. View Status (1 minute)
```bash
# Check platform status
sec status
```

## 🎯 Common Tasks

### Network Security Scan
```bash
# Quick scan of local network
sec scan 192.168.1.0/24

# Deep scan of specific host
sec scan 192.168.1.100 --deep

# Stealth scan
sec scan target.com --stealth
```

### Container Security
```bash
# Scan all containers
sec check containers

# Scan specific image
sec scan image nginx:latest

# Monitor container security
sec monitor containers
```

### Incident Response
```bash
# View security alerts
sec alert list

# Investigate incident
sec ai analyze --incident-id 12345

# Start threat hunt
sec hunt --technique T1055
```

### API Security
```bash
# Check API gateway status
sec api status

# Create API key
sec api keys create --client myapp

# Validate request
sec api validate --endpoint /api/v1/users
```

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Quick security status |
| `Ctrl+X,S` | Start security scan |
| `Ctrl+X,C` | Run security check |
| `Ctrl+X,A` | Show alerts |
| `Ctrl+R` | Search command history |

## 🎨 Console Features

### Fuzzy Search
```bash
# Search security logs
fsec

# Find and analyze alerts
sec alert list | fzf

# Interactive process kill
fkill
```

### Security Functions
```bash
# Generate secure password
genpass 20

# Check SSL certificate
check-ssl example.com

# Monitor specific service
monitor-service nginx
```

## 📊 Dashboards

### Start Monitoring Dashboard
```bash
# Launch tmux security session
~/.security/console/tmux-security-session.sh
```

### Grafana Dashboards
Access at http://localhost:3000
- Security Overview
- Container Security
- Threat Detection
- Compliance Status

## 🔍 Quick Troubleshooting

### Check Installation
```bash
# Verify installation
sec help

# Check module status
sec status --modules

# View logs
sec logs
```

### Common Issues

**Command not found**
```bash
source ~/.bashrc
# or
export PATH="/opt/security-platform/bin:$PATH"
```

**Permission denied**
```bash
# Most commands need sudo for system scanning
sudo sec scan
```

**Module not loaded**
```bash
# Check profile
sec profile --show

# Switch to profile with needed module
sec profile --advanced
```

## 🎚️ Profile Management

### View Current Profile
```bash
sec profile --show
```

### Change Profile
```bash
# Minimal (containers, IoT)
sec profile --minimal

# Standard (servers)
sec profile --standard  

# Advanced (security teams)
sec profile --advanced

# Enterprise (large orgs)
sec profile --enterprise
```

## 📱 Mobile Security

```bash
# Scan mobile device
sec mobile scan --device android-001

# Enroll device
sec mobile enroll --device iphone-123 --user john

# Apply security policy
sec mobile policy --strict
```

## 🔗 Supply Chain Security

```bash
# Generate SBOM
sec supply sbom .

# Scan dependencies
sec supply scan

# Sign artifact
sec supply sign app.tar.gz
```

## 🤖 AI Features

```bash
# Run AI analysis
sec ai analyze

# Train on new data
sec ai train --data /path/to/logs

# Predict threats
sec ai predict
```

## 📈 Reporting

```bash
# Generate security report
sec report generate --format pdf

# Compliance report
sec report compliance --framework cis

# Executive summary
sec report summary --exec
```

## 🆘 Getting Help

```bash
# General help
sec help

# Command-specific help
sec scan --help

# Show examples
sec examples

# Interactive guide
sec guide
```

## 📚 Next Steps

1. **Explore Modules**: Try different security modules
2. **Customize**: Edit `~/.security/profile.conf`
3. **Automate**: Set up scheduled scans
4. **Integrate**: Connect to your SIEM/tools
5. **Learn**: Read full documentation

---

**Pro Tip**: Use `sec` + `Tab` for auto-completion of commands!

**Support**: See `/opt/security-platform/docs/` for detailed guides