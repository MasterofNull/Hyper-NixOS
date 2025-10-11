# Hyper-NixOS (Hypervisor Suite)

A NixOS-based, security and performance focused hypervisor with a boot-time VM menu, ISO download + verification, libvirt management, and optional VFIO passthrough.

---

## 🚀 Installation (Choose ONE method)

### Method 1: One-Liner Install (Recommended - Works anywhere)

**Perfect for:** Fresh installs, automated deployments, USB boots

This single command downloads the repo, installs the system, and reboots:
```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
```

**What it does:**
- ✅ Installs git if needed
- ✅ Clones the repository  
- ✅ Runs bootstrap installer
- ✅ Migrates your existing users/settings
- ✅ Switches to new system
- ✅ Reboots automatically

**That's it!** After reboot, you'll see the hypervisor menu. Skip to [After Installation](#after-installation).

---

### Method 2: Manual Install (If you already have the repo)

**Perfect for:** Development, testing, customization

#### Step 1: Enable flakes (Skip if already enabled)

Check if you need this:
```bash
nixos-rebuild --help 2>&1 | grep -q -- --flake && echo "Flakes already enabled ✓" || echo "Need to enable flakes"
```

If needed, enable flakes:
```bash
sudo bash -lc 'set -euo pipefail; if ! nixos-rebuild --help 2>&1 | grep -q -- --flake; then tmp=/tmp/enable-flakes.nix; printf "%s\n" "{ config, pkgs, lib, ... }:" "{" "  imports = [ /etc/nixos/configuration.nix ];" "  nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];" "  nix.package = pkgs.nixVersions.stable;" "}" > "$tmp"; nixos-rebuild switch -I nixos-config="$tmp"; fi'
```

#### Step 2: Run bootstrap

**Option A - Guided install with prompts:**
```bash
cd /path/to/Hyper-NixOS
sudo nix run .#bootstrap
```

**Option B - Unattended install:**
```bash
cd /path/to/Hyper-NixOS
sudo ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$(pwd)" --reboot
```

**What bootstrap does:**
- ✅ Copies configuration to `/etc/hypervisor/src`
- ✅ Creates `/etc/hypervisor/flake.nix` 
- ✅ Generates `users-local.nix` with your current users (including sudo access)
- ✅ Generates `system-local.nix` with your timezone/locale
- ✅ Runs `nixos-rebuild switch` to activate the new system
- ✅ Optionally reboots

---

### Method 3: Build Bootable ISO

**Perfect for:** Creating installation media, bare metal deployments

```bash
cd /path/to/Hyper-NixOS
nix build .#iso
# ISO will be in ./result/iso/
```

Boot from the ISO. On first boot, a setup wizard helps you configure networking and create your first VM.

---

## After Installation

After reboot, you'll see the hypervisor boot menu with options to:
- 🖥️ **Start VMs** - Launch your virtual machines
- 📦 **Download ISOs** - Get OS installation images  
- ⚙️ **Create VMs** - Set up new virtual machines
- 🔧 **System Tools** - Diagnostics, updates, backups
- 🪟 **GNOME Desktop** - Graphical fallback environment

**Next steps:** See [Quick Start Guide](docs/QUICKSTART_EXPANDED.md) to create your first VM.

---

## Quick Reference

### Update the system
```bash
sudo bash /etc/hypervisor/scripts/update_hypervisor.sh
```

### Rebuild after config changes
```bash
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

### Rebuild helper (alternative)
```bash
nix run .#rebuild-helper -- --flake /etc/hypervisor --host $(hostname -s) {build|test|switch}
```


## System features
- Boot-time TUI menu (multi-tier): VM list, GNOME fallback, and More Options
- Autostart last VM with configurable timeout (`/etc/hypervisor/config.json`)
- ISO manager with checksum/signature verification
- VM creation wizard and per-VM JSON profiles
- Libvirt XML generation and start (pinning/hugepages/audio/LookingGlass/hostdev)
- Optional GNOME fallback desktop (`configuration/gui-local.nix`)
- VFIO guided flow + Nix snippet, bridge helper, snapshots/backups
- Hardened kernel, non-root QEMU, auditd, SSH (keys only)

## Documentation
- Install and host details: `docs/README_install.md`
- Optional GNOME fallback: `docs/gui_fallback.md`
- Advanced options and feature toggles: `docs/advanced_features.md`
- Updating to latest or a specific ref: use the menu option “Update Hypervisor (pin to latest)” or run:
```bash
sudo bash /etc/hypervisor/scripts/update_hypervisor.sh [--ref <commit|branch|tag>]
```

When you finish configuring and validating the system, you can optionally harden permissions on `/etc/hypervisor`:
```bash
sudo bash /etc/hypervisor/scripts/harden_permissions.sh
```

If you need to update or prune old generations later, temporarily relax permissions, perform the maintenance, then harden again:
```bash
sudo bash /etc/hypervisor/scripts/relax_permissions.sh
# ... perform updates, GC, or generation cleanup ...
sudo bash /etc/hypervisor/scripts/harden_permissions.sh
```

Troubleshooting (optional)
- Force a fresh fetch on rebuild (if you hit cache/NAR issues):
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --impure --flake "/etc/hypervisor#$(hostname -s)" \
  --refresh --option tarball-ttl 0 \
  --option narinfo-cache-positive-ttl 0 \
  --option narinfo-cache-negative-ttl 0
```

See `/etc/hypervisor/docs` on the running system.
