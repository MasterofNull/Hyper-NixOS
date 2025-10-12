# Final Solution - Respecting Your GUI Choices

## Core Philosophy

**We don't force anything. Your NixOS installation choices are respected.**

---

## How It Actually Works Now

### Without Override (`gui-local.nix` doesn't exist)

**Behavior:** Use your base NixOS configuration exactly as-is

```nix
# Hypervisor checks: Do you have an explicit preference?
hasHypervisorGuiPreference = lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config;

# Answer: NO (gui-local.nix doesn't exist)
# Result: Don't touch GUI config, use base system
services.xserver.enable = lib.mkIf hasHypervisorGuiPreference (...);
# ↑ This line does NOTHING because condition is false
```

**Your base system config wins** - whatever you installed with NixOS is what you get.

### With Override (`gui-local.nix` exists)

**Behavior:** Override base system with your explicit choice

```nix
# Hypervisor checks: Do you have an explicit preference?
hasHypervisorGuiPreference = true  # gui-local.nix exists

# Answer: YES
# Result: Override base system with your preference
services.xserver.displayManager.gdm.enable = lib.mkOverride 900 enableGuiAtBoot;
# ↑ This OVERRIDES base system
```

**Your explicit override wins** - you said what you want, we make it happen.

---

## Your Situation

You installed NixOS with GNOME:
- Base system: `services.xserver.enable = true` ✓
- Base system: `services.xserver.displayManager.gdm.enable = true` ✓
- Result: GNOME login screen on boot

### Solution: Override It

Since you want console menu instead of GNOME auto-start:

```bash
# Create override to force console menu
sudo /etc/hypervisor/scripts/toggle_gui.sh off
sudo systemctl reboot
```

This creates `/var/lib/hypervisor/configuration/gui-local.nix`:
```nix
{
  hypervisor.gui.enableAtBoot = false;
  hypervisor.menu.enableAtBoot = true;
}
```

**Result:** Console menu on boot, GNOME login bypassed.

### Want Your Original GNOME Back?

```bash
# Remove override, go back to base system choice
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
sudo systemctl reboot
```

**Result:** GNOME login screen on boot (your original install choice).

---

## Check What's Configured

```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh status
```

### Example Output (No Override)
```
GUI Environment Status:
=======================

Base System GUI: true
Hypervisor Override: NONE (no gui-local.nix)
Configuration: Using base system default (respecting your choice)

Result: GNOME will start (from your NixOS installation)

Your base system has GNOME configured. This is respected.

To override and force console menu:
  sudo /etc/hypervisor/scripts/toggle_gui.sh off

Current default target: graphical.target
```

### Example Output (With Override)
```
GUI Environment Status:
=======================

Base System GUI: true
Hypervisor Override: ACTIVE (gui-local.nix exists)
Override Setting: hypervisor.gui.enableAtBoot = false

Result: Console menu on boot (OVERRIDING base system)

To remove override and respect base system:
  sudo /etc/hypervisor/scripts/toggle_gui.sh auto

Current default target: multi-user.target
```

---

## Three Simple Commands

### 1. Force Console Menu (Override)
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```
Even if base has GNOME, console menu loads.

### 2. Force GUI Start (Override)
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```
Even if base has no GUI, GNOME loads.

### 3. Use Base System (No Override)
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```
Whatever you installed NixOS with is what you get.

---

## The Configuration Priority

```
┌─────────────────────────────────────┐
│  Base NixOS Installation            │
│  - Your initial choices              │
│  - Priority: 1000 (default)          │
└──────────────┬──────────────────────┘
               │
               ↓
       ┌───────────────┐
       │ Override?     │
       └───────┬───────┘
               │
      ┌────────┴────────┐
      │                 │
     NO                YES
      │                 │
      ↓                 ↓
┌──────────┐      ┌──────────────┐
│ Use Base │      │ Use Override │
│ (Respect)│      │ Priority: 900│
└──────────┘      └──────────────┘
```

**Priority 900 > Priority 1000** - Override wins when present

---

## What Changed

### Before (Wrong)
```nix
# This forced behavior
services.xserver.displayManager.gdm.enable = lib.mkDefault false;
# ↑ Even with mkDefault, this set it to false
```
**Problem:** Always disabled GDM, ignoring base system.

### After (Correct)
```nix
# This respects base system when no preference
services.xserver.displayManager.gdm.enable = 
  lib.mkIf hasHypervisorGuiPreference (lib.mkOverride 900 enableGuiAtBoot);
# ↑ Only configures if gui-local.nix exists
```
**Solution:** Only touches config when you explicitly override.

---

## For Your Specific Need

**Problem:** GNOME auto-starts, want console menu

**Solution:**
```bash
# 1. Create override
sudo /etc/hypervisor/scripts/toggle_gui.sh off

# 2. Rebuild
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)

# 3. Reboot
sudo systemctl reboot
```

**Result:**
- ✅ Console menu on boot
- ✅ GNOME still installed
- ✅ Can launch GNOME from menu
- ✅ Your base system preserved
- ✅ Reversible with "auto" mode

---

## Key Points

✅ **No forced defaults** - Base system is respected
✅ **Override when YOU want** - Explicit choice required
✅ **Always reversible** - Can go back to base system
✅ **Clear status** - Know what's configured and why
✅ **Your choice, your control** - We just provide tools

---

## Test It

```bash
# Check current status
sudo /etc/hypervisor/scripts/toggle_gui.sh status

# If GNOME auto-starting and you want console:
sudo /etc/hypervisor/scripts/toggle_gui.sh off
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)
sudo systemctl reboot

# Expected: Console menu appears, no GDM login screen
```

**Your preferences. Your control. Respected.**
