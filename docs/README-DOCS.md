# Administrator Guides

System administration guides for Hyper-NixOS.

## Core Guides

1. **[System Administration](system-administration.md)**
   - Service management
   - User management
   - Storage pools
   - Backup and recovery

2. **[Security Configuration](security-configuration.md)**
   - Security hardening
   - Access control
   - Audit logging
   - Threat detection

3. **[Network Configuration](network-configuration.md)**
   - Bridge setup
   - VLAN configuration
   - Firewall rules
   - Network isolation

4. **[Monitoring Setup](monitoring-setup.md)**
   - Prometheus configuration
   - Grafana dashboards
   - Alert rules
   - Performance metrics

## Quick Reference

- **Add user to libvirt**: `sudo usermod -aG libvirtd,kvm username`
- **Check services**: `systemctl status hypervisor-*`
- **View logs**: `journalctl -u libvirtd -f`

## Advanced Topics

- **[Enterprise Features](ENTERPRISE_FEATURES.md)** - For Professional/Enterprise tiers
- **[Automation Guide](AUTOMATION_GUIDE.md)** - Automation and orchestration
