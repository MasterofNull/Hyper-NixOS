# Configuration Updated - GUI Detection & Respect

## ✅ Problem Solved

The hypervisor configuration now **detects and respects** your base NixOS installation's GUI configuration.

### What Changed

#### 1. **Base System Detection** ✓
The configuration now checks if your base NixOS install has GNOME:
```nix
baseSystemHasGui = config.services.xserver.enable or false;
```

#### 2. **Additive Configuration** ✓
Uses `lib.mkDefault` so base system config takes precedence:
```nix
services.xserver.enable = lib.mkDefault enableGuiAtBoot;
services.xserver.desktopManager.gnome.enable = lib.mkDefault (enableGuiAtBoot && hasOldDesk);
```

#### 3. **Conditional Override** ✓
The `gui-local.nix` file is now **optional** and only used to override:
- No file = Use base system default
- File exists = Override base system

#### 4. **GUI Environment Detection** ✓
New script: `/etc/hypervisor/scripts/detect_gui_environment.sh`

Returns JSON with:
- Base system GUI status
- Hypervisor GUI override status
- Current display server (X11/Wayland)
- Desktop environment (GNOME/KDE/etc)
- Whether GUI can be launched

#### 5. **Management Dashboard Integration** ✓
Dashboard now shows GUI status in title bar and provides:
- Show GUI environment status
- GUI: Use base system default (auto mode)
- GUI: Force GNOME at boot (override on)
- GUI: Force console menu at boot (override off)
- Network foundation setup

---

## Your Scenario

Since you installed NixOS with GNOME initially:

**Current State:**
- Base system: `services.xserver.enable = true` ✓
- Base system: `services.desktopManager.gnome.enable = true` ✓
- Hypervisor detects: `baseSystemHasGui = true` ✓

**Result:** GNOME respects your base installation

**If `gui-local.nix` exists with override:**
- It was created by testing/toggling
- Solution: Use "auto" mode to respect base system

---

## Three Simple Commands

### 1. Check Current Status
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh status
```

Shows:
- Base System GUI: true/false
- Hypervisor GUI Override: enabled/disabled/not set
- Result: What will happen on boot
- Current default target

### 2. Use Base System Default (Recommended)
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```

Removes any override - respects your NixOS install choice.

### 3. Override If Needed
```bash
# Force console menu (ignore base system GNOME)
sudo /etc/hypervisor/scripts/toggle_gui.sh off

# Force GNOME (even if base system doesn't have it)
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```

---

## Management Dashboard

The GUI dashboard now shows real-time status:

**Title Bar:**
- `Hypervisor Dashboard - GUI: ON (base system)`
- `Hypervisor Dashboard - GUI: Forced OFF (override)`
- `Hypervisor Dashboard - GUI: Forced ON (override)`

**New Options:**
- **Network foundation setup** - Quick access to networking wizard
- **Show GUI environment status** - Detailed GUI info
- **GUI: Use base system default** - Remove override
- **GUI: Force GNOME at boot** - Override on
- **GUI: Force console menu at boot** - Override off

---

## The NixOS Way

### Declarative Hierarchy

1. **Base System** (highest priority)
   - Your NixOS installation configuration
   - Has GNOME if you installed with it

2. **Hypervisor Default** (low priority)
   - Default: Console menu
   - Uses `lib.mkDefault` (can be overridden)

3. **Hypervisor Override** (highest priority)
   - File: `/var/lib/hypervisor/configuration/gui-local.nix`
   - Optional - only use to override

### Clean System Behavior

**Fresh Install with GNOME:**
- Base has GUI → GNOME starts ✓
- No `gui-local.nix` needed
- Respects your choice

**Fresh Install without GUI:**
- Base has no GUI → Console menu starts ✓
- No `gui-local.nix` needed
- Hypervisor default applies

**Testing/Rollbacks:**
- Each generation has its own state
- `gui-local.nix` is per-host (in `/var/lib`)
- Survives rollbacks but can be changed

---

## Quick Fix for Your System

If you want console menu despite having GNOME installed:

```bash
# Option 1: Force console menu (override base system)
sudo /etc/hypervisor/scripts/toggle_gui.sh off

# Option 2: Keep GNOME but use console first-boot
# Edit /var/lib/hypervisor/configuration/management-local.nix
# Set: hypervisor.menu.enableAtBoot = true
```

Or just remove any existing override to use base system:
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```

---

## Files Changed

### Configuration
- `configuration/configuration.nix` - Now detects base GUI and uses mkDefault

### Scripts
- `scripts/detect_gui_environment.sh` - New: Detect GUI details (JSON)
- `scripts/toggle_gui.sh` - Updated: Added "auto" mode and better status
- `scripts/management_dashboard.sh` - Updated: Shows GUI status and controls

### Documentation
- `GUI_CONFIGURATION.md` - Complete guide to GUI configuration
- `NETWORKING_FOUNDATION.md` - Foundational networking docs
- `DESKTOP_ICONS.md` - Desktop launcher docs

---

## Test It

Check your current status:
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh status
```

Example output:
```
GUI Environment Status:
=======================

Base System GUI: true
Hypervisor GUI Override: not set (no gui-local.nix)

Result: GNOME will start (from base system install)

To force console menu:
  sudo /etc/hypervisor/scripts/toggle_gui.sh off

Current default target: graphical.target
```

---

## Summary

✅ **Detects base system GUI** - Knows if you installed with GNOME
✅ **Respects your choice** - Doesn't override unless you want it to
✅ **Conditional override** - gui-local.nix is optional, not required
✅ **Clear status** - Always know what's configured and why
✅ **GUI dashboard integration** - Manage from graphical interface
✅ **NixOS declarative** - Everything in configuration, no hidden state

Your base GNOME installation is now respected and preserved!
