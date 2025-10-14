# Quick Start Guide - Hyper-NixOS

## 🚀 **Get Started in 5 Minutes**

This guide gets you up and running with Hyper-NixOS quickly. For detailed information, see the [User Guide](USER_GUIDE.md).

## 📋 **Prerequisites**

- NixOS system (or NixOS installer)
- Basic familiarity with command line
- Network connection for downloading packages

## ⚡ **Quick Setup**

### 1. Clone the Configuration
```bash
git clone <repository-url> /etc/hypervisor
cd /etc/hypervisor
```

### 2. Choose Your Profile
```bash
# For production/server use (recommended)
echo 'hypervisor.security.profile = "headless";' >> configuration.nix

# For development/management use
echo 'hypervisor.security.profile = "management";' >> configuration.nix
```

### 3. Apply Configuration
```bash
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

### 4. Access the System
```bash
# Text-based menu (automatically starts on boot)
# OR
sudo /etc/hypervisor/scripts/menu.sh

# Web dashboard (if enabled)
firefox http://localhost:8080
```

## 🎯 **Common First Tasks**

### Enable GUI (Optional)
```nix
# Add to configuration.nix
hypervisor.gui.enableAtBoot = true;
```

### Enable Web Dashboard
```nix
# Add to configuration.nix
hypervisor.web.enable = true;
```

### Enable Monitoring
```nix
# Add to configuration.nix
hypervisor.monitoring.enablePrometheus = true;
hypervisor.monitoring.enableGrafana = true;
```

### Enable Automated Backups
```nix
# Add to configuration.nix
hypervisor.backup.enable = true;
hypervisor.backup.schedule = "daily";
```

## 🔧 **Basic Usage**

### Managing VMs
```bash
# List VMs
virsh list --all

# Start a VM
virsh start vm-name

# Stop a VM
virsh shutdown vm-name

# Connect to VM console
virsh console vm-name
```

### Using the Menu System
```bash
# Main menu
sudo /etc/hypervisor/scripts/menu.sh

# VM management
sudo /etc/hypervisor/scripts/vm_manager.sh

# Network setup
sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
```

### Checking System Status
```bash
# System services
systemctl status hypervisor-menu
systemctl status hypervisor-web-dashboard

# Logs
journalctl -u hypervisor-menu -f
journalctl -u libvirtd -f
```

## 🆘 **Quick Troubleshooting**

### Build Errors
```bash
# Check for syntax errors
nixos-rebuild dry-build --show-trace

# Check specific issues
nix-instantiate --eval --strict configuration.nix
```

### Service Issues
```bash
# Check service status
systemctl status <service-name>

# View logs
journalctl -u <service-name> -f

# Restart service
sudo systemctl restart <service-name>
```

### Permission Issues
```bash
# Check user groups
groups $USER

# Add user to required groups
sudo usermod -a -G libvirtd,kvm $USER
```

## 📚 **Next Steps**

- **Complete Setup**: Read the [User Guide](USER_GUIDE.md) for detailed configuration
- **Security**: Review the [Security Model](../admin-guides/SECURITY_MODEL.md)
- **Networking**: Configure networking with [Network Configuration](../admin-guides/NETWORK_CONFIGURATION.md)
- **Monitoring**: Set up observability with [Monitoring Setup](../admin-guides/MONITORING_SETUP.md)
- **Troubleshooting**: Check [Common Issues](../COMMON_ISSUES_AND_SOLUTIONS.md) for problems

## 🎯 **Success Indicators**

You've successfully set up Hyper-NixOS when:
- ✅ System boots without errors
- ✅ Menu system is accessible
- ✅ libvirtd service is running
- ✅ You can list VMs with `virsh list`
- ✅ Web dashboard loads (if enabled)
- ✅ No infinite recursion or build errors

Welcome to Hyper-NixOS! 🎉