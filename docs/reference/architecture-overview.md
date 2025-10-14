# Architecture Overview

This document provides a comprehensive overview of the Hyper-NixOS architecture.

## System Architecture

### Core Components

1. **NixOS Base System**
   - Declarative configuration
   - Atomic updates
   - Rollback capability

2. **Virtualization Layer**
   - libvirt for VM management
   - QEMU/KVM for hypervisor
   - virt-manager for GUI (optional)

3. **Management Layer**
   - CLI tools (hv command)
   - Web dashboard (tier-dependent)
   - REST API (tier-dependent)

4. **Security Layer**
   - Multiple security profiles
   - AI/ML threat detection (Professional/Enterprise)
   - Automated responses

### Module System

Hyper-NixOS uses a modular architecture:

```
modules/
├── core/           # Core system modules
├── security/       # Security modules
├── features/       # Feature management
├── virtualization/ # VM management
└── automation/     # Automation modules
```

### Configuration Tiers

| Tier | Components | Use Case |
|------|------------|----------|
| Minimal | Core + libvirt | Basic virtualization |
| Standard | + Monitoring + Security | Production ready |
| Enhanced | + GUI + Advanced networking | Power users |
| Professional | + AI/ML + Automation | Enterprise features |
| Enterprise | + HA + Clustering | Large deployments |

## Data Flow

1. **User Input** → CLI/Web/API
2. **Management Layer** → Validates and processes
3. **libvirt** → Executes VM operations
4. **QEMU/KVM** → Runs virtual machines
5. **Monitoring** → Collects metrics
6. **Security** → Analyzes and responds

## Security Architecture

See [Security Model](../admin-guides/security-configuration.md) for detailed security architecture.

## Networking Architecture

See [Network Configuration](../admin-guides/network-configuration.md) for networking details.
