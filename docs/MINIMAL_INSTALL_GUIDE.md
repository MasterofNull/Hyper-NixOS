# Hyper-NixOS Minimal Installation Guide

## Overview

The Hyper-NixOS minimal installer provides a streamlined installation process that:

1. **Installs a minimal base configuration** - Just enough to boot and run the setup wizard
2. **Migrates existing users** - Preserves your current usernames and passwords  
3. **Prepares for first boot** - Sets up the configuration wizard that runs on first boot

## Quick Install

### One-line Install (Recommended)

```bash
curl -L https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install-minimal.sh | sudo bash
```

### Manual Install

```bash
# Clone the repository
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd Hyper-NixOS

# Run the installer
sudo ./install.sh
```

## System Requirements

### Minimum Requirements
- **CPU**: 2 cores (4+ recommended)
- **RAM**: 2GB (4GB+ recommended)
- **Disk**: 50GB free space
- **OS**: NixOS (any recent version)
- **Architecture**: x86_64 or aarch64

### Recommended Requirements
- **CPU**: 4+ cores with virtualization support (Intel VT-x/AMD-V)
- **RAM**: 8GB or more
- **Disk**: 100GB+ free space on SSD
- **Network**: Stable internet connection for downloads

## Installation Process

### Step 1: Pre-installation

The installer will:
- Check system requirements
- Verify you're running NixOS
- Create backups of existing configuration
- Install minimal dependencies (git, etc.)

### Step 2: Configuration Setup

The installer will:
- Download/copy Hyper-NixOS files to `/etc/nixos`
- Generate hardware configuration for your system
- Migrate existing users and their passwords
- Create a minimal configuration file

### Step 3: System Build

The installer will:
- Build the minimal Hyper-NixOS system
- Install essential packages and services
- Configure the first boot wizard
- Apply the new configuration

### Step 4: First Boot

After rebooting, you'll see:
- **First Boot Configuration Wizard** on TTY1
- The wizard will help you:
  - Set new secure passwords (if needed)
  - Choose your system tier
  - Configure final settings

## System Tiers

During first boot, you can choose from:

1. **Minimal** - Basic VM management (2GB RAM minimum)
   - Core libvirt/KVM functionality
   - Basic VM operations
   - Essential tools only

2. **Standard** - Common features (4GB RAM recommended)
   - Web dashboard
   - Basic monitoring
   - Snapshot management

3. **Enhanced** - Advanced features (8GB RAM recommended)
   - Advanced networking
   - Automated backups
   - Performance monitoring

4. **Professional** - Full features (16GB RAM recommended)
   - Enterprise security
   - Advanced automation
   - Multi-host support ready

5. **Enterprise** - All features (32GB RAM recommended)
   - Full monitoring stack
   - AI-powered insights
   - Complete automation suite

## User Migration

The installer automatically migrates:
- All user accounts (UID >= 1000)
- User passwords (securely)
- Group memberships
- User descriptions and shell preferences

### Security Notes

- Migrated admin users (wheel group) retain sudo access
- Non-admin users get VM management permissions only
- First boot wizard enforces password changes for security
- Original passwords are preserved until changed

## Post-Installation

### After First Boot

1. Log in with your migrated username and password
2. Access the main menu (if configured)
3. Start creating and managing VMs

### Common Commands

```bash
# Check system status
systemctl status hypervisor-*

# Access the menu system
hypervisor-menu

# View documentation
less /etc/nixos/docs/README.md
```

### Changing System Tier

If you need to change your tier after installation:

```bash
sudo /etc/hypervisor/bin/reconfigure-tier
```

## Troubleshooting

### Installation Fails

1. Check you have enough disk space: `df -h /`
2. Ensure internet connectivity: `ping -c1 github.com`
3. Verify NixOS: `nixos-version`
4. Check logs: `journalctl -xe`

### First Boot Wizard Doesn't Appear

- The wizard only runs if no users have been configured
- Check if already complete: `ls /var/lib/hypervisor/.first-boot-complete`
- Manually run: `sudo first-boot-wizard`

### Can't Login After Installation

- Ensure you're using a migrated username
- Try on TTY2 if TTY1 is showing the wizard
- Boot previous configuration from boot menu if needed

## Security Considerations

1. **Change default passwords** - The first boot wizard enforces this
2. **Review sudo access** - Only give admin rights to trusted users
3. **Enable firewall** - Configured by default, review rules
4. **SSH keys** - Add your SSH public keys for remote access

## Next Steps

After installation:

1. **Read the documentation** in `/etc/nixos/docs/`
2. **Explore the web dashboard** (if enabled in your tier)
3. **Create your first VM** using the menu system
4. **Set up automated backups** for your VMs
5. **Configure monitoring** for production use

## Getting Help

- **Documentation**: `/etc/nixos/docs/`
- **Issues**: https://github.com/MasterofNull/Hyper-NixOS/issues
- **Community**: See COMMUNITY_AND_SUPPORT.md

---

© 2024-2025 MasterofNull - Hyper-NixOS Project