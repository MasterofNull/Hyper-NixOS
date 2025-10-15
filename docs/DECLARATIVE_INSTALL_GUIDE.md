# Hyper-NixOS Declarative Installation Guide

## Overview

The declarative installation workflow provides a clean, NixOS-native approach to installing Hyper-NixOS:

1. **Installer** - Initial setup and preparation
2. **Migration** - System and user configuration migration  
3. **Minimal Profile** - Switch to NixOS declarative minimal profile
4. **First Boot** - Full system setup with GUI wizard
5. **Feature Selection** - Custom features via guided installer
6. **Final System** - Switch to completed configuration

## Installation Process

### Quick Install

```bash
# Download and run the declarative installer
curl -L https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install-declarative.sh | sudo bash
```

### Manual Install

```bash
# Clone repository
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd Hyper-NixOS

# Run declarative installer
sudo ./install-declarative.sh
```

## Workflow Details

### Step 1: Installer Setup

The installer:
- Verifies you're running NixOS
- Backs up existing configuration
- Downloads/copies Hyper-NixOS files
- Prepares the installation environment

### Step 2: Configuration Migration

Automatically migrates from your current system:
- **System settings**: hostname, timezone, locale
- **User accounts**: usernames, UIDs, password hashes
- **Group memberships**: including sudo/wheel groups
- Creates `modules/system-migrated.nix` and `modules/users-migrated.nix`

### Step 3: Minimal Profile Switch

Switches to a minimal NixOS configuration that:
- Uses `<nixpkgs/nixos/modules/profiles/minimal.nix>`
- Includes only essential packages
- Enables GUI for setup wizard
- Prepares for first boot configuration

### Step 4: First Boot Experience

After reboot:
1. System boots into minimal GUI environment (Sway/Wayland)
2. Setup wizard launches automatically
3. Graphical interface guides through configuration

### Step 5: GUI Setup Wizard

The wizard provides:

#### Profile Selection
Choose your system tier:
- **Minimal** (2GB RAM) - Basic VM management
- **Standard** (4GB RAM) - Common features  
- **Enhanced** (8GB RAM) - Advanced features
- **Professional** (16GB RAM) - Full features
- **Enterprise** (32GB RAM) - All features

#### Feature Selection
Based on your profile, select from:
- Web dashboard
- Monitoring stack (Prometheus + Grafana)
- VM templates library
- Automated backups
- Network isolation
- GPU passthrough
- Multi-host clustering
- REST/GraphQL API
- Audit logging
- Disk encryption

#### Network Configuration
Optional setup of:
- VM network bridges
- VLANs and isolation
- Firewall rules
- Performance optimization

#### Storage Configuration
Configure:
- VM storage location
- ISO storage location
- Backup destination

### Step 6: Final System

After wizard completion:
- System rebuilds with selected configuration
- Full Hyper-NixOS environment activates
- All selected features are available
- Ready for VM management

## System Profiles

### Minimal Profile
- Core libvirt/KVM
- Basic VM operations
- Command-line tools
- 2GB RAM minimum

### Standard Profile  
- Minimal + Web dashboard
- Basic monitoring
- VM templates
- Automated backups
- 4GB RAM recommended

### Enhanced Profile
- Standard + Advanced networking
- Performance monitoring
- Network isolation
- Storage management
- 8GB RAM recommended

### Professional Profile
- Enhanced + Enterprise features
- GPU passthrough support
- Clustering ready
- Full API access
- 16GB RAM recommended

### Enterprise Profile
- All features enabled
- AI-powered monitoring
- Complete automation
- Multi-site support
- 32GB RAM recommended

## GUI Technologies

The setup uses:
- **Wayland**: Modern, secure display protocol
- **Sway**: Tiling window manager (no X11)
- **Zenity/Whiptail**: GUI dialogs
- **Firefox**: Documentation browser
- **Virt-Manager**: Graphical VM management

## Post-Installation

### Accessing the System

After setup completes:

```bash
# Command-line menu
hypervisor-menu

# Web dashboard (if enabled)
firefox http://localhost:8080

# VM manager GUI (if GUI kept)
virt-manager
```

### Changing Configuration

To modify your system after installation:

```bash
# Edit configuration
sudo vim /etc/nixos/configuration.nix

# Rebuild system
sudo nixos-rebuild switch
```

### Adding Features Later

To add features not selected during setup:

1. Edit `/etc/nixos/configuration.nix`
2. Add feature flags under `hypervisor.features`
3. Run `sudo nixos-rebuild switch`

## Troubleshooting

### GUI Doesn't Start

If the GUI wizard doesn't launch:
1. Switch to TTY2 (Ctrl+Alt+F2)
2. Login as your user
3. Run: `sudo /etc/hypervisor/scripts/setup_wizard_gui.sh`

### Build Fails

Common solutions:
- Check disk space: `df -h`
- Check internet: `ping github.com`
- Review logs: `journalctl -xe`
- Try manual rebuild: `sudo nixos-rebuild switch --show-trace`

### Can't Login

- Use migrated username/password
- Try TTY2 if GUI is on TTY1
- Boot previous generation from boot menu

## Security Notes

1. **Minimal Attack Surface**: Minimal profile reduces exposure
2. **No X11**: Pure Wayland for better security
3. **Migrated Credentials**: Passwords preserved securely
4. **One-Time Setup**: Wizard only runs once
5. **Declarative Config**: All changes tracked in Nix

## Advanced Options

### Headless Installation

For servers without GUI:
```bash
# Set headless mode before install
export HYPER_NIXOS_HEADLESS=1
sudo ./install-declarative.sh
```

### Custom Profile Path

To use a custom profile:
```bash
# Create custom profile
cat > /etc/nixos/profiles/custom.nix << EOF
{ config, lib, pkgs, ... }:
{
  # Your custom configuration
}
EOF

# Reference in configuration
```

### Unattended Installation

For automated deployment:
```bash
# Create answer file
cat > /tmp/wizard-answers << EOF
PROFILE=standard
FEATURES=web-dashboard,monitoring-stack,auto-backups
ENABLE_GUI=false
EOF

# Run with answers
sudo WIZARD_ANSWERS=/tmp/wizard-answers ./install-declarative.sh
```

## Benefits

1. **NixOS Native**: Uses standard NixOS patterns
2. **Declarative**: All configuration in Nix files
3. **Reproducible**: Can recreate exact system
4. **Rollback**: Boot previous configurations
5. **Clean**: Minimal base, add only what you need

---

© 2024-2025 MasterofNull - Hyper-NixOS Project