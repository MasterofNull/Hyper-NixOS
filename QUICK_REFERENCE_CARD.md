# Hypervisor Quick Reference Card

**Essential commands and procedures for daily operations**

---

## 🚀 Daily Operations

### VM Management
```bash
# List all VMs
virsh list --all

# Start VM
virsh start <vm-name>

# Stop VM (graceful)
virsh shutdown <vm-name>

# Force stop VM
virsh destroy <vm-name>

# Restart VM
virsh reboot <vm-name>

# Access VM console
virsh console <vm-name>
# Exit console: Ctrl+]

# VM status
virsh dominfo <vm-name>
```

### System Health
```bash
# Quick health check
sudo /etc/hypervisor/scripts/system_health_check.sh

# View system status
systemctl status libvirtd
systemctl status hypervisor-menu

# Check disk space
df -h /var/lib/hypervisor

# Check resources
free -h
nproc
```

### Backups
```bash
# Manual backup
sudo /etc/hypervisor/scripts/automated_backup.sh backup <vm-name>

# List backups
sudo /etc/hypervisor/scripts/automated_backup.sh list

# Restore VM
sudo /etc/hypervisor/scripts/automated_backup.sh restore <vm-name>
```

---

## 🔧 Troubleshooting

### VM Won't Start
```bash
# 1. Run pre-flight check
/etc/hypervisor/scripts/preflight_check.sh vm-start "" "<vm-name>"

# 2. Check VM configuration
virsh dumpxml <vm-name>

# 3. Check logs
journalctl -u libvirtd -n 50

# 4. Verify disk exists
virsh domblklist <vm-name>
```

### Out of Disk Space
```bash
# Check usage
df -h /var/lib/hypervisor

# Delete old snapshots
virsh snapshot-list <vm-name>
virsh snapshot-delete <vm-name> <snapshot-name>

# Clean up old backups
find /var/lib/hypervisor/backups -mtime +60 -delete

# Run cleanup
sudo systemctl start hypervisor-storage-cleanup
```

### Network Issues
```bash
# Check bridge
ip addr show br0

# Test connectivity
ping -c 4 8.8.8.8

# Restart networkd
sudo systemctl restart systemd-networkd

# Check firewall
sudo iptables -L -n
```

---

## 📊 Monitoring

### Check Automation Status
```bash
# List timers
systemctl list-timers | grep hypervisor

# Check specific service
systemctl status hypervisor-backup
journalctl -u hypervisor-backup -n 20
```

### View Metrics
```bash
# Latest metrics
cat /var/lib/hypervisor/metrics-*.json | tail -1 | jq .

# Health status
cat /var/lib/hypervisor/health-status.json | jq .

# Resource usage
htop
iotop
```

---

## 🔄 Updates

### Check for Updates
```bash
sudo /etc/hypervisor/scripts/update_manager.sh check
```

### Apply Updates
```bash
# Test only (dry-run)
sudo nixos-rebuild dry-build --flake "/etc/hypervisor#$(hostname -s)"

# Apply updates
sudo /etc/hypervisor/scripts/update_manager.sh update

# Rollback if needed
sudo /etc/hypervisor/scripts/update_manager.sh rollback
```

---

## 🔒 Security

### Check Security Status
```bash
# Verify no passwordless sudo
sudo -l

# Check SSH configuration
sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'

# View audit logs
sudo ausearch -m all -ts recent

# Check firewall
sudo iptables -L -n -v
```

### User Management
```bash
# List users
cat /etc/passwd | grep -v nologin | grep -v false

# Check groups
groups <username>

# View sudo permissions
sudo -l -U <username>
```

---

## 🌐 Network

### Bridge Management
```bash
# Create/configure bridge
sudo /etc/hypervisor/scripts/bridge_helper.sh

# Check bridge status
ip link show br0
bridge link

# List VM networks
virsh net-list --all

# Check DHCP leases
virsh net-dhcp-leases default
```

---

## 💾 Storage

### Disk Management
```bash
# List VM disks
virsh domblklist <vm-name>

# Check disk info
qemu-img info /path/to/disk.qcow2

# Resize disk
qemu-img resize /path/to/disk.qcow2 +10G

# Check storage pool
virsh pool-list --all
virsh pool-info default
```

### Snapshots
```bash
# Create snapshot
virsh snapshot-create-as <vm-name> <snapshot-name> --description "backup before update"

# List snapshots
virsh snapshot-list <vm-name>

# Revert to snapshot
virsh snapshot-revert <vm-name> <snapshot-name>

# Delete snapshot
virsh snapshot-delete <vm-name> <snapshot-name>
```

---

## 📁 File Locations

### Important Directories
```
/etc/hypervisor/               # Configuration and scripts
/etc/hypervisor/scripts/       # Management scripts
/var/lib/hypervisor/           # VM data and state
/var/lib/hypervisor/disks/     # VM disk images
/var/lib/hypervisor/isos/      # ISO images
/var/lib/hypervisor/backups/   # VM backups
/var/lib/hypervisor/logs/      # Operation logs
/var/log/libvirt/              # Libvirt logs
```

### Configuration Files
```
/etc/hypervisor/config.json           # Main config
/etc/hypervisor/flake.nix             # NixOS flake
/etc/nixos/configuration.nix          # System config
/var/lib/hypervisor/configuration/    # Local overrides
```

### Log Files
```
/var/lib/hypervisor/logs/health-*.log      # Health checks
/var/lib/hypervisor/logs/backup-*.log      # Backups
/var/lib/hypervisor/logs/update-*.log      # Updates
/var/log/libvirt/libvirtd.log              # Libvirt daemon
journalctl -u libvirtd                     # System journal
```

---

## 🆘 Emergency Procedures

### System Won't Boot
1. Select previous NixOS generation in GRUB
2. System auto-rolls back on boot failure
3. Check: `nixos-rebuild list-generations`

### VM Crashed
```bash
# Check state
virsh domstate <vm-name>

# Try restart
virsh destroy <vm-name>
virsh start <vm-name>

# Check logs
journalctl -u libvirtd -f

# Restore from backup if needed
sudo /etc/hypervisor/scripts/automated_backup.sh restore <vm-name>
```

### Out of Memory
```bash
# Check usage
free -h

# Stop non-critical VMs
virsh shutdown <vm-name>

# Clear cache (if safe)
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
```

### Disk Full
```bash
# Check usage
df -h

# Quick cleanup
sudo systemctl start hypervisor-storage-cleanup

# Delete old generations
sudo nix-collect-garbage -d

# Delete old snapshots
virsh snapshot-delete <vm> <snapshot>
```

---

## 📞 Support Resources

### Documentation
- Main guide: `README.md`
- Security: `docs/SECURITY_MODEL.md`
- Network: `docs/NETWORK_CONFIGURATION.md`
- Troubleshooting: `docs/TROUBLESHOOTING.md`

### Logs to Check
1. Health check: `/var/lib/hypervisor/logs/health-*.log`
2. System journal: `journalctl -u libvirtd -n 50`
3. VM console: `virsh console <vm-name>`
4. Audit log: `sudo ausearch -ts recent`

### Quick Diagnostics
```bash
# Run full diagnostic
sudo /etc/hypervisor/scripts/system_health_check.sh

# Check automation
systemctl list-timers | grep hypervisor

# View recent errors
journalctl -p err -n 50
```

---

## 📌 Useful Aliases (Optional)

Add to `~/.bashrc`:
```bash
# VM shortcuts
alias vlist='virsh list --all'
alias vstart='virsh start'
alias vstop='virsh shutdown'
alias vkill='virsh destroy'
alias vconsole='virsh console'

# System shortcuts
alias health='sudo /etc/hypervisor/scripts/system_health_check.sh'
alias backup='sudo /etc/hypervisor/scripts/automated_backup.sh'
alias updates='sudo /etc/hypervisor/scripts/update_manager.sh check'

# Monitoring shortcuts
alias hstatus='systemctl list-timers | grep hypervisor'
alias hlogs='journalctl -u hypervisor-* -f'
alias hmetrics='cat /var/lib/hypervisor/metrics-*.json | tail -1 | jq .'
```

---

**Keep this card handy for quick reference during operations!**
