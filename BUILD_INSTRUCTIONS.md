# Build Instructions for Hyper-NixOS

## System Architecture

Hyper-NixOS uses a **flake-based architecture** with the following structure:

```
/etc/hypervisor/
├── flake.nix                    # Host flake (main entry point)
├── flake.lock                   # Locked dependencies
└── src/                         # Installed repository
    ├── configuration.nix
    ├── modules/
    ├── profiles/
    └── scripts/

/etc/nixos/
└── hardware-configuration.nix   # Auto-generated hardware detection (ONLY file needed)

/home/hyperd/Documents/Hyper-NixOS/
└── (development repository - not used by live system)
```

**Key Points:**
- The **installed system** lives at `/etc/hypervisor/`
- The **development repo** at `/home/hyperd/Documents/Hyper-NixOS/` is NOT used by the live system
- `/etc/nixos/` only needs `hardware-configuration.nix` - everything else is legacy

---

## Standard Build Commands

### Building the Installed System

```bash
# Build without activating (test)
sudo nixos-rebuild build --flake /etc/hypervisor

# Build and activate temporarily (reverts on reboot)
sudo nixos-rebuild test --flake /etc/hypervisor

# Build and activate permanently
sudo nixos-rebuild switch --flake /etc/hypervisor

# Syntax check only (fast)
sudo nixos-rebuild dry-build --flake /etc/hypervisor
```

The system automatically detects your hostname and uses the corresponding configuration from `/etc/hypervisor/flake.nix`.

### Using the Rebuild Helper

```bash
# Convenient wrapper script
./scripts/rebuild_helper.sh build
./scripts/rebuild_helper.sh test
./scripts/rebuild_helper.sh switch

# Or via nix run
nix run .#rebuild-helper
```

---

## Development Workflow

### Working on Hyper-NixOS Development

When making changes to Hyper-NixOS itself:

```bash
cd /home/hyperd/Documents/Hyper-NixOS

# Make your changes to modules, scripts, etc.

# Test the development version
sudo nixos-rebuild build --flake .

# After testing, copy changes to installed system
sudo rsync -av --exclude='.git' ./ /etc/hypervisor/src/

# Then rebuild from installed location
sudo nixos-rebuild switch --flake /etc/hypervisor
```

### Quick Development Cycle

```bash
# Edit files in development repo
vim /home/hyperd/Documents/Hyper-NixOS/modules/something.nix

# Test directly (reads from current directory)
cd /home/hyperd/Documents/Hyper-NixOS
sudo nixos-rebuild build --flake .

# If successful, sync to production
sudo rsync -av --exclude='.git' ./ /etc/hypervisor/src/
sudo nixos-rebuild switch --flake /etc/hypervisor
```

---

## Cleaning Up `/etc/nixos/`

### What Can Be Removed

The `/etc/nixos/` directory may contain leftover files from vanilla NixOS installation:

```bash
# Remove vanilla NixOS configuration (not used by Hyper-NixOS)
sudo rm /etc/nixos/configuration.nix

# Remove flake.nix symlink (redundant - real flake is at /etc/hypervisor/flake.nix)
sudo rm /etc/nixos/flake.nix

# Remove old backups if you don't need them
sudo rm /etc/nixos/hardware-configuration.nix.pre-hyper-nixos
```

### What MUST Remain

```bash
/etc/nixos/
└── hardware-configuration.nix   # Auto-generated - DO NOT REMOVE
```

The `hardware-configuration.nix` file is **critical** - it contains auto-detected:
- Boot loader settings
- Kernel modules
- Filesystem UUIDs
- Hardware-specific configuration

This file is imported by `/etc/hypervisor/flake.nix`.

---

## Common Workflows

### Update System Packages

```bash
# Update flake inputs (nixpkgs, etc.)
cd /etc/hypervisor
sudo nix flake update

# Rebuild with updated packages
sudo nixos-rebuild switch --flake /etc/hypervisor
```

### Switch NixOS Channels

```bash
# Use the channel switcher script
cd /etc/hypervisor/src
sudo ./scripts/switch-channel.sh

# Or manually edit /etc/hypervisor/flake.nix
sudo vim /etc/hypervisor/flake.nix
# Change: nixpkgs.url = "github:NixOS/nixpkgs/nixos-XX.YY";

# Then update and rebuild
sudo nix flake update /etc/hypervisor
sudo nixos-rebuild switch --flake /etc/hypervisor
```

### Test Configuration Changes Safely

```bash
# Option 1: Test mode (reverts on reboot)
sudo nixos-rebuild test --flake /etc/hypervisor
# Try it out...
# If something breaks, just reboot to previous config

# Option 2: Build only (doesn't activate)
sudo nixos-rebuild build --flake /etc/hypervisor
# Check the result symlink
ls -l ./result
# If looks good, then switch:
sudo nixos-rebuild switch --flake /etc/hypervisor
```

---

## Troubleshooting

### Error: "option does not exist"

**Cause:** Building from wrong location or stale files

**Fix:**
```bash
# Ensure you're building from /etc/hypervisor
sudo nixos-rebuild build --flake /etc/hypervisor

# If using dev repo, make sure it's synced
sudo rsync -av --exclude='.git' /home/hyperd/Documents/Hyper-NixOS/ /etc/hypervisor/src/
```

### Error: "flake not found"

**Cause:** Wrong directory or missing flake.nix

**Fix:**
```bash
# Check flake exists
ls -l /etc/hypervisor/flake.nix

# Use absolute path
sudo nixos-rebuild build --flake /etc/hypervisor
```

### Error: Building from `/etc/nixos/configuration.nix`

**Cause:** Missing `--flake` flag causes NixOS to use default configuration

**Fix:**
```bash
# Always use --flake flag
sudo nixos-rebuild switch --flake /etc/hypervisor
```

### Development Changes Not Applied

**Cause:** Editing dev repo but building from `/etc/hypervisor/src/`

**Fix:**
```bash
# Sync development changes to installed location
cd /home/hyperd/Documents/Hyper-NixOS
sudo rsync -av --exclude='.git' ./ /etc/hypervisor/src/

# Then rebuild
sudo nixos-rebuild switch --flake /etc/hypervisor
```

---

## Architecture Details

### Why Two Locations?

1. **`/etc/hypervisor/src/`** - Installed, production system
   - Used by live system rebuilds
   - Updated via installer or manual sync
   - Should be stable and tested

2. **`/home/hyperd/Documents/Hyper-NixOS/`** - Development repository
   - Version controlled with git
   - For development and testing
   - Changes must be synced to `/etc/hypervisor/src/` to take effect

### The Host Flake

`/etc/hypervisor/flake.nix` is the **host flake** that defines your system:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.hypervisor = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        /etc/nixos/hardware-configuration.nix
        /etc/hypervisor/src/profiles/configuration-minimal.nix
      ];
    };
  };
}
```

This imports:
- Hardware detection from `/etc/nixos/hardware-configuration.nix`
- System configuration from `/etc/hypervisor/src/profiles/`

### Why Keep `/etc/nixos/hardware-configuration.nix`?

NixOS's `nixos-generate-config` puts it there by default, and it's the standard location. The host flake references it with an absolute path: `/etc/nixos/hardware-configuration.nix`.

You could move it elsewhere and update the flake, but keeping it in the standard location maintains compatibility with NixOS conventions.

---

## Quick Reference

| Task | Command |
|------|---------|
| Build installed system | `sudo nixos-rebuild build --flake /etc/hypervisor` |
| Apply changes | `sudo nixos-rebuild switch --flake /etc/hypervisor` |
| Test changes (revert on reboot) | `sudo nixos-rebuild test --flake /etc/hypervisor` |
| Syntax check | `sudo nixos-rebuild dry-build --flake /etc/hypervisor` |
| Update packages | `sudo nix flake update /etc/hypervisor && sudo nixos-rebuild switch --flake /etc/hypervisor` |
| Sync dev to production | `sudo rsync -av --exclude='.git' /home/hyperd/Documents/Hyper-NixOS/ /etc/hypervisor/src/` |
| Test dev changes | `cd /home/hyperd/Documents/Hyper-NixOS && sudo nixos-rebuild build --flake .` |

---

**Last Updated:** 2025-10-19
**System:** NixOS 25.05
**Architecture:** Flake-based with separated development and production locations
