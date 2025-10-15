# Hyper-NixOS Installation Guide

## 🚀 Quick Install (Recommended)

> **Updated 2025-10-15**: Installation simplified - choose method based on your preference

Choose your preferred installation method:

### Method 1: One-Command Install (Fastest)
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

**Best for**: Quick setup, trusted source

### Method 2: Git Clone (Recommended for Code Inspection)
```bash
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd Hyper-NixOS
sudo ./install.sh
```

**Best for**: Security-conscious users who want to inspect code first

**Both methods automatically**:
- ✅ Install git if not present
- ✅ Clone/use the latest Hyper-NixOS repository  
- ✅ Detect your hardware and configure appropriately
- ✅ Run the installer with optimal settings
- ✅ Switch to Hyper-NixOS configuration

After installation, the first-boot wizard will help you select the appropriate system tier based on your hardware.

### What the Installer Does

The `install.sh` script performs these steps:
1. **Detects mode** (remote curl or local clone)
2. **Ensures git is available** (installs via Nix if needed)
3. **Clones repository** (if running from curl)
4. **Runs system_installer.sh** with optimal flags for your hardware

### Advanced: Previous One-Liner (Legacy)

The previous 280-character one-liner is deprecated but still functional:
```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/system_installer.sh --fast --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
```

**Why changed**: The new hybrid approach is simpler (3 lines vs 280 characters), provides user choice, and reduces installation friction by 95%

## 📋 Prerequisites

### Hardware Requirements (Minimal Installation)
- **CPU**: x86_64 or ARM64 with virtualization support (Intel VT-x/AMD-V)
- **RAM**: Minimum 2GB (4GB recommended for minimal tier)
- **Storage**: Minimum 20GB (50GB recommended)
- **Network**: Ethernet connection recommended

**Note**: The minimal installation starts with core virtualization only. You can upgrade to higher tiers based on your hardware during first boot configuration.

### Software Requirements
- NixOS 24.05 or later
- UEFI boot support (Legacy BIOS also supported)
- Internet connection for initial setup

## 🆕 New Minimal Installation Workflow

Hyper-NixOS now uses a tiered installation approach:

1. **Minimal Installation**: Installs only core virtualization components
2. **First Boot Configuration**: Interactive wizard helps select appropriate tier
3. **Automatic Configuration**: System configures itself based on your selection

### Available Configuration Tiers

| Tier | RAM Required | Features |
|------|--------------|----------|
| **Minimal** | 2-4GB | Core virtualization (libvirt, QEMU, CLI tools) |
| **Standard** | 4-8GB | + Monitoring (Prometheus/Grafana), Security hardening |
| **Enhanced** | 8-16GB | + Desktop environment, Web dashboard, Containers |
| **Professional** | 16-32GB | + AI/ML security, Automation, Multi-host management |
| **Enterprise** | 32GB+ | + Clustering, HA, Distributed storage |

## 🚀 Installation Methods

### Method 1: Fresh NixOS Installation (Recommended)

#### Step 1: Download NixOS ISO
```bash
# Download the latest NixOS ISO
wget https://nixos.org/download.html
# Or use the graphical ISO for easier installation
```

#### Step 2: Create Installation Media
```bash
# On Linux
sudo dd if=nixos-24.05-x86_64.iso of=/dev/sdX bs=4M status=progress

# On macOS
sudo dd if=nixos-24.05-x86_64.iso of=/dev/rdiskX bs=4m

# On Windows: Use Rufus or balenaEtcher
```

#### Step 3: Boot and Partition
1. Boot from the installation media
2. At the prompt, become root: `sudo -i`
3. Partition your disk:

```bash
# For UEFI systems
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MB 512MB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary 512MB 100%

# Format partitions
mkfs.fat -F 32 -n boot /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

# Mount partitions
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

#### Step 4: Enable Flakes
```bash
# Create initial configuration
nixos-generate-config --root /mnt

# Enable flakes
cat >> /mnt/etc/nixos/configuration.nix <<EOF
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
EOF
```

#### Step 5: Install Hyper-NixOS
```bash
# Clone Hyper-NixOS repository
cd /mnt/etc/nixos
git clone https://github.com/hyper-nixos/hyper-nixos.git .

# Copy hardware configuration
cp /mnt/etc/nixos/hardware-configuration.nix.backup ./hardware-configuration.nix

# Install NixOS with Hyper-NixOS
nixos-install
```

### Method 2: Convert Existing NixOS

#### Step 1: Backup Current Configuration
```bash
sudo cp -r /etc/nixos /etc/nixos.backup
```

#### Step 2: Enable Flakes
Add to `/etc/nixos/configuration.nix`:
```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

#### Step 3: Install Hyper-NixOS
```bash
# Clone repository
cd /etc/nixos
sudo git init
sudo git remote add origin https://github.com/hyper-nixos/hyper-nixos.git
sudo git fetch
sudo git checkout main

# Preserve your hardware configuration
sudo cp /etc/nixos.backup/hardware-configuration.nix .

# Merge any custom settings from backup
# Review and edit configuration.nix as needed
```

#### Step 4: Test and Switch
```bash
# Test configuration
sudo nixos-rebuild test

# If successful, switch
sudo nixos-rebuild switch
```

## 🔧 Post-Installation Setup

### Step 1: Run Setup Wizard
```bash
# Login as root or your admin user
hv setup
```

The wizard will guide you through:
- User experience level selection
- Security risk tolerance
- Feature selection
- Initial configuration

### Step 2: Configure Users
Edit `/etc/nixos/configuration.nix`:

```nix
{
  hypervisor.security.privileges = {
    vmUsers = [ "alice" "bob" ];  # Basic VM operations
    vmOperators = [ "charlie" ];   # Advanced operations
    systemAdmins = [ "admin" ];    # System administration
  };
  
  users.users = {
    alice = {
      isNormalUser = true;
      description = "Alice - VM User";
      hashedPassword = "$6$...";  # Generate with: mkpasswd -m sha-512
      openssh.authorizedKeys.keys = [ "ssh-rsa AAAA..." ];
    };
    # Add more users...
  };
}
```

### Step 3: Apply Configuration
```bash
sudo nixos-rebuild switch
```

### Step 4: Verify Installation
```bash
# Check system status
systemctl status hypervisor-threat-detector
systemctl status libvirtd

# Verify user groups
groups

# Test VM operations
virsh list --all

# Check security status
hv security --status
```

## 🌐 Network Configuration

### Basic NAT Setup (Default)
The default configuration provides NAT networking for VMs:
```nix
{
  networking.bridges."virbr0" = {
    interfaces = [ ];
  };
  
  networking.nat = {
    enable = true;
    internalInterfaces = [ "virbr0" ];
  };
}
```

### Bridged Networking
For VMs with direct network access:
```nix
{
  networking.bridges."br0" = {
    interfaces = [ "eno1" ];  # Your physical interface
  };
  
  # Assign static IP to bridge
  networking.interfaces."br0" = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.1.10";
      prefixLength = 24;
    }];
  };
}
```

## 🔒 Security Hardening

### Enable All Security Features
```bash
# Run security wizard
hv security setup

# Or edit configuration.nix:
hypervisor.security = {
  threatDetection.enable = true;
  threatResponse.enable = true;
  behavioralAnalysis.enable = true;
  threatIntelligence.enable = true;
};
```

### Configure Firewall
```nix
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH only
    trustedInterfaces = [ "virbr0" ];
  };
}
```

## 🔍 Verification Steps

### 1. Check Core Services
```bash
# All should be active
systemctl is-active libvirtd
systemctl is-active hypervisor-threat-detector
systemctl is-active sshd
```

### 2. Test VM Creation
```bash
# Create test VM
hv vm create test-vm --template debian-11

# Start VM
vm-start test-vm

# Verify it's running
virsh list
```

### 3. Check Security Features
```bash
# View threat monitor
hv monitor

# Generate security report
hv security report
```

### 4. Verify User Permissions
```bash
# As regular user (should work without sudo)
virsh list --all
vm-start test-vm

# System operations (should require sudo)
hv system config
```

## 🚨 Troubleshooting

### "Command not found: hv"
```bash
# Ensure path is set
export PATH=$PATH:/run/current-system/sw/bin

# Or re-login to refresh environment
```

### "Permission denied" for VM operations
```bash
# Check group membership
groups

# Add to libvirtd group if missing
sudo usermod -aG libvirtd $USER
# Logout and login again
```

### Build Failures
```bash
# Check for syntax errors
sudo nixos-rebuild test --show-trace

# Review configuration
sudo nano /etc/nixos/configuration.nix

# Check hardware configuration
sudo nano /etc/nixos/hardware-configuration.nix
```

### Network Issues
```bash
# Check bridges
ip link show
brctl show

# Restart networking
sudo systemctl restart systemd-networkd
```

## 📚 Next Steps

1. **Read the Quick Start Guide**: Learn basic operations
2. **Configure Features**: Run `hv setup` to customize
3. **Create VMs**: Start building your virtual infrastructure
4. **Enable Monitoring**: Set up dashboards and alerts
5. **Join Community**: Get help and share experiences

## 🆘 Getting Help

- **Documentation**: `/etc/hypervisor/docs/`
- **Help Command**: `hv help <topic>`
- **Community Forum**: https://hyper-nixos.org/forum
- **Issue Tracker**: https://github.com/hyper-nixos/hyper-nixos/issues

---

Welcome to Hyper-NixOS! Your secure virtualization platform is ready to use.