# Hyper-NixOS Quick Start Guide

Get up and running with Hyper-NixOS in minutes! This guide assumes you've already installed Hyper-NixOS.

## 🎯 5-Minute Quick Start

### 1. Initial Setup (First Run Only)
```bash
# Run the setup wizard
hv setup

# Select:
# - Your experience level
# - Security preferences
# - Features to enable
```

### 2. Create Your First VM
```bash
# List available templates
hv template list

# Create a Debian VM
hv vm create my-first-vm --template debian-11

# Start the VM
vm-start my-first-vm

# Connect to console
virsh console my-first-vm
# (Press Ctrl+] to exit console)
```

### 3. Basic VM Management
```bash
# List all VMs
virsh list --all

# Stop a VM
vm-stop my-first-vm

# Delete a VM
virsh destroy my-first-vm    # Force stop
virsh undefine my-first-vm   # Remove
```

## 📊 Using the Dashboard

### Interactive Menu
```bash
# Launch the main menu
menu

# Navigate with arrow keys
# Press Enter to select
# Q to quit
```

### Security Monitor
```bash
# Real-time threat monitoring
hv monitor

# View security status
hv security status

# Generate security report
hv security report
```

## 🌐 Networking Basics

### Default NAT Network
VMs use NAT by default and can access the internet:
```bash
# Inside VM
ping google.com
```

### VM-to-VM Communication
VMs on the same bridge can communicate:
```bash
# Get VM IP addresses
virsh domifaddr my-first-vm
virsh domifaddr my-second-vm
```

### Port Forwarding
Forward host ports to VM:
```bash
# Forward host port 8080 to VM port 80
hv network forward --host-port 8080 --vm my-first-vm --vm-port 80
```

## 💾 Storage Management

### VM Disks
```bash
# List VM disks
virsh domblklist my-first-vm

# Resize disk (offline)
virsh shutdown my-first-vm
qemu-img resize /var/lib/libvirt/images/my-first-vm.qcow2 +10G
virsh start my-first-vm
```

### Snapshots
```bash
# Create snapshot
virsh snapshot-create-as my-first-vm snapshot1 "Before updates"

# List snapshots
virsh snapshot-list my-first-vm

# Revert to snapshot
virsh snapshot-revert my-first-vm snapshot1

# Delete snapshot
virsh snapshot-delete my-first-vm snapshot1
```

## 🔒 Security Essentials

### Check Security Status
```bash
# Quick security check
hv security status

# Detailed threat analysis
hv threats analyze

# View active alerts
hv alerts list
```

### Respond to Threats
```bash
# If threat detected on VM
hv threats respond --isolate my-infected-vm

# Create forensic snapshot
hv forensics snapshot my-infected-vm
```

## 👥 User Management

### No Sudo Required for VMs!
Regular users in the `libvirtd` group can manage VMs:
```bash
# These work without sudo
vm-start my-vm
vm-stop my-vm
virsh list --all
```

### System Operations Need Sudo
```bash
# These require sudo
sudo hv system config
sudo hv security setup
sudo systemctl restart libvirtd
```

## 📚 Common Tasks

### Clone a VM
```bash
# Shutdown source VM
virsh shutdown my-first-vm

# Clone it
virt-clone --original my-first-vm --name my-cloned-vm --auto-clone

# Start the clone
virsh start my-cloned-vm
```

### Import Existing VM
```bash
# From qcow2 image
hv vm import my-imported-vm --disk /path/to/disk.qcow2 --memory 2048 --vcpus 2
```

### Backup VM
```bash
# Create backup
hv backup create my-first-vm

# List backups
hv backup list

# Restore from backup
hv backup restore my-first-vm --backup-id 20250101-1200
```

### Access VM Display
```bash
# GUI access (if available)
virt-viewer my-first-vm

# Or via SPICE/VNC
virsh domdisplay my-first-vm
# Connect with any VNC client
```

## 🎓 Learning Resources

### Get Help
```bash
# General help
hv help

# Command-specific help
hv help vm create

# Interactive tutorial
hv tutorial basics
```

### Show Examples
```bash
# Show examples for any command
hv examples vm-management
hv examples networking
hv examples security
```

## ⚡ Pro Tips

### 1. Use Tab Completion
```bash
vm-start my<TAB>     # Autocompletes VM names
hv vm <TAB>          # Shows subcommands
```

### 2. Quick VM Status
```bash
# One-line VM status
virsh list --all --title
```

### 3. Keyboard Shortcuts
- In `virsh console`: `Ctrl+]` to exit
- In `menu`: `Q` to quit, `H` for help
- In `monitor`: `P` to pause, `C` to clear

### 4. Aliases for Common Commands
Add to your `~/.bashrc`:
```bash
alias vl='virsh list --all'
alias vc='virsh console'
alias vs='vm-start'
alias vst='vm-stop'
```

## 🚨 Quick Troubleshooting

### VM Won't Start
```bash
# Check for errors
virsh dominfo my-vm
journalctl -u libvirtd -n 50

# Common fixes
# - Check disk space: df -h
# - Check memory: free -h
# - Verify disk exists: ls -la /var/lib/libvirt/images/
```

### Can't Connect to Console
```bash
# VM might be booting, wait and retry
sleep 30
virsh console my-vm

# Or use display instead
virt-viewer my-vm
```

### Permission Denied
```bash
# Check groups
groups

# If missing libvirtd
sudo usermod -aG libvirtd $USER
# Then logout and login
```

## 🎯 What's Next?

Now that you're up and running:

1. **Explore Features**: Run `hv setup` to enable more features
2. **Create Templates**: Build your own VM templates
3. **Set Up Monitoring**: Enable dashboards and alerts
4. **Configure Backups**: Automate VM backups
5. **Learn Security**: Explore threat detection features

## 🆘 Need Help?

- **Built-in Help**: `hv help <topic>`
- **Documentation**: `/etc/hypervisor/docs/`
- **Community**: Visit our forums and chat
- **Issues**: Report bugs on GitHub

---

🎉 **Congratulations!** You're now ready to build and manage your virtual infrastructure with Hyper-NixOS!