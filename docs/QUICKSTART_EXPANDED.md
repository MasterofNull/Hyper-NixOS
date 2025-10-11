# Hypervisor Quick Start Guide

**Complete these steps to create and run your first VM in ~10 minutes.**

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Download an OS Installation ISO](#step-1-download-an-os-installation-iso)
- [Step 2: Create a VM Profile](#step-2-create-a-vm-profile)
- [Step 3: Start the VM](#step-3-start-the-vm)
- [Step 4: Connect to the VM Console](#step-4-connect-to-the-vm-console)
- [Step 5: Install the Guest OS](#step-5-install-the-guest-os)
- [Step 6: After Installation](#step-6-after-installation)
- [Common Issues & Solutions](#common-issues--solutions)
- [Next Steps](#next-steps)

---

## Prerequisites

Before you start, ensure:
- ✅ Hypervisor is installed and booted
- ✅ You can access the TUI menu (should appear at boot)
- ✅ System has internet connectivity (for ISO download)
- ✅ At least 20GB free disk space

**Check Your System:**
```bash
# Run system diagnostics
/etc/hypervisor/scripts/diagnose.sh

# Check disk space
df -h /var/lib/hypervisor
```

---

## Step 1: Download an OS Installation ISO

**Time:** 3-10 minutes (depending on download speed)

### From the Boot Menu

1. **Navigate to ISO Manager**
   ```
   Main Menu → More Options → ISO Manager
   ```

2. **Select a Distribution**
   - Choose from preset list (recommended):
     - Ubuntu 24.04 LTS (Server or Desktop)
     - Debian 12
     - Fedora 40
     - Arch Linux
   - Or choose "Download from URL" for custom ISO

3. **Wait for Download**
   - Progress will be shown
   - Automatic GPG/checksum verification happens after download
   - ✅ Look for "Downloaded and verified" message

4. **Verify ISO Location**
   ```bash
   ls -lh /var/lib/hypervisor/isos/
   # You should see your ISO file with a .sha256.verified marker
   ```

### Example Output

```
Downloaded: ubuntu-24.04-live-server-amd64.iso (2.1 GB)
✓ Checksum verified: SHA256 matches official source
✓ Saved to: /var/lib/hypervisor/isos/
```

### Troubleshooting Step 1

| Problem | Solution |
|---------|----------|
| **Download fails** | Check internet: `ping 8.8.8.8` |
| **Slow download** | Try different mirror or download manually |
| **Verification fails** | Check system time: `date`<br>May need to import GPG keys |
| **No space left** | Free space: `sudo nix-collect-garbage -d` |

---

## Step 2: Create a VM Profile

**Time:** 2 minutes

VM profiles are JSON files that define your VM's hardware configuration.

### From the Boot Menu

1. **Navigate to VM Creation Wizard**
   ```
   Main Menu → More Options → Create VM (wizard)
   ```

2. **Enter VM Details**
   
   **Name:** `ubuntu-desktop` (or your choice)
   - Only alphanumeric, `.`, `_`, `-`
   - Must start with alphanumeric character
   - Max 64 characters
   
   **CPUs:** `2` (or more, based on your hardware)
   - Recommended: 1-2 for servers, 2-4 for desktops
   - Check available: `nproc`
   
   **Memory:** `4096` MB (4 GB)
   - Minimum: 2 GB for Ubuntu Server, 4 GB for Desktop
   - Recommended: 4-8 GB for desktop, 2-4 GB for server
   - Check available: `free -h`
   
   **Disk Size:** `20` GB
   - Minimum: 20 GB for Ubuntu, 25 GB for Windows
   - Recommended: 30-50 GB for comfortable use

3. **Select ISO**
   - Choose the ISO you downloaded in Step 1
   - Path: `/var/lib/hypervisor/isos/ubuntu-24.04-live-server-amd64.iso`

4. **Choose Network**
   - **default** - NAT network (internet access, isolated from host)
   - **br0** - Bridged network (if you created a bridge)
   
   Recommended: `default` for first VM

5. **Review and Save**
   - Profile will be saved to: `/var/lib/hypervisor/vm_profiles/ubuntu-desktop.json`

### Example VM Profile

```json
{
  "name": "ubuntu-desktop",
  "cpus": 2,
  "memory_mb": 4096,
  "disk_gb": 30,
  "iso_path": "/var/lib/hypervisor/isos/ubuntu-24.04-live-server-amd64.iso",
  "arch": "x86_64",
  "network": {
    "bridge": "default"
  },
  "video": {
    "heads": 1
  }
}
```

### Verify Profile

```bash
# View profile
cat /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json

# Validate profile (optional)
/etc/hypervisor/scripts/validate_profile.sh /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json
```

### Troubleshooting Step 2

| Problem | Solution |
|---------|----------|
| **Invalid VM name** | Use only A-Z, a-z, 0-9, ., _, - and start with alphanumeric |
| **Profile already exists** | Choose different name or edit existing: `nano /var/lib/hypervisor/vm_profiles/NAME.json` |
| **ISO not found** | Verify ISO path: `ls /var/lib/hypervisor/isos/` |

---

## Step 3: Start the VM

**Time:** 30 seconds

### From the Main Menu

1. **Select Your VM**
   ```
   Main Menu → VM: ubuntu-desktop
   ```

2. **Choose Action**
   ```
   VM Action Menu:
   1. Start/Resume VM       ← Choose this
   2. Launch Console
   3. View VM Status
   ...
   ```

3. **Wait for Startup**
   - VM will be defined in libvirt
   - Disk image will be created
   - VM will start (~10 seconds)

### Verify VM is Running

```bash
# Check VM status
virsh list --all

# Expected output:
Id   Name             State
---------------------------------
1    ubuntu-desktop   running

# Check VM info
virsh dominfo ubuntu-desktop
```

### What Happens During Start?

1. ✅ JSON profile is validated
2. ✅ Disk image created: `/var/lib/hypervisor/disks/ubuntu-desktop.qcow2`
3. ✅ XML generated: `/var/lib/hypervisor/xml/ubuntu-desktop.xml`
4. ✅ VM defined in libvirt
5. ✅ VM started with QEMU/KVM
6. ✅ UEFI firmware (OVMF) booted
7. ✅ ISO mounted as CD-ROM

### Troubleshooting Step 3

| Problem | Solution |
|---------|----------|
| **VM won't start** | Check: `ls /dev/kvm` (should exist)<br>Check: `systemctl status libvirtd` (should be active) |
| **Insufficient space** | Check: `df -h /var/lib/hypervisor`<br>Free space: `sudo nix-collect-garbage -d` |
| **Permission denied** | Check: `ls -ld /var/lib/hypervisor/disks`<br>Fix: Ensure user in `libvirtd` group |
| **ISO verification failed** | Verify ISO: `ls /var/lib/hypervisor/isos/*.verified`<br>Or bypass: `export HYPERVISOR_REQUIRE_ISO_VERIFICATION=0` |

---

## Step 4: Connect to the VM Console

**Time:** 1 minute

Now that your VM is running, you need to connect to its display to complete the OS installation.

### Option A: Using the VM Action Menu (Easiest)

1. **From Main Menu**
   ```
   Main Menu → VM: ubuntu-desktop
   ```

2. **Launch Console**
   ```
   VM Action Menu:
   2. Launch Console (SPICE/VNC)  ← Choose this
   ```

3. **Console Window Opens**
   - SPICE viewer launches automatically
   - You'll see the Ubuntu installer boot screen

### Option B: Manual SPICE Connection

```bash
# Install virt-viewer (if not already installed)
nix-env -iA nixpkgs.virt-viewer

# Get display URI
virsh domdisplay ubuntu-desktop
# Output: spice://127.0.0.1:5900

# Connect
remote-viewer spice://127.0.0.1:5900
```

### Option C: VNC Connection

```bash
# Install VNC viewer
nix-env -iA nixpkgs.tigervnc

# Get VNC port
virsh domdisplay ubuntu-desktop
# Output: vnc://127.0.0.1:5900

# Connect
vncviewer 127.0.0.1:5900
```

### Option D: Serial Console (Text-Only)

```bash
# Connect to serial console (if configured in VM)
virsh console ubuntu-desktop

# Press Ctrl+] to disconnect
```

### Troubleshooting Step 4

| Problem | Solution |
|---------|----------|
| **Can't connect to console** | Verify VM is running: `virsh domstate ubuntu-desktop`<br>Check display: `virsh domdisplay ubuntu-desktop` |
| **No display URI** | Ensure VM has graphics in profile<br>Check: `virsh dumpxml ubuntu-desktop \| grep graphics` |
| **remote-viewer not found** | Install: `nix-env -iA nixpkgs.virt-viewer` |
| **Connection refused** | Check firewall: `sudo iptables -L`<br>Verify SPICE listening: `ss -tlnp \| grep 590` |

---

## Step 5: Install the Guest OS

**Time:** Varies by OS (10-30 minutes)

Follow the OS installer in the SPICE/VNC console window.

### Ubuntu Installation Steps

1. **Choose Language**
   - Select your preferred language
   - Continue

2. **Update Installer** (if prompted)
   - Recommended to update
   - Wait for update to complete

3. **Keyboard Configuration**
   - Select your keyboard layout
   - Test in the text box

4. **Network Configuration**
   - Should auto-detect network (via default NAT)
   - If static IP needed, configure manually

5. **Proxy Configuration**
   - Leave blank unless you need a proxy
   - Continue

6. **Mirror Configuration**
   - Use default Ubuntu mirror
   - Continue

7. **Storage Configuration**
   - ⚠️ Choose: **"Use an entire disk"**
   - ✅ Safe! This is a virtual disk, not your host disk
   - Select the virtual disk (should be only option)
   - Confirm partitioning

8. **Profile Setup**
   - Your name: `Your Name`
   - Server name: `ubuntu-vm`
   - Username: `your-username`
   - Password: (choose a strong password)
   - Confirm password

9. **SSH Setup**
   - ✅ **Recommended: Install OpenSSH server**
   - Allows remote access after installation
   - Can import SSH keys from GitHub/Launchpad (optional)

10. **Featured Server Snaps** (optional)
    - Select any additional software you want
    - Can be installed later with `sudo snap install`

11. **Installation**
    - Wait for installation to complete (10-20 minutes)
    - Progress will be shown

12. **Reboot**
    - Once complete, select "Reboot Now"
    - ⚠️ **Important:** See Step 6 to remove ISO before reboot

### Installation Tips

| Tip | Details |
|-----|---------|
| **✅ Enable SSH** | Allows remote access: `ssh user@VM-IP` |
| **✅ Use entire disk** | Safe for virtual disk, gives full space |
| **✅ Install guest tools** | `sudo apt install qemu-guest-agent` (Ubuntu)<br>Enables better integration |
| **⚠️ Keyboard shortcuts** | Host key varies by viewer (Ctrl+Alt for SPICE) |
| **💡 Copy/Paste** | Install spice-vdagent in guest for clipboard sharing |

---

## Step 6: After Installation

**Time:** 2-5 minutes

### A. Remove ISO for Faster Boots

After OS is installed, the ISO is no longer needed.

```bash
# Edit VM profile
nano /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json

# Remove or comment out the iso_path line:
# "iso_path": "/var/lib/hypervisor/isos/ubuntu-24.04-live-server-amd64.iso",

# Save: Ctrl+O, Enter
# Exit: Ctrl+X
```

### B. Restart VM

```bash
# Stop VM
virsh shutdown ubuntu-desktop
# Or from menu: VM → Stop VM

# Wait for clean shutdown (10-30 seconds)
virsh domstate ubuntu-desktop

# Start VM again
virsh start ubuntu-desktop
# Or from menu: VM → Start/Resume VM
```

### C. Get VM IP Address

```bash
# Method 1: Ask libvirt
virsh domifaddr ubuntu-desktop

# Method 2: Check DHCP leases
virsh net-dhcp-leases default

# Method 3: From guest console
# Login and run:
ip addr show

# Example output:
# inet 192.168.122.45/24
```

### D. SSH into VM (Optional but Recommended)

```bash
# SSH from host
ssh your-username@192.168.122.45

# First time will ask to verify fingerprint
# Type 'yes' and enter password
```

### E. Install Guest Tools

Guest tools improve performance and enable features like proper shutdown, time sync, and clipboard sharing.

```bash
# From inside VM (via SSH or console)

# Ubuntu/Debian:
sudo apt update
sudo apt install qemu-guest-agent spice-vdagent

# Fedora/RHEL:
sudo dnf install qemu-guest-agent spice-vdagent

# Arch:
sudo pacman -S qemu-guest-agent spice-vdagent

# Enable and start
sudo systemctl enable --now qemu-guest-agent
```

### F. Enable Autostart (Optional)

If you want the VM to start automatically when the host boots:

```bash
# Method 1: Edit profile
nano /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json
# Add: "autostart": true

# Method 2: Via virsh
virsh autostart ubuntu-desktop

# Verify
virsh dominfo ubuntu-desktop | grep Autostart
```

### G. Take a Snapshot (Recommended)

Create a snapshot of the clean installation:

```bash
# Create snapshot
virsh snapshot-create-as ubuntu-desktop \
  clean-install \
  "Fresh OS install before customization"

# List snapshots
virsh snapshot-list ubuntu-desktop

# Restore snapshot later if needed
virsh snapshot-revert ubuntu-desktop clean-install
```

---

## Common Issues & Solutions

### VM Won't Start

**Symptoms:** Error when trying to start VM

**Check:**
```bash
# 1. Verify KVM is available
ls /dev/kvm
# Should show: /dev/kvm

# 2. Check libvirtd is running
systemctl status libvirtd
# Should be: active (running)

# 3. Check disk space
df -h /var/lib/hypervisor
# Need at least 20GB free

# 4. Check error logs
journalctl -u libvirtd -n 50
```

**Solutions:**
- **No /dev/kvm:** Enable virtualization in BIOS/UEFI
- **libvirtd not running:** `sudo systemctl start libvirtd`
- **No space:** Free space with `sudo nix-collect-garbage -d`
- **Permission denied:** Add user to groups: `sudo usermod -a -G kvm,libvirtd $USER`

### No Network in VM

**Symptoms:** VM has no internet, can't ping anything

**Check:**
```bash
# 1. Check default network
virsh net-info default
# Should show: Active: yes

# 2. Check if network is started
virsh net-list --all

# 3. From inside VM
ip link show
ip addr show
ip route show
```

**Solutions:**
```bash
# Start default network
virsh net-start default

# Enable autostart
virsh net-autostart default

# Check bridge on host
ip link show virbr0

# Verify DHCP is running
sudo systemctl status dnsmasq (or check libvirt dnsmasq)
```

### Can't Connect to Console

**Symptoms:** remote-viewer fails or connection refused

**Check:**
```bash
# 1. Verify VM is running
virsh domstate ubuntu-desktop
# Should show: running

# 2. Check display URI
virsh domdisplay ubuntu-desktop
# Should show: spice://127.0.0.1:PORT or vnc://...

# 3. Check if port is listening
ss -tlnp | grep 590
```

**Solutions:**
```bash
# Install virt-viewer
nix-env -iA nixpkgs.virt-viewer

# Try VNC instead
virsh dumpxml ubuntu-desktop | grep graphics
# Modify to use VNC if needed

# Check graphics in profile
cat /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json | grep video
```

### Slow Performance

**Symptoms:** VM is sluggish, high CPU usage

**Check:**
```bash
# 1. Check resource usage on host
htop

# 2. Check VM stats
virsh domstats ubuntu-desktop

# 3. Verify virtio drivers are loaded in guest
lsmod | grep virtio  # (inside VM)
```

**Solutions:**
1. **Enable hugepages** in VM profile:
   ```json
   "hugepages": true
   ```

2. **CPU pinning** for dedicated cores:
   ```json
   "cpu_pinning": [0, 1]
   ```

3. **Check I/O scheduler** (inside VM):
   ```bash
   cat /sys/block/vda/queue/scheduler
   # Should be: [none] or [mq-deadline] for virtio
   ```

4. **Install virtio drivers** (Windows guests)
   - Download: https://fedorapeople.org/groups/virt/virtio-win/

### ISO Verification Fails

**Symptoms:** "ISO verification required" error

**Check:**
```bash
# Check if ISO has verification marker
ls /var/lib/hypervisor/isos/*.verified
```

**Solutions:**
```bash
# Option 1: Verify ISO through manager
# Menu → More Options → ISO Manager → Validate ISO checksum

# Option 2: Manual verification
cd /var/lib/hypervisor/isos
sha256sum ubuntu-*.iso
# Compare with official: https://releases.ubuntu.com/
touch ubuntu-*.iso.sha256.verified

# Option 3: Bypass (not recommended)
export HYPERVISOR_REQUIRE_ISO_VERIFICATION=0
# Then start VM
```

### Can't Delete VM

**Symptoms:** VM won't delete or shows errors

**Check:**
```bash
# Check if VM is running
virsh domstate ubuntu-desktop
```

**Solutions:**
```bash
# Force stop VM
virsh destroy ubuntu-desktop

# Undefine with storage removal
virsh undefine ubuntu-desktop --remove-all-storage

# Manual cleanup if needed
rm /var/lib/hypervisor/disks/ubuntu-desktop.qcow2
rm /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json
rm /var/lib/hypervisor/xml/ubuntu-desktop.xml
```

---

## Next Steps

### Learn More

- **Advanced Features:** `docs/advanced_features.md`
  - GPU passthrough
  - CPU pinning
  - NUMA optimization
  - SEV/SNP encryption
  
- **Networking:** `docs/networking.txt`
  - Bridge networking
  - Network zones
  - Firewall rules
  
- **Storage:** `docs/storage.txt`
  - Snapshots
  - Backups
  - Storage pools
  
- **Workflows:** `docs/workflows.txt`
  - Common VM management tasks
  - Automation examples

### Create More VMs

1. **Clone Existing VM**
   ```
   Menu → VM: ubuntu-desktop → Clone VM
   Enter new name: ubuntu-desktop-2
   ```

2. **Create from Template**
   - Modify existing profile
   - Change name, resources
   - Start new VM

3. **Try Different OSes**
   - Windows 11 (requires TPM)
   - Fedora Server
   - Debian
   - Arch Linux

### Automation

```bash
# Create VM from command line
/etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh \
  /var/lib/hypervisor/vm_profiles/my-vm.json

# Start VM
virsh start my-vm

# Stop VM
virsh shutdown my-vm

# Get VM info
virsh dominfo my-vm
```

### Monitoring

```bash
# Watch VM resources
watch -n 2 'virsh domstats my-vm | grep -E "cpu.time|balloon.current"'

# View all VMs
virsh list --all

# Run system diagnostics
/etc/hypervisor/scripts/diagnose.sh
```

---

## Quick Reference Commands

```bash
# VM Management
virsh list --all              # List all VMs
virsh start NAME              # Start VM
virsh shutdown NAME           # Graceful shutdown
virsh destroy NAME            # Force stop
virsh reboot NAME             # Reboot VM
virsh reset NAME              # Hard reset

# VM Information
virsh dominfo NAME            # VM details
virsh domstate NAME           # Current state
virsh domstats NAME           # Resource stats
virsh domdisplay NAME         # Console URI
virsh domifaddr NAME          # IP address

# Console Access
remote-viewer $(virsh domdisplay NAME)
virsh console NAME            # Serial console

# Snapshots
virsh snapshot-create-as NAME snapshot-name "description"
virsh snapshot-list NAME
virsh snapshot-revert NAME snapshot-name

# Network
virsh net-list --all          # List networks
virsh net-start default       # Start network
virsh net-dhcp-leases default # DHCP leases

# Storage
virsh vol-list default        # List volumes
virsh vol-info --pool default NAME.qcow2

# System
systemctl status libvirtd     # Check libvirt
/etc/hypervisor/scripts/diagnose.sh  # Run diagnostics
```

---

## Getting Help

### Documentation

- **Full docs:** `/etc/hypervisor/docs/`
- **Quick reference:** `docs/QUICK_REFERENCE.md`
- **Troubleshooting:** `docs/troubleshooting.md` (if created)
- **Security:** `docs/security_best_practices.md`

### Diagnostic Tools

```bash
# System health check
/etc/hypervisor/scripts/diagnose.sh

# View logs
tail -f /var/lib/hypervisor/logs/menu.log
journalctl -u libvirtd -f

# Check recent errors
journalctl -u libvirtd --since "1 hour ago" -p err
```

### Command Help

```bash
# Virsh help
virsh help                    # All commands
virsh help start              # Specific command

# Man pages
man virsh
man qemu
```

---

## Summary Checklist

- [ ] Downloaded ISO with verification
- [ ] Created VM profile
- [ ] Started VM successfully
- [ ] Connected to console
- [ ] Installed guest OS
- [ ] Removed ISO from profile
- [ ] Restarted VM without ISO
- [ ] Got VM IP address
- [ ] SSH access working (if enabled)
- [ ] Installed guest tools
- [ ] (Optional) Enabled autostart
- [ ] (Optional) Created snapshot

**Congratulations! You've successfully created your first VM!** 🎉

For more advanced features, check out the other documentation files in `/etc/hypervisor/docs/`.
