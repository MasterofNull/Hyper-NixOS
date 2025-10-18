# Respecting User's GUI Preferences

## Philosophy

**The hypervisor configuration respects your base NixOS installation choices.**

We don't force any GUI behavior. We provide tools, and you decide.

---

## How It Works

### Three Configuration Layers

1. **Base System** (Your NixOS Installation)
   - What you configured during NixOS install
   - Example: If you installed with GNOME, it's configured here

2. **Hypervisor Default** (When No Preference)
   - **Does nothing** - your base config is used as-is
   - Provides console menu and tools
   - Doesn't override your GUI choice

3. **Hypervisor Override** (Explicit Preference)
   - File: `/var/lib/hypervisor/configuration/gui-local.nix`
   - Only used when YOU want to override base system
   - Optional - not created by default

### The Logic

```nix
# Check if user has explicit hypervisor GUI preference
hasHypervisorGuiPreference = lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config;

# If no preference, use base system; if preference exists, use it
enableGuiAtBoot = if hasHypervisorGuiPreference 
                  then hypervisorGuiRequested 
                  else baseSystemHasGui;

# Only configure GUI if user has explicit preference
# Otherwise, base system config is untouched
services.xserver.enable = lib.mkIf hasHypervisorGuiPreference (lib.mkOverride 900 enableGuiAtBoot);
```

**Translation:**
- No `gui-local.nix` = Your base system choice is respected
- `gui-local.nix` exists = Your explicit override is used

---

## Your Scenarios

### Scenario 1: Installed NixOS with GNOME
**What you chose:** GNOME desktop during install

**Without hypervisor override:**
- ✅ GNOME starts on boot (your choice respected)
- ✅ Hypervisor tools available in GNOME
- ✅ Desktop shortcuts for console menu

**To use console menu instead:**
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```
Creates override to force console boot.

**To restore your original choice:**
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```
Removes override, back to GNOME.

### Scenario 2: Installed NixOS without GUI
**What you chose:** Minimal/server install, no GUI

**Without hypervisor override:**
- ✅ Console boots (your choice respected)
- ✅ Console menu available
- ✅ No GUI components loaded

**To add GUI capability:**
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```
Enables GNOME for hypervisor management.

### Scenario 3: Fresh Hypervisor Install
**What you chose:** Starting fresh

**Without hypervisor override:**
- ✅ Uses base system default
- ✅ Console menu if no GUI
- ✅ GNOME if GUI installed

**Your preference:**
Set it however you want using toggle_gui.sh.

---

## The Toggle Tool

### Three Modes

#### Auto Mode (Respect Base System)
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```

- Removes `/var/lib/hypervisor/configuration/gui-local.nix`
- Hypervisor doesn't set GUI preferences
- Base system configuration is used
- **Default behavior - nothing forced**

#### Force GUI On
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```

- Creates `gui-local.nix` with `hypervisor.gui.enableAtBoot = true`
- Overrides base system to enable GUI boot
- Even if base system has no GUI, this enables it

#### Force GUI Off
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```

- Creates `gui-local.nix` with `hypervisor.gui.enableAtBoot = false`
- Overrides base system to disable GUI boot
- Even if base system has GNOME, this forces console

### Check Status
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh status
```

Shows:
- Base system GUI configuration
- Hypervisor override status
- What will actually happen on boot
- Current systemd target

---

## Configuration Precedence

### Without `gui-local.nix`
```
Base System Config → Result
└─ No hypervisor interference
```

**Example:**
- Base has `services.xserver.enable = true`
- Hypervisor: *(nothing set)*
- Result: GNOME starts (base system choice)

### With `gui-local.nix`
```
Base System Config → Hypervisor Override → Result
                      └─ Wins (priority 900)
```

**Example:**
- Base has `services.xserver.enable = true`
- Hypervisor: `hypervisor.gui.enableAtBoot = false`
- Result: Console menu (hypervisor override)

---

## Key Insight

**Your initial NixOS installation choice is always preserved unless YOU explicitly override it.**

- Installed with GNOME → Keep GNOME (unless you say otherwise)
- Installed without GUI → Keep console (unless you say otherwise)
- Want to change → Use toggle tool to override

---

## Priority System

NixOS has priority levels:
- `100` = lib.mkForce (highest - forces value)
- `900` = lib.mkOverride 900 (high - hypervisor uses this)
- `1000` = lib.mkDefault (low - base system typically)
- `1500` = lib.mkOptionDefault (lowest)

**Our strategy:**
- Base system uses default priority (~1000)
- Hypervisor uses priority 900 (only when preference set)
- Result: Hypervisor override wins when present, base system wins when not

---

## For Your Situation

Since you want console menu but installed NixOS with GNOME:

### Option 1: Temporary Override
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
sudo systemctl reboot
```
Console menu on boot, GNOME still available.

### Option 2: Permanent Change
Edit your base system configuration to remove/disable GNOME, then rebuild.

### Option 3: Switch Dynamically
```bash
# Use console menu most of the time
sudo /etc/hypervisor/scripts/toggle_gui.sh off

# When you want GUI
sudo /etc/hypervisor/scripts/toggle_gui.sh on

# Back to base system default
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```

---

## Summary

✅ **Base system choice respected** - We don't force anything
✅ **Optional override** - Only when you explicitly want it
✅ **Easy to change** - Simple toggle tool
✅ **Clear status** - Always know what's configured
✅ **No hidden behavior** - Everything explicit in config files
✅ **Reversible** - Can always go back to base system default

**Your preferences. Your control. We just provide the tools.**
