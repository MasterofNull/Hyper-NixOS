# Hyper-NixOS Feature Compatibility Matrix

## Overview

This document shows which features can be used together and any dependencies or conflicts.

## Feature Compatibility Table

| Feature | Web Dashboard | API | Monitoring | Threat Detection | ML Analysis | Remote Backup | Live Migration | GPU Passthrough |
|---------|--------------|-----|------------|------------------|-------------|---------------|----------------|-----------------|
| **Web Dashboard** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **API** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Monitoring** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Threat Detection** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| **ML Analysis** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| **Remote Backup** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Live Migration** | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | ✅ | ❌ |
| **GPU Passthrough** | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ✅ |

**Legend:**
- ✅ Fully compatible
- ⚠️ Compatible with limitations
- ❌ Not compatible

## Feature Dependencies

### Core Dependencies
```
VM Management (always enabled)
├── Privilege Separation (always enabled)
├── Audit Logging (always enabled)
└── Basic Monitoring (always enabled)
```

### Feature Trees

#### Web Dashboard
```
Web Dashboard
├── Requires: nginx
├── Requires: TLS certificates
├── Optional: Monitoring (for metrics display)
└── Optional: API (for backend)
```

#### API Access
```
API (REST/GraphQL)
├── Requires: Audit Logging
├── Requires: Authentication system
├── Optional: Rate limiting
└── Optional: API key management
```

#### Threat Detection
```
Threat Detection
├── Requires: Monitoring
├── Optional: ML Analysis (better detection)
├── Optional: Threat Intelligence (external feeds)
└── Optional: Automated Response (immediate action)
```

#### Backup System
```
Local Backup
├── Remote Backup
│   ├── Requires: Network access
│   └── Requires: Remote credentials
└── Continuous Replication
    ├── Requires: Remote Backup
    └── Conflicts: Live Migration
```

## Risk Level Combinations

### Low Risk (Recommended for Production)
- ✅ VM Management
- ✅ Monitoring
- ✅ Local Backup
- ✅ Micro-segmentation
- ✅ Encryption

### Moderate Risk (Recommended for Development)
- ✅ All Low Risk features
- ✅ Web Dashboard
- ✅ Remote Backup
- ✅ Prometheus Export
- ⚠️ API Access (with authentication)

### High Risk (Lab/Testing Only)
- ✅ All Moderate Risk features
- ⚠️ Live Migration
- ⚠️ GPU Passthrough
- ⚠️ Public Network Bridge
- ⚠️ Automated Response

## Platform Compatibility

### Operating Systems
| Feature | Linux x86_64 | Linux ARM64 | BSD | macOS (partial) |
|---------|--------------|-------------|-----|-----------------|
| Core VM Management | ✅ | ✅ | ⚠️ | ❌ |
| KVM Acceleration | ✅ | ✅ | ❌ | ❌ |
| GPU Passthrough | ✅ | ⚠️ | ❌ | ❌ |
| Container Support | ✅ | ✅ | ⚠️ | ⚠️ |

### Hypervisor Features
| Feature | QEMU/KVM | Xen | VMware | Hyper-V |
|---------|----------|-----|---------|---------|
| Full Integration | ✅ | ❌ | ❌ | ❌ |
| VM Import | ✅ | ⚠️ | ⚠️ | ⚠️ |
| Live Migration | ✅ | ❌ | ❌ | ❌ |
| Snapshots | ✅ | ⚠️ | ⚠️ | ⚠️ |

### Hardware Requirements

#### CPU Features
| Feature | Intel VT-x | AMD-V | Intel VT-d | AMD-Vi | ARM SVE |
|---------|------------|-------|------------|---------|---------|
| Basic Virtualization | ✅ | ✅ | - | - | ✅ |
| Nested Virtualization | ✅ | ✅ | - | - | ⚠️ |
| Device Passthrough | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| SR-IOV | ✅ | ✅ | ✅ | ✅ | ❌ |

#### Storage Backends
| Backend | Local | NFS | iSCSI | S3 | Ceph |
|---------|-------|-----|--------|-----|------|
| VM Storage | ✅ | ✅ | ✅ | ❌ | ✅ |
| Backup Target | ✅ | ✅ | ✅ | ✅ | ✅ |
| Live Migration | ✅ | ✅ | ✅ | ❌ | ✅ |
| Encryption | ✅ | ⚠️ | ⚠️ | ✅ | ✅ |

## Security Mode Compatibility

### Setup Phase (Permissive)
- ✅ All features available
- ✅ Configuration changes allowed
- ✅ User modifications permitted
- ⚠️ Security monitoring active but not enforcing

### Hardened Phase (Restrictive)
- ✅ VM operations
- ✅ Monitoring and alerting
- ✅ Backup operations
- ❌ System configuration changes
- ❌ User modifications
- ❌ Feature additions

## Network Configuration Compatibility

### NAT Mode (Default)
- ✅ Internet access for VMs
- ✅ VM-to-VM communication
- ✅ Port forwarding
- ❌ Direct external access to VMs

### Bridged Mode
- ✅ Direct network access
- ✅ External accessibility
- ⚠️ Requires additional firewall config
- ⚠️ Security considerations

### Isolated Mode
- ✅ Maximum security
- ✅ VM-to-VM only
- ❌ No internet access
- ❌ No external access

## Performance Impact Matrix

| Feature | CPU Impact | Memory Impact | Disk I/O | Network I/O |
|---------|------------|---------------|----------|-------------|
| Basic VM | Low | Low | Low | Low |
| Monitoring | Low | Low | Low | Low |
| Threat Detection | Medium | Medium | Low | Low |
| ML Analysis | High | High | Medium | Low |
| Encryption | Low | Low | Medium | Low |
| Live Migration | High | Low | Low | High |
| Continuous Backup | Low | Low | High | High |

## Recommended Configurations

### Home Lab
```nix
{
  hypervisor.featureManager = {
    profile = "balanced";
    riskTolerance = "balanced";
    enabledFeatures = [
      "monitoring"
      "localBackup"
      "webDashboard"
      "cliEnhancements"
    ];
  };
}
```

### Development Environment
```nix
{
  hypervisor.featureManager = {
    profile = "full";
    riskTolerance = "accepting";
    enabledFeatures = [
      "monitoring"
      "api"
      "devEnvironments"
      "snapshots"
      "webDashboard"
    ];
  };
}
```

### Production Deployment
```nix
{
  hypervisor.featureManager = {
    profile = "custom";
    riskTolerance = "cautious";
    enabledFeatures = [
      "monitoring"
      "threatDetection"
      "remoteBackup"
      "microSegmentation"
      "encryption"
      "auditLogging"
    ];
  };
}
```

### Security-Critical
```nix
{
  hypervisor.featureManager = {
    profile = "minimal";
    riskTolerance = "paranoid";
    enabledFeatures = [
      "auditLogging"
      "threatDetection"
      "behavioralAnalysis"
      "forensics"
    ];
  };
}
```

---

*This compatibility matrix is updated with each release. Check the version at the top of this document.*