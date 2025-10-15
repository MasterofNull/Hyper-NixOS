# Hyper-NixOS User Guide

Complete guide for installing, configuring, and managing your Hyper-NixOS hypervisor system.

---

## Table of Contents

- [Installation](#installation)
- [Getting Started](#getting-started)
- [User Management](#user-management)
- [System Updates](#system-updates)
- [Virtual Machine Management](#virtual-machine-management)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

---

## Installation

### Prerequisites

Before installing Hyper-NixOS, ensure you have:

1. **Fresh NixOS Installation**
   - Minimal or graphical installer
   - Base system installed and bootable
   
2. **User Account**
   - Regular user account with sudo access
   - User must be in the `wheel` group
   
3. **Network Connectivity**
   - Internet access for downloading packages
   - GitHub access for repository clone

4. **Hardware Requirements**
   - x86_64 or aarch64 processor
   - Virtualization support (Intel VT-x/AMD-V)
   - Minimum 4GB RAM (8GB+ recommended)
   - 20GB free disk space

### Installation Methods

#### Method 1: One-Liner Quick Install (Recommended)

Perfect for fresh installations and quick deployments:

```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/system_installer.sh --fast --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
```

**What this does:**
1. Installs git if not present
2. Clones repository to temporary directory
3. Runs system installer with optimized settings
4. **Automatically detects your username** (from the user who ran sudo)
5. Migrates your user account and settings
6. Switches to new system configuration
7. Reboots automatically

**Time:** ~15 minutes | **Download:** ~2GB

#### Method 2: Interactive Installation

For more control over the installation process:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/MasterofNull/Hyper-NixOS
   cd Hyper-NixOS
   ```

2. **Run the system installer:**
   ```bash
   sudo nix run .#system-installer -- --fast
   ```

3. **Follow the prompts:**
   - Hostname configuration
   - Update check from GitHub
   - User selection (your user is highlighted)
   - Installation action (build/test/switch)

**What gets migrated:**

The installer automatically preserves:

- **Your User Account**
  - Username and user ID
  - Password (encrypted hash)
  - Home directory
  - Group memberships
  - Shell preferences

- **System Settings**
  - Timezone and locale
  - Console keymap
  - System state version
  - Hostname
  - Swap/hibernation config

**Added automatically:**

Your user will be added to these groups for full hypervisor access:
- `wheel` - Sudo access (requires password)
- `kvm` - KVM virtualization
- `libvirtd` - LibVirt daemon access
- `video` - Graphics access
- `input` - Input device access

#### Method 3: Offline Installation

For systems without internet or air-gapped environments:

1. **Download on connected system:**
   ```bash
   git clone https://github.com/MasterofNull/Hyper-NixOS
   cd Hyper-NixOS
   nix flake archive --to /path/to/usb
   ```

2. **Transfer to target system**
   - Copy repository to USB drive
   - Boot target system
   - Mount USB drive

3. **Install from USB:**
   ```bash
   cd /mnt/usb/Hyper-NixOS
   sudo ./scripts/system_installer.sh --skip-update-check --force --fast
   ```

### Installation Options

For complete command-line options, see [SCRIPT_REFERENCE.md](SCRIPT_REFERENCE.md#system-installer).

**Common options:**

- `--fast` - Enable optimized parallel downloads (recommended)
- `--hostname NAME` - Set custom hostname
- `--action switch` - Skip prompts, do full installation
- `--skip-update-check` - Skip GitHub update check (offline)
- `--reboot` - Reboot automatically after installation

### Post-Installation

After installation and reboot:

1. **Login** with your migrated user account
2. **System boots to hypervisor menu**
3. **Select "More Options" → "Install VMs"**
4. **Follow the setup wizard**

---

## Getting Started

### First Boot

After installation, the system boots to an interactive menu:

```
╔════════════════════════════════════════╗
║     Hyper-NixOS Hypervisor Menu        ║
╠════════════════════════════════════════╣
║  1. VM List                            ║
║  2. Start GNOME Desktop                ║
║  3. More Options                       ║
║  4. Exit to Shell                      ║
╚════════════════════════════════════════╝
```

### Initial Setup

1. **Select "More Options"**
2. **Choose "Install VMs"**
3. **Follow the wizard:**
   - Configure networking
   - Download OS ISO files
   - Create first virtual machine

### Understanding Your System

**Key Directories:**

- `/etc/hypervisor/` - System configuration
- `/etc/hypervisor/src/` - Hyper-NixOS source files
- `/var/lib/libvirt/` - VM storage and configs
- `/var/log/hypervisor/` - System logs

**Configuration Files:**

- `/etc/nixos/flake.nix` - Symlink to main flake
- `/etc/hypervisor/src/flake.nix` - Main configuration
- `/var/lib/hypervisor/configuration/users-local.nix` - Your users
- `/var/lib/hypervisor/configuration/system-local.nix` - System settings

---

## User Management

### Your User Account

During installation, your user account is automatically:

1. **Detected** - System finds your username via `sudo`
2. **Highlighted** - Marked as "(current user)" in selection
3. **Migrated** - Username, password, and settings preserved
4. **Enhanced** - Added to required groups for hypervisor access

### Password Requirements

**Important:** Passwords are required for system administration.

- **VM Operations:** Passwordless sudo (configured automatically)
- **System Admin:** Password required (security feature)

**Operations requiring password:**
- `nixos-rebuild` - System configuration changes
- `systemctl` - Service management
- Package installation - System-wide software

**Operations without password:**
- `virsh` - VM management commands
- VM start/stop - Virtual machine control
- Monitoring - System and VM status

### Changing Your Password

```bash
# Change your own password
passwd

# As root, change another user's password
sudo passwd username
```

### Adding Additional Users

```bash
# Edit users-local.nix
sudo nano /var/lib/hypervisor/configuration/users-local.nix

# Add user definition:
users.users.newuser = {
  isNormalUser = true;
  extraGroups = [ "wheel" "kvm" "libvirtd" "video" "input" ];
  createHome = true;
  # Set initial password or hashedPassword
  initialPassword = "changeme";
};

# Rebuild system
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)
```

### Group Memberships

Your user needs these groups for full access:

| Group | Purpose | Auto-Added |
|-------|---------|------------|
| `wheel` | Sudo access | ✅ Yes |
| `kvm` | KVM virtualization | ✅ Yes |
| `libvirtd` | VM management | ✅ Yes |
| `video` | Graphics access | ✅ Yes |
| `input` | Input devices | ✅ Yes |

---

## System Updates

### Development Updates

For rapid iteration during development:

```bash
# Full update workflow (validate → sync → rebuild)
sudo /etc/hypervisor/scripts/dev_update_hypervisor.sh

# Just check for updates
sudo /etc/hypervisor/scripts/dev_update_hypervisor.sh --check-only

# Update from specific branch
sudo /etc/hypervisor/scripts/dev_update_hypervisor.sh --ref develop
```

**What happens:**

1. **Validates** current installation
2. **Smart syncs** changed files from GitHub (10-50x faster)
3. **Rebuilds** system with updates
4. **Prompts** for reboot if needed

### Smart Sync Technology

Hyper-NixOS uses intelligent file synchronization:

- **Only downloads changed files**
- **10-50x faster** than full git clone
- **Validates** file integrity with checksums
- **Falls back** to full clone if needed

**Manual smart sync:**

```bash
# Sync latest changes
sudo /etc/hypervisor/scripts/smart_sync_hypervisor.sh

# Check what needs updating
sudo /etc/hypervisor/scripts/smart_sync_hypervisor.sh --check-only

# Sync specific version
sudo /etc/hypervisor/scripts/smart_sync_hypervisor.sh --ref v2.1
```

For complete options, see [SCRIPT_REFERENCE.md](SCRIPT_REFERENCE.md#smart-sync).

### Manual System Rebuild

```bash
# Test new configuration (temporary)
sudo nixos-rebuild test --flake /etc/hypervisor#$(hostname -s)

# Switch to new configuration (persistent)
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)

# Build without activating
sudo nixos-rebuild build --flake /etc/hypervisor#$(hostname -s)
```

### Rollback to Previous Version

NixOS keeps previous system generations:

```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Rollback to specific generation
sudo nix-env --switch-generation 123 --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

---

## Virtual Machine Management

### Creating VMs

**Via Wizard (Recommended):**

1. Main Menu → More Options → Create VM (wizard)
2. Follow prompts for name, resources, ISO
3. VM automatically configured and started

**Via Command Line:**

```bash
# Create VM profile
sudo /etc/hypervisor/scripts/create_vm.sh my-vm

# Edit configuration
sudo nano /var/lib/hypervisor/vms/my-vm.json

# Define and start
sudo virsh define /var/lib/libvirt/configs/my-vm.xml
sudo virsh start my-vm
```

### Managing VMs

**Common operations:**

```bash
# List all VMs
sudo virsh list --all

# Start VM
sudo virsh start vm-name

# Stop VM gracefully
sudo virsh shutdown vm-name

# Force stop VM
sudo virsh destroy vm-name

# Restart VM
sudo virsh reboot vm-name

# Delete VM (keeps disk)
sudo virsh undefine vm-name

# Delete VM and disk
sudo virsh undefine vm-name --remove-all-storage
```

### Snapshots and Backups

**Create snapshot:**

```bash
# Via menu
Main Menu → More Options → Snapshots/Backups → Create

# Via command
sudo virsh snapshot-create-as vm-name snapshot-name "Description"
```

**Restore snapshot:**

```bash
# List snapshots
sudo virsh snapshot-list vm-name

# Restore
sudo virsh snapshot-revert vm-name snapshot-name
```

### Monitoring VMs

**Check VM status:**

```bash
# Via menu
Main Menu → VM List → Select VM

# Via command
sudo virsh dominfo vm-name
sudo virsh domstats vm-name
```

**View console:**

```bash
# Connect to VM console
sudo virsh console vm-name

# Disconnect: Ctrl+]
```

**Network information:**

```bash
# Get VM IP address
sudo virsh domifaddr vm-name

# List networks
sudo virsh net-list --all
```

---

## Troubleshooting

### Validation

Check system health:

```bash
# Full validation
sudo /etc/hypervisor/scripts/validate_hypervisor_install.sh

# Quick check
sudo /etc/hypervisor/scripts/validate_hypervisor_install.sh --quick

# Attempt automatic fixes
sudo /etc/hypervisor/scripts/validate_hypervisor_install.sh --fix
```

### Common Issues

#### "Permission denied" on VM operations

**Problem:** User not in required groups  
**Solution:**
```bash
# Check current groups
groups

# Add user to groups (requires re-login)
sudo usermod -aG kvm,libvirtd,video,input $USER

# Or rebuild system (if groups already in users-local.nix)
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)
```

#### "Cannot access /var/lib/libvirt"

**Problem:** Libvirt daemon not running  
**Solution:**
```bash
# Start libvirtd
sudo systemctl start libvirtd

# Enable on boot
sudo systemctl enable libvirtd

# Check status
sudo systemctl status libvirtd
```

#### System won't boot after update

**Problem:** Configuration error  
**Solution:**
```bash
# Boot into previous generation (GRUB menu → Old Configurations)
# Then rollback:
sudo nixos-rebuild switch --rollback
```

#### Out of disk space

**Problem:** VM disk images filling storage  
**Solution:**
```bash
# Check disk usage
df -h
sudo du -sh /var/lib/libvirt/*

# Delete unused VMs and snapshots
sudo virsh snapshot-list vm-name
sudo virsh snapshot-delete vm-name snapshot-name

# Compact VM disk (if qcow2)
sudo qemu-img convert -O qcow2 old.qcow2 new.qcow2
```

### Logs

**System logs:**

```bash
# General system log
journalctl -xe

# Hypervisor logs
tail -f /var/log/hypervisor/*.log

# LibVirt logs
tail -f /var/log/libvirt/qemu/*.log

# NixOS rebuild logs
cat /var/log/nixos/nixos-rebuild.log
```

### Getting Help

1. **Check documentation:** `/etc/hypervisor/docs/`
2. **Run validation:** `sudo validate_hypervisor_install.sh`
3. **View logs:** `journalctl -xe`
4. **Script help:** `script-name.sh --help`
5. **See:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## Advanced Topics

### Custom Configuration

**Editing NixOS configuration:**

```bash
# Main configuration
sudo nano /etc/hypervisor/src/configuration.nix

# User configuration
sudo nano /var/lib/hypervisor/configuration/users-local.nix

# System settings
sudo nano /var/lib/hypervisor/configuration/system-local.nix

# Apply changes
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)
```

### Development Workflow

**Making changes to Hyper-NixOS:**

1. Edit files in `/etc/hypervisor/src/`
2. Test build: `sudo nixos-rebuild build --flake /etc/hypervisor#$(hostname -s)`
3. Test run: `sudo nixos-rebuild test --flake /etc/hypervisor#$(hostname -s)`
4. Make permanent: `sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)`

**Syncing from development branch:**

```bash
sudo /etc/hypervisor/scripts/dev_update_hypervisor.sh --ref develop --skip-rebuild
# Make local changes
# Test
sudo /etc/hypervisor/scripts/dev_update_hypervisor.sh --ref main  # Back to stable
```

### Performance Tuning

**Optimize for VM performance:**

See `/etc/hypervisor/docs/advanced_features.md` for:
- CPU pinning
- NUMA configuration
- Hugepages
- Network optimization
- Storage tuning

### Security Hardening

**Additional security measures:**

See `/etc/hypervisor/docs/security_best_practices.md` for:
- Firewall configuration
- Network isolation
- Access control policies
- Audit logging
- Compliance settings

### Backup Strategies

**System backups:**

```bash
# Backup configuration
sudo tar czf /backup/hypervisor-config-$(date +%F).tar.gz \
  /etc/hypervisor/configuration \
  /etc/nixos

# Backup VMs
sudo /etc/hypervisor/scripts/backup_vm.sh vm-name
```

---

## Quick Reference

### Essential Commands

```bash
# System update
sudo /etc/hypervisor/scripts/dev_update_hypervisor.sh

# List VMs
sudo virsh list --all

# Start VM
sudo virsh start vm-name

# Stop VM
sudo virsh shutdown vm-name

# VM console
sudo virsh console vm-name

# System rebuild
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)

# Validation
sudo /etc/hypervisor/scripts/validate_hypervisor_install.sh
```

### Key Files

```
/etc/hypervisor/src/                     - Source repository
/var/lib/hypervisor/configuration/       - Local configuration
  ├── users-local.nix                    - User accounts
  └── system-local.nix                   - System settings
/etc/nixos/flake.nix                     - Symlink to main flake
/var/lib/libvirt/                        - VM storage
/var/log/hypervisor/                     - System logs
```

### Support Resources

- **Script Reference:** [SCRIPT_REFERENCE.md](SCRIPT_REFERENCE.md)
- **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Testing Guide:** [TESTING_GUIDE.md](TESTING_GUIDE.md)
- **Beginner Guide:** [novice_user_guide.md](novice_user_guide.md)
- **Main README:** [../README.md](../README.md)

## Community & Support

For additional help and community resources, see our comprehensive [Community and Support Guide](../COMMUNITY_AND_SUPPORT.md).

### Quick Links
- **GitHub**: https://github.com/Hyper-NixOS/Hyper-NixOS
- **Issues**: https://github.com/Hyper-NixOS/Hyper-NixOS/issues
- **Contact**: Discord - [@quin-tessential](https://discord.com/users/quin-tessential)
- **Security**: Contact via Discord or GitHub Security Advisory

---

**Last Updated:** 2025-10-14  
**Version:** 2.0.0
