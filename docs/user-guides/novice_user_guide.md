# Hypervisor Beginner's Guide

Welcome to your NixOS-based hypervisor! This guide will help you get started with creating and managing virtual machines (VMs) safely and easily.

## What is a Hypervisor?

A hypervisor is software that creates and runs virtual machines. Think of it as a computer within a computer - you can run multiple operating systems simultaneously on one physical machine, each isolated from the others.

## Getting Started

### First Boot

When you first start your hypervisor, you'll see:

1. **Setup Wizard** (first time only) - Helps configure networking and download ISOs
2. **Main Menu** - Your control center for managing VMs

### Understanding the Menu Structure

The main menu has three primary options:

1. **VM List** - Shows your virtual machines
2. **Start GNOME** - Opens a graphical desktop (if you prefer clicking to typing)
3. **More Options** - Additional tools and settings

## Creating Your First VM

### Step 1: Download an Operating System

1. From the main menu, select **More Options**
2. Choose **ISO Manager**
3. Pick an operating system (Ubuntu and Fedora are good for beginners)
4. The system will download and verify the ISO file

### Step 2: Create the VM

1. Select **More Options** → **Create VM (wizard)**
2. Follow the prompts:
   - **Name**: Give your VM a memorable name (e.g., "my-ubuntu")
   - **CPUs**: Start with 2 (you can change this later)
   - **Memory**: Start with 4096 MB (4 GB)
   - **Disk**: 20-40 GB is usually enough to start
   - **ISO**: Select the one you downloaded

### Step 3: Start Your VM

1. Your new VM will appear in the main menu
2. Select it and press Enter
3. The VM will start, and you can install the operating system

## Important Concepts for Beginners

### Resources (CPU, Memory, Disk)

- **CPUs**: Virtual processors. More CPUs = faster VM (but leaves less for other VMs)
- **Memory**: RAM for the VM. Too little = slow VM, too much = slow host
- **Disk**: Storage space. This grows as needed up to the limit you set

### Safe Defaults

The hypervisor uses safe defaults:
- VMs can't access your main system files
- Each VM is isolated from others
- Network access is controlled

### VM States

- **Running**: VM is active and using resources
- **Shut off**: VM is stopped (like a powered-off computer)
- **Paused**: VM is frozen in time (useful for snapshots)

## Common Tasks

### Installing an Operating System

1. Start the VM with an ISO attached
2. Follow the OS installer (just like installing on a regular computer)
3. After installation, remove the ISO from the VM profile to boot from disk

### Connecting to Your VM

**Console Access** (built-in):
- The VM console opens automatically when you start a VM
- Use Ctrl+] to exit the console

**Network Access** (after OS installation):
1. Find the VM's IP address: `virsh domifaddr your-vm-name`
2. Connect via SSH: `ssh username@vm-ip-address`

### Taking Snapshots (Backups)

Snapshots save the VM state so you can restore if something goes wrong:

1. Select **More Options** → **Snapshots/Backups**
2. Choose your VM
3. Create a snapshot with a descriptive name

### Shutting Down Safely

Always shut down VMs properly:
1. Inside the VM: Use the OS shutdown command
2. From the menu: Select the VM and choose shutdown option
3. Emergency only: Force stop (like pulling the power cord)

## Network Zones Explained

The hypervisor uses network "zones" for security:

- **Secure Zone**: VMs that need to talk to the host or each other
- **Untrusted Zone**: Isolated VMs (good for testing suspicious software)

By default, new VMs go in the secure zone. Change this in the VM profile if needed.

## Troubleshooting Tips

### VM Won't Start
- Check if you have enough free memory
- Verify the ISO/disk path is correct
- Look at logs: **More Options** → **View logs**

### Can't Connect to VM
- Ensure the VM OS is fully installed
- Check if the VM has an IP address
- Verify firewall settings allow connections

### Performance Issues
- Don't allocate all host memory to VMs (keep 2-4GB free)
- Start with fewer CPUs and increase if needed
- Check **Health diagnostics** for system status

## Best Practices for Beginners

### 1. Start Small
- Create one VM at a time
- Use minimal resources initially
- Increase resources as needed

### 2. Take Snapshots
- Before major changes
- After successful installation
- Before experimenting

### 3. Monitor Resources
- Check system health regularly
- Watch for high CPU/memory usage
- Keep some disk space free

### 4. Stay Organized
- Use descriptive VM names
- Document what each VM is for
- Delete unused VMs to free resources

## Getting Help

### Built-in Documentation
- Select **More Options** → **Documentation browser**
- Read tooltips and help text in menus

### Health Checks
- Run **Health diagnostics** if something seems wrong
- Check **View logs** for error messages

### Safe Mode
If you break something:
1. Reboot the hypervisor
2. Don't start problematic VMs
3. Fix issues using the menu tools

## Quick Reference

### Keyboard Shortcuts
- **Arrow keys**: Navigate menus
- **Enter**: Select option
- **Escape**: Go back/cancel
- **Ctrl+]**: Exit VM console

### Important Paths
- VM Profiles: `/var/lib/hypervisor/vm_profiles/`
- ISOs: `/var/lib/hypervisor/isos/`
- Logs: `/var/lib/hypervisor/logs/`

### Essential Commands
```bash
# List all VMs
virsh list --all

# Start a VM
virsh start vm-name

# Shut down a VM
virsh shutdown vm-name

# View VM information
virsh dominfo vm-name

# Connect to VM console
virsh console vm-name
```

## Next Steps

Once comfortable with basics:

1. **Explore VM Templates**: Pre-configured VMs for common uses
2. **Try Different Operating Systems**: Linux, BSD, even Windows
3. **Learn About Snapshots**: Practice backup and restore
4. **Experiment with Networking**: Create isolated test environments

Remember: The hypervisor is designed to be safe. VMs are isolated, so feel free to experiment inside them. If something goes wrong, you can always delete the VM and start fresh!

## Safety Tips

- **Never** run commands you don't understand
- **Always** shut down VMs properly before maintenance
- **Keep** the hypervisor system updated
- **Document** your VM configurations
- **Test** backups by actually restoring them

Welcome to the world of virtualization! Take your time, experiment safely, and have fun learning.