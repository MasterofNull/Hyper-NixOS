# System Administration Guide

This guide covers system administration tasks for Hyper-NixOS.

## System Management

### Service Management
```bash
# Check all hypervisor services
systemctl status hypervisor-*

# Restart services
sudo systemctl restart libvirtd
sudo systemctl restart hypervisor-api
```

### User Management
```bash
# Add user to virtualization groups
sudo usermod -aG libvirtd,kvm username

# Create hypervisor admin
sudo useradd -m -G wheel,libvirtd,kvm hvadmin
```

### Storage Pools

#### Creating Pools
```bash
# Directory-based pool
virsh pool-define-as mypool dir --target /data/vms
virsh pool-start mypool
virsh pool-autostart mypool

# LVM pool
virsh pool-define-as lvmpool logical --source-name vg0 --target /dev/vg0
```

#### Managing Pools
```bash
# List pools
virsh pool-list --all

# Pool info
virsh pool-info mypool

# Refresh pool
virsh pool-refresh mypool
```

### Backup and Recovery

#### VM Backups
```bash
# Backup VM
virsh dumpxml my-vm > my-vm.xml
cp /var/lib/libvirt/images/my-vm.qcow2 /backup/

# Restore VM
virsh define my-vm.xml
cp /backup/my-vm.qcow2 /var/lib/libvirt/images/
```

#### System Backups
See [Backup Guide](backup-recovery.md) for comprehensive backup strategies.

### Performance Tuning

#### CPU Pinning
```bash
# Pin VM to specific CPUs
virsh vcpupin my-vm 0 2
virsh vcpupin my-vm 1 3
```

#### Memory Optimization
- Enable huge pages
- Configure memory ballooning
- Set memory limits appropriately

### Troubleshooting

#### Common Issues
1. **VM won't start**: Check logs with `virsh domlog my-vm`
2. **Network issues**: Verify bridge configuration
3. **Storage full**: Check with `virsh pool-info`
4. **Permission denied**: Verify group membership

#### Debug Commands
```bash
# System logs
journalctl -u libvirtd -f

# VM logs
virsh domlog my-vm

# Check resources
virsh nodeinfo
```

## Security Hardening

See [Security Configuration](security-configuration.md) for detailed security setup.

## Monitoring

See [Monitoring Setup](monitoring-setup.md) for Prometheus/Grafana configuration.
