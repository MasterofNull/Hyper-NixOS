# Administrator Guide - Hyper-NixOS

## 🎯 **Purpose**

This guide covers system administration tasks for Hyper-NixOS, including configuration management, security hardening, monitoring setup, and maintenance procedures.

## 🏗️ **System Architecture Overview**

### Core Components
- **NixOS Base** - Declarative system configuration
- **libvirt/QEMU** - Virtualization stack
- **Security Profiles** - Headless (production) vs Management (development)
- **Web Dashboard** - Browser-based VM management
- **Monitoring Stack** - Prometheus + Grafana + Alertmanager
- **Automation** - Backup, scheduling, maintenance

### Configuration Structure
```
/etc/hypervisor/
├── configuration.nix     ← Main system configuration
├── modules/             ← Feature modules
│   ├── core/           ← Core system options
│   ├── web/            ← Web dashboard
│   ├── monitoring/     ← Observability
│   ├── security/       ← Security hardening
│   └── automation/     ← Backup & scheduling
└── scripts/            ← Management scripts
```

## 🔒 **Security Administration**

### Security Profiles

#### Headless Profile (Production)
```nix
hypervisor.security.profile = "headless";
```
- **Zero-trust approach** - No sudo access for operator
- **Polkit-based permissions** - Granular VM management
- **Minimal attack surface** - Only essential services
- **Audit logging** - All operations logged

#### Management Profile (Development)
```nix
hypervisor.security.profile = "management";
```
- **Sudo access** - Full system administration
- **Convenience features** - Easier development workflow
- **Expanded permissions** - Suitable for trusted environments

### Security Hardening Options

#### SSH Hardening
```nix
hypervisor.security.sshStrictMode = true;
```
- Strongest encryption algorithms only
- Reduced connection limits
- Enhanced authentication requirements

#### Firewall Hardening
```nix
hypervisor.security.strictFirewall = true;
```
- Default-deny nftables rules
- Minimal open ports
- Interface-specific restrictions

#### Additional Security
```nix
# Kernel hardening
boot.kernelParams = [
  "slab_nomerge"
  "init_on_alloc=1"
  "init_on_free=1"
  "page_alloc.shuffle=1"
];

# Network security
networking.firewall.logRefusedConnections = true;
security.auditd.enable = true;
```

## 📊 **Monitoring Administration**

### Prometheus Stack
```nix
hypervisor.monitoring = {
  enablePrometheus = true;
  enableGrafana = true;
  enableAlertmanager = true;
  prometheusPort = 9090;
  grafanaPort = 3000;
};
```

### Key Metrics Monitored
- **System Resources** - CPU, memory, disk, network
- **VM Performance** - Per-VM resource usage
- **Service Health** - libvirtd, web dashboard, backup services
- **Security Events** - Failed logins, permission changes

### Alert Configuration
```yaml
# /etc/hypervisor/monitoring/alert-rules.yml
groups:
  - name: hypervisor
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage > 90
        for: 5m
        annotations:
          summary: "High CPU usage detected"
      
      - alert: VMDown
        expr: libvirt_domain_state != 1
        annotations:
          summary: "VM {{ $labels.domain }} is down"
```

### Grafana Dashboards
- **System Overview** - Host system metrics
- **VM Performance** - Individual VM statistics
- **Network Traffic** - Bridge and interface metrics
- **Storage Usage** - Disk space and I/O metrics

## 🤖 **Automation Administration**

### Backup Configuration
```nix
hypervisor.backup = {
  enable = true;
  schedule = "daily";  # or "weekly", or custom systemd timer
  destination = "/var/lib/hypervisor/backups";
  encrypt = true;
  compression = "zstd";
  retention = {
    daily = 7;
    weekly = 4;
    monthly = 3;
  };
};
```

### Backup Management
```bash
# Manual backup
sudo /etc/hypervisor/scripts/automated_backup.sh

# Check backup status
systemctl status hypervisor-backup
journalctl -u hypervisor-backup -f

# List backups
ls -la /var/lib/hypervisor/backups/

# Restore from backup
sudo /etc/hypervisor/scripts/restore_backup.sh backup-name
```

### Scheduled Maintenance
```nix
# Custom maintenance tasks
systemd.services.hypervisor-maintenance = {
  description = "Daily maintenance tasks";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "/etc/hypervisor/scripts/daily_maintenance.sh";
  };
};

systemd.timers.hypervisor-maintenance = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "daily";
    Persistent = true;
  };
};
```

## 🌐 **Network Administration**

### Bridge Configuration
```bash
# Create VM bridge
sudo /etc/hypervisor/scripts/foundational_networking_setup.sh

# List bridges
ip link show type bridge

# Check bridge status
brctl show
```

### VLAN Setup
```nix
networking.vlans = {
  vlan10 = {
    id = 10;
    interface = "br0";
  };
  vlan20 = {
    id = 20;
    interface = "br0";
  };
};
```

### Firewall Management
```nix
# Interface-specific rules
networking.firewall.interfaces = {
  "br0" = {
    allowedTCPPorts = [ 22 80 443 ];
  };
  "lo" = {
    allowedTCPPorts = [ 8080 9090 3000 ];
  };
};
```

## 💾 **Storage Administration**

### VM Storage Management
```bash
# List VM disks
virsh vol-list default

# Create new disk
virsh vol-create-as default vm-disk.qcow2 20G --format qcow2

# Resize disk
virsh vol-resize vm-disk.qcow2 30G --pool default
```

### Backup Storage
```bash
# Check backup space
df -h /var/lib/hypervisor/backups

# Clean old backups
sudo /etc/hypervisor/scripts/cleanup_backups.sh

# Monitor disk usage
du -sh /var/lib/hypervisor/*
```

### Storage Quotas
```nix
# Enable quotas
boot.supportedFilesystems = [ "ext4" ];
services.quota = {
  enable = true;
  devices = [ "/dev/sda1" ];
};
```

## 🔧 **System Maintenance**

### Regular Tasks

#### Daily
- Check system logs: `journalctl --since today`
- Verify backup completion: `systemctl status hypervisor-backup`
- Monitor resource usage: `htop`, `df -h`
- Check VM status: `virsh list --all`

#### Weekly
- Update system: `sudo nixos-rebuild switch --upgrade`
- Clean old generations: `sudo nix-collect-garbage -d`
- Review security logs: `journalctl -u sshd --since "1 week ago"`
- Test backup restoration

#### Monthly
- Review and rotate logs
- Update documentation
- Security audit
- Performance analysis

### Configuration Management
```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"

# Test configuration without applying
sudo nixos-rebuild dry-build --flake "/etc/hypervisor#$(hostname -s)"

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

### Log Management
```bash
# View system logs
journalctl -f

# Service-specific logs
journalctl -u libvirtd -f
journalctl -u hypervisor-web-dashboard -f

# Log rotation
sudo systemctl restart systemd-journald
```

## 🚨 **Troubleshooting**

### Common Issues

#### Service Failures
```bash
# Check service status
systemctl status <service>

# Restart failed service
sudo systemctl restart <service>

# Check dependencies
systemctl list-dependencies <service>
```

#### Permission Issues
```bash
# Check user groups
groups <username>

# Fix libvirt permissions
sudo usermod -a -G libvirtd <username>

# Check file permissions
ls -la /var/lib/hypervisor/
```

#### Network Issues
```bash
# Check bridge status
ip link show
brctl show

# Test connectivity
ping -c 3 <vm-ip>

# Check firewall rules
sudo iptables -L
```

### Performance Monitoring
```bash
# System resources
htop
iotop
nethogs

# VM performance
virsh domstats <vm-name>
virsh cpu-stats <vm-name>
```

## 📚 **Additional Resources**

- **[Security Model](SECURITY_MODEL.md)** - Detailed security architecture
- **[Network Configuration](NETWORK_CONFIGURATION.md)** - Advanced networking
- **[Monitoring Setup](MONITORING_SETUP.md)** - Observability configuration
- **[Common Issues](../COMMON_ISSUES_AND_SOLUTIONS.md)** - Troubleshooting guide

## 🎯 **Best Practices**

1. **Configuration Management**
   - Use version control for configuration changes
   - Test changes in dry-build mode first
   - Document custom modifications

2. **Security**
   - Regularly update the system
   - Monitor security logs
   - Use appropriate security profile for environment

3. **Monitoring**
   - Set up alerting for critical issues
   - Regularly review metrics and logs
   - Monitor backup completion

4. **Maintenance**
   - Follow regular maintenance schedule
   - Keep documentation updated
   - Test disaster recovery procedures

Remember: Hyper-NixOS is designed to be secure by default while providing the flexibility needed for various use cases. Always consider the security implications of configuration changes.