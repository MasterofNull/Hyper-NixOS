# Boot Behavior Fix & Foundational Networking Setup

## Summary of Changes

Two major improvements have been completed:

### 1. **Foundational Networking Setup** (NEW!)
Complete network configuration wizard that runs **BEFORE** any other setup processes.

### 2. **Boot Behavior Fix** 
Fixes GNOME auto-starting instead of console menu + adds desktop shortcuts for easy navigation.

---

## Problem 1 SOLVED: GNOME Auto-Starting Instead of Console Menu

### The Issue
After updates, GNOME was loading automatically on boot instead of the console menu, and there were no desktop icons to easily return to the menu.

### The Solution

#### Quick Fix (Immediate)
Run this command to fix boot behavior right now:
```bash
sudo /etc/hypervisor/scripts/fix_boot_to_console.sh
```

This will:
- ✓ Disable GNOME autostart at boot
- ✓ Enable console menu (default behavior)
- ✓ Install desktop shortcuts for all users
- ✓ Rebuild system configuration
- ✓ Guide you through next steps

#### Manual Fix (Alternative)
If you prefer manual control:

1. **Disable GUI boot:**
   ```bash
   sudo /etc/hypervisor/scripts/toggle_gui.sh off
   ```

2. **Install desktop shortcuts:**
   ```bash
   /etc/hypervisor/scripts/install_desktop_shortcuts.sh
   ```

3. **Reboot:**
   ```bash
   sudo systemctl reboot
   ```

### Desktop Shortcuts

When in GNOME, you now have these desktop icons:

- **Hypervisor Console Menu** - Opens the main menu in terminal
- **Hypervisor Setup Wizard** - Run setup/configuration
- **Network Foundation Setup** - Configure networking
- **Hypervisor Dashboard** - GUI management interface

The shortcuts are automatically installed and trusted, so you can double-click them immediately.

### Checking Boot Status

Check current configuration:
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh status
```

### Switching Between Console and GUI

**To enable GNOME at boot:**
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```

**To disable GNOME at boot (use console):**
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```

**Switch to console without rebooting:**
```bash
sudo systemctl isolate multi-user.target
```

**Switch to GNOME without rebooting:**
```bash
sudo systemctl isolate graphical.target
```

---

## Problem 2 SOLVED: Networking Setup As Foundation

### The Issue
Network setup was buried in the middle of the setup wizard, but MANY processes depend on networking:
- ISO downloads require internet
- Package installation needs network
- VM creation needs bridges
- Network discovery and DHCP
- Security zones

### The Solution

#### Foundational Networking Setup Script (NEW!)
A comprehensive, intelligent networking wizard that runs **FIRST** before anything else.

**Location:** `/etc/hypervisor/scripts/foundational_networking_setup.sh`

#### What It Does

**Phase 1: Network Capability Assessment**
- ✓ Detects ALL physical network interfaces
- ✓ Filters out virtual, loopback, docker, etc.
- ✓ Assesses each interface (state, speed, IP, primary status)
- ✓ Identifies your primary/active network connection

**Phase 2: Intelligent Interface Selection**
- ✓ Automatically selects best interface (primary → active → first)
- ✓ Provides detailed information about each interface
- ✓ Shows which interface has default route (★PRIMARY★)
- ✓ Explains binding process in plain language
- ✓ Interactive selection with recommendations

**Phase 3: Bridge Configuration**
- ✓ Creates high-performance network bridge
- ✓ Offers performance profiles (Standard MTU 1500 vs Performance MTU 9000)
- ✓ Explains each option thoroughly
- ✓ Automatically binds interface to bridge
- ✓ Applies configuration safely

**Phase 4: Bridge Validation**
- ✓ Verifies bridge creation
- ✓ Checks interface binding
- ✓ Waits for DHCP IP address
- ✓ Reports detailed status

**Phase 5: Libvirt Network Configuration**
- ✓ Creates libvirt bridge network definition
- ✓ Defines and starts network
- ✓ Enables autostart
- ✓ Integrates with VM management

**Phase 6: Connectivity Validation**
- ✓ Tests gateway reachability
- ✓ Tests internet connectivity
- ✓ Tests DNS resolution
- ✓ Reports connectivity status

**Phase 7: Readiness Marker**
- ✓ Creates JSON marker: `/var/lib/hypervisor/.network_ready`
- ✓ Stores configuration details
- ✓ Enables other scripts to check network readiness

### Running Foundational Networking Setup

#### From Setup Wizard
The setup wizard now automatically runs networking setup as **STEP 1** before anything else.

#### Standalone
```bash
sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
```

#### Non-Interactive Mode
```bash
sudo NON_INTERACTIVE=true /etc/hypervisor/scripts/foundational_networking_setup.sh
```

### Checking Network Readiness

Scripts can now check if networking is ready:
```bash
/etc/hypervisor/scripts/check_network_ready.sh
```

Verbose output:
```bash
/etc/hypervisor/scripts/check_network_ready.sh -v
```

### Setup Wizard Updates

The setup wizard (`/etc/hypervisor/scripts/setup_wizard.sh`) now:

1. **Checks for existing network configuration**
   - If found, offers to skip or reconfigure
   - If not found, runs foundational setup

2. **Runs networking FIRST (Step 1/4)**
   - Explains why networking is critical
   - Shows comprehensive guide
   - Validates connectivity before proceeding

3. **Adapts based on network status**
   - Skips ISO download if network not ready
   - Warns before VM creation if network not ready
   - Shows appropriate messages

4. **Provides detailed error handling**
   - Clear error messages
   - Troubleshooting steps
   - Manual recovery options

### Benefits

#### For Users
- ✓ **Automation** - No manual IP commands or configuration files
- ✓ **Guidance** - Every step explained clearly
- ✓ **Intelligence** - Automatic detection and recommendations
- ✓ **Safety** - Validation at every phase
- ✓ **Transparency** - Full logging and status reporting

#### For The System
- ✓ **Foundation First** - Network ready before dependent processes
- ✓ **Predictability** - Readiness marker for other scripts
- ✓ **Robustness** - Comprehensive error handling
- ✓ **Validation** - Connectivity testing built-in

### Binding Process Explained

The wizard now explains binding clearly:

**"When an interface is 'bound' to a bridge:**
- The interface becomes part of the bridge
- Network configuration moves from interface to bridge
- The bridge gets the IP address (via DHCP)
- VMs connect through the bridge to your network
- Your interface continues to work normally

**This is automatic and safe!**"

---

## New Scripts

### 1. `foundational_networking_setup.sh`
Complete networking foundation wizard with 7 phases of configuration and validation.

### 2. `check_network_ready.sh`
Quick check if networking has been properly configured. Used by other scripts as prerequisite.

### 3. `fix_boot_to_console.sh`
One-command fix for boot behavior - disables GNOME autostart and enables console menu.

### 4. `install_desktop_shortcuts.sh`
Installs desktop icons for easy menu access from GNOME.

### 5. `toggle_gui.sh`
Simple on/off toggle for GNOME boot behavior with status checking.

---

## Files Changed

### Configuration Files

**`configuration/configuration.nix`**
- Desktop files now ALWAYS present (not just when GUI enabled)
- Added 4 desktop application launchers
- Added desktop shortcut for new users

### Scripts

**`scripts/setup_wizard.sh`**
- Added Step 0: Foundational Networking Setup (CRITICAL FIRST STEP)
- Checks for existing network configuration
- Skips network-dependent steps if network not ready
- Shows appropriate warnings
- Comprehensive error handling

---

## Quick Commands Reference

### Boot Behavior
```bash
# Fix boot to load console menu (not GNOME)
sudo /etc/hypervisor/scripts/fix_boot_to_console.sh

# Check current boot configuration
sudo /etc/hypervisor/scripts/toggle_gui.sh status

# Enable GNOME at boot
sudo /etc/hypervisor/scripts/toggle_gui.sh on

# Disable GNOME at boot (use console)
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```

### Desktop Shortcuts
```bash
# Install desktop shortcuts for current user
/etc/hypervisor/scripts/install_desktop_shortcuts.sh
```

### Networking Setup
```bash
# Run foundational networking setup
sudo /etc/hypervisor/scripts/foundational_networking_setup.sh

# Check if network is ready
/etc/hypervisor/scripts/check_network_ready.sh -v

# View network readiness details
cat /var/lib/hypervisor/.network_ready | jq
```

### System Switching
```bash
# Switch to console (from GNOME)
sudo systemctl isolate multi-user.target

# Switch to GNOME (from console)
sudo systemctl isolate graphical.target

# Reboot
sudo systemctl reboot
```

---

## Recommended Next Steps

1. **Fix boot behavior** (if GNOME is auto-starting):
   ```bash
   sudo /etc/hypervisor/scripts/fix_boot_to_console.sh
   ```

2. **Install desktop shortcuts** (for easy menu access):
   ```bash
   /etc/hypervisor/scripts/install_desktop_shortcuts.sh
   ```

3. **Reboot to see console menu**:
   ```bash
   sudo systemctl reboot
   ```

4. **Run setup wizard** (which now includes networking first):
   ```bash
   /etc/hypervisor/scripts/setup_wizard.sh
   ```

5. **Configure networking properly**:
   ```bash
   sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
   ```

---

## Logs

- **Boot fix log**: `/var/lib/hypervisor/logs/boot_fix.log`
- **Networking setup log**: `/var/lib/hypervisor/logs/foundational_networking.log`
- **Setup wizard log**: `/var/lib/hypervisor/logs/first_boot.log`
- **Network readiness marker**: `/var/lib/hypervisor/.network_ready`

---

## Support

If you encounter issues:

1. **Check logs** (locations above)
2. **Check boot status**: `sudo /etc/hypervisor/scripts/toggle_gui.sh status`
3. **Check network status**: `/etc/hypervisor/scripts/check_network_ready.sh -v`
4. **Verify bridge**: `ip addr show br0`
5. **Test connectivity**: `ping -c 2 8.8.8.8`

---

## Summary

✓ **Boot behavior fixed** - Console menu loads first (not GNOME)
✓ **Desktop shortcuts added** - Easy navigation from GNOME
✓ **Networking foundation setup** - Comprehensive, automated, intelligent
✓ **Setup wizard updated** - Networking runs FIRST
✓ **Network readiness checking** - Other scripts can verify prerequisites
✓ **Complete documentation** - Every step explained clearly
✓ **Robust error handling** - Clear messages and recovery steps

Everything is ready for you to use!
