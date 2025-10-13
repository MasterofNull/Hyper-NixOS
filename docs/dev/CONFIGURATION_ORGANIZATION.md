# Configuration Organization

This document describes the new organized structure for Hyper-NixOS configuration files.

## Overview

The configuration has been reorganized from a flat structure into topic-based folders. This makes it easier to find, maintain, and understand the various configuration modules.

## Directory Structure

```
configuration/
├── configuration.nix          # Main configuration (clean, top-level only)
├── core/                      # Core system settings
│   ├── boot.nix              # Bootloader and kernel selection
│   ├── system.nix            # Hostname, timezone, basic settings
│   ├── packages.nix          # System-wide packages
│   ├── directories.nix       # Directory structure and permissions
│   ├── logrotate.nix         # Log rotation configuration
│   ├── cache-optimization.nix # Nix cache and download optimization
│   └── hardware-configuration.nix # Hardware-specific settings
├── security/                  # Security configuration
│   ├── base.nix              # Core security (libvirt, audit, apparmor)
│   ├── production.nix        # Production security overrides
│   ├── profiles.nix          # Security profiles (headless/management)
│   ├── kernel-hardening.nix  # Consolidated kernel sysctl settings
│   ├── firewall.nix          # Firewall configuration (iptables/nftables)
│   ├── ssh.nix               # SSH hardening
│   ├── nftables.nix          # Advanced nftables rules
│   └── strict.nix            # Maximum security mode (optional)
├── virtualization/           # Virtualization settings
│   ├── libvirt.nix           # Libvirt configuration
│   └── performance.nix       # Hugepages, SMT settings (optional)
├── monitoring/               # Monitoring and logging
│   ├── prometheus.nix        # Prometheus metrics collection
│   ├── alerting.nix          # Alert configuration
│   └── logging.nix           # Centralized logging (syslog-ng)
├── automation/               # Automated tasks
│   ├── services.nix          # Health checks, cleanup, metrics
│   └── backup.nix            # Automated VM backups
├── enterprise/               # Enterprise features (optional)
│   ├── features.nix          # Enterprise feature aggregator
│   ├── quotas.nix            # Resource quota management
│   ├── storage-quotas.nix    # Storage quota enforcement
│   ├── network-isolation.nix # VLAN and network isolation
│   ├── snapshots.nix         # Snapshot lifecycle management
│   └── encryption.nix        # VM disk encryption (LUKS)
├── gui/                      # GUI configuration
│   ├── desktop.nix           # Desktop environment and X server
│   └── input.nix             # Touchpad, keyboard, ACPI events
└── web/                      # Web interface
    └── dashboard.nix         # Web dashboard service
```

## Key Changes

### Eliminated Duplicates

The following settings were duplicated across multiple files and have been consolidated:

1. **Kernel Hardening (`security/kernel-hardening.nix`)**
   - Previously duplicated in: `security-production.nix`, `security-strict.nix`, `cache-optimization.nix`
   - Now consolidated with proper `lib.mkDefault` for overridability

2. **Firewall Settings (`security/firewall.nix`)**
   - Previously duplicated in: `security-production.nix`, `security.nix`, `security-strict.nix`
   - Now provides both standard (iptables) and strict (nftables) modes via options

3. **SSH Configuration (`security/ssh.nix`)**
   - Previously duplicated in: `security-production.nix`, `security-strict.nix`
   - Now supports standard and strict modes via options

4. **Directory/Tmpfiles Rules (`core/directories.nix`)**
   - Previously scattered across: `security-profiles.nix`, `automation.nix`, `backup.nix`, etc.
   - Now centralized with profile-aware ownership

5. **Logrotate Configuration (`core/logrotate.nix`)**
   - Previously duplicated in: `configuration.nix`, `centralized-logging.nix`
   - Now consolidated with consistent retention policies

### Topic-Based Organization

Each folder represents a configuration topic:

- **core/**: Essential system configuration
- **security/**: All security-related settings
- **virtualization/**: VM and KVM configuration
- **monitoring/**: Metrics, alerts, and logging
- **automation/**: Background tasks and automation
- **enterprise/**: Optional enterprise features
- **gui/**: Desktop and input device configuration
- **web/**: Web dashboard and interfaces

### Clean configuration.nix

The main `configuration.nix` file is now clean and organized:
- Top-level system settings only
- Clear import sections by topic
- No duplicate settings
- Well-commented structure

### Local Overrides

The system still supports local per-host overrides in `/var/lib/hypervisor/configuration/`:
- `performance.nix` - Performance tuning
- `security-local.nix` - Security overrides
- `gui-local.nix` - GUI customization
- `system-local.nix` - System overrides
- etc.

## Migration Notes

### For Users

No action required. The reorganization is transparent and all existing functionality is preserved.

### For Developers

When adding new configuration:

1. **Determine the topic**: Which folder does your configuration belong to?
2. **Check for duplicates**: Search existing files to avoid duplication
3. **Use proper priorities**: Use `lib.mkDefault` for defaults that should be overridable
4. **Update configuration.nix**: Add your module to the appropriate import section

### File Mappings

Old location → New location:

```
hardware-configuration.nix → core/hardware-configuration.nix
hardware-input.nix → gui/input.nix
performance.nix → virtualization/performance.nix
cache-optimization.nix → core/cache-optimization.nix
security.nix → security/nftables.nix
security-production.nix → security/production.nix
security-profiles.nix → security/profiles.nix
security-strict.nix → security/strict.nix
monitoring.nix → monitoring/prometheus.nix
alerting.nix → monitoring/alerting.nix
centralized-logging.nix → monitoring/logging.nix
backup.nix → automation/backup.nix
automation.nix → automation/services.nix
resource-quotas.nix → enterprise/quotas.nix
storage-quotas.nix → enterprise/storage-quotas.nix
network-isolation.nix → enterprise/network-isolation.nix
snapshot-lifecycle.nix → enterprise/snapshots.nix
vm-encryption.nix → enterprise/encryption.nix
web-dashboard.nix → web/dashboard.nix
enterprise-features.nix → enterprise/features.nix
```

## Benefits

1. **Easier Navigation**: Find related settings quickly by topic
2. **No Duplicates**: Each setting defined once, reused everywhere
3. **Clear Dependencies**: Imports organized by topic
4. **Better Maintainability**: Changes to a topic contained in one folder
5. **Modular Design**: Enable/disable entire topics easily
6. **Scalability**: Easy to add new topics as the system grows

## Testing

All configuration changes have been validated to:
- Eliminate duplicate definitions
- Maintain existing functionality
- Support both headless and management profiles
- Preserve local override capability
- Support optional enterprise features
