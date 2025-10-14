# Hyper-NixOS

A comprehensive, security-focused virtualization platform built on NixOS that provides advanced VM management with enterprise-grade features while maintaining ease of use. Get started in minutes with our quick install one-liner, or choose from multiple installation methods to suit your needs.

## 🚀 Quick Install (Recommended)

Get Hyper-NixOS up and running with a single command:

```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/system_installer.sh --fast --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
```

This one-liner will:
- Install git if needed
- Clone the Hyper-NixOS repository
- Run the installer with optimal settings
- Configure your system
- Reboot into Hyper-NixOS

After reboot, the first-boot wizard will help you select the appropriate system tier based on your hardware.

## 🎯 Features

### Core Capabilities
- **🔒 Security-First Design** - Two-phase security model, privilege separation
- **🚀 Revolutionary VM Management** - Operate VMs without sudo
- **📦 Modular Architecture** - Enable only what you need
- **🎨 Intuitive Interface** - Console menu or optional GUI
- **🔧 Enterprise Ready** - Clustering, HA, automated backups
- **🤖 AI-Powered Security** - Threat detection and response
- **📊 Comprehensive Monitoring** - Prometheus, Grafana, alerts
- **🌐 Multi-Architecture** - x86_64, ARM64, RISC-V support

### System Tiers
| Tier | RAM | Use Case |
|------|-----|----------|
| **Minimal** | 2-4GB | Core virtualization only |
| **Standard** | 4-8GB | + Monitoring & Security |
| **Enhanced** | 8-16GB | + Desktop & Advanced Features |
| **Professional** | 16-32GB | + AI Security & Automation |
| **Enterprise** | 32GB+ | + Clustering & High Availability |

## 📋 Prerequisites

- **OS**: NixOS 23.11 or newer (or any Linux for NixOS installation)
- **RAM**: Minimum 2GB (4GB+ recommended)
- **CPU**: x86_64 or ARM64 with virtualization support
- **Disk**: 20GB minimum (50GB+ recommended)
- **Network**: Internet connection for initial setup

## 🛠️ Alternative Installation Methods

### Manual Installation
For more control over the installation process:

```bash
# Clone the repository
git clone https://github.com/MasterofNull/Hyper-NixOS
cd Hyper-NixOS

# Run the installer
sudo bash ./scripts/system_installer.sh

# Follow the interactive prompts
```

### Offline Installation
For air-gapped environments:

```bash
# On a connected machine, clone the repository
git clone https://github.com/MasterofNull/Hyper-NixOS
cd Hyper-NixOS

# Create offline bundle
./scripts/create-offline-bundle.sh

# Transfer to target machine and install
cd /path/to/bundle
sudo bash ./scripts/system_installer.sh --offline
```

## 🎮 Basic Usage

After installation, access the main menu:

```bash
# Console menu (default)
# Automatically starts on login

# Or manually via
hypervisor-menu

# GUI (if enabled)
# Access via desktop environment
```

### Common Operations

```bash
# Create a VM
hv create my-vm

# Start/stop VMs
hv start my-vm
hv stop my-vm

# List VMs
hv list

# Access VM console
hv console my-vm
```

## 📚 Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - Get running in minutes
- **[User Guide](docs/user-guides/USER_GUIDE.md)** - Complete usage documentation
- **[Admin Guide](docs/admin-guides/ADMIN_GUIDE.md)** - System administration
- **[Feature Catalog](docs/FEATURE_CATALOG.md)** - All available features
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🏗️ Architecture

Hyper-NixOS uses a modular NixOS-based architecture:

```
modules/
├── core/           # System essentials
├── security/       # Security configurations
├── virtualization/ # VM management
├── monitoring/     # Metrics and logging
├── features/       # Optional features
└── enterprise/     # Enterprise features
```

## 🔒 Security

- **Two-Phase Security Model**: Permissive setup → Hardened production
- **Privilege Separation**: VM operations don't require sudo
- **Defense in Depth**: Multiple security layers
- **Zero-Trust Principles**: Verify everything
- **Comprehensive Auditing**: All actions logged

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📞 Support

- **Documentation**: [Full documentation](docs/README.md)
- **Issues**: [GitHub Issues](https://github.com/MasterofNull/Hyper-NixOS/issues)
- **Community**: [GitHub Discussions](https://github.com/MasterofNull/Hyper-NixOS/discussions)

## 📜 License

Hyper-NixOS is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Credits

See [CREDITS.md](CREDITS.md) for a full list of contributors and acknowledgments.

---

**Current Version**: v2.0.0 - Production Ready  
**Repository**: https://github.com/MasterofNull/Hyper-NixOS  
**Status**: Active Development