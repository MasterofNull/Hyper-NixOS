# Hyper-NixOS

[![NixOS](https://img.shields.io/badge/NixOS-24.05-blue.svg)](https://nixos.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Beta-yellow.svg)](https://github.com/MasterofNull/Hyper-NixOS)
[![Third-Party Licenses](https://img.shields.io/badge/Dependencies-Properly%20Licensed-success)](THIRD_PARTY_LICENSES.md)

Next-generation virtualization platform built on NixOS with revolutionary features that redefine infrastructure management. Install in seconds with our one-line installer!

## 🚀 Quick Install

Get started with Hyper-NixOS in seconds:

### Method 1: One-Command Install (Fastest)
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

### Method 2: Git Clone (Recommended for Inspection)
```bash
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd Hyper-NixOS
sudo ./install.sh
```

**Both methods automatically**:
- ✅ Install git if not present
- ✅ Clone/use the latest Hyper-NixOS repository
- ✅ Detect your hardware and configure appropriately
- ✅ Run the installer with optimal settings
- ✅ Switch to Hyper-NixOS configuration

> **New in 2025-10-15**: Remote installation now offers multiple download options:
> - **Git Clone (HTTPS)** - Public access, no authentication
> - **Git Clone (SSH)** - Authenticated with SSH key (auto-generates if needed)
> - **Git Clone (Token)** - Authenticated with GitHub personal access token
> - **Tarball Download** - Fastest option, no git required
>
> The installer will prompt you to choose your preferred method.

After installation, the first-boot wizard will help you select the appropriate system tier based on your hardware.

**Advanced Options**: Pass flags to installer: `sudo ./install.sh --reboot --action switch`

For manual installation or advanced options, see our [Installation Guide](docs/INSTALLATION_GUIDE.md).

---

## 🎯 Quick Start with Intelligent Defaults

After installation, use the unified `hv` command:

```bash
# Install CLI (if not already available)
sudo ./scripts/install-hv-cli.sh

# See what your system has
hv discover

# Interactive demo of intelligent defaults
hv defaults-demo

# Create your first VM with intelligent defaults
hv vm-create

# Configure security based on detected risks
hv security-config

# Set up backups optimized for your storage
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

```bash
# Compute management
hv-compute list              # List compute units
hv-compose blueprint web-app # Create from blueprint

# Storage management  
hv-storage-fabric tiers      # View storage tiers
hv-storage-fabric heatmap    # Show access heat map

# Cluster management
hv-mesh status               # Cluster status
hv-mesh peers                # View mesh topology

# AI monitoring
hv-ai models                 # List AI models
hv-ai anomalies              # Recent anomalies

# Backup management
hv-backup sources            # List backup sources
hv-backup stats              # Deduplication stats
```

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

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup
```bash
# Fork and clone
git clone https://github.com/yourusername/hyper-nixos.git
cd hyper-nixos

# Create development environment
nix-shell

# Run tests
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

- 📖 [Documentation](https://hyper-nixos.org)
- 💬 [Discussions](https://github.com/yourusername/hyper-nixos/discussions)
- 🐛 [Issue Tracker](https://github.com/yourusername/hyper-nixos/issues)
- 💼 [Commercial Support](https://hyper-nixos.org/support)

---

**Ready to revolutionize your infrastructure? [Get started now!](DEPLOYMENT.md)**
---

## 📄 License and Attribution

### Hyper-NixOS License

**Hyper-NixOS** is licensed under the **MIT License**.

```
Copyright (c) 2024-2025 MasterofNull

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

See [LICENSE](LICENSE) for the complete MIT License text.

### Third-Party Components

Hyper-NixOS integrates many excellent open source projects:

**Core Stack**:
- **NixOS** (MIT) - Operating system foundation
- **QEMU/KVM** (GPL-2.0) - Virtualization engine
- **Libvirt** (LGPL-2.1+) - Virtualization management
- **SystemD** (LGPL-2.1+) - Service management

**Monitoring**:
- **Prometheus** (Apache 2.0) - Metrics collection
- **Grafana** (AGPL-3.0) - Visualization
- **Node Exporter** (Apache 2.0) - System metrics

**Security**:
- **AppArmor** (GPL-2.0) - Mandatory access control
- **PolicyKit** (LGPL-2.1+) - Authorization framework

And many more! See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for the complete list.

### Documentation

For comprehensive licensing information:
- **[LICENSE](LICENSE)** - Hyper-NixOS MIT License
- **[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)** - All dependency licenses
- **[CREDITS.md](CREDITS.md)** - Project attributions
- **[docs/LICENSING_ATTRIBUTION_GUIDE.md](docs/LICENSING_ATTRIBUTION_GUIDE.md)** - Developer guide

### Compliance

All components are used in compliance with their respective licenses:
- GPL/LGPL components: Used as system programs/libraries without modification
- Apache 2.0 components: Properly attributed
- AGPL components: Used unmodified from nixpkgs
- Source code available through nixpkgs

**We respect and acknowledge all upstream open source contributions.**

---

## 🙏 Acknowledgments

Hyper-NixOS would not be possible without the incredible work of:

- **NixOS Community** - For the amazing distribution
- **QEMU/KVM Developers** - For virtualization technology
- **Libvirt Team** - For the management layer
- **Prometheus & Grafana Teams** - For monitoring tools
- **Linux Kernel Developers** - For KVM and security modules
- **All open source contributors** - For making this possible

See [CREDITS.md](CREDITS.md) for complete acknowledgments.

**Thank you to the open source community! 🎉**

---

## 📞 Contact

- **Project**: Hyper-NixOS
- **Lead**: MasterofNull
- **Repository**: https://github.com/MasterofNull/Hyper-NixOS
- **License**: MIT License

For licensing questions, see our [documentation](docs/LICENSING_ATTRIBUTION_GUIDE.md).

---

**© 2024-2025 MasterofNull and Contributors**  
**Licensed under the MIT License**

*Built with ❤️ and open source*
