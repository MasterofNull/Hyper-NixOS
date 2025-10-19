# Build Instructions for Hyper-NixOS

## ⚠️ CRITICAL: `/etc/nixos/configuration.nix` is a LEFTOVER REMNANT

### What is `/etc/nixos/configuration.nix`?

**It's a leftover file from the vanilla NixOS installation** - NOT part of Hyper-NixOS!

When NixOS was first installed (before Hyper-NixOS), the installer created:
- `/etc/nixos/configuration.nix` - Default NixOS template
- `/etc/nixos/hardware-configuration.nix` - Hardware detection

When Hyper-NixOS was installed, it:
- ✅ Created `/etc/hypervisor/` structure
- ✅ Created `/etc/hypervisor/flake.nix`
- ✅ Symlinked `/etc/nixos/flake.nix` → `/etc/hypervisor/flake.nix`
- ❌ **DID NOT REPLACE** `/etc/nixos/configuration.nix`

**This leftover file is causing all your errors!**

### The Problem

The system has **TWO** configuration locations:

1. `/etc/nixos/configuration.nix` - **Vanilla NixOS template** (NOT Hyper-NixOS, causes errors)
2. `/home/hyperd/Documents/Hyper-NixOS/configuration.nix` - **Hyper-NixOS repository** (FIXED, correct)

### Why This Causes Errors

When you run `sudo nixos-rebuild switch` WITHOUT the `--flake` flag, NixOS reads from `/etc/nixos/configuration.nix` which:
- Is NOT our fixed code
- May import from `/etc/hypervisor/src/` (old modules)
- Contains the anti-pattern we fixed

### The Solution

You MUST explicitly tell NixOS to use OUR flake configuration.

---

## ✅ Correct Build Commands

### From Repository Directory

```bash
# Change to repository
cd /home/hyperd/Documents/Hyper-NixOS

# Option 1: Build without activating (test)
sudo nixos-rebuild build --flake .#hypervisor-x86_64

# Option 2: Build and switch (activate)
sudo nixos-rebuild switch --flake .#hypervisor-x86_64

# Option 3: Build and test in VM
sudo nixos-rebuild build-vm --flake .#hypervisor-x86_64
./result/bin/run-hypervisor-x86_64-vm
```

### Explanation

- `--flake .` - Use the flake in current directory
- `#hypervisor-x86_64` - Use the "hypervisor-x86_64" configuration from flake.nix
- This reads from `/home/hyperd/Documents/Hyper-NixOS/configuration.nix`
- NOT from `/etc/nixos/configuration.nix`

---

## ❌ Commands That Will FAIL

```bash
# ❌ WRONG - Uses /etc/nixos/configuration.nix (old code)
sudo nixos-rebuild switch

# ❌ WRONG - Uses /etc/nixos/configuration.nix (old code)
sudo nixos-rebuild build

# ❌ WRONG - Still uses system config
cd /home/hyperd/Documents/Hyper-NixOS
sudo nixos-rebuild switch  # Missing --flake flag!
```

---

---

## 🧹 CLEANUP: Remove the Leftover File (Recommended)

Since `/etc/nixos/configuration.nix` is just a vanilla NixOS remnant and NOT part of Hyper-NixOS, you should replace it:

### Option 1: Replace with Minimal Stub (Safest)

```bash
# Backup the old file
sudo mv /etc/nixos/configuration.nix /etc/nixos/configuration.nix.nixos-vanilla-backup

# Create minimal stub that says "use the flake"
sudo tee /etc/nixos/configuration.nix <<'EOF'
# This system uses Hyper-NixOS managed via flake
# The vanilla NixOS configuration has been replaced
#
# To rebuild: cd /home/hyperd/Documents/Hyper-NixOS
#             sudo nixos-rebuild switch --flake .#hypervisor-x86_64
#
# Original vanilla NixOS config backed up as: configuration.nix.nixos-vanilla-backup

{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  system.stateVersion = "25.05";

  # All actual configuration is in the Hyper-NixOS flake
  # See: /home/hyperd/Documents/Hyper-NixOS/configuration.nix
}
EOF
```

### Option 2: Symlink to Repository (Alternative)

```bash
# Backup the old file
sudo mv /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup

# Create symlink to Hyper-NixOS
sudo ln -s /home/hyperd/Documents/Hyper-NixOS/configuration.nix /etc/nixos/configuration.nix
sudo ln -s /home/hyperd/Documents/Hyper-NixOS/modules /etc/nixos/modules
```

**Warning**: This makes `/etc/nixos/` depend on your home directory!

---

## 🔧 Permanent Fix Options

### Option A: Make Flake the Default (Recommended)

Edit `/etc/nixos/flake.nix` to point to our repository:

```bash
sudo mkdir -p /etc/nixos
sudo tee /etc/nixos/flake.nix <<'EOF'
{
  inputs = {
    hyper-nixos.url = "path:/home/hyperd/Documents/Hyper-NixOS";
  };

  outputs = { hyper-nixos, ... }: {
    nixosConfigurations.default = hyper-nixos.nixosConfigurations.hypervisor-x86_64;
  };
}
EOF

# Then you can use:
sudo nixos-rebuild switch --flake /etc/nixos
```

### Option B: Symlink Configuration (Simple but risky)

```bash
# Backup existing config
sudo mv /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup

# Create symlink to our repository
sudo ln -s /home/hyperd/Documents/Hyper-NixOS/configuration.nix /etc/nixos/configuration.nix

# Do the same for modules
sudo ln -s /home/hyperd/Documents/Hyper-NixOS/modules /etc/nixos/modules

# Now regular nixos-rebuild will work
sudo nixos-rebuild switch
```

**Warning**: This makes `/etc/nixos` depend on your home directory!

### Option C: Use /etc/hypervisor/src as Development Location

```bash
# Make /etc/hypervisor/src a git clone
sudo rm -rf /etc/hypervisor/src  # Remove old version
sudo git clone /home/hyperd/Documents/Hyper-NixOS /etc/hypervisor/src

# Keep it updated
cd /home/hyperd/Documents/Hyper-NixOS
git pull
sudo rsync -av --delete ./ /etc/hypervisor/src/

# Then build from there
cd /etc/hypervisor/src
sudo nixos-rebuild switch --flake .#hypervisor-x86_64
```

---

## 📋 Quick Reference

### Current Working Commands

```bash
cd /home/hyperd/Documents/Hyper-NixOS

# Test build
sudo nixos-rebuild build --flake .#hypervisor-x86_64

# Apply changes
sudo nixos-rebuild switch --flake .#hypervisor-x86_64

# Test in VM
sudo nixos-rebuild build-vm --flake .#hypervisor-x86_64

# Dry build (check syntax)
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64
```

### Troubleshooting

**Error: "option does not exist"**
- You're building from `/etc/nixos` (old code)
- Use `--flake .#hypervisor-x86_64` flag

**Error: "Permission denied"**
- Run with `sudo`
- Ensure you're in the repository directory

**Error: "flake not found"**
- Make sure you're in `/home/hyperd/Documents/Hyper-NixOS`
- Check `flake.nix` exists in current directory

---

## 🎯 Recommended Workflow

1. **Always work in the repository**:
   ```bash
   cd /home/hyperd/Documents/Hyper-NixOS
   ```

2. **Use the flake explicitly**:
   ```bash
   sudo nixos-rebuild build --flake .#hypervisor-x86_64
   ```

3. **Test before applying**:
   ```bash
   # First: dry-build
   sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64

   # Then: build
   sudo nixos-rebuild build --flake .#hypervisor-x86_64

   # Finally: switch
   sudo nixos-rebuild switch --flake .#hypervisor-x86_64
   ```

4. **Commit changes**:
   ```bash
   git add -A
   git commit -m "your changes"
   git push
   ```

---

## 📝 Notes

- The flake.nix defines `hypervisor-x86_64` as the configuration name
- Our fixed modules are in `/home/hyperd/Documents/Hyper-NixOS/modules/`
- System default modules (if they exist) are in `/etc/hypervisor/src/modules/` or `/etc/nixos/modules/`
- **Always use --flake flag** to ensure you're building the right configuration

---

**Last Updated**: 2025-10-19
**Issue**: System was building from `/etc/nixos/configuration.nix` instead of repository
**Solution**: Always use `--flake .#hypervisor-x86_64` flag
