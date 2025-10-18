# Hyper-NixOS Feature Catalog

## 📚 Overview

This document provides a comprehensive catalog of all available features in Hyper-NixOS, including descriptions, requirements, dependencies, and configuration details.

## 🎯 Feature Categories

### Core System
Essential components required for basic operation.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `core` | Essential system components and CLI tools | 512 | None | Always required |
| `cli-tools` | Command-line management utilities | 64 | core | Includes `hv`, `sec` commands |

### Virtualization
VM management and hypervisor features.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `libvirt` | LibVirt daemon and API | 256 | core | Base virtualization |
| `qemu-kvm` | QEMU/KVM hypervisor | 128 | libvirt | Hardware virtualization |
| `virt-manager` | GUI VM management | 512 | libvirt, desktop-* | Requires desktop environment |
| `vm-templates` | Pre-configured VM templates | 0 | libvirt | Convenience feature |
| `live-migration` | VM live migration support | 256 | libvirt, networking-advanced | Enterprise feature |

### Networking
Network configuration and management.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `networking-basic` | NAT networking, basic bridges | 64 | core | Default networking |
| `networking-advanced` | VLANs, OVS, SDN support | 256 | networking-basic | Complex topologies |
| `firewall` | NFTables-based firewall | 128 | networking-basic | Security essential |
| `network-isolation` | Network segregation policies | 64 | firewall | Multi-tenant |
| `vpn-server` | WireGuard/OpenVPN server | 128 | networking-advanced | Remote access |

### Storage Management
Storage backends and management.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `storage-basic` | Local file-based storage | 0 | core | Default storage |
| `storage-lvm` | LVM volume management | 128 | storage-basic | Flexible volumes |
| `storage-zfs` | ZFS filesystem support | 1024 | storage-basic | Advanced features |
| `storage-distributed` | Ceph/GlusterFS support | 2048 | networking-advanced | Clustered storage |
| `storage-encryption` | LUKS disk encryption | 256 | storage-basic | Data protection |

### Security
Security hardening and threat protection.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `security-base` | Basic hardening, SELinux | 512 | core | Recommended minimum |
| `ssh-hardening` | SSH security configurations | 0 | security-base | Best practices |
| `audit-logging` | System audit trail | 256 | security-base | Compliance |
| `ai-security` | AI/ML threat detection | 4096 | monitoring, security-base | Advanced protection |
| `compliance` | Compliance scanning tools | 512 | audit-logging | CIS, STIG, PCI-DSS |
| `ids-ips` | Intrusion detection/prevention | 1024 | networking-advanced | Network security |
| `vulnerability-scanning` | CVE scanning and patching | 512 | security-base | Proactive security |

### Monitoring & Observability
System monitoring and metrics.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `monitoring` | Prometheus + Grafana stack | 1024 | core | Metrics collection |
| `logging` | Loki centralized logging | 512 | monitoring | Log aggregation |
| `alerting` | AlertManager notifications | 256 | monitoring | Alert routing |
| `tracing` | Jaeger distributed tracing | 512 | monitoring | Performance debugging |
| `metrics-export` | External metrics export | 128 | monitoring | Integration |

### Automation
Automation and orchestration tools.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `automation` | Ansible integration | 256 | core | Playbook support |
| `terraform` | Terraform provider | 128 | automation | IaC support |
| `ci-cd` | GitLab runner/Jenkins | 1024 | container-support | Pipeline execution |
| `orchestration` | Kubernetes operator | 512 | container-support | K8s integration |
| `scheduled-tasks` | Cron job management | 64 | core | Task scheduling |

### Desktop Environments
GUI desktop options.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `desktop-kde` | KDE Plasma desktop | 2048 | core | Full-featured DE |
| `desktop-gnome` | GNOME desktop | 2048 | core | Modern DE |
| `desktop-xfce` | XFCE lightweight desktop | 1024 | core | Resource-efficient |
| `remote-desktop` | VNC/RDP server | 256 | desktop-* | Remote GUI access |

### Development Tools
Development and debugging utilities.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `dev-tools` | Compilers, debuggers | 512 | core | Development basics |
| `container-support` | Podman/Docker runtime | 1024 | core | Container execution |
| `kubernetes-tools` | kubectl, helm | 256 | container-support | K8s management |
| `database-tools` | PostgreSQL, Redis | 1024 | core | Data services |

### Enterprise Features
Advanced enterprise capabilities.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `clustering` | HA clustering support | 8192 | monitoring, networking-advanced | High availability |
| `high-availability` | Automatic failover | 1024 | clustering | Fault tolerance |
| `multi-tenant` | Tenant isolation | 2048 | network-isolation | Multi-customer |
| `federation` | Identity federation | 512 | security-base | SSO/LDAP/AD |
| `backup-enterprise` | Enterprise backup | 2048 | storage-distributed | Deduplication |
| `disaster-recovery` | DR orchestration | 1024 | backup-enterprise | Site failover |

### Web & API
Web interfaces and APIs.

| Feature | Description | RAM (MB) | Dependencies | Notes |
|---------|-------------|----------|--------------|-------|
| `web-dashboard` | Web management UI | 512 | monitoring | Browser-based |
| `rest-api` | RESTful API server | 256 | core | Programmatic access |
| `graphql-api` | GraphQL API endpoint | 256 | rest-api | Modern API |
| `websocket-api` | Real-time updates | 128 | rest-api | Live data |

## 🔗 Feature Dependencies

### Dependency Graph

```
core
├── cli-tools
├── networking-basic
│   ├── networking-advanced
│   │   ├── vpn-server
│   │   ├── ids-ips
│   │   └── storage-distributed
│   └── firewall
│       └── network-isolation
├── storage-basic
│   ├── storage-lvm
│   ├── storage-zfs
│   └── storage-encryption
├── security-base
│   ├── ssh-hardening
│   ├── audit-logging
│   │   └── compliance
│   ├── vulnerability-scanning
│   └── federation
├── monitoring
│   ├── logging
│   ├── alerting
│   ├── tracing
│   ├── metrics-export
│   └── web-dashboard
└── container-support
    ├── kubernetes-tools
    ├── ci-cd
    └── orchestration
```

## 📊 Resource Requirements by Tier

### Minimal Tier
- **Total RAM**: ~1GB
- **Features**: core, libvirt, networking-basic
- **Use Case**: Basic VM hosting, learning

### Standard Tier  
- **Total RAM**: ~3GB
- **Features**: + monitoring, security-base, firewall, ssh-hardening, backup-basic
- **Use Case**: Small production deployments

### Enhanced Tier
- **Total RAM**: ~6GB  
- **Features**: + web-dashboard, networking-advanced, container-support, storage-lvm
- **Use Case**: SMB environments, development

### Professional Tier
- **Total RAM**: ~12GB
- **Features**: + ai-security, automation, multi-host, backup-advanced
- **Use Case**: Enterprise departments, MSPs

### Enterprise Tier
- **Total RAM**: ~24GB+
- **Features**: + clustering, high-availability, storage-distributed, multi-tenant
- **Use Case**: Large deployments, service providers

## 🚀 Feature Combinations

### Security-Focused Setup
```
security-base + ssh-hardening + firewall + audit-logging + 
ai-security + ids-ips + vulnerability-scanning + compliance
```

### Developer Workstation
```
core + desktop-kde + dev-tools + container-support + 
kubernetes-tools + database-tools + web-dashboard
```

### High-Performance Cluster
```
clustering + high-availability + storage-distributed + 
monitoring + alerting + backup-enterprise + disaster-recovery
```

### Multi-Tenant Hosting
```
multi-tenant + network-isolation + federation + 
web-dashboard + rest-api + monitoring + compliance
```

## ⚙️ Feature Configuration Examples

### Enabling AI Security
```nix
hypervisor.security.ai = {
  enable = true;
  models = [ "anomaly-detection" "threat-classification" ];
  updateInterval = "6h";
  sensitivity = "balanced";
};
```

### Configuring Monitoring Stack
```nix
services.prometheus = {
  enable = true;
  scrapeConfigs = [ /* ... */ ];
};

services.grafana = {
  enable = true;
  provision = {
    dashboards = [ /* ... */ ];
  };
};
```

### Setting Up Clustering
```nix
hypervisor.clustering = {
  enable = true;
  nodes = [ "node1" "node2" "node3" ];
  quorum = 2;
  fencing = "ipmi";
};
```

## 📝 Feature Flags

Some features have additional configuration flags:

| Feature | Flag | Description | Default |
|---------|------|-------------|---------|
| `ai-security` | `sensitivity` | Detection sensitivity | `balanced` |
| `monitoring` | `retention` | Metrics retention days | `30` |
| `backup-enterprise` | `dedup` | Enable deduplication | `true` |
| `clustering` | `auto-failover` | Automatic failover | `true` |
| `web-dashboard` | `ssl` | Enable HTTPS | `true` |

## 🔧 Troubleshooting Features

### Common Issues

1. **Feature won't enable**
   - Check dependencies are met
   - Verify sufficient resources
   - Review system logs

2. **Performance degradation**
   - Check RAM allocation
   - Review enabled features
   - Consider disabling unused features

3. **Conflicts between features**
   - Desktop environments are mutually exclusive
   - Some security features may conflict
   - Check feature compatibility matrix

## 📚 Additional Resources

- [Feature Management Guide](./FEATURE_MANAGEMENT_GUIDE.md)
- [System Requirements](./SYSTEM_REQUIREMENTS.md)
- [Performance Tuning](./PERFORMANCE_TUNING.md)
- [Security Best Practices](./SECURITY_GUIDE.md)