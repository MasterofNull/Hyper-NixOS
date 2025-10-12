# Foundational Networking Setup - Complete

## What Was Done

### 1. Foundational Networking Setup Script ✓
**New**: `/etc/hypervisor/scripts/foundational_networking_setup.sh`

A comprehensive, automated networking wizard that runs **FIRST** before everything else:
- Automatic interface detection and recommendations
- Clear explanation of binding process (no more confusion!)
- Intelligent bridge configuration with performance profiles
- Complete validation (gateway, internet, DNS)
- Libvirt integration
- Network readiness marker for dependent processes
- 7 phases with detailed guidance

### 2. Network Readiness Check ✓
**New**: `/etc/hypervisor/scripts/check_network_ready.sh`

Other scripts can verify networking is configured before proceeding.

### 3. Setup Wizard Updated ✓
**Modified**: `/etc/hypervisor/scripts/setup_wizard.sh`

Now runs foundational networking as **Step 1** automatically:
- Checks for existing configuration
- Runs networking setup first if needed
- Skips network-dependent steps if network unavailable
- Shows appropriate warnings

### 4. Desktop Icons ✓  
**Modified**: `configuration/configuration.nix`

Desktop application launchers are now **always** present (declaratively):
- Hypervisor Console Menu
- Hypervisor Dashboard
- Hypervisor Setup Wizard
- Network Foundation Setup

These are part of the NixOS configuration - no installation scripts needed!

### 5. GUI Toggle Tool ✓
**New**: `/etc/hypervisor/scripts/toggle_gui.sh`

Convenience tool for enabling/disabling GNOME at boot:
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on   # Enable GNOME at boot
sudo /etc/hypervisor/scripts/toggle_gui.sh off  # Disable GNOME (console menu)
sudo /etc/hypervisor/scripts/toggle_gui.sh status  # Check current state
```

---

## About GNOME Auto-Starting

### On a Clean Install

The default configuration is:
- `hypervisor.gui.enableAtBoot = false` (GNOME disabled)
- `hypervisor.menu.enableAtBoot = true` (console menu enabled)

**Result**: Console menu loads on boot (NOT GNOME)

### If GNOME Is Starting

GNOME will only start if `/var/lib/hypervisor/configuration/gui-local.nix` exists and enables it.

Check if it exists:
```bash
ls -la /var/lib/hypervisor/configuration/gui-local.nix
cat /var/lib/hypervisor/configuration/gui-local.nix
```

If it exists and you want console boot:
```bash
sudo rm /var/lib/hypervisor/configuration/gui-local.nix
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)
```

Or use the convenience tool:
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```

### NixOS Rollbacks

If you're testing with `nixos-rebuild switch` and then rolling back:
- Rolling back takes you to the previous generation
- That generation might have had gui-local.nix enabled
- Check the generation's configuration: `nixos-rebuild list-generations`

---

## Key Files

### Scripts
- `scripts/foundational_networking_setup.sh` - Main networking wizard
- `scripts/check_network_ready.sh` - Network readiness check
- `scripts/toggle_gui.sh` - GUI boot toggle (convenience)

### Configuration  
- `configuration/configuration.nix` - Base config (GUI disabled by default)
- `/var/lib/hypervisor/configuration/gui-local.nix` - Per-host GUI override (if exists)

### Runtime
- `/var/lib/hypervisor/.network_ready` - Network readiness marker
- `/var/lib/hypervisor/logs/foundational_networking.log` - Networking setup log

---

## Quick Commands

### Networking
```bash
# Run foundational networking setup
sudo /etc/hypervisor/scripts/foundational_networking_setup.sh

# Check if network is ready
/etc/hypervisor/scripts/check_network_ready.sh -v

# View readiness marker
cat /var/lib/hypervisor/.network_ready | jq
```

### Boot Behavior
```bash
# Check current boot mode
sudo /etc/hypervisor/scripts/toggle_gui.sh status

# Ensure console boot (if GNOME is starting)
sudo /etc/hypervisor/scripts/toggle_gui.sh off

# Enable GNOME boot (if desired)
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```

---

## The NixOS Way

Everything is **declarative**:
- ✓ Default configuration is correct (console menu on boot)
- ✓ Desktop icons are part of the config (not installed separately)
- ✓ No "fix" scripts needed
- ✓ Clean installs work correctly out of the box
- ✓ Rollbacks work as expected

The only reason GNOME would start on a clean system is if:
1. `gui-local.nix` exists and enables it
2. You rolled back to a generation that had it enabled
