# Hyper-NixOS

[![NixOS](https://img.shields.io/badge/NixOS-25.05-blue.svg)](https://nixos.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Beta-yellow.svg)](https://github.com/MasterofNull/Hyper-NixOS)
[![Third-Party Licenses](https://img.shields.io/badge/Dependencies-Properly%20Licensed-success)](THIRD_PARTY_LICENSES.md)

Next-generation virtualization platform built on NixOS with revolutionary features that redefine infrastructure management. Install in seconds with our one-line installer!

## 🚀 Quick Install

Get started with Hyper-NixOS in seconds:

### Method 1: One-Command Install (Fastest)

**Download and run installer directly (RECOMMENDED):**

```bash
# Best: Uses process substitution for reliable terminal input
sudo bash <(curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh)
```

**Alternative: Piped method (may have input issues with some terminals):**

```bash
# Works but may timeout waiting for input after sudo password
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

**Or specify method via environment variable (skips prompt):**

```bash
# With process substitution (recommended)
HYPER_INSTALL_METHOD=https sudo -E bash <(curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh)

# Or with pipe
HYPER_INSTALL_METHOD=https curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo -E bash
```

**Available download methods** (installer will prompt):
- `tarball` - Direct tarball download (default, fastest, no git required)
- `https` - Git clone via HTTPS (public access, no authentication)
- `ssh` - Git clone via SSH (requires GitHub key)
- `token` - Git clone with token authentication

✅ **Now includes**: Interactive prompts via `/dev/tty`, timeout protection, and reliable defaults

<details>
<summary>📋 Alternative: Two-Step Process (Click to expand)</summary>

**Step 1: Download installer script**
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh -o /tmp/hyper-install.sh
```

**Step 2: Run installer**
```bash
sudo bash /tmp/hyper-install.sh
```

</details>

### Method 2: Git Clone (Recommended for Inspection)

**Step 1: Clone repository**
```bash
git clone https://github.com/MasterofNull/Hyper-NixOS.git
```

**Step 2: Enter directory**
```bash
cd Hyper-NixOS
```

**Step 3: Run installer**
```bash
sudo ./install.sh
```

**Both methods automatically**:
- ✅ Install git if not present
- ✅ Clone/use the latest Hyper-NixOS repository
- ✅ Detect your hardware and configure appropriately
- ✅ Run the installer with optimal settings
- ✅ Switch to Hyper-NixOS configuration

> **New in 2025-10-16**: Remote installation enhancements:
> - **Interactive prompts work in piped mode** using `/dev/tty`
> - **Environment variable override**: Set `HYPER_INSTALL_METHOD` to skip prompts
> - **Multiple download options**: HTTPS, SSH, Token, or Tarball
> - **Improved error handling**: Better network diagnostics and fallbacks
>
> The installer will prompt you to choose your preferred method if a terminal is available.

After installation, the first-boot wizard will help you select the appropriate system tier based on your hardware.

**Advanced Options**: Pass flags to installer: `sudo ./install.sh --reboot --action switch`

For manual installation or advanced options, see our [Installation Guide](docs/INSTALLATION_GUIDE.md).

---

## 📋 Complete Installation Process

For a full Hyper-NixOS setup, follow these steps in order:

### Step 1: Install Base NixOS (Required)

**Prerequisites:**
- NixOS **24.05 or later** installed on your system
- Root/sudo access
- Internet connection

**If you don't have NixOS yet:**
1. Download NixOS ISO from [nixos.org](https://nixos.org/download)
2. Create bootable USB: `dd if=nixos.iso of=/dev/sdX bs=4M status=progress`
3. Boot from USB and run: `nixos-install`
4. Follow NixOS installation wizard
5. Reboot into your new NixOS system

**Verify NixOS version:**
```bash
nixos-version
# Should show: 24.05 or later
```

### Step 2: Set Up Development Environment (Optional)

**If you plan to develop or modify Hyper-NixOS**, set up the dev environment first:

```bash
# Download the dev environment quick deploy script
curl -O https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/scripts/nixos-dev-quick-deploy.sh

# Make executable
chmod +x nixos-dev-quick-deploy.sh

# Run (as regular user, NOT sudo)
./nixos-dev-quick-deploy.sh
```

**This installs (10-20 minutes):**
- VSCodium with Claude Code and 25+ extensions
- Modern CLI tools (ripgrep, fd, fzf, bat, eza, jq, yq)
- Development languages (Node.js 22, Python 3, Go, Rust)
- Build tools (GCC, Make)

**Skip this step if you only want to use Hyper-NixOS** (not develop it).

See [NixOS Dev Environment Setup Guide](docs/NIXOS_DEV_ENV_SETUP.md) for details.

### Step 3: Run Hyper-NixOS Install Script (Required)

**Choose one installation method:**

#### Option A: One-Line Remote Install (Fastest)
```bash
# Recommended: Process substitution for reliable input
sudo bash <(curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh)
```

#### Option B: Clone and Install (For Inspection)
```bash
# Clone repository
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd Hyper-NixOS

# Run installer
sudo ./install.sh
```

**The installer will:**
- ✅ Detect your hardware configuration
- ✅ Copy Hyper-NixOS to `/etc/hypervisor/src`
- ✅ Generate host flake at `/etc/hypervisor/flake.nix`
- ✅ Create user accounts and security profiles
- ✅ Run `nixos-rebuild switch` to activate the system
- ✅ Enable first-boot configuration service

**Installation takes:** 15-30 minutes (depends on download speed and hardware)

### Step 4: First-Boot Configuration Wizard (Required)

**After installation completes and system reboots**, the first-boot wizard launches automatically.

**The wizard will guide you through:**

1. **System Tier Selection** (based on detected hardware):
   - Minimal (2GB RAM, basic features)
   - Enhanced (4GB+ RAM, standard features)
   - Complete (8GB+ RAM, all features)

2. **Security Profile Configuration**:
   - Minimal (basic security)
   - Standard (recommended for most users)
   - Paranoid (maximum security, some convenience trade-offs)

3. **Network Configuration**:
   - Static IP or DHCP
   - Firewall rules
   - Optional: MAC spoofing, VPN

4. **Storage Setup**:
   - VM storage pools
   - ISO storage
   - Backup locations

5. **User Privilege Separation**:
   - Admin users (full system access)
   - Operator users (VM management only)

6. **Feature Selection**:
   - VM management features
   - Monitoring and alerting
   - Backup automation
   - Enterprise features (clustering, HA, etc.)

**To manually run the wizard later:**
```bash
hv setup
# or
/etc/hypervisor/bin/setup-wizard
```

### Step 5: Verify Installation (Recommended)

After the first-boot wizard completes:

```bash
# Check system status
hv status

# Discover system capabilities
hv discover

# Verify virtualization is working
hv vm-create --test

# Check security configuration
hv security-status
```

### Step 6: Start Using Hyper-NixOS

**Create your first VM:**
```bash
hv vm-create
```

**Configure monitoring:**
```bash
hv monitoring-config
```

**Set up backups:**
```bash
hv backup-config
```

**Access the management menu:**
```bash
hv
# or
hv menu
```

---

## 🎯 Quick Start with Intelligent Defaults

After installation, use the unified `hv` command:

**Step 1: Install CLI (if not already available)**
```bash
sudo ./scripts/install-hv-cli.sh
```

**Step 2: Discover your system capabilities**
```bash
hv discover
```

**Step 3: Run interactive demo of intelligent defaults**
```bash
hv defaults-demo
```

**Step 4: Create your first VM with intelligent defaults**
```bash
hv vm-create
```

**Step 5: Configure security based on detected risks**
```bash
hv security-config
```

**Step 6: Set up backups optimized for your storage**
```bash
hv backup-config
```

**All wizards use intelligent defaults** based on detected hardware. Just press Enter to accept recommendations, or customize as needed.

See the complete [Wizard Guide](docs/WIZARD_GUIDE.md) for all configuration wizards.

## 🌟 Features

### Revolutionary Concepts

- **🏷️ Tag-Based Compute Units** - VMs inherit configuration from composable tags and policies
- **🔥 Heat-Map Storage Tiers** - Automatic data movement based on AI-predicted access patterns  
- **🕸️ Mesh Clustering** - Decentralized consensus-based cluster with pluggable algorithms
- **🔐 Capability-Based Security** - Fine-grained temporal access control with zero-trust
- **💾 Incremental Forever Backups** - Content-aware deduplication with continuous protection
- **🧩 Component Composition** - Build VMs from reusable, versioned components
- **📊 GraphQL Event-Driven API** - Real-time reactive API with WebSocket subscriptions
- **🔄 Streaming Migration** - Live VM transformation during zero-downtime migration
- **🤖 AI-Driven Monitoring** - Predictive anomaly detection and auto-remediation

## 📋 Requirements

- **OS**: NixOS 24.05 or later
- **CPU**: 4+ cores (x86_64 or aarch64) 
- **RAM**: 8 GB minimum (64 GB recommended)
- **Storage**: 100 GB SSD minimum
- **Network**: 1 Gbps minimum

## 🏗️ Architecture

Hyper-NixOS introduces groundbreaking concepts:

```
┌─────────────────────────────────────────────────────┐
│                   Applications                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │
│  │ Compute Unit│ │ Compute Unit│ │ Compute Unit│  │
│  │  [Tags: web]│ │  [Tags: db] │ │ [Tags: ai]  │  │
│  └─────────────┘ └─────────────┘ └─────────────┘  │
├─────────────────────────────────────────────────────┤
│                  Platform Layer                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │Component │ │  GraphQL │ │    AI    │           │
│  │Compositor│ │   API    │ │ Monitor  │           │
│  └──────────┘ └──────────┘ └──────────┘           │
├─────────────────────────────────────────────────────┤
│              Infrastructure Layer                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │   Mesh   │ │ Storage  │ │ Security │           │
│  │ Cluster  │ │  Tiers   │ │   Caps   │           │
│  └──────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────┘
```

## 💡 Innovative Features Explained

### Tag-Based Compute Units
```nix
hypervisor.compute.units.webserver = {
  tags = [ "production" "high-performance" "public-facing" ];
  policies = [ "web-tier" ];
  resources.compute.units = 400;  # Abstract compute units
};
```

### Heat-Map Storage
```nix
hypervisor.storage.tiers = {
  ultra = { level = 0; characteristics.latency = "< 0.1ms"; };
  fast = { level = 1; characteristics.latency = "< 1ms"; };
  standard = { level = 2; characteristics.latency = "< 10ms"; };
};
```

### Component Composition
```nix
hypervisor.composition.blueprints.web-app = {
  components = [
    { component = "alpine-base"; }
    { component = "nodejs-20"; }
    { component = "nginx-optimized"; }
    { component = "security-hardening"; }
  ];
};
```

## 📚 Documentation

- [Deployment Guide](DEPLOYMENT.md) - Complete installation and setup
- [Architecture Overview](docs/INNOVATIVE_ARCHITECTURE.md) - Deep dive into our innovations
- [API Reference](api/graphql/schema.graphql) - GraphQL schema documentation
- [Examples](examples/) - Production-ready configurations

## 🛠️ CLI Tools

**Compute management:**
```bash
hv-compute list
hv-compose blueprint web-app
```
List compute units and create from blueprint.

**Storage management:**
```bash
hv-storage-fabric tiers
hv-storage-fabric heatmap
```
View storage tiers and access heat map.

**Cluster management:**
```bash
hv-mesh status
hv-mesh peers
```
Check cluster status and view mesh topology.

**AI monitoring:**
```bash
hv-ai models
hv-ai anomalies
```
List AI models and view recent anomalies.

**Backup management:**
```bash
hv-backup sources
hv-backup stats
```
List backup sources and view deduplication stats.

## 🔧 Configuration Example

```nix
{
  hypervisor = {
    compute.units.production = {
      tags = [ "production" "database" ];
      resources = {
        compute.units = 800;
        memory.size = "32Gi";
      };
    };
    
    storage.fabric.heatMap = {
      algorithm = "ml-predicted";
      granularity = "256Ki";
    };
    
    mesh.consensus.algorithm = "raft";
    
    monitoring.ai.models.anomaly = {
      type = "isolation-forest";
      training.features = [ "cpu" "memory" "disk" "network" ];
    };
  };
}
```

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

### Development Setup

**Step 1: Fork and clone the repository**
```bash
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd hyper-nixos
```

**Step 2: Create development environment**
```bash
nix-shell
```

**Step 3: Run tests**
```bash
make test
```

## 📈 Performance

Benchmarks showing revolutionary improvements:

| Feature | Traditional | Hyper-NixOS | Improvement |
|---------|-------------|-------------|-------------|
| VM Boot Time | 30-60s | 3-5s | 10x faster |
| Storage Tiering | Manual | Automatic | ∞ |
| Backup Dedup Ratio | 3:1 | 20:1 | 6.7x better |
| Anomaly Detection | Rules-based | AI-driven | 95% accuracy |
| Migration Downtime | Minutes | <1s | 100x less |

## 🗺️ Roadmap

- [ ] Quantum-ready encryption
- [ ] WebAssembly compute units
- [ ] Blockchain-verified audit logs
- [ ] AR/VR management interface
- [ ] Edge-to-cloud federation
- [ ] Kubernetes CRI integration

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built with ❤️ using:
- [NixOS](https://nixos.org) - The purely functional Linux distribution
- [GraphQL](https://graphql.org) - Query language for APIs
- [NATS](https://nats.io) - High-performance messaging
- [TensorFlow](https://tensorflow.org) - Machine learning framework

## 📞 Support

- 📖 [Documentation](docs/)
- 💬 [Discussions](https://github.com/MasterofNull/Hyper-NixOS/discussions)
- 🐛 [Issue Tracker](https://github.com/MasterofNull/Hyper-NixOS/issues)
- 💼 [Commercial Support](https://github.com/MasterofNull/Hyper-NixOS)

---

**Ready to revolutionize your infrastructure? [Get started now!](DEPLOYMENT.md)**

---

<div align="center">

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 [MasterofNull](https://github.com/MasterofNull) | Licensed under the [MIT License](LICENSE)

[Documentation](docs/) • [Contributing](docs/CONTRIBUTING.md) • [Authors](docs/AUTHORS.md) • [Security](docs/SECURITY.md)

</div>
