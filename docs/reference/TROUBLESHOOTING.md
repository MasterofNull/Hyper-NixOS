# Hypervisor Troubleshooting Guide

**Quick fixes for common issues**

---

## Table of Contents

- [Quick Diagnostic](#quick-diagnostic)
- [VM Won't Start](#vm-wont-start)
- [Network Problems](#network-problems)
- [Performance Issues](#performance-issues)
- [Console/Display Problems](#consoledisplay-problems)
- [Storage Issues](#storage-issues)
- [Installation Problems](#installation-problems)
- [Security/Permission Errors](#securitypermission-errors)
- [System-Level Issues](#system-level-issues)
- [Recovery Procedures](#recovery-procedures)

---

## Quick Diagnostic

**Start here when you have any problem:**

```bash
# Run comprehensive diagnostics
/etc/hypervisor/scripts/diagnose.sh

# Check specific components
systemctl status libvirtd    # Libvirt daemon
virsh list --all             # VM states
df -h /var/lib/hypervisor    # Disk space
ip link show                  # Network interfaces
journalctl -u libvirtd -n 50 # Recent errors
```

---

## VM Won't Start

### Error: "Missing dependency: jq"

**Cause:** Required tools not installed

**Solution:**
```bash
# Install missing dependencies
nix-env -iA nixpkgs.jq nixpkgs.libvirt

# Verify
command -v jq
command -v virsh
```

### Error: "KVM device not accessible"

**Cause:** No /dev/kvm or wrong permissions

**Check:**
```bash
ls -l /dev/kvm
# Should show: crw-rw---- 1 root kvm /dev/kvm
```

**Solution:**
```bash
# Add user to kvm group
sudo usermod -a -G kvm $USER

# Re-login for group to take effect
# Or run: newgrp kvm

# Verify
groups | grep kvm
```

**If /dev/kvm doesn't exist:**
- Virtualization is disabled in BIOS
- Reboot and enable Intel VT-x or AMD-V
- Check: `grep -E '(vmx|svm)' /proc/cpuinfo`

### Error: "Failed to create disk image"

**Cause 1: Insufficient disk space**

**Check:**
```bash
df -h /var/lib/hypervisor
```

**Solution:**
```bash
# Free up space
sudo nix-collect-garbage -d

# Check again
df -h /var/lib/hypervisor
```

**Cause 2: Permission denied**

**Check:**
```bash
ls -ld /var/lib/hypervisor/disks
# Should be writable by your user or libvirtd group
```

**Solution:**
```bash
# Fix permissions
sudo chown -R $USER:$USER /var/lib/hypervisor/disks
# Or for group access:
sudo chown -R :libvirtd /var/lib/hypervisor/disks
sudo chmod -R g+w /var/lib/hypervisor/disks
```

### Error: "ISO verification required"

**Cause:** ISO hasn't been checksummed

**Solution:**
```bash
# Option 1: Verify through menu
# Menu → More Options → ISO Manager → Validate ISO checksum

# Option 2: Manual verification
cd /var/lib/hypervisor/isos
# Get checksum from official source (e.g., Ubuntu website)
echo "CHECKSUM  filename.iso" | sha256sum -c
# If matches, create marker:
touch filename.iso.sha256.verified

# Option 3: Bypass (NOT RECOMMENDED)
export HYPERVISOR_REQUIRE_ISO_VERIFICATION=0
# Then try starting VM again
```

### Error: "Invalid VM name"

**Cause:** Name contains invalid characters

**Valid characters:** A-Z, a-z, 0-9, `.`, `_`, `-`  
**Must start with:** Alphanumeric character  
**Length:** 1-64 characters

**Solution:**
```bash
# Edit profile and fix name
nano /var/lib/hypervisor/vm-profiles/your-vm.json

# Valid names:
# ✓ "my-vm"
# ✓ "ubuntu_server"
# ✓ "vm01"
# ✗ "-invalid"
# ✗ ".invalid"
# ✗ "my vm" (space)
```

### VM Starts But Immediately Stops

**Cause:** Configuration error or resource conflict

**Check logs:**
```bash
journalctl -u libvirtd -n 100

# Also check
virsh dumpxml VM-NAME | less
# Look for configuration issues
```

**Common causes:**
- Duplicate MAC address
- Port conflict (VNC/SPICE)
- Invalid device configuration
- Resource limits too restrictive

**Solution:**
```bash
# Generate new MAC address
virsh dumpxml VM-NAME > /tmp/vm.xml
# Edit /tmp/vm.xml, find <mac address='...'/>
# Change to random: 52:54:00:XX:XX:XX
virsh define /tmp/vm.xml
```

---

## Network Problems

### No Internet in VM

**Symptom:** VM has no network connectivity

**Check from inside VM:**
```bash
# Check interface is up
ip link show

# Check IP address assigned
ip addr show

# Check default route
ip route show

# Try ping
ping 8.8.8.8
```

**Check from host:**
```bash
# Check default network
virsh net-info default
# Should show: Active: yes

# Check DHCP leases
virsh net-dhcp-leases default

# Check bridge
ip link show virbr0
```

**Solution 1: Start default network**
```bash
virsh net-start default
virsh net-autostart default
```

**Solution 2: Restart VM networking**
```bash
# From inside VM
sudo systemctl restart NetworkManager
# Or
sudo dhclient -r && sudo dhclient
```

**Solution 3: Check firewall**
```bash
# On host
sudo iptables -L -n -v | grep virbr0

# May need to allow forwarding
sudo sysctl net.ipv4.ip_forward=1
```

### Can't Reach VM from Host

**Symptom:** Can't SSH or access services in VM

**Check:**
```bash
# Get VM IP
virsh domifaddr VM-NAME

# Try ping
ping VM-IP

# Check if service is listening in VM
# From inside VM:
ss -tlnp | grep PORT
```

**Solution:**
```bash
# Check VM firewall (inside VM)
sudo iptables -L -n
# Or on Ubuntu/Fedora
sudo ufw status
sudo firewall-cmd --list-all

# Allow SSH (example)
sudo ufw allow 22/tcp
```

### Bridge Network Not Working

**Symptom:** Created bridge but VMs can't use it

**Check:**
```bash
# Check bridge exists
ip link show br0

# Check bridge has interfaces
bridge link show

# Check bridge configuration
cat /etc/systemd/network/br0.netdev
cat /etc/systemd/network/br0.network
```

**Solution:**
```bash
# Recreate bridge
sudo /etc/hypervisor/scripts/bridge_helper.sh

# Or manually
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip link set eth0 master br0
```

---

## Performance Issues

### VM is Slow/Laggy

**Check resource usage:**
```bash
# On host
htop

# VM CPU time
virsh domstats VM-NAME | grep cpu.time

# VM memory usage
virsh dominfo VM-NAME | grep "Used memory"
```

**Solution 1: Enable hugepages**

Edit VM profile:
```json
{
  "hugepages": true
}
```

Then restart VM.

**Solution 2: CPU pinning**

Edit VM profile:
```json
{
  "cpu_pinning": [0, 1]
}
```

Pins vCPUs to specific host CPUs for better performance.

**Solution 3: Check I/O scheduler**

Inside VM:
```bash
cat /sys/block/vda/queue/scheduler
# Should be: [none] or [mq-deadline] for virtio

# Change if needed
echo "none" | sudo tee /sys/block/vda/queue/scheduler
```

**Solution 4: Verify virtio drivers**

Inside VM:
```bash
# Check if virtio modules loaded
lsmod | grep virtio

# Should see: virtio_net, virtio_blk, etc.
```

For Windows, install virtio drivers from:
https://fedorapeople.org/groups/virt/virtio-win/

### High CPU Usage on Host

**Cause:** VM consuming too many resources

**Check:**
```bash
# VM CPU usage
virt-top

# Or
top -p $(pgrep qemu-system)
```

**Solution:**
```bash
# Limit VM CPU quota
# Edit /etc/systemd/system/libvirt-qemu.service.d/override.conf
CPUQuota=50%

# Or set cgroup limits
virsh schedinfo VM-NAME --set cpu_shares=512
```

### Disk I/O is Slow

**Check:**
```bash
# Inside VM
sudo iostat -x 1 5

# On host
iotop
```

**Solution 1: Use virtio-scsi**

Edit VM profile:
```json
{
  "disk": {
    "driver": "virtio-scsi"
  }
}
```

**Solution 2: Check disk cache mode**

```bash
virsh dumpxml VM-NAME | grep "driver.*cache"
# Recommended: cache='none' or cache='writeback'
```

**Solution 3: Use SSD for VM storage**

```bash
# Move disk to SSD
mv /var/lib/hypervisor/disks/vm.qcow2 /mnt/ssd/
# Update path in profile
```

---

## Console/Display Problems

### Can't Connect to Console

**Error:** "No display available"

**Check:**
```bash
# VM must be running
virsh domstate VM-NAME

# Get display URI
virsh domdisplay VM-NAME
```

**Solution 1: Install virt-viewer**
```bash
nix-env -iA nixpkgs.virt-viewer
```

**Solution 2: Check graphics configuration**
```bash
virsh dumpxml VM-NAME | grep -A 5 "<graphics"

# Should show SPICE or VNC configuration
```

**Solution 3: Start VM with graphics**

Edit profile to ensure graphics are enabled:
```json
{
  "video": {
    "heads": 1
  }
}
```

### Console is Blank/Black Screen

**Causes:**
1. VM is at boot menu (wait or press Enter)
2. Display not initialized
3. Guest OS not configured for console

**Solution:**
```bash
# Check if VM is actually running
virsh dominfo VM-NAME

# Check for kernel messages
virsh console VM-NAME
# Press Enter a few times

# Reset VM
virsh reset VM-NAME
```

### Mouse Not Syncing

**Cause:** Missing tablet input device

**Solution:**

VM profiles should include tablet input for mouse sync:
```xml
<input type='tablet' bus='usb'/>
```

Or install SPICE guest tools inside VM:
```bash
# Ubuntu/Debian
sudo apt install spice-vdagent

# Fedora
sudo dnf install spice-vdagent

# Enable
sudo systemctl enable --now spice-vdagent
```

### Can't Copy/Paste Between Host and VM

**Cause:** Missing SPICE agent

**Solution:**

Inside VM:
```bash
# Ubuntu/Debian
sudo apt install spice-vdagent

# Fedora
sudo dnf install spice-vdagent

# Windows
# Download from: https://www.spice-space.org/download.html
```

Restart VM or spice-vdagent service.

---

## Storage Issues

### Disk Full

**Check:**
```bash
df -h /var/lib/hypervisor
```

**Solution:**
```bash
# Clean up old ISOs
rm /var/lib/hypervisor/isos/old-*.iso

# Remove unused VM disks
virsh vol-list default
virsh vol-delete --pool default unused-disk.qcow2

# Clean Nix store
sudo nix-collect-garbage -d

# Clean logs
sudo journalctl --vacuum-time=7d
```

### Can't Resize VM Disk

**To increase VM disk size:**

```bash
# 1. Shut down VM
virsh shutdown VM-NAME

# 2. Resize qcow2 image
qemu-img resize /var/lib/hypervisor/disks/VM-NAME.qcow2 +10G

# 3. Start VM
virsh start VM-NAME

# 4. Inside VM, resize partition
# For ext4:
sudo growpart /dev/vda 1
sudo resize2fs /dev/vda1

# For XFS:
sudo growpart /dev/vda 1
sudo xfs_growfs /
```

### Snapshot Failed

**Error:** "Cannot create snapshot"

**Cause 1: External snapshot required**

```bash
# Create external snapshot
virsh snapshot-create-as VM-NAME snapshot-name \
  --disk-only --atomic
```

**Cause 2: Insufficient space**

Check disk space and free up if needed.

**Cause 3: VM using raw disk**

Raw disks don't support internal snapshots. Use qcow2.

### Disk Corruption

**Symptoms:** VM won't boot, filesystem errors

**Check:**
```bash
# Check qcow2 integrity
qemu-img check /var/lib/hypervisor/disks/VM-NAME.qcow2

# If errors, try repair
qemu-img check -r all /var/lib/hypervisor/disks/VM-NAME.qcow2
```

**Recovery:**
```bash
# Restore from snapshot if available
virsh snapshot-revert VM-NAME snapshot-name

# Or restore from backup
cp /var/lib/hypervisor/backups/VM-NAME.qcow2 \
   /var/lib/hypervisor/disks/VM-NAME.qcow2
```

---

## Installation Problems

### OS Installer Won't Boot

**Check:**
1. ISO is correctly attached
2. Boot order is correct
3. Firmware (UEFI/BIOS) matches OS

**Solution:**
```bash
# Check XML
virsh dumpxml VM-NAME | grep -A 5 "<os>"

# Should show boot from cdrom first:
# <boot dev='cdrom'/>
# <boot dev='hd'/>

# Check ISO path
virsh dumpxml VM-NAME | grep -A 3 "<disk.*cdrom"
```

### Installation Hangs/Freezes

**Possible causes:**
- Insufficient memory
- Slow disk I/O
- Network issues during package download

**Solutions:**
1. Increase memory: Edit profile, increase `memory_mb`
2. Use local mirror for packages
3. Check host resource usage: `htop`

### Can't Find Disk During Installation

**Cause:** Using wrong disk driver

**For Windows:**
Need virtio drivers loaded during installation.

**Solution:**
1. Download virtio-win ISO
2. Attach as second CD-ROM
3. During Windows install, load driver from second CD

**For Linux:**
Should work with virtio by default.

---

## Security/Permission Errors

### Permission Denied on /dev/kvm

**Solution:**
```bash
# Add user to kvm group
sudo usermod -a -G kvm,libvirtd $USER

# Logout and login again
# Or
newgrp kvm
```

### Can't Access VM Disks

**Check:**
```bash
ls -l /var/lib/hypervisor/disks/
```

**Solution:**
```bash
# Fix ownership
sudo chown -R $USER:libvirtd /var/lib/hypervisor/disks
sudo chmod -R 0750 /var/lib/hypervisor/disks
```

### AppArmor Blocking QEMU

**Check logs:**
```bash
sudo journalctl -k | grep -i apparmor | grep -i denied
```

**Temporary disable:**
```bash
sudo aa-complain /usr/bin/qemu-system-x86_64
```

**Permanent fix:**

Edit AppArmor profile:
```bash
sudo nano /etc/apparmor.d/abstractions/libvirt-qemu
```

Add required paths, then:
```bash
sudo apparmor_parser -r /etc/apparmor.d/abstractions/libvirt-qemu
```

---

## System-Level Issues

### Libvirtd Won't Start

**Check:**
```bash
systemctl status libvirtd
journalctl -u libvirtd -n 50
```

**Common causes:**
1. Configuration syntax error
2. Conflicting daemon (old libvirt)
3. Missing dependencies

**Solution:**
```bash
# Check config syntax
sudo libvirtd --version
sudo libvirtd -f /etc/libvirt/libvirtd.conf --validate

# Remove stale PID file
sudo rm /var/run/libvirtd.pid

# Restart
sudo systemctl restart libvirtd
```

### IOMMU Not Working (for VFIO)

**Check:**
```bash
dmesg | grep -i iommu
ls /sys/kernel/iommu_groups/
```

**Solution:**

Add kernel parameters in configuration.nix:
```nix
boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
# Or for AMD:
boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];
```

Rebuild and reboot:
```bash
sudo nixos-rebuild switch
sudo reboot
```

### System Runs Out of Memory

**Symptoms:** OOM killer, system freeze

**Check:**
```bash
free -h
dmesg | grep -i "out of memory"
```

**Solution:**
```bash
# Reduce VM memory
# Edit each VM profile, reduce memory_mb

# Add swap
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent in configuration.nix
```

---

## Recovery Procedures

### VM Won't Boot After Host Update

**Cause:** Mismatched OVMF/firmware

**Solution:**
```bash
# Recreate NVRAM
virsh destroy VM-NAME
rm /var/lib/hypervisor/VM-NAME.OVMF_VARS.fd
cp /run/current-system/sw/share/OVMF/OVMF_VARS.fd \
   /var/lib/hypervisor/VM-NAME.OVMF_VARS.fd
virsh start VM-NAME
```

### Rescue Boot Hung VM

**Solution 1: Force reset**
```bash
virsh reset VM-NAME
```

**Solution 2: Force stop and restart**
```bash
virsh destroy VM-NAME
virsh start VM-NAME
```

**Solution 3: Boot from rescue ISO**
```bash
# Edit XML temporarily
virsh edit VM-NAME
# Change boot order to boot from cdrom first
# Attach rescue ISO
```

### Restore VM from Backup

```bash
# 1. Stop VM
virsh destroy VM-NAME
virsh undefine VM-NAME

# 2. Restore disk
cp /var/lib/hypervisor/backups/VM-NAME-DATE.qcow2 \
   /var/lib/hypervisor/disks/VM-NAME.qcow2

# 3. Restore profile
cp /var/lib/hypervisor/backups/VM-NAME-DATE.json \
   /var/lib/hypervisor/vm-profiles/VM-NAME.json

# 4. Recreate VM
/etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh \
  /var/lib/hypervisor/vm-profiles/VM-NAME.json
```

### Reset to Clean State

**Nuclear option - removes all VMs:**

```bash
# CAUTION: This will delete ALL VMs and data!

# 1. Stop all VMs
virsh list --all | awk 'NR>2 {print $2}' | while read vm; do
  virsh destroy "$vm" 2>/dev/null
  virsh undefine "$vm" --remove-all-storage 2>/dev/null
done

# 2. Clean directories
rm -rf /var/lib/hypervisor/disks/*
rm -rf /var/lib/hypervisor/vm-profiles/*.json
rm -rf /var/lib/hypervisor/xml/*

# 3. Restart libvirtd
sudo systemctl restart libvirtd

# 4. Run first-boot wizard
/etc/hypervisor/scripts/setup_wizard.sh
```

---

## Getting More Help

### Log Locations

```bash
# Libvirt logs
journalctl -u libvirtd -f

# VM console logs
ls /var/log/libvirt/qemu/

# Hypervisor menu logs
tail -f /var/lib/hypervisor/logs/menu.log

# System messages
dmesg | tail -50
```

### Collect Debug Information

```bash
# Run full diagnostics
/etc/hypervisor/scripts/diagnose.sh > /tmp/diagnostics.txt

# Collect VM info
virsh dumpxml VM-NAME > /tmp/vm-config.xml
virsh dominfo VM-NAME > /tmp/vm-info.txt
virsh domstats VM-NAME > /tmp/vm-stats.txt

# Package for support
tar -czf /tmp/hypervisor-debug.tar.gz /tmp/*.txt /tmp/*.xml
```

### Enable Debug Logging

```bash
# Enable libvirt debug logging
sudo systemctl edit libvirtd

# Add:
[Service]
Environment="LIBVIRT_DEBUG=1"

# Restart
sudo systemctl restart libvirtd

# View logs
journalctl -u libvirtd -f
```

---

## Quick Command Reference

```bash
# Diagnostics
/etc/hypervisor/scripts/diagnose.sh   # Full system check
virsh dominfo VM-NAME                 # VM details
virsh domstats VM-NAME                # VM statistics
systemctl status libvirtd             # Libvirt status
df -h /var/lib/hypervisor             # Disk space

# VM Control
virsh list --all                      # List all VMs
virsh start VM-NAME                   # Start
virsh shutdown VM-NAME                # Graceful stop
virsh destroy VM-NAME                 # Force stop
virsh reset VM-NAME                   # Reset
virsh reboot VM-NAME                  # Reboot

# Networking
virsh net-list --all                  # List networks
virsh net-start default               # Start network
virsh domifaddr VM-NAME               # Get IP address
virsh net-dhcp-leases default         # DHCP leases

# Console
remote-viewer $(virsh domdisplay VM-NAME)  # GUI console
virsh console VM-NAME                 # Serial console

# Logs
journalctl -u libvirtd -n 100         # Recent libvirt logs
tail -f /var/log/libvirt/qemu/VM-NAME.log  # VM logs
dmesg | tail                          # Kernel messages
```

---

**Still having issues?** Run the diagnostic tool and review the output carefully:
```bash
/etc/hypervisor/scripts/diagnose.sh | less
```
