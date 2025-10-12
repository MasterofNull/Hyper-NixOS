# Desktop Icons for GNOME

## Overview

Desktop shortcuts are now **automatically** included in the NixOS configuration.

No installation scripts needed - they're part of the declarative config!

## Available Desktop Launchers

When you access GNOME (manually or via menu), these application launchers are available:

### Hypervisor Console Menu
- **Name**: Hypervisor Console Menu
- **Description**: Main hypervisor management menu
- **Launches**: Terminal with main menu
- **Icon**: utilities-terminal

### Hypervisor Dashboard  
- **Name**: Hypervisor Dashboard
- **Description**: GUI dashboard for VM and task management
- **Icon**: computer

### Hypervisor Setup Wizard
- **Name**: Hypervisor Setup Wizard
- **Description**: Run first-boot setup and configuration wizard
- **Launches**: Terminal with setup wizard
- **Icon**: system-software-install

### Network Foundation Setup
- **Name**: Network Foundation Setup
- **Description**: Configure foundational networking
- **Launches**: Terminal with network setup (requires sudo)
- **Icon**: network-wired

## Location

Application launchers appear in:
- Application menu (press Super/Windows key, then type "Hypervisor")
- Show Applications grid
- Desktop (for new users via /etc/skel/Desktop/)

## How It Works

The desktop files are declared in `configuration/configuration.nix`:

```nix
environment.etc."xdg/applications/hypervisor-menu.desktop" = { ... };
environment.etc."xdg/applications/hypervisor-dashboard.desktop" = { ... };
environment.etc."xdg/applications/hypervisor-installer.desktop" = { ... };
environment.etc."xdg/applications/hypervisor-networking.desktop" = { ... };
```

These are **always** present, even if GNOME boot is disabled. This way, if you manually access GNOME (via menu selection or `systemctl isolate graphical.target`), the launchers are already there.

## Desktop Shortcuts for New Users

New users get a desktop shortcut automatically via:

```nix
environment.etc."skel/Desktop/Hypervisor-Menu.desktop" = { ... };
```

This appears on the desktop for any newly created users.

## Existing Users

If you want desktop shortcuts on your existing Desktop folder:

1. Copy from skel:
```bash
cp /etc/skel/Desktop/Hypervisor-Menu.desktop ~/Desktop/
chmod +x ~/Desktop/Hypervisor-Menu.desktop
```

2. Or create manually using the application launchers in `/etc/xdg/applications/`

## The NixOS Way

This is the declarative approach:
- ✓ Desktop files are part of the system configuration
- ✓ Always present, no installation needed
- ✓ Consistent across all users
- ✓ Survive system rebuilds
- ✓ Can be version controlled

No "install desktop shortcuts" script needed!
