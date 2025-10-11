# Hypervisor Troubleshooting Guide

This guide provides step-by-step solutions for common issues. Follow the decision trees to diagnose and fix problems.

---

## Quick Diagnostic Command

Before troubleshooting, run the diagnostic tool:
```bash
/etc/hypervisor/scripts/diagnose.sh
```

---

## 🚫 VM Won't Start

Follow this decision tree:

```
VM won't start
├─ Check: Is KVM available?
│  └─ Run: ls /dev/kvm
│     ├─ ❌ No /dev/kvm found
│     │  └─ Cause: Virtualization disabled
│     │     └─ Fix: Enable Intel VT-x or AMD-V in BIOS/UEFI
│     └─ ✅ /dev/kvm exists
│        └─ Check: Is libvirtd running?
│           └─ Run: systemctl status libvirtd
│              ├─ ❌ Not running
│              │  └─ Fix: sudo systemctl start libvirtd
│              └─ ✅ Running
│                 └─ Check: Sufficient disk space?
│                    └─ Run: df -h /var/lib/hypervisor
│                       ├─ ❌ Less than VM disk size + 2GB
│                       │  └─ Fix: Free space or reduce VM disk size
│                       └─ ✅ Enough space
│                          └─ Check: VM definition valid?
│                             └─ Run: virsh dumpxml vmname
│                                ├─ ❌ Error shown
│                                │  └─ Fix: Check JSON profile syntax
│                                └─ ✅ XML shown
│                                   └─ Check libvirt logs:
│                                      journalctl -u libvirtd -n 50
```

### Common "VM Won't Start" Solutions

1. **Permission Denied**
   ```bash
   # Add user to libvirtd group
   sudo usermod -aG libvirtd $USER
   newgrp libvirtd
   ```

2. **Network 'default' is not active**
   ```bash
   virsh net-start default
   virsh net-autostart default
   ```

3. **Disk image not found**
   - Check profile JSON for correct paths
   - Ensure ISO exists: `ls /var/lib/hypervisor/isos/`
   - Verify disk created: `ls /var/lib/hypervisor/disks/`

4. **Insufficient memory**
   ```bash
   # Check available memory
   free -h
   # Reduce VM memory in profile or stop other VMs
   ```

---

## 🌐 No Network in VM

```
No network connectivity
├─ Check: Can VM get DHCP?
│  └─ Inside VM: ip addr show
│     ├─ ❌ No IP address
│     │  └─ Check: Is default network active?
│     │     └─ Run: virsh net-list --all
│     │        ├─ ❌ 'default' inactive
│     │        │  └─ Fix: virsh net-start default
│     │        └─ ✅ 'default' active
│     │           └─ Check: DHCP leases?
│     │              └─ Run: virsh net-dhcp-leases default
│     │                 ├─ ❌ No leases shown
│     │                 │  └─ Inside VM: sudo dhclient
│     │                 └─ ✅ Leases shown
│     │                    └─ Restart network in VM
│     └─ ✅ Has IP address
│        └─ Check: Can ping gateway?
│           └─ Inside VM: ping 192.168.122.1
│              ├─ ❌ No response
│              │  └─ Check firewall rules
│              └─ ✅ Gateway responds
│                 └─ Check: Can reach internet?
│                    └─ Inside VM: ping 8.8.8.8
│                       ├─ ❌ No response
│                       │  └─ Check NAT/forwarding
│                       └─ ✅ Internet works
```

### Network Troubleshooting Commands

**On Host:**
```bash
# List networks
virsh net-list --all

# Show network details
virsh net-info default

# Show DHCP leases
virsh net-dhcp-leases default

# Check bridge
ip link show virbr0

# Check iptables NAT
sudo iptables -t nat -L -n -v
```

**Inside VM:**
```bash
# Show interfaces
ip addr show

# Request DHCP
sudo dhclient -v

# Check routes
ip route show

# Test connectivity
ping -c 4 192.168.122.1  # Gateway
ping -c 4 8.8.8.8        # Internet
```

---

## 🖥️ Can't Connect to Console

```
Console connection fails
├─ Check: Is VM running?
│  └─ Run: virsh list --all
│     ├─ ❌ VM not in list or "shut off"
│     │  └─ Start VM first
│     └─ ✅ VM is "running"
│        └─ Check: Display configured?
│           └─ Run: virsh domdisplay vmname
│              ├─ ❌ No output
│              │  └─ VM has no display
│              │     └─ Check profile has graphics
│              └─ ✅ Shows URI (spice://... or vnc://...)
│                 └─ Check: Viewer installed?
│                    └─ Run: which remote-viewer
│                       ├─ ❌ Not found
│                       │  └─ Fix: nix-env -iA nixpkgs.virt-viewer
│                       └─ ✅ Viewer available
│                          └─ Try connection
│                             └─ Run: remote-viewer URI
│                                ├─ ❌ Connection refused
│                                │  └─ Check firewall/ports
│                                └─ ✅ Connected
```

### Console Connection Methods

1. **SPICE (Recommended)**
   ```bash
   # Get SPICE URI
   virsh domdisplay vmname
   # Connect
   remote-viewer spice://127.0.0.1:5900
   ```

2. **VNC**
   ```bash
   # Get VNC display
   virsh vncdisplay vmname
   # Connect (add 5900 to display number)
   vncviewer 127.0.0.1:5900
   ```

3. **Serial Console**
   ```bash
   # Requires console=ttyS0 in VM kernel params
   virsh console vmname
   # Exit with Ctrl+]
   ```

---

## 🐌 Slow VM Performance

```
VM performance issues
├─ Check: CPU steal time?
│  └─ Inside VM: top (check %st)
│     ├─ ❌ High steal time (>10%)
│     │  └─ Host CPU overcommitted
│     │     ├─ Reduce VM count
│     │     └─ Enable CPU pinning
│     └─ ✅ Low steal time
│        └─ Check: Memory pressure?
│           └─ Inside VM: free -h
│              ├─ ❌ High swap usage
│              │  └─ Increase VM memory
│              └─ ✅ Memory OK
│                 └─ Check: Disk I/O?
│                    └─ Inside VM: iotop
│                       ├─ ❌ High wait time
│                       │  └─ Check host disk
│                       └─ ✅ I/O normal
│                          └─ Check virtio drivers
```

### Performance Optimization

1. **Enable Hugepages**
   ```json
   // In VM profile
   "hugepages": true
   ```

2. **CPU Pinning**
   ```json
   "cpu_pinning": [
     {"vcpu": 0, "hostcpu": 2},
     {"vcpu": 1, "hostcpu": 3}
   ]
   ```

3. **Use Host CPU Model**
   ```json
   "cpu_model": "host-passthrough"
   ```

4. **Virtio Drivers**
   - Disk: Use virtio-blk or virtio-scsi
   - Network: Use virtio-net
   - Install guest drivers/agents

---

## 💾 Disk/Storage Issues

```
Storage problems
├─ Check: Disk space available?
│  └─ Run: df -h /var/lib/hypervisor
│     ├─ ❌ Less than 10% free
│     │  └─ Free up space
│     │     ├─ Delete old ISOs
│     │     ├─ Remove snapshots
│     │     └─ Clean old VMs
│     └─ ✅ Space available
│        └─ Check: Disk image exists?
│           └─ Run: ls /var/lib/hypervisor/disks/
│              ├─ ❌ VM disk missing
│              │  └─ Recreate or restore
│              └─ ✅ Disk exists
│                 └─ Check: Permissions?
│                    └─ Run: ls -l disk.qcow2
│                       ├─ ❌ Wrong owner
│                       │  └─ Fix ownership
│                       └─ ✅ Permissions OK
```

### Disk Management Commands

```bash
# Check disk usage
du -sh /var/lib/hypervisor/*

# List VM disks
virsh vol-list default

# Check disk image info
qemu-img info /var/lib/hypervisor/disks/vm.qcow2

# Resize disk (offline)
qemu-img resize disk.qcow2 +10G

# Check disk errors
qemu-img check disk.qcow2
```

---

## 🔒 Security/Permission Issues

```
Permission denied errors
├─ Check: User in libvirtd group?
│  └─ Run: groups
│     ├─ ❌ Not in libvirtd
│     │  └─ Fix: sudo usermod -aG libvirtd $USER
│     │     └─ Logout and login
│     └─ ✅ In libvirtd group
│        └─ Check: AppArmor blocking?
│           └─ Run: sudo aa-status
│              ├─ ❌ Profile denials
│              │  └─ Check audit log
│              │     └─ sudo journalctl -u auditd
│              └─ ✅ No denials
│                 └─ Check: SELinux?
│                    └─ Run: getenforce
│                       ├─ ❌ Enforcing
│                       │  └─ Add exceptions
│                       └─ ✅ Disabled/Permissive
```

---

## 🔄 VM State Issues

### VM Stuck in "Paused" State
```bash
# Resume paused VM
virsh resume vmname

# If stuck, force reset
virsh destroy vmname
virsh start vmname
```

### VM Won't Shut Down
```bash
# Graceful shutdown (requires guest agent)
virsh shutdown vmname

# Force shutdown
virsh destroy vmname

# If completely stuck
sudo kill -9 $(pgrep -f vmname)
```

---

## 📊 Resource Issues

### Out of Memory
```bash
# Check memory usage
free -h

# List VM memory usage
for vm in $(virsh list --name); do
  echo "$vm: $(virsh dommemstat $vm | grep actual | awk '{print $2/1024 "MB"}')"
done

# Reduce VM memory temporarily
virsh setmem vmname 2G --live
```

### CPU Overload
```bash
# Check CPU usage
htop

# Limit VM CPU usage
virsh schedinfo vmname --set cpu_shares=512
```

---

## 🛠️ Recovery Procedures

### Corrupted VM Definition
```bash
# Backup current XML
virsh dumpxml vmname > vmname.xml.backup

# Undefine VM (keeps disks)
virsh undefine vmname

# Recreate from profile
/etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh \
  /var/lib/hypervisor/vm_profiles/vmname.json
```

### Lost VM Profile
```bash
# Generate profile from XML
virsh dumpxml vmname > temp.xml
# Manually create JSON from XML content
```

### Recover from Snapshot
```bash
# List snapshots
virsh snapshot-list vmname

# Revert to snapshot
virsh snapshot-revert vmname snapname
```

---

## 📞 Getting Help

If these steps don't resolve your issue:

1. **Collect Diagnostic Info**
   ```bash
   /etc/hypervisor/scripts/diagnose.sh > diagnostic.log
   virsh dumpxml vmname > vm.xml
   journalctl -u libvirtd -n 100 > libvirt.log
   ```

2. **Check Logs**
   - Menu log: `/var/lib/hypervisor/logs/menu.log`
   - Libvirt: `journalctl -u libvirtd -f`
   - VM specific: `/var/log/libvirt/qemu/vmname.log`

3. **Community Resources**
   - GitHub Issues
   - NixOS Forums
   - Libvirt Users Mailing List

Remember: Most issues have simple solutions. Stay calm and work through the decision trees systematically.