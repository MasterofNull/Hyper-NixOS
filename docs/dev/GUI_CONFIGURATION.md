# GUI Configuration - Respecting Base System

## How It Works

The hypervisor configuration now **detects and respects** your base NixOS installation's GUI configuration.

### Configuration Hierarchy

1. **Base System** (your NixOS install)
   - If you installed NixOS with GNOME, it's configured in your base system

2. **Hypervisor Default** (this configuration)
   - Default: Console menu on boot
   - Uses `lib.mkDefault` so base system takes precedence

3. **Hypervisor Override** (optional)
   - File: `/var/lib/hypervisor/configuration/gui-local.nix`
   - Can force GUI on/off regardless of base system

### Three Modes

#### Auto Mode (Recommended)
No `gui-local.nix` file - respects base system choice

- Base system has GNOME → GNOME starts
- Base system has no GUI → Console menu starts

```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh auto
```

#### Force GUI On
Override to always start GNOME (even if base system doesn't have it)

```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh on
```

#### Force GUI Off
Override to always start console menu (even if base system has GNOME)

```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```

## Checking Status

See what's configured:
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

## Detecting GUI Environment

The hypervisor can detect GUI details:
```bash
/etc/hypervisor/scripts/detect_gui_environment.sh | jq
```

Example output:
```json
{
  "gui_available": true,
  "display_server": "wayland",
  "desktop_environment": "GNOME",
  "display_manager": "GDM",
  "session_type": "wayland",
  "hypervisor_gui_enabled": false,
  "base_system_gui": true,
  "can_launch_gui": true,
  "current_target": "graphical.target"
}
```

## Management Dashboard Integration

The GUI dashboard now shows GUI status in the title bar and provides options:

- **GUI: Use base system default** - Remove override
- **GUI: Force GNOME at boot** - Override to always use GUI
- **GUI: Force console menu at boot** - Override to always use console
- **Show GUI environment status** - View current configuration

## Configuration Details

### Base Configuration (`configuration.nix`)

```nix
# Detect if GUI is enabled (either by user's base install or hypervisor config)
baseSystemHasGui = config.services.xserver.enable or false;
hypervisorGuiRequested = lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config;

# Enable GUI if either base system has it OR hypervisor config requests it
enableGuiAtBoot = baseSystemHasGui || hypervisorGuiRequested;

# Use mkDefault so base system config takes precedence
services.xserver.enable = lib.mkDefault enableGuiAtBoot;
services.xserver.desktopManager.gnome.enable = lib.mkDefault (enableGuiAtBoot && hasOldDesk);
```

### Override File (`/var/lib/hypervisor/configuration/gui-local.nix`)

**Force GUI:**
```nix
{ config, lib, pkgs, ... }:
{
  hypervisor.gui.enableAtBoot = true;
  hypervisor.menu.enableAtBoot = false;
}
```

**Force Console:**
```nix
{ config, lib, pkgs, ... }:
{
  hypervisor.gui.enableAtBoot = false;
  hypervisor.menu.enableAtBoot = true;
}
```

**Auto (delete file):**
```bash
sudo rm /var/lib/hypervisor/configuration/gui-local.nix
```

## Your Scenario

If you installed NixOS with GNOME:
1. Base system has `services.xserver.enable = true`
2. Base system has `services.xserver.desktopManager.gnome.enable = true`
3. Hypervisor detects this: `baseSystemHasGui = true`
4. Result: GNOME starts (respecting your choice)

To force console menu instead:
```bash
sudo /etc/hypervisor/scripts/toggle_gui.sh off
```

This creates `gui-local.nix` with `hypervisor.gui.enableAtBoot = false`, which overrides the base system.

## The NixOS Way

- ✓ **Declarative**: Everything in configuration files
- ✓ **Composable**: Base system + hypervisor layers
- ✓ **Predictable**: Clear precedence (base → default → override)
- ✓ **Reversible**: Easy to change and rollback
- ✓ **Inspectable**: Check status at any time

No hidden state - everything is in configuration!
