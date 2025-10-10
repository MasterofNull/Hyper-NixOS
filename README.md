# Hyper-NixOS (Hypervisor Suite)

A NixOS-based, security and performance focused hypervisor with a boot-time VM menu, ISO download + verification, libvirt management, and optional VFIO passthrough.

Quick install (one‑liner):
```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; sudo "$tmp/hyper/scripts/bootstrap_nixos.sh" --hostname "$(hostname -s)" --action switch --source "$tmp/hyper"'
```

## Quick start

- On an existing NixOS host (guided TUI bootstrap):
```bash
sudo nix run .#bootstrap
```

- One‑shot install from a USB/Git folder (no prompts):
```bash
sudo ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$(pwd)"
```

- Optional rebuild helper (scriptable):
```bash
nix run .#rebuild-helper -- --flake /etc/nixos --host $(hostname -s) {build|test|switch}
```

- Build a bootable ISO:
```bash
nix build .#iso
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

See `/etc/hypervisor/docs` on the running system.
