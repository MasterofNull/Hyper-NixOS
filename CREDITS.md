# Credits and Attributions

## Hyper-NixOS Project

### Project Lead
- **MasterofNull** - Creator and Lead Developer

### Core Contributors
- The NixOS Community
- Contributors from the Open Source Community

---

## Major Dependencies and Attributions

### Core Operating System
**NixOS**
- **Copyright**: NixOS contributors
- **License**: MIT License
- **Website**: https://nixos.org/
- **Attribution**: Hyper-NixOS is built on top of NixOS, using its module system, package management, and declarative configuration approach. We are grateful to the NixOS team and community for creating this powerful platform.

### Virtualization Stack
**QEMU (Quick Emulator)**
- **Copyright**: Fabrice Bellard and the QEMU Project contributors
- **License**: GNU General Public License v2.0
- **Website**: https://www.qemu.org/
- **Attribution**: QEMU provides the core virtualization engine that powers all VM operations in Hyper-NixOS.

**KVM (Kernel-based Virtual Machine)**
- **Copyright**: Linux kernel contributors
- **License**: GNU General Public License v2.0
- **Website**: https://www.linux-kvm.org/
- **Attribution**: KVM provides hardware-accelerated virtualization support for optimal performance.

**Libvirt**
- **Copyright**: Red Hat, Inc. and Libvirt contributors
- **License**: GNU Lesser General Public License v2.1+
- **Website**: https://libvirt.org/
- **Attribution**: Libvirt provides the virtualization management API that Hyper-NixOS uses to control VMs, networks, and storage.

### Monitoring and Observability
**Prometheus**
- **Copyright**: The Prometheus Authors
- **License**: Apache License 2.0
- **Website**: https://prometheus.io/
- **Attribution**: Prometheus collects and stores all metrics data for monitoring the hypervisor and VMs.

**Grafana**
- **Copyright**: Grafana Labs
- **License**: GNU Affero General Public License v3.0
- **Website**: https://grafana.com/
- **Attribution**: Grafana provides beautiful visualizations and dashboards for monitoring data. Used as-is from nixpkgs without modifications.

**Node Exporter**
- **Copyright**: The Prometheus Authors
- **License**: Apache License 2.0
- **Attribution**: Provides system metrics for Prometheus monitoring.

### System Services
**SystemD**
- **Copyright**: systemd contributors
- **License**: GNU Lesser General Public License v2.1+
- **Website**: https://systemd.io/
- **Attribution**: SystemD manages all services, timers, and system initialization for Hyper-NixOS.

**PolicyKit (polkit)**
- **Copyright**: The polkit authors
- **License**: GNU Lesser General Public License v2.1+
- **Attribution**: Provides fine-grained authorization and privilege management for non-root operations.

### Security Components
**AppArmor**
- **Copyright**: Canonical Ltd. and AppArmor contributors
- **License**: GNU General Public License v2.0
- **Website**: https://apparmor.net/
- **Attribution**: Provides mandatory access control and application confinement for enhanced security.

**Linux Kernel Security Modules**
- **Copyright**: Linux kernel contributors
- **License**: GNU General Public License v2.0
- **Attribution**: Provides SELinux, AppArmor, and Seccomp for system security.

### Networking
**Netfilter Project (iptables/nftables)**
- **Copyright**: The Netfilter Project
- **License**: GNU General Public License v2.0
- **Website**: https://www.netfilter.org/
- **Attribution**: Provides firewall and packet filtering capabilities.

### Backup and Storage
**Restic**
- **Copyright**: Alexander Neumann and contributors
- **License**: BSD 2-Clause License
- **Website**: https://restic.net/
- **Attribution**: Provides secure, incremental backup capabilities (optional component).

**OpenZFS**
- **Copyright**: OpenZFS contributors
- **License**: CDDL 1.0
- **Website**: https://openzfs.org/
- **Attribution**: Provides advanced storage features (optional component).

### Programming Languages and Tools
**Rust**
- **Copyright**: The Rust Project Developers
- **License**: MIT License and Apache License 2.0
- **Website**: https://www.rust-lang.org/
- **Attribution**: Used for building performance-critical management tools.

**Go**
- **Copyright**: The Go Authors
- **License**: BSD 3-Clause License
- **Website**: https://go.dev/
- **Attribution**: Used for the API server and event-driven backend.

**Python**
- **Copyright**: Python Software Foundation
- **License**: Python Software Foundation License
- **Website**: https://www.python.org/
- **Attribution**: Used for web interfaces and utility scripts.

**Bash**
- **Copyright**: Free Software Foundation
- **License**: GNU General Public License v3.0+
- **Attribution**: Primary scripting language for system automation.

---

## Inspirations and Concept Attribution

While no code was directly copied from these projects, they provided valuable inspiration for design concepts and workflows:

**Proxmox VE**
- **Website**: https://www.proxmox.com/
- **Inspiration**: VM management workflows, clustering concepts, and enterprise features

**Harvester**
- **Website**: https://harvesterhci.io/
- **Inspiration**: Modern UI/UX approaches and Kubernetes-based management concepts

**oVirt**
- **Website**: https://www.ovirt.org/
- **Inspiration**: Enterprise virtualization features and multi-host management

---

## Documentation References

**Arch Linux Wiki**
- **Website**: https://wiki.archlinux.org/
- **License**: GNU Free Documentation License 1.3
- **Usage**: Reference for system configuration and troubleshooting approaches

**NixOS Wiki**
- **Website**: https://nixos.wiki/
- **License**: Creative Commons Attribution-ShareAlike 4.0 International
- **Usage**: Reference for NixOS-specific implementation patterns

---

## Community and Support

### Special Thanks
- **NixOS Community** - For the amazing distribution and continuous support
- **QEMU/KVM Developers** - For making hardware virtualization accessible
- **Libvirt Team** - For the unified virtualization management API
- **Prometheus & Grafana Teams** - For best-in-class monitoring tools
- **Linux Kernel Developers** - For KVM and security modules
- **SystemD Developers** - For modern service management
- **Open Source Community** - For making all of this possible

### Contributors
- All contributors who have submitted issues, pull requests, and feedback
- Beta testers who helped identify issues and improve the system
- Documentation contributors who help others get started

---

## Standards and Specifications

This project implements or follows:
- **Libvirt API Specifications** - For VM management
- **Prometheus Exposition Format** - For metrics
- **SystemD Unit File Specifications** - For service management
- **NixOS Module System** - For configuration management
- **Unicode Standards** - For terminal UI elements
- **POSIX Standards** - For shell scripting compatibility

---

## Package Dependencies

Hyper-NixOS uses numerous packages from nixpkgs. Each package maintains its own license. For a complete list, see `THIRD_PARTY_LICENSES.md`.

Key packages include:
- coreutils, util-linux, procps (system utilities)
- iproute2, bridge-utils, dnsmasq (networking)
- spice-gtk, virt-viewer (remote access)
- curl, wget, git, jq (tools)
- And many more from the nixpkgs collection

---

## License Information

**Hyper-NixOS** is licensed under the **MIT License**.

For complete license information and third-party attributions, see:
- `LICENSE` - Hyper-NixOS license
- `THIRD_PARTY_LICENSES.md` - Complete third-party license information

---

## Giving Credit

If you use, distribute, or build upon Hyper-NixOS:

1. Include the LICENSE file
2. Maintain attribution to MasterofNull and contributors
3. Reference THIRD_PARTY_LICENSES.md for dependencies
4. Comply with all upstream licenses (especially GPL/LGPL/AGPL)
5. Consider contributing improvements back to the project

---

## Contact

- **Project**: Hyper-NixOS
- **Lead**: MasterofNull
- **Repository**: https://github.com/MasterofNull/Hyper-NixOS
- **License**: MIT License

---

## Acknowledgments

This project stands on the shoulders of giants. We are deeply grateful to all the open source projects, developers, and communities that make Hyper-NixOS possible. Without their dedication to open source software, this project would not exist.

**Thank you to everyone who contributes to open source! 🙏**

---

**Last Updated**: 2025-10-15  
© 2024-2025 MasterofNull and Contributors

For the complete list of licenses and detailed attributions, please see `THIRD_PARTY_LICENSES.md`.