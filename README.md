# Hyper-NixOS (Hypervisor Suite)

A NixOS-based, security and performance focused hypervisor with a boot-time VM menu, ISO download + verification, libvirt management, and optional VFIO passthrough.

Enable flakes on fresh NixOS (first time only):
```bash
sudo bash -lc 'set -euo pipefail; if ! nixos-rebuild --help 2>&1 | grep -q -- --flake; then tmp=/tmp/enable-flakes.nix; printf "%s\n" "{ config, pkgs, lib, ... }:" "{" "  imports = [ /etc/nixos/configuration.nix ];" "  nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];" "  nix.package = pkgs.nixVersions.stable;" "}" > "$tmp"; nixos-rebuild switch -I nixos-config="$tmp"; fi'
```

Quick install (one‑liner):
```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; rev=$(git rev-parse HEAD); sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$tmp/hyper"'
```

## Quick start

- On an existing NixOS host (guided TUI bootstrap):
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" nix run .#bootstrap
```

- One‑shot install from a USB/Git folder (no prompts):
```bash
sudo ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$(pwd)"
```

- Optional rebuild helper (scriptable):
```bash
env NIX_CONFIG="experimental-features = nix-command flakes" nix run .#rebuild-helper -- --flake /etc/nixos --host $(hostname -s) {build|test|switch}
```

- Build a bootable ISO:
```bash
env NIX_CONFIG="experimental-features = nix-command flakes" nix build .#iso
```
Boot the ISO. On first boot, the setup wizard runs once to help with networking, ISO download/verification, and creating your first VM.

## Install
- One‑liner (downloads and runs bootstrap installer): see above.
- From a cloned repo (guided TUI):
```bash
sudo nix run .#bootstrap
```
- From a cloned repo (one‑shot):
```bash
sudo ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$(pwd)"
```
- Build a bootable ISO:
```bash
nix build .#iso
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

See `/etc/hypervisor/docs` on the running system.
