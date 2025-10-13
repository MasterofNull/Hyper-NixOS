# Quick Reference: Where to Find Settings

## Quick Lookup Table

| I want to configure... | Look in this file... |
|------------------------|---------------------|
| **System Basics** | |
| Hostname, timezone | `core/system.nix` |
| Bootloader, kernel | `core/boot.nix` |
| System packages | `core/packages.nix` |
| Hardware detection | `core/hardware-configuration.nix` |
| **Security** | |
| Firewall rules | `security/firewall.nix` |
| SSH settings | `security/ssh.nix` |
| Kernel hardening (sysctl) | `security/kernel-hardening.nix` |
| Audit logging | `security/base.nix` |
| Security profiles | `security/profiles.nix` |
| Maximum security mode | `security/strict.nix` |
| **Virtualization** | |
| Libvirt/KVM | `virtualization/libvirt.nix` |
| Performance tuning | `virtualization/performance.nix` |
| **Monitoring** | |
| Prometheus metrics | `monitoring/prometheus.nix` |
| Alerts | `monitoring/alerting.nix` |
| Log aggregation | `monitoring/logging.nix` |
| **Automation** | |
| Health checks, cleanup | `automation/services.nix` |
| VM backups | `automation/backup.nix` |
| **Enterprise** | |
| Resource quotas | `enterprise/quotas.nix` |
| Storage quotas | `enterprise/storage-quotas.nix` |
| Network isolation/VLANs | `enterprise/network-isolation.nix` |
| Snapshot management | `enterprise/snapshots.nix` |
| Disk encryption | `enterprise/encryption.nix` |
| **GUI** | |
| Desktop environment | `gui/desktop.nix` |
| Touchpad, keyboard | `gui/input.nix` |
| **Web** | |
| Web dashboard | `web/dashboard.nix` |
| **Maintenance** | |
| Directory permissions | `core/directories.nix` |
| Log rotation | `core/logrotate.nix` |
| Nix cache optimization | `core/cache-optimization.nix` |

## Common Tasks

### Enable Strict Security Mode
```nix
# In configuration.nix or local override
hypervisor.security.strictFirewall = true;
hypervisor.security.sshStrictMode = true;
```

### Change Security Profile
```nix
# Headless (zero-trust, operator user)
hypervisor.security.profile = "headless";

# Management (sudo access, admin user)
hypervisor.security.profile = "management";
```

### Enable Enterprise Features
```nix
# Make sure enterprise/features.nix exists, then in configuration.nix:
imports = [
  ./enterprise/features.nix
];
```

### Enable GUI at Boot
```nix
hypervisor.gui.enableAtBoot = true;
```

### Override Per-Host Settings
Create files in `/var/lib/hypervisor/configuration/`:
- `security-local.nix` - Security overrides
- `performance.nix` - Performance tuning
- `gui-local.nix` - GUI customization
- `system-local.nix` - System overrides

## Folder Purpose Summary

| Folder | Purpose | When to Use |
|--------|---------|-------------|
| `core/` | System fundamentals | Basic system configuration |
| `security/` | Security hardening | Security policies, access control |
| `virtualization/` | VM configuration | Libvirt, KVM, performance |
| `monitoring/` | Metrics & logging | Observability, alerts |
| `automation/` | Background tasks | Automated maintenance |
| `enterprise/` | Advanced features | Quotas, isolation, encryption |
| `gui/` | Desktop environment | When using GUI mode |
| `web/` | Web interface | Web dashboard management |

## Tips

1. **Finding a setting**: Use grep across the configuration:
   ```bash
   grep -r "setting-name" configuration/
   ```

2. **Understanding imports**: Check `configuration.nix` for the import order

3. **Testing changes**: Always dry-build first:
   ```bash
   sudo nixos-rebuild dry-build --flake .
   ```

4. **Local overrides**: Use `/var/lib/hypervisor/configuration/` for per-host customization

5. **Profile switching**: Change `hypervisor.security.profile` to switch between headless and management modes
