# Hyper-NixOS (Hypervisor Suite)

A NixOS-based, security and performance focused hypervisor with a boot-time VM menu, ISO download + verification, libvirt management, and optional VFIO passthrough.

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

## Features
- Boot-time TUI menu (whiptail)
- ISO manager with auto checksum/signature verification and offline storage
- VM creation wizard and per-VM JSON profiles
- Libvirt XML generation and start (with pinning/hugepages/audio/LookingGlass/hostdev)
- VFIO guided flow + Nix snippet
- Snapshots, backups, bridge helper, hardware detection
- Hardened kernel, non-root qemu, auditd, SSH (keys only)

### Management environment (GUI)
- The hypervisor host does not run a desktop environment. Management is via a console TUI (whiptail/dialog) at boot and on-demand.
- X11/Wayland are disabled (`services.xserver.enable = false`). QEMU uses KMSDRM for host-side output; guests use OVMF (UEFI).

## Configuration layering and carry-over
On first install (bootstrap), the installer copies this repo to `/etc/hypervisor` and writes a host flake at `/etc/nixos/flake.nix`. To make host‑specific changes easy and keep secrets out of the repo, additional optional modules are auto-detected:

- `configuration/users-local.nix` (auto‑generated):
  - Contains carried‑over local user accounts from the base NixOS install, including `extraGroups` and the `hashedPassword` when available.
  - Written to `/etc/hypervisor/configuration/users-local.nix` with `0600` permissions.
  - Edit to add/remove users or change groups/passwords; delete the file to disable carry‑over.

- `configuration/system-local.nix` (auto‑generated):
  - Contains base system settings detected from the initial install, such as `networking.hostName`, `time.timeZone`, `i18n.defaultLocale`, and `console.keyMap`.
  - Written to `/etc/hypervisor/configuration/system-local.nix`.
  - Edit as needed; delete to fall back to defaults in `configuration/configuration.nix`.

Both files are imported conditionally by `configuration/configuration.nix` only if present. They are not part of the Git repository.

### Linux 6.18 highlights supported
- x86 CET virtualization toggles: Shadow Stack (`cpu_features.shstk`), IBT (`cpu_features.ibt` on Intel)
- AMD virtualization: AVIC (`cpu_features.avic`), SEV/SEV-ES/SEV-SNP and related toggles
- Guest memory options groundwork: `memory_options.guest_memfd`, `memory_options.private`
- Multi-arch guests: set `arch` to `x86_64`, `aarch64`, `riscv64`, or `loongarch64`

## Layout
- `configuration/` NixOS config and modules
- `hypervisor_manager/` TUI launcher (Python)
- `scripts/` automation (menu, iso, vfio, snapshots, setup, etc.)
- `vm_profiles/` example VM profiles
- `docs/` guides and warnings
  - See `docs/gui_fallback.md` for enabling an optional GNOME desktop when needed.

See `/etc/hypervisor/docs` on the running system.
