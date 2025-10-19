# Build Instructions for Hyper-NixOS

## NixOS Flake-Based System

Hyper-NixOS is a **flake-based NixOS system**. This means:
- The `flake.nix` is the entry point (not `/etc/nixos/configuration.nix`)
- You MUST use `--flake` flag when rebuilding
- Configuration is managed in the repository, not `/etc/nixos/`

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

# Option 3: Dry build (syntax check)
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64

# Option 4: Build and test in VM
sudo nixos-rebuild build-vm --flake .#hypervisor-x86_64
./result/bin/run-hypervisor-x86_64-vm
```

### Explanation

- `--flake .` - Use the flake in current directory
- `#hypervisor-x86_64` - Use the "hypervisor-x86_64" configuration from [flake.nix](flake.nix)
- This reads from `/home/hyperd/Documents/Hyper-NixOS/configuration.nix`
- NOT from `/etc/nixos/configuration.nix` (if it exists)

---

## ❌ Commands That Will FAIL

```bash
# ❌ WRONG - Uses /etc/nixos/configuration.nix (not our flake)
sudo nixos-rebuild switch

# ❌ WRONG - Uses /etc/nixos/configuration.nix (not our flake)
sudo nixos-rebuild build

# ❌ WRONG - Still uses system config
cd /home/hyperd/Documents/Hyper-NixOS
sudo nixos-rebuild switch  # Missing --flake flag!
```

**Why these fail**: Without `--flake`, NixOS defaults to `/etc/nixos/configuration.nix` which may be:
- A vanilla NixOS template (from initial installation)
- Outdated or unrelated to Hyper-NixOS
- Missing our fixes and modules

---

## 🧹 Cleaning Up `/etc/nixos/configuration.nix`

### Standard NixOS Practice

**For flake-based systems, `/etc/nixos/configuration.nix` is NOT required.**

If you have a leftover `/etc/nixos/configuration.nix` from the vanilla NixOS installation, you can safely remove it:

```bash
# Backup the vanilla NixOS template (for reference)
sudo mv /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup-vanilla-nixos

# That's it! No replacement needed for flake-based systems.
```

### What Should Remain in `/etc/nixos/`

After cleanup, `/etc/nixos/` should contain:

```
/etc/nixos/
├── hardware-configuration.nix          # Auto-generated hardware detection (KEEP)
└── configuration.nix.backup-vanilla-nixos  # Backup of original (optional)
```

**Note**: Some systems may have `/etc/nixos/flake.nix` as a symlink to `/etc/hypervisor/flake.nix` - this is fine to keep.

---

## 🎯 Recommended Workflow

### 1. Always work in the repository

```bash
cd /home/hyperd/Documents/Hyper-NixOS
```

### 2. Test before applying

```bash
# First: Check syntax
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64

# Then: Build (creates result symlink)
sudo nixos-rebuild build --flake .#hypervisor-x86_64

# Finally: Switch (activate)
sudo nixos-rebuild switch --flake .#hypervisor-x86_64
```

### 3. Commit changes

```bash
git add -A
git commit -m "your changes"
git push
```

---

## 📋 Quick Reference

### Available Build Commands

```bash
cd /home/hyperd/Documents/Hyper-NixOS

# Syntax check only (fast)
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64

# Build without activating
sudo nixos-rebuild build --flake .#hypervisor-x86_64

# Build and activate
sudo nixos-rebuild switch --flake .#hypervisor-x86_64

# Build and activate, but keep in boot menu
sudo nixos-rebuild boot --flake .#hypervisor-x86_64

# Test in VM
sudo nixos-rebuild build-vm --flake .#hypervisor-x86_64
./result/bin/run-hypervisor-x86_64-vm
```

### Configuration Profiles

The flake defines multiple configurations in [flake.nix](flake.nix):

- `hypervisor-x86_64` - Full production hypervisor (default)
- `hypervisor-aarch64` - ARM64 version
- Other profiles may be defined in the flake

Check [flake.nix](flake.nix) for all available configurations.

---

## 🔧 Troubleshooting

### Error: "option does not exist"

**Cause**: Building from wrong configuration (likely `/etc/nixos/configuration.nix`)

**Fix**: Use `--flake .#hypervisor-x86_64` flag

```bash
cd /home/hyperd/Documents/Hyper-NixOS
sudo nixos-rebuild build --flake .#hypervisor-x86_64
```

### Error: "Permission denied"

**Cause**: Missing sudo or wrong directory permissions

**Fix**: Run with `sudo` and ensure you're in the repository directory

```bash
cd /home/hyperd/Documents/Hyper-NixOS
sudo nixos-rebuild build --flake .#hypervisor-x86_64
```

### Error: "flake not found"

**Cause**: Not in repository directory or `flake.nix` missing

**Fix**: Ensure you're in the correct directory

```bash
cd /home/hyperd/Documents/Hyper-NixOS
ls -l flake.nix  # Should exist
pwd  # Should be /home/hyperd/Documents/Hyper-NixOS
```

### Error: Building from `/etc/hypervisor/src/`

**Cause**: System has old symlinks or references to `/etc/hypervisor/src/`

**Fix**: Use explicit flake path

```bash
cd /home/hyperd/Documents/Hyper-NixOS
sudo nixos-rebuild build --flake .#hypervisor-x86_64
```

---

## 📚 Understanding Flake-Based NixOS

### Traditional NixOS (without flakes)

```
/etc/nixos/
├── configuration.nix  # Main config (used by default)
└── hardware-configuration.nix

# Rebuild: sudo nixos-rebuild switch
```

### Flake-Based NixOS (Hyper-NixOS)

```
/home/hyperd/Documents/Hyper-NixOS/
├── flake.nix          # Entry point (defines configurations)
├── configuration.nix  # Main config (imported by flake)
├── modules/           # NixOS modules
└── profiles/          # Different configurations

# Rebuild: sudo nixos-rebuild switch --flake .#hypervisor-x86_64
```

### Key Differences

| Aspect | Traditional | Flake-Based (Hyper-NixOS) |
|--------|-------------|---------------------------|
| **Entry Point** | `/etc/nixos/configuration.nix` | `flake.nix` |
| **Rebuild Command** | `sudo nixos-rebuild switch` | `sudo nixos-rebuild switch --flake .#config` |
| **Configuration Location** | `/etc/nixos/` | Anywhere (typically repository) |
| **Reproducibility** | Manual pinning | Automatic via `flake.lock` |
| **Multiple Configs** | Not supported | Multiple configs in one flake |

---

## 🎓 Best Practices

### 1. Always use the flake flag

Never run `nixos-rebuild` without `--flake` on this system.

### 2. Work from the repository

All changes should be made in `/home/hyperd/Documents/Hyper-NixOS/`

### 3. Version control everything

```bash
git add -A
git commit -m "describe your changes"
git push
```

### 4. Test before switching

Use `build` or `dry-build` before `switch`:

```bash
sudo nixos-rebuild dry-build --flake .#hypervisor-x86_64  # Fast syntax check
sudo nixos-rebuild build --flake .#hypervisor-x86_64      # Full build test
sudo nixos-rebuild switch --flake .#hypervisor-x86_64     # Activate
```

### 5. Keep flake.lock updated

```bash
nix flake update  # Update all inputs
nix flake lock --update-input nixpkgs  # Update specific input
```

---

## 📝 File Locations Reference

### Repository (source of truth)

```
/home/hyperd/Documents/Hyper-NixOS/
├── flake.nix                    # Flake entry point
├── flake.lock                   # Locked dependency versions
├── configuration.nix            # Main NixOS configuration
├── modules/                     # Custom NixOS modules
│   ├── core/                   # Core system modules
│   ├── hardware/               # Hardware-specific modules
│   ├── security/               # Security modules
│   ├── features/               # Feature modules
│   └── system/                 # System utilities
├── profiles/                    # Different configuration profiles
├── scripts/                     # Helper scripts
└── docs/                        # Documentation
```

### System Directories

```
/etc/nixos/
├── hardware-configuration.nix   # Auto-generated (DO NOT EDIT)
└── configuration.nix.backup-*   # Backups (optional)

/etc/hypervisor/                 # May exist on some systems
└── flake.nix                    # May be symlink to repository
```

### Build Output

```
/home/hyperd/Documents/Hyper-NixOS/
└── result -> /nix/store/...     # Symlink created by build command
```

---

**Last Updated**: 2025-10-19
**System**: NixOS 25.05
**Build Method**: Flake-based
