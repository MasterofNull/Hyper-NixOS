# Third-Party Licenses and Attributions

This document lists all third-party software, libraries, patterns, and projects that Hyper-NixOS uses or derives inspiration from, along with their respective licenses and attributions.

---

## Core Dependencies

### NixOS and Nixpkgs
- **Project**: NixOS - The Purely Functional Linux Distribution
- **Source**: https://github.com/NixOS/nixpkgs
- **License**: MIT License
- **Copyright**: NixOS contributors
- **Usage**: Core operating system, package management, and system configuration
- **Files Affected**: All `.nix` files, `flake.nix`, configuration modules

**License Text**:
```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## Virtualization Stack

### QEMU (Quick Emulator)
- **Project**: QEMU - Generic and Open Source Machine Emulator and Virtualizer
- **Source**: https://www.qemu.org/
- **License**: GNU General Public License v2.0 (GPL-2.0)
- **Copyright**: Fabrice Bellard and the QEMU Project contributors
- **Usage**: Core virtualization engine for running virtual machines
- **Files Affected**: `modules/virtualization/libvirt.nix`, VM management scripts

**Attribution**: QEMU is used as the underlying hypervisor for all VM operations.

### KVM (Kernel-based Virtual Machine)
- **Project**: KVM - Linux kernel virtualization infrastructure
- **Source**: https://www.linux-kvm.org/
- **License**: GNU General Public License v2.0 (GPL-2.0)
- **Copyright**: Linux kernel contributors
- **Usage**: Hardware-accelerated virtualization
- **Files Affected**: `modules/virtualization/libvirt.nix`, kernel modules

**Attribution**: KVM provides hardware virtualization support for optimal VM performance.

### Libvirt
- **Project**: Libvirt - The virtualization API
- **Source**: https://libvirt.org/
- **License**: GNU Lesser General Public License v2.1+ (LGPL-2.1+)
- **Copyright**: Red Hat, Inc. and Libvirt contributors
- **Usage**: Virtualization management layer, API for VM operations
- **Files Affected**: `modules/virtualization/libvirt.nix`, all VM management scripts

**Attribution**: Libvirt provides the management layer for controlling VMs through a unified API.

---

## Monitoring Stack

### Prometheus
- **Project**: Prometheus - Monitoring system and time series database
- **Source**: https://prometheus.io/ | https://github.com/prometheus/prometheus
- **License**: Apache License 2.0
- **Copyright**: The Prometheus Authors
- **Usage**: Metrics collection, storage, and querying
- **Files Affected**: `modules/monitoring/prometheus.nix`, monitoring configuration

**License Summary**: 
```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

**Attribution**: Prometheus is used for collecting and storing time-series metrics data from the hypervisor and VMs.

### Grafana
- **Project**: Grafana - The open observability platform
- **Source**: https://grafana.com/ | https://github.com/grafana/grafana
- **License**: GNU Affero General Public License v3.0 (AGPL-3.0)
- **Copyright**: Grafana Labs
- **Usage**: Metrics visualization and dashboarding
- **Files Affected**: `modules/monitoring/prometheus.nix`, dashboard configurations

**Attribution**: Grafana provides visualization and dashboarding capabilities for monitoring data.

**Note**: AGPL-3.0 requires that if you modify Grafana and make it available over a network, you must make the modified source available. Hyper-NixOS uses Grafana without modifications as provided by nixpkgs.

### Node Exporter
- **Project**: Prometheus Node Exporter
- **Source**: https://github.com/prometheus/node_exporter
- **License**: Apache License 2.0
- **Copyright**: The Prometheus Authors
- **Usage**: System metrics export for Prometheus
- **Files Affected**: `modules/monitoring/prometheus.nix`

**Attribution**: Node Exporter provides hardware and OS metrics for monitoring.

---

## System Components

### SystemD
- **Project**: systemd - System and Service Manager
- **Source**: https://systemd.io/ | https://github.com/systemd/systemd
- **License**: GNU Lesser General Public License v2.1+ (LGPL-2.1+) and GNU General Public License v2.0+ (GPL-2.0+)
- **Copyright**: systemd contributors
- **Usage**: Service management, timers, and system initialization
- **Files Affected**: All service definitions in modules, timer configurations

**Attribution**: SystemD manages services, timers, and system units for the hypervisor.

### AppArmor
- **Project**: AppArmor - Application Security Framework
- **Source**: https://apparmor.net/ | https://gitlab.com/apparmor/apparmor
- **License**: GNU General Public License v2.0 (GPL-2.0)
- **Copyright**: Canonical Ltd. and AppArmor contributors
- **Usage**: Mandatory Access Control (MAC) security
- **Files Affected**: `modules/security/*.nix`, security profiles

**Attribution**: AppArmor provides application confinement and security profiles.

### PolicyKit (polkit)
- **Project**: polkit - Authorization Framework
- **Source**: https://gitlab.freedesktop.org/polkit/polkit
- **License**: GNU Lesser General Public License v2.1+ (LGPL-2.1+)
- **Copyright**: The polkit authors
- **Usage**: Authorization and privilege management
- **Files Affected**: `modules/security/polkit-rules.nix`, privilege separation

**Attribution**: PolicyKit manages authorization and privilege elevation without requiring full root access.

---

## Networking

### iptables / nftables
- **Project**: netfilter - Linux kernel firewall framework
- **Source**: https://www.netfilter.org/
- **License**: GNU General Public License v2.0 (GPL-2.0)
- **Copyright**: The Netfilter Project
- **Usage**: Firewall rules and network filtering
- **Files Affected**: `modules/network-settings/firewall.nix`, network security modules

**Attribution**: Netfilter/iptables/nftables provide network packet filtering and firewall functionality.

### Open vSwitch (OVS)
- **Project**: Open vSwitch - Production Quality, Multilayer Open Virtual Switch
- **Source**: https://www.openvswitch.org/
- **License**: Apache License 2.0
- **Copyright**: The Open vSwitch contributors
- **Usage**: Network virtualization (optional, for advanced networking features)
- **Files Affected**: Advanced networking configurations

**Attribution**: Open vSwitch provides advanced network virtualization capabilities.

---

## Storage and Backup

### Restic
- **Project**: Restic - Fast, secure, efficient backup program
- **Source**: https://restic.net/ | https://github.com/restic/restic
- **License**: BSD 2-Clause "Simplified" License
- **Copyright**: Alexander Neumann and contributors
- **Usage**: Backup system for VMs and configuration (optional)
- **Files Affected**: `modules/automation/backup.nix`, backup scripts

**License Summary**:
```
BSD 2-Clause License

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice
2. Redistributions in binary form must reproduce the above copyright notice
```

**Attribution**: Restic provides secure, incremental backup capabilities.

### ZFS on Linux
- **Project**: OpenZFS - Open source ZFS
- **Source**: https://openzfs.org/
- **License**: CDDL 1.0 (Common Development and Distribution License)
- **Copyright**: OpenZFS contributors
- **Usage**: Optional advanced storage features
- **Files Affected**: Storage tier management (when ZFS is enabled)

**Attribution**: ZFS provides advanced storage features like snapshots and compression.

---

## Development Tools

### Rust Toolchain
- **Project**: Rust Programming Language
- **Source**: https://www.rust-lang.org/
- **License**: MIT License and Apache License 2.0 (dual-licensed)
- **Copyright**: The Rust Project Developers
- **Usage**: Development of performance-critical tools
- **Files Affected**: `tools/rust-lib/`, compiled binaries

**Attribution**: Rust is used for building performance-critical hypervisor management tools.

### Go Toolchain
- **Project**: Go Programming Language
- **Source**: https://go.dev/
- **License**: BSD 3-Clause License
- **Copyright**: The Go Authors
- **Usage**: API server and GraphQL backend
- **Files Affected**: `api/`, Go modules

**Attribution**: Go is used for building the API server and event-driven backend.

### Python
- **Project**: Python Programming Language
- **Source**: https://www.python.org/
- **License**: Python Software Foundation License
- **Copyright**: Python Software Foundation
- **Usage**: Web dashboard and utility scripts
- **Files Affected**: `scripts/*.py`, web dashboard

**Attribution**: Python is used for web interfaces and utility scripts.

---

## Inspirations and Pattern Sources

### NixOS Community Patterns
- **Source**: Various NixOS community modules and patterns
- **License**: MIT License (typical for NixOS community contributions)
- **Usage**: Module structure, configuration patterns, flake patterns
- **Files Affected**: Module organization in `modules/`, flake.nix structure

**Attribution**: This project follows standard NixOS module patterns and best practices established by the NixOS community.

### Proxmox VE
- **Project**: Proxmox Virtual Environment
- **Source**: https://www.proxmox.com/
- **License**: GNU Affero General Public License v3.0 (AGPL-3.0)
- **Inspiration**: VM management UI concepts, clustering approaches
- **Note**: No code copied, concepts and workflow inspiration only

**Attribution**: Proxmox VE inspired some of the VM management workflow concepts and clustering design approaches.

### Harvester
- **Project**: Harvester - Open source hyperconverged infrastructure
- **Source**: https://harvesterhci.io/ | https://github.com/harvester/harvester
- **License**: Apache License 2.0
- **Inspiration**: Kubernetes-based management, modern UI/UX concepts
- **Note**: No code copied, architectural inspiration only

**Attribution**: Harvester inspired the modern approach to hypervisor management and Kubernetes integration concepts.

### oVirt
- **Project**: oVirt - Open source virtualization management platform
- **Source**: https://www.ovirt.org/
- **License**: Apache License 2.0
- **Inspiration**: Enterprise virtualization features, management concepts
- **Note**: No code copied, feature inspiration only

**Attribution**: oVirt influenced enterprise feature design and multi-host management concepts.

---

## Documentation and Patterns

### Arch Linux Wiki
- **Source**: https://wiki.archlinux.org/
- **License**: GNU Free Documentation License 1.3
- **Usage**: Reference for system configuration and troubleshooting
- **Files Affected**: Documentation approach

**Attribution**: Arch Wiki served as a reference for comprehensive technical documentation.

### NixOS Wiki
- **Source**: https://nixos.wiki/
- **License**: Creative Commons Attribution-ShareAlike 4.0 International
- **Usage**: Reference for NixOS-specific configuration
- **Files Affected**: Documentation and module patterns

**Attribution**: NixOS Wiki provided guidance on NixOS-specific implementations.

---

## Fonts and UI Elements (if applicable)

### Terminal UI Elements
- **Project**: Various Unicode box-drawing characters and symbols
- **Standard**: Unicode Consortium
- **License**: Unicode License Agreement
- **Usage**: Progress bars, UI formatting in scripts
- **Files Affected**: `install.sh`, menu scripts

**Attribution**: Unicode characters used for enhanced terminal UI presentation.

---

## Package Dependencies (from nixpkgs)

The following packages are used from nixpkgs and inherit their respective licenses:

| Package | License | Purpose |
|---------|---------|---------|
| bash | GPL-3.0+ | Shell scripting |
| coreutils | GPL-3.0+ | Core utilities |
| util-linux | GPL-2.0+ | System utilities |
| procps | GPL-2.0+ | Process monitoring |
| iproute2 | GPL-2.0+ | Network utilities |
| bridge-utils | GPL-2.0+ | Network bridge utilities |
| dnsmasq | GPL-2.0+ | DHCP/DNS server |
| spice-gtk | LGPL-2.1+ | Remote display |
| virt-viewer | GPL-3.0+ | VM console viewer |
| qemu | GPL-2.0 | Virtualization |
| libvirt | LGPL-2.1+ | Virtualization API |
| curl | MIT-like | HTTP client |
| wget | GPL-3.0+ | Download utility |
| git | GPL-2.0 | Version control |
| jq | MIT | JSON processor |

---

## Security Tools and Frameworks

### Linux Kernel Security Modules
- **License**: GNU General Public License v2.0 (GPL-2.0)
- **Usage**: SELinux, AppArmor, Seccomp
- **Files Affected**: Security modules

**Attribution**: Linux kernel security modules provide mandatory access control and system call filtering.

---

## License Compatibility

Hyper-NixOS is licensed under the **MIT License**, which is compatible with all the licenses used by its dependencies:

- **MIT, BSD, Apache 2.0**: Fully compatible, permissive licenses
- **LGPL-2.1+**: Compatible for linking (libraries used, not modified)
- **GPL-2.0, GPL-3.0**: Compatible (used as separate programs, not linked)
- **AGPL-3.0**: Used as provided by nixpkgs without modifications

For GPL/LGPL components: Hyper-NixOS uses these as separate programs or system libraries without creating derivative works. Users can obtain the source code for all GPL/LGPL components through nixpkgs.

---

## Disclaimer

This project:
- Uses NixOS module patterns following community conventions
- Integrates existing open source tools without modification (except configuration)
- Provides original orchestration and automation layers
- Implements original UI/UX concepts
- Creates original documentation and workflows

Where code or patterns are derived from specific sources, attribution is provided in the relevant files.

---

## How to Comply with These Licenses

If you distribute or modify Hyper-NixOS:

1. **MIT License (Hyper-NixOS)**: Include the LICENSE file
2. **GPL/LGPL Components**: 
   - Do not modify the components themselves
   - If you do modify them, publish your modifications
   - Source available through nixpkgs
3. **AGPL Components (Grafana)**:
   - If you modify Grafana and run it as a service, publish modifications
   - Using as-is from nixpkgs requires no action
4. **Apache 2.0 Components**:
   - Include NOTICE file if provided
   - State changes if modified

---

## Contact

For licensing questions or concerns:
- **Project**: Hyper-NixOS
- **Maintainer**: MasterofNull
- **License**: MIT License (see LICENSE file)

---

## Changelog

- **2025-10-15**: Initial comprehensive third-party licenses document created
- **2025-10-15**: Added attributions for all major dependencies and inspirations

---

**Last Updated**: 2025-10-15  
**Document Version**: 1.0

---

This document will be updated as new dependencies are added or licenses change. All efforts are made to ensure accuracy and compliance with open source licenses.
