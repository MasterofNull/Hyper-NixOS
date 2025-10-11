═══════════════════════════════════════════════════════════
  Hypervisor Quick Start Guide
═══════════════════════════════════════════════════════════

Complete these steps to create and run your first VM in ~10 minutes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: Download an OS Installation ISO (3-5 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From the boot menu:
  1. Select "More Options"
  2. Choose "ISO Manager"
  3. Select a distribution (e.g., "Ubuntu 24.04 LTS")
  4. Wait for download and automatic GPG verification
  
The ISO will be saved to: /var/lib/hypervisor/isos/

Troubleshooting:
  - Download fails? Check internet: ping 8.8.8.8
  - Slow download? Try a different mirror in ISO presets
  - Verification fails? Check system time: date

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2: Create a VM Profile (2 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From the boot menu:
  1. Select "More Options"
  2. Choose "Create VM (wizard)"
  3. Enter VM details:
     - Name: ubuntu-desktop (any name, alphanumeric + . _ -)
     - CPUs: 2 (or more)
     - Memory: 4096 MB (4GB minimum for desktop, 2GB for server)
     - Disk: 20 GB (minimum for Ubuntu)
  4. Select the ISO you downloaded
  5. Choose network: default or bridge
  6. Review and save

The profile will be saved to: /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json

You can edit this file later with: nano /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 3: Start the VM (1 minute)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From the main menu:
  1. Select your VM (e.g., "VM: ubuntu-desktop")
  2. Choose "Start VM" or "Define/Start from JSON"
  3. Wait for libvirt to start the VM (~10 seconds)

The VM is now running headless (no display attached yet).

What's happening:
  - Libvirt creates the VM definition
  - QEMU starts with your specified resources
  - The VM boots from the ISO

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 4: Connect to the VM Console (1 minute)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Option A: SPICE Viewer (recommended - best performance)
  1. Install virt-viewer: 
     nix-env -iA nixpkgs.virt-viewer
  
  2. Find the SPICE port:
     virsh domdisplay ubuntu-desktop
     # Output example: spice://127.0.0.1:5900
  
  3. Connect:
     remote-viewer spice://127.0.0.1:5900

Option B: VNC Viewer (alternative)
  1. Install tigervnc: 
     nix-env -iA nixpkgs.tigervnc
  
  2. Find VNC port:
     virsh vncdisplay ubuntu-desktop
     # Output example: :0 (means port 5900)
  
  3. Connect:
     vncviewer 127.0.0.1:5900

Option C: Serial Console (text-only, if configured)
  virsh console ubuntu-desktop
  # Press Ctrl+] to exit

Troubleshooting Connection Issues:
  - No display URI? VM might not be running: virsh list --all
  - Connection refused? Check firewall: sudo iptables -L -n
  - Black screen? OS might still be booting, wait 30 seconds

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 5: Install the Guest OS (20-30 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Follow the OS installer in the SPICE/VNC window.

Ubuntu Installation Tips:
  1. Language: Choose your preferred language
  2. Keyboard: Select your keyboard layout
  3. Installation type: Choose "Erase disk and install Ubuntu"
     (This is safe - it only erases the virtual disk)
  4. User setup: Create your username and password
  5. Optional: Enable "Install third-party software"
  6. Wait for installation to complete

Windows Installation Tips:
  1. Press any key to boot from DVD when prompted
  2. Choose "Custom: Install Windows only"
  3. Select the virtual disk (usually Drive 0)
  4. Skip product key (enter it later)
  5. Choose Windows edition
  6. Create local account (for Windows 11, use workarounds)

General Tips:
  - Enable SSH server during install for remote access
  - Install guest additions/tools for better performance
  - Choose minimal installation for servers
  - Enable automatic security updates

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 6: Post-Installation Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Remove ISO for faster boots:
   # Edit the profile
   nano /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json
   
   # Find and delete or comment out this line:
   "iso_path": "/var/lib/hypervisor/isos/ubuntu-24.04-desktop-amd64.iso",
   
   # Save with Ctrl+O, exit with Ctrl+X

2. Restart VM to boot from disk:
   virsh destroy ubuntu-desktop    # Force stop
   virsh start ubuntu-desktop      # Start again

3. Optional: Enable autostart on host boot:
   # Edit profile and add:
   "autostart": true,
   
   # Then run:
   virsh autostart ubuntu-desktop

4. Get VM IP address for SSH:
   # Wait ~30 seconds for VM to boot, then:
   virsh domifaddr ubuntu-desktop
   # Or check DHCP leases:
   virsh net-dhcp-leases default

5. SSH into VM (if SSH server installed):
   ssh username@192.168.122.100  # Use actual IP

6. Install guest tools for better performance:
   # Inside Ubuntu VM:
   sudo apt update
   sudo apt install qemu-guest-agent spice-vdagent
   
   # Inside Windows VM:
   # Download virtio drivers and SPICE guest tools

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Common Issues & Solutions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue: VM won't start
  Check: ls /dev/kvm  
    # Should show: /dev/kvm
    # If missing: Enable virtualization in BIOS
  
  Check: systemctl status libvirtd
    # Should show: active (running)
    # If not: sudo systemctl start libvirtd
  
  Check: df -h /var/lib/hypervisor
    # Need at least 20GB free for a basic VM
  
  Check logs: journalctl -u libvirtd -n 50

Issue: No network in VM
  Check default network:
    virsh net-list --all
    # Should show 'default' as active
    
  Start network if inactive:
    virsh net-start default
    virsh net-autostart default
  
  Check bridge (if using bridged network):
    ip link show br0
    # Should show UP state
  
  Inside VM, check:
    ip addr show
    # Should have IP address
    ping 8.8.8.8
    # Should get replies

Issue: Can't connect to console
  Check VM is running:
    virsh list --all
    # Should show 'running' state
  
  Get display info:
    virsh domdisplay ubuntu-desktop
    # Should show spice:// or vnc:// URI
  
  Check if viewer is installed:
    which remote-viewer
    # If missing: nix-env -iA nixpkgs.virt-viewer
  
  Try alternate connection:
    virsh vncdisplay ubuntu-desktop
    # Shows VNC display number

Issue: Slow performance
  Enable hugepages:
    # Add to VM profile:
    "hugepages": true,
  
  Enable CPU host passthrough:
    # Add to VM profile:
    "cpu_model": "host-passthrough",
  
  Check CPU governor:
    cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    # Should show 'performance' not 'powersave'
  
  Increase VM resources:
    # Edit profile: increase cpus and memory_mb

Issue: Mouse not captured properly
  For SPICE: Install spice-vdagent in VM
  For VNC: Use tablet input device (default)
  Try: Ctrl+Alt to release mouse

Issue: Copy/paste not working
  Install guest agents:
    # Ubuntu: sudo apt install spice-vdagent
    # Windows: Install SPICE guest tools
  Restart VM after installation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Quick Commands Reference
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VM Management:
  virsh list --all           # List all VMs
  virsh start vmname         # Start a VM
  virsh shutdown vmname      # Graceful shutdown
  virsh destroy vmname       # Force stop
  virsh autostart vmname     # Enable autostart
  virsh console vmname       # Serial console
  virsh dominfo vmname       # VM information

Network Info:
  virsh domifaddr vmname     # Get VM IP address
  virsh net-list --all       # List networks
  virsh net-dhcp-leases default  # Show DHCP leases

Storage:
  virsh vol-list default     # List volumes
  ls /var/lib/hypervisor/disks/  # VM disk files
  du -sh /var/lib/hypervisor/*   # Check disk usage

Snapshots:
  virsh snapshot-create-as vmname snapname  # Create snapshot
  virsh snapshot-list vmname                 # List snapshots
  virsh snapshot-revert vmname snapname      # Revert to snapshot

Diagnostics:
  /etc/hypervisor/scripts/diagnose.sh  # System health check
  journalctl -u libvirtd -f            # Live libvirt logs
  virsh dumpxml vmname                 # Show VM config

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Now that you have your first VM running:

1. Create More VMs:
   - Try different operating systems
   - Create a Windows VM for gaming
   - Set up a development environment
   - Build a home lab network

2. Learn Advanced Features:
   - CPU pinning for performance
   - GPU passthrough for gaming
   - Network zones for security
   - Automated backups

3. Explore Documentation:
   /etc/hypervisor/docs/advanced_features.md
   /etc/hypervisor/docs/networking.txt
   /etc/hypervisor/docs/security_best_practices.md

4. Join the Community:
   - Report issues on GitHub
   - Share your VM recipes
   - Contribute improvements

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Tips for Success
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Start simple: Basic VM first, then add features
- Take snapshots: Before major changes
- Monitor resources: Use htop and iotop
- Read error messages: They usually tell you what's wrong
- Check logs: journalctl is your friend
- Ask for help: Include diagnostic output

Remember: Every expert was once a beginner. Take your time
and enjoy learning!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━