# Hypervisor Quick Reference Card

One-page reference for common operations. Keep this handy!

---

## Essential Commands

### VM Management
```bash
# List all VMs
virsh list --all

# Start a VM
virsh start <vm-name>

# Stop a VM (graceful)
virsh shutdown <vm-name>

# Stop a VM (force)
virsh destroy <vm-name>

# Delete a VM
virsh undefine <vm-name>
rm /var/lib/hypervisor/disks/<vm-name>.qcow2

# Get VM info
virsh dominfo <vm-name>

# Get VM IP address
virsh domifaddr <vm-name>

# Enable VM autostart
virsh autostart <vm-name>

# Disable VM autostart  
virsh autostart --disable <vm-name>
```

### Console Access
```bash
# SPICE viewer (best quality)
remote-viewer spice://127.0.0.1:$(virsh domdisplay <vm-name> | cut -d: -f4)

# VNC viewer
vncviewer 127.0.0.1:$(virsh vncdisplay <vm-name> | cut -d: -f2)

# Serial console (text only)
virsh console <vm-name>
# Press Ctrl+] to exit
```

### Disk Management
```bash
# Check disk usage
du -sh /var/lib/hypervisor/disks/*

# Create snapshot
virsh snapshot-create-as <vm-name> snapshot1 "Before update"

# List snapshots
virsh snapshot-list <vm-name>

# Restore snapshot
virsh snapshot-revert <vm-name> snapshot1

# Delete snapshot
virsh snapshot-delete <vm-name> snapshot1

# Backup VM disk
cp /var/lib/hypervisor/disks/<vm-name>.qcow2 /backups/
```

### Network Management
```bash
# List bridges
ip link show type bridge

# Show default network
virsh net-info default

# Start network
virsh net-start default

# Show network DHCP leases
virsh net-dhcp-leases default

# Create bridge (interactive)
/etc/hypervisor/scripts/bridge_helper.sh
```

---

## File Locations

### Configuration
```
/etc/hypervisor/                       # Main installation
├── configuration/                     # NixOS configs
│   ├── configuration.nix             # Main config
│   ├── security.nix                  # Security settings
│   ├── performance.nix               # Performance tuning
│   └── config.json                   # Runtime settings
├── scripts/                          # All management scripts
├── docs/                             # Documentation
└── vm_profiles/                      # VM profile templates
```

### Runtime State
```
/var/lib/hypervisor/                  # Stateful data
├── vm_profiles/                      # User VM profiles (JSON)
├── disks/                            # VM disk images (.qcow2)
├── xml/                              # Libvirt XML configs
├── isos/                             # Downloaded ISOs
├── backups/                          # Backup storage
└── logs/                             # Log files
```

### Logs
```
/var/lib/hypervisor/logs/menu.log     # Menu/TUI logs
/var/log/hypervisor/                  # System logs
journalctl -u libvirtd                # Libvirt logs
journalctl -u hypervisor-menu         # Menu service logs
```

---

## VM Profile JSON Template

```json
{
  "name": "my-vm",
  "cpus": 2,
  "memory_mb": 4096,
  "disk_gb": 20,
  "iso_path": "/var/lib/hypervisor/isos/ubuntu-24.04.iso",
  "arch": "x86_64",
  "network": {
    "bridge": "br0",
    "vhost": true
  },
  "audio": {
    "model": "ich9"
  },
  "video": {
    "heads": 1
  },
  "autostart": false
}
```

### Common Profile Modifications

**Remove ISO after install:**
```json
{
  "name": "my-vm",
  // Remove or comment out this line:
  // "iso_path": "/var/lib/hypervisor/isos/ubuntu-24.04.iso",
  ...
}
```

**Enable autostart:**
```json
{
  "autostart": true,
  "autostart_priority": 10
}
```

**Add CPU pinning:**
```json
{
  "cpu_pinning": [0, 1, 2, 3],
  "hugepages": true
}
```

**GPU passthrough:**
```json
{
  "hostdevs": ["0000:01:00.0", "0000:01:00.1"]
}
```

**Looking Glass (low-latency display):**
```json
{
  "looking_glass": {
    "enable": true,
    "size_mb": 128
  }
}
```

---

## Troubleshooting

### VM Won't Start

**Check KVM:**
```bash
ls -l /dev/kvm
# Should show: crw-rw---- 1 root kvm

# Add yourself to kvm group if needed:
sudo usermod -a -G kvm $USER
# Then logout and login
```

**Check libvirtd:**
```bash
systemctl status libvirtd
# Should show: active (running)

# Start if stopped:
sudo systemctl start libvirtd
```

**Check disk space:**
```bash
df -h /var/lib/hypervisor
# Need at least 20GB free
```

**View recent errors:**
```bash
journalctl -u libvirtd -n 50 --no-pager
```

### No Network in VM

**Check default network:**
```bash
virsh net-info default
# Should show: Active: yes

# Start if inactive:
virsh net-start default
virsh net-autostart default
```

**Check bridge (if using):**
```bash
ip link show br0
# Should show: state UP

# Restart networking:
sudo systemctl restart systemd-networkd
```

**Check firewall:**
```bash
# If using nftables:
sudo nft list ruleset | grep -A5 forward

# If using iptables:
sudo iptables -L FORWARD -v -n
```

### Can't Connect to Console

**Verify VM is running:**
```bash
virsh domstate <vm-name>
# Should show: running
```

**Get display info:**
```bash
virsh domdisplay <vm-name>
# Should show: spice://127.0.0.1:5900 or similar
```

**Install viewer:**
```bash
nix-env -iA nixpkgs.virt-viewer  # for remote-viewer
nix-env -iA nixpkgs.tigervnc     # for vncviewer
```

### Slow Performance

**Enable hugepages:**
```bash
# Add to VM profile:
"hugepages": true

# Enable in NixOS config:
hypervisor.performance.enableHugepages = true;
```

**Use CPU pinning:**
```bash
# Find available CPUs:
lscpu --extended

# Add to VM profile:
"cpu_pinning": [4, 5, 6, 7]
```

**Check resource usage:**
```bash
# Host CPU/memory:
htop

# Per-VM stats:
virsh domstats <vm-name>

# Top VMs by CPU:
virsh list --name | xargs -I {} virsh domstats {} --cpu-total
```

---

## System Maintenance

### Free Up Space
```bash
# Clean Nix store
sudo nix-collect-garbage -d

# List old VM disks
ls -lh /var/lib/hypervisor/disks/

# Remove old snapshots
virsh snapshot-list <vm-name>
virsh snapshot-delete <vm-name> <snapshot-name>
```

### Update System
```bash
# Update hypervisor
sudo /etc/hypervisor/scripts/update_hypervisor.sh

# Rebuild NixOS
sudo nixos-rebuild switch --flake /etc/nixos#$(hostname -s)

# Update VM profiles schema
sudo /etc/hypervisor/scripts/update_os_presets.sh
```

### Backup VMs
```bash
# Manual backup
sudo /etc/hypervisor/scripts/snapshots_backups.sh

# Or copy disk:
virsh shutdown <vm-name>
cp /var/lib/hypervisor/disks/<vm-name>.qcow2 /backup/
virsh start <vm-name>
```

### View System Health
```bash
# Run diagnostics
/etc/hypervisor/scripts/diagnose.sh

# Check security status
sudo aa-status                    # AppArmor
sudo auditctl -l                  # Audit rules
systemctl status sshd             # SSH status

# Check all VMs
virsh list --all
```

---

## Security Hardening

### Lock Down Hypervisor
```bash
# After initial setup, harden permissions:
sudo /etc/hypervisor/scripts/harden_permissions.sh

# To update later:
sudo /etc/hypervisor/scripts/relax_permissions.sh
# ... perform updates ...
sudo /etc/hypervisor/scripts/harden_permissions.sh
```

### Enable Strict Firewall
```nix
# Add to /etc/hypervisor/configuration/security-local.nix:
{
  hypervisor.security.strictFirewall = true;
  hypervisor.security.migrationTcp = false;
}
```

### Per-VM Firewall Rules
```bash
# Interactive rule management:
/etc/hypervisor/scripts/per_vm_firewall.sh
```

### Enable Encrypted VMs (AMD SEV)
```json
{
  "cpu_features": {
    "sev": true,
    "sev_es": true
  }
}
```

---

## Performance Tuning

### Recommended Settings

**Desktop VMs:**
```json
{
  "cpus": 4,
  "memory_mb": 8192,
  "hugepages": true,
  "audio": {"model": "ich9"},
  "video": {"heads": 1},
  "network": {"vhost": true}
}
```

**Server VMs:**
```json
{
  "cpus": 2,
  "memory_mb": 2048,
  "hugepages": false,
  "network": {"vhost": true, "bridge": "br0"}
}
```

**Gaming VMs:**
```json
{
  "cpus": 6,
  "memory_mb": 16384,
  "cpu_pinning": [4,5,6,7,8,9],
  "hugepages": true,
  "hostdevs": ["0000:01:00.0"],
  "looking_glass": {"enable": true, "size_mb": 128}
}
```

---

## Quick Diagnostics

**One-line health check:**
```bash
echo "KVM: $(test -e /dev/kvm && echo OK || echo FAIL)"; \
echo "Libvirt: $(systemctl is-active libvirtd)"; \
echo "Space: $(df -h /var/lib/hypervisor | tail -1 | awk '{print $4}') free"; \
echo "VMs: $(virsh list --name | wc -l) running"
```

**Resource usage:**
```bash
echo "Host CPU: $(top -bn1 | grep Cpu | awk '{print $2}')%"; \
echo "Host RAM: $(free -h | grep Mem | awk '{print $3 "/" $2}')"; \
virsh list --name | xargs -I {} sh -c 'echo "VM {}: $(virsh domstats {} --cpu-total | grep cpu.time)"'
```

---

## Emergency Recovery

### VM Won't Stop
```bash
# Force stop
virsh destroy <vm-name>

# If that fails, find PID and kill:
ps aux | grep qemu | grep <vm-name>
sudo kill -9 <PID>
```

### Can't Access Host
```bash
# From another terminal/SSH:
sudo pkill -9 qemu
sudo systemctl restart libvirtd
```

### Corrupted VM Disk
```bash
# Check and repair:
qemu-img check /var/lib/hypervisor/disks/<vm-name>.qcow2
qemu-img check -r all /var/lib/hypervisor/disks/<vm-name>.qcow2

# Restore from backup:
virsh destroy <vm-name>
mv /var/lib/hypervisor/disks/<vm-name>.qcow2 /tmp/corrupted.qcow2
cp /backup/<vm-name>.qcow2 /var/lib/hypervisor/disks/
virsh start <vm-name>
```

### Reset Everything
```bash
# Nuclear option - destroys all VMs:
sudo systemctl stop libvirtd
sudo rm -rf /var/lib/hypervisor/disks/*
sudo rm -rf /var/lib/hypervisor/xml/*
sudo rm -rf /var/lib/hypervisor/vm_profiles/*
sudo systemctl start libvirtd
# Then recreate VMs from scratch
```

---

## Useful Keyboard Shortcuts

**In TUI Menu:**
- `↑/↓` - Navigate
- `Space` - Select
- `Enter` - Confirm  
- `Tab` - Next field
- `Esc` - Cancel/Back

**In virsh console:**
- `Ctrl+]` - Exit console

**In SPICE viewer:**
- `Shift+F12` - Release mouse/keyboard
- `Shift+F11` - Fullscreen

---

## Getting Help

**Documentation:**
```bash
ls /etc/hypervisor/docs/
cat /etc/hypervisor/docs/quickstart.txt
less /etc/hypervisor/docs/README_install.md
```

**Logs:**
```bash
# Menu logs
tail -f /var/lib/hypervisor/logs/menu.log

# System logs  
journalctl -u libvirtd -f
journalctl -u hypervisor-menu -f

# Audit logs
sudo ausearch -m AVC -ts recent
```

**Community:**
- File issues on GitHub
- Check documentation in `/etc/hypervisor/docs/`
- Run diagnostics: `/etc/hypervisor/scripts/diagnose.sh`

---

## Pro Tips

1. **Always snapshot before major changes**
   ```bash
   virsh snapshot-create-as <vm-name> before-update
   ```

2. **Use cloud-init for fast deployments**
   - Download cloud image instead of ISO
   - Auto-configure SSH, network, users
   - Boot in ~30 seconds vs ~30 minutes

3. **Monitor resource usage**
   ```bash
   watch -n 1 'virsh list --name | xargs -I {} virsh domstats {} --cpu-total --balloon'
   ```

4. **Create VM templates**
   - Configure a VM perfectly
   - Snapshot it
   - Clone for new VMs

5. **Automate common tasks**
   ```bash
   # Start all VMs in a group:
   jq -r 'select(.autostart_group=="production") | .name' /var/lib/hypervisor/vm_profiles/*.json | xargs -I {} virsh start {}
   ```

---

**Remember:** When in doubt, check `/etc/hypervisor/docs/` or run the diagnostic tool!

```bash
/etc/hypervisor/scripts/diagnose.sh | less
```
