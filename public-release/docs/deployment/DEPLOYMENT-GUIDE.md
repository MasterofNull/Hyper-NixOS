# Security Platform Deployment Guide

## 📋 Table of Contents
1. [System Requirements](#system-requirements)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Installation Methods](#installation-methods)
4. [Profile Selection](#profile-selection)
5. [Post-Installation](#post-installation)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

## 💻 System Requirements

### Minimum Requirements (Minimal Profile)
- **OS**: Linux (Ubuntu 20.04+, RHEL 8+, Debian 10+)
- **CPU**: 2 cores
- **RAM**: 1GB (512MB for platform)
- **Storage**: 500MB
- **Python**: 3.8+
- **Network**: Internet for updates

### Recommended Requirements (Standard Profile)
- **OS**: Linux (Ubuntu 22.04, RHEL 9)
- **CPU**: 4 cores
- **RAM**: 4GB (2GB for platform)
- **Storage**: 5GB
- **Python**: 3.10+
- **Docker**: 20.10+ (optional)

### Enterprise Requirements
- **CPU**: 8+ cores
- **RAM**: 32GB (16GB for platform)
- **Storage**: 50GB SSD
- **Network**: Dedicated security VLAN
- **Additional**: PostgreSQL, Redis, Elasticsearch

## ✅ Pre-Deployment Checklist

### 1. System Preparation
```bash
# Update system
sudo apt update && sudo apt upgrade -y  # Debian/Ubuntu
sudo yum update -y                       # RHEL/CentOS

# Install prerequisites
sudo apt install -y python3 python3-pip git curl wget
sudo yum install -y python3 python3-pip git curl wget

# Verify Python version
python3 --version  # Should be 3.8+
```

### 2. User Permissions
```bash
# Create security user (optional)
sudo useradd -m -s /bin/bash secops
sudo usermod -aG sudo secops  # Or wheel for RHEL

# Or use existing user with sudo
groups  # Should show sudo or wheel
```

### 3. Network Configuration
```bash
# Check network connectivity
ping -c 4 google.com
curl -I https://github.com

# Firewall rules (if needed)
sudo ufw allow 8443/tcp  # API port
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus
```

## 🚀 Installation Methods

### Method 1: Automated Installation (Recommended)
```bash
# Clone repository
git clone <repository-url> security-platform
cd security-platform

# Run automated installer
sudo ./security-platform-deploy.sh

# Auto-select optimal profile
./profile-selector.sh --auto
```

### Method 2: Manual Profile Installation
```bash
# Choose specific profile
./modular-security-framework.sh --standard

# Or interactive selection
./modular-security-framework.sh
```

### Method 3: Docker Installation
```bash
# Build Docker image
docker build -t security-platform:v2.0 .

# Run container
docker run -d \
  --name security-platform \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e SECURITY_PROFILE=standard \
  -p 8443:8443 \
  security-platform:v2.0
```

### Method 4: Kubernetes Deployment
```bash
# Apply configurations
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check deployment
kubectl get pods -n security-platform
```

## 🎚️ Profile Selection

### Understanding Profiles

| Profile | Use Case | Resources | Modules |
|---------|----------|-----------|---------|
| **Minimal** | Containers, IoT | <512MB RAM | Core only |
| **Standard** | Servers, VMs | <2GB RAM | +Compliance |
| **Advanced** | SOC teams | <4GB RAM | +AI, Forensics |
| **Enterprise** | Large orgs | <16GB RAM | All modules |

### Selecting a Profile

#### Automatic Selection
```bash
# Let the system choose
./profile-selector.sh --auto
```

#### Manual Selection
```bash
# View current profile
./profile-selector.sh --show

# Select specific profile
./profile-selector.sh --standard
./profile-selector.sh --advanced
./profile-selector.sh --enterprise
```

#### Custom Profile
```bash
# Interactive custom selection
./profile-selector.sh --select
# Choose option 5 for custom
```

## 🔧 Post-Installation

### 1. Activate Console Enhancements
```bash
# Source activation script
source /opt/security-platform/console/activate.sh

# Add to shell profile
echo 'source /opt/security-platform/console/activate.sh' >> ~/.bashrc
source ~/.bashrc
```

### 2. Configure System Service
```bash
# Enable service
sudo systemctl enable security-platform
sudo systemctl start security-platform

# Check status
sudo systemctl status security-platform
```

### 3. Initial Configuration
```bash
# Run initial setup
sec setup

# Configure API keys (if needed)
sec api keys create --admin

# Set up monitoring
sec monitor setup
```

### 4. Database Setup (Enterprise)
```bash
# PostgreSQL
sudo -u postgres createdb security_platform
sudo -u postgres createuser -P secops

# Redis
sudo systemctl enable redis
sudo systemctl start redis

# Elasticsearch
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch
```

## ✔️ Verification

### 1. Basic Functionality
```bash
# Check installation
sec help

# Verify version
sec version

# List modules
sec status --modules
```

### 2. Run Test Suite
```bash
# Quick tests
./audit-platform.sh

# Comprehensive tests
./test-platform-features.sh

# Validate implementation
./validate-implementation.sh
```

### 3. Security Scan Test
```bash
# Scan localhost
sec scan localhost

# Check system
sec check

# View results
sec report last
```

### 4. Monitor Dashboard
```bash
# Start monitoring
sec monitor start

# Access dashboards
# Grafana: http://localhost:3000
# Default: admin/admin
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Command Not Found
```bash
# Fix PATH
export PATH="/opt/security-platform/bin:$PATH"

# Or reinstall shell integration
source /opt/security-platform/console/activate.sh
```

#### 2. Permission Denied
```bash
# Fix permissions
sudo chown -R $USER:$USER ~/.security
sudo chmod -R 755 /opt/security-platform/bin
```

#### 3. Module Not Loading
```bash
# Check profile
sec profile --show

# Reinstall module
./module-installer.sh --module ai_detection
```

#### 4. Python Import Errors
```bash
# Install dependencies
pip3 install -r requirements.txt

# Or use virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Log Files
```bash
# Platform logs
/var/log/security-platform/platform.log

# Module logs
/var/log/security-platform/modules/*.log

# System logs
journalctl -u security-platform -f
```

### Getting Help
```bash
# Built-in help
sec help
sec <command> --help

# Diagnostic info
sec debug --info

# Support logs
sec debug --collect-logs
```

## 🚨 Security Considerations

### 1. Hardening
```bash
# Restrict file permissions
sudo chmod 700 /opt/security-platform/config
sudo chmod 600 /opt/security-platform/config/*

# Enable audit logging
sec config set audit.enabled true
```

### 2. Network Security
```bash
# Bind to localhost only
sec config set api.bind 127.0.0.1

# Enable TLS
sec config set api.tls.enabled true
sec config set api.tls.cert /path/to/cert
sec config set api.tls.key /path/to/key
```

### 3. Access Control
```bash
# Enable authentication
sec config set auth.enabled true

# Create users
sec users create --username admin --role admin
sec users create --username analyst --role user
```

## 📊 Performance Tuning

### Resource Limits
```bash
# Set memory limit
sec config set performance.max_memory 4G

# Set CPU limit
sec config set performance.max_cpu_percent 75

# Configure workers
sec config set performance.worker_threads 4
```

### Optimization
```bash
# Enable caching
sec config set cache.enabled true
sec config set cache.size 1G

# Optimize scanning
sec config set scanner.parallel_scans 4
sec config set scanner.timeout 300
```

## 🎯 Next Steps

1. **Run Initial Scan**: `sec scan --quick`
2. **Set Up Alerts**: `sec alert config`
3. **Schedule Scans**: `sec schedule create`
4. **Review Reports**: `sec report`
5. **Customize Policies**: `sec policy edit`

---

**Support**: See `/opt/security-platform/docs/` for detailed documentation