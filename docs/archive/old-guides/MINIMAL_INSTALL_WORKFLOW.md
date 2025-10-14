# Minimal Installation Workflow

## Overview

Hyper-NixOS now uses a minimal installation approach:

1. **Initial Install**: Installs only core virtualization components
2. **First Boot**: Interactive wizard helps select appropriate configuration tier
3. **System Rebuild**: Applies selected tier with all associated features

## Installation Steps

### 1. Install Minimal System

```bash
# Quick install one-liner
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/system_installer.sh --fast --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
```

This installs:
- Core virtualization (libvirt, QEMU, KVM)
- Basic networking (NAT)
- Command-line tools
- First-boot configuration wizard

### 2. Reboot

```bash
sudo reboot
```

### 3. First Boot Configuration

On first boot, you'll see the configuration wizard automatically.

If it doesn't start automatically, run:
```bash
sudo first-boot-wizard
```

The wizard will:
- Detect your system resources (RAM, CPU, GPU, disk)
- Present configuration tiers with requirements
- Show detailed information about each tier
- Apply your selected configuration

### 4. Configuration Tiers

| Tier | Min RAM | Rec RAM | Min CPU | Use Case |
|------|---------|---------|---------|----------|
| **Minimal** | 2GB | 4GB | 2 cores | Basic VM hosting |
| **Standard** | 4GB | 8GB | 2 cores | + Monitoring & Security |
| **Enhanced** | 8GB | 16GB | 4 cores | + Desktop & Advanced Features |
| **Professional** | 16GB | 32GB | 8 cores | + AI Security & Automation |
| **Enterprise** | 32GB | 64GB | 16 cores | + Clustering & HA |

### 5. Post-Configuration

After selecting your tier:

```bash
# Change default password
passwd admin

# Check system status
systemctl status hypervisor-*

# View available commands
hv help
```

## Reconfiguring Your System

To change your configuration tier later:

```bash
sudo /etc/hypervisor/bin/reconfigure-tier
```

## Manual Tier Selection

If you prefer to manually set your tier without the wizard:

1. Edit `/etc/nixos/hypervisor-tier.nix`:
```nix
{ config, lib, pkgs, ... }:
{
  hypervisor.systemTier = "standard";  # Change to desired tier
}
```

2. Rebuild:
```bash
sudo nixos-rebuild switch
```

## Troubleshooting

### Wizard doesn't start
- Check: `systemctl status hypervisor-first-boot`
- Run manually: `sudo first-boot-wizard`

### Configuration fails
- Check logs: `journalctl -xe`
- Restore backup: `sudo cp /etc/nixos/configuration.nix.backup.* /etc/nixos/configuration.nix`

### Resource detection incorrect
- Override in tier config: Add `hypervisor.systemResources` options

## Benefits of Minimal Install

1. **Faster Initial Setup**: Only essential components
2. **Resource Efficient**: Start with minimal footprint
3. **Flexible Growth**: Add features as needed
4. **Clear Upgrade Path**: Structured tier progression
5. **Hardware Appropriate**: Automatic recommendations based on resources
