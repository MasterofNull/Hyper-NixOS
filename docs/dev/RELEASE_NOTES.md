# Hyper-NixOS Release Notes

## Version 1.0.1 - Bug Fixes
*Release Date: October 13, 2025*

### 🐛 Bug Fixes

#### CI/CD Improvements
- **Fixed**: `test_common_ci` failing in GitHub Actions due to readonly variable conflicts
- **Fixed**: Test script termination when testing failure cases with `require` function
- **Fixed**: Strict error handling from sourced libraries affecting test execution

#### Build System
- **Fixed**: Nix configuration build error: `undefined variable 'elem'` at line 345
- **Improvement**: Added proper `lib.` prefix for standard Nix library functions

### 📝 Documentation Updates
- Updated CI test fixes documentation with latest solutions
- Added new troubleshooting entries for common CI/CD issues
- Enhanced best practices for writing CI-friendly tests

### 🔧 Technical Details
- Modified test framework to handle readonly variables in test environments
- Implemented subshell isolation for tests that may call `exit`
- Improved error handling in CI test scripts

---

## Version 1.0.0 - Initial Release
*Release Date: January 1, 2025*

### 🎉 Overview

We are excited to announce the first official release of Hyper-NixOS - a comprehensive, security-focused virtualization platform built on NixOS. This release represents months of development and includes enterprise-grade features while maintaining ease of use for home labs and development environments.

### ✨ Key Features

#### 🏗️ Core Virtualization
- **KVM/QEMU Integration**: Full hardware virtualization support
- **libvirt Management**: Industry-standard VM management
- **Multi-Architecture**: Support for x86_64 and ARM64
- **Hardware Passthrough**: GPU and device passthrough capabilities
- **Nested Virtualization**: Run VMs inside VMs

#### 🔒 Advanced Security
- **Threat Detection System**: Real-time monitoring with ML-based anomaly detection
- **Zero-Day Protection**: Behavioral analysis for unknown threats
- **Automated Response**: Configurable threat response playbooks
- **Threat Intelligence**: Integration with external threat feeds
- **Forensics Tools**: Automated evidence collection
- **Two-Phase Security**: Setup mode and hardened mode

#### 👥 Privilege Separation
- **No Sudo for VMs**: Regular users can manage VMs without sudo
- **Clear Boundaries**: System operations require explicit sudo
- **Group-Based Access**: Fine-grained permission control
- **Polkit Integration**: GUI tools work without passwords

#### 🎨 User Experience
- **Adaptive Documentation**: Adjusts to user experience level
- **Interactive Tutorials**: Built-in learning system
- **Setup Wizard**: Guided configuration with risk awareness
- **Console Menu**: Feature-rich TUI for management
- **Progress Tracking**: Monitor your learning journey

#### 📊 Monitoring & Reporting
- **Real-time Dashboard**: Live threat and system monitoring
- **Comprehensive Reports**: HTML/PDF security reports
- **Performance Metrics**: Prometheus/Grafana integration
- **Alert System**: Multi-channel notifications

#### 🔧 Advanced Features
- **Backup & Recovery**: Automated backup system
- **Network Isolation**: Micro-segmentation support
- **Storage Management**: Multiple backend support
- **API Access**: REST/GraphQL for automation
- **Container Support**: Optional Podman integration

### 📋 System Requirements

- **CPU**: x86_64 or ARM64 with virtualization support
- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: Minimum 50GB, recommended 200GB+ SSD
- **OS**: NixOS 24.05 or later

### 🚀 Getting Started

1. Install Hyper-NixOS following the [Installation Guide](INSTALLATION_GUIDE.md)
2. Run the setup wizard: `hv setup`
3. Create your first VM: `hv vm create my-vm --template debian-11`
4. Start exploring with: `hv help`

### 🔄 Migration Notes

For users migrating from other virtualization platforms:

- **From Proxmox**: Use our migration scripts in `/tools/migration/`
- **From VMware**: VMDK images can be converted with `qemu-img`
- **From VirtualBox**: VDI images supported via conversion

### ⚠️ Known Issues

1. **NVIDIA GPU Passthrough**: Requires manual configuration on some models
2. **ARM64**: Some features limited compared to x86_64
3. **SELinux**: Full integration pending (AppArmor used instead)

### 🐛 Bug Fixes

As this is the initial release, no bug fixes are included. Please report any issues to our GitHub repository.

### 🙏 Acknowledgments

Special thanks to:
- The NixOS community for the excellent foundation
- All contributors who helped shape Hyper-NixOS
- Early testers who provided valuable feedback

### 📚 Documentation

Complete documentation is available:
- In the system: `/etc/hypervisor/docs/`
- Online: https://hyper-nixos.org/docs
- Built-in help: `hv help`

### 🔮 Future Roadmap

Planned for future releases:
- Kubernetes integration improvements
- Web-based management interface
- Mobile app for monitoring
- Enhanced cloud provider support
- Additional VM templates
- Cluster management features

### 📞 Support

- **Community Forum**: https://hyper-nixos.org/forum
- **Chat**: https://hyper-nixos.org/chat
- **Issues**: https://github.com/hyper-nixos/hyper-nixos/issues
- **Security**: security@hyper-nixos.org

### 📄 License

Hyper-NixOS is released under the MIT License. See [LICENSE](../LICENSE) for details.

---

## Upgrade Instructions

For future upgrades, run:
```bash
# Update flake
nix flake update

# Test changes
sudo nixos-rebuild test

# Apply changes
sudo nixos-rebuild switch
```

---

Thank you for choosing Hyper-NixOS! We're excited to see what you build with it.

*- The Hyper-NixOS Team*