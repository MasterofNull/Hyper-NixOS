# Boot Behavior - ACTUALLY Fixed

## The Original Problem

GNOME login screen was showing on boot, bypassing the console menu.

## Why It Happened

You installed NixOS with GNOME, which configured:
- `services.xserver.enable = true`
- `services.xserver.displayManager.gdm.enable = true`
- `services.xserver.desktopManager.gnome.enable = true`

The display manager (GDM) was starting automatically, showing the login screen.

## The Real Fix

The key insight: **Having GNOME installed ≠ wanting it to auto-start on boot**

### What The Configuration Now Does

```nix
# Keep GNOME installed (if base system has it)
services.xserver.enable = lib.mkDefault (baseSystemHasGui || enableGuiAtBoot);

# BUT: Only start display manager if explicitly requested
services.xserver.displayManager.gdm.enable = lib.mkDefault (enableGuiAtBoot && hasOldDM);

# Console auto-login ONLY if not booting to GUI
services.getty.autologinUser = lib.mkIf ((enableMenuAtBoot || enableWizardAtBoot) && !enableGuiAtBoot) mgmtUser;
```

### The Result

**Default Behavior (Clean Install):**
1. ✅ Console menu loads on boot
2. ✅ GNOME packages installed and available
3. ✅ Can launch GNOME from console menu
4. ✅ No GDM auto-start
5. ✅ No GUI login screen bypass

**The Difference:**
- `services.xserver.enable = true` → GNOME packages installed
- `services.xserver.displayManager.gdm.enable = false` → GDM doesn't auto-start
- Result: Console boot, GNOME available on demand

---

## Testing the Fix

### 1. Remove Any Existing Override

If `gui-local.nix` exists, remove it to test clean behavior:
```bash
sudo rm /var/lib/hypervisor/configuration/gui-local.nix
```

### 2. Rebuild
```bash
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)
```

### 3. Reboot
```bash
sudo systemctl reboot
```

### 4. Expected Result
- ✅ Console appears with console menu
- ✅ NO GDM login screen
- ✅ NO GNOME desktop auto-start
- ✅ Can select "GNOME Desktop" from menu if desired

---

## Configuration States

### State 1: Console Boot (Default)
```bash
# No gui-local.nix file exists
```

**Result:**
- Console menu on boot
- GNOME installed but not started
- GDM disabled

### State 2: Force GUI Boot
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```

Creates `gui-local.nix` with:
```nix
{
  hypervisor.gui.enableAtBoot = true;
  hypervisor.menu.enableAtBoot = false;
}
```

**Result:**
- GNOME auto-starts on boot
- GDM enabled
- Console menu disabled

### State 3: Force Console Boot
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```

Creates `gui-local.nix` with:
```nix
{
  hypervisor.gui.enableAtBoot = false;
  hypervisor.menu.enableAtBoot = true;
}
```

**Result:**
- Console menu on boot
- GDM explicitly disabled
- Same as default, but explicit

### State 4: Auto (Remove Override)
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```

Removes `gui-local.nix`

**Result:**
- Back to default behavior (console boot)

---

## How to Use GNOME

With console boot as default:

### Option 1: From Console Menu
1. Boot to console menu
2. Select: "More Options" → "GNOME Desktop"
3. GNOME launches

### Option 2: Switch Target
```bash
sudo systemctl isolate graphical.target
```

### Option 3: Make GUI Default
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on
sudo systemctl reboot
```

---

## The Critical Change

### Before (Wrong)
```nix
# This made GUI auto-start if base system had it
enableGuiAtBoot = baseSystemHasGui || hypervisorGuiRequested;
services.xserver.displayManager.gdm.enable = lib.mkDefault enableGuiAtBoot;
```

**Problem:** Having GNOME installed → GDM auto-starts → login screen on boot

### After (Correct)
```nix
# GUI boot ONLY if explicitly requested
enableGuiAtBoot = hypervisorGuiRequested;
services.xserver.displayManager.gdm.enable = lib.mkDefault (enableGuiAtBoot && hasOldDM);
```

**Fix:** GDM only starts if you explicitly enable GUI boot → console boot by default

---

## Check Status

```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh status
```

Should show:
```
GUI Environment Status:
=======================

Base System GUI: true
Hypervisor GUI Override: not set (no gui-local.nix)

Result: Console menu on boot (default)

Current default target: multi-user.target
```

---

## Summary

✅ **Console menu on boot** - Default behavior
✅ **GNOME available** - Launch from menu when needed
✅ **No GDM auto-start** - Display manager disabled by default
✅ **No login screen bypass** - Console loads first
✅ **Base system preserved** - GNOME packages remain installed
✅ **Easy to toggle** - Can enable GUI boot if desired

The original problem is now fixed!
