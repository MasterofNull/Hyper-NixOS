# Hyper-NixOS (Hypervisor Suite)

A NixOS-based, security-focused hypervisor with a boot-time VM menu, ISO download + verification, libvirt management, and optional VFIO passthrough.

## Quick start
```bash
nix build .#iso
```
Boot the ISO. On first boot, choose "Setup wizard" to configure networking, download an OS ISO, and create your first VM.

## Features
- Boot-time TUI menu (whiptail)
- ISO manager with auto checksum/signature verification and offline storage
- VM creation wizard and per-VM JSON profiles
- Libvirt XML generation and start (with pinning/hugepages/audio/LookingGlass/hostdev)
- VFIO guided flow + Nix snippet
- Snapshots, backups, bridge helper, hardware detection
- Hardened kernel, non-root qemu, auditd, SSH (keys only)

## Layout
- `configuration/` NixOS config and modules
- `hypervisor_manager/` TUI launcher (Python)
- `scripts/` automation (menu, iso, vfio, snapshots, setup, etc.)
- `vm_profiles/` example VM profiles
- `docs/` guides and warnings

See `/etc/hypervisor/docs` on the running system.
