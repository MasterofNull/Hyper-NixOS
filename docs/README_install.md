# Hypervisor Suite - Quick Install

### Fresh NixOS host (recommended bootstrap)

Run the guided bootstrap (TUI). This copies files to `/etc/hypervisor`, writes `/etc/nixos/flake.nix`, and lets you dry-run, test, or switch safely.

```
nix run .#bootstrap
```

If you prefer non-interactive:

```
nix run .#rebuild-helper -- --flake /etc/nixos --host $(hostname -s) build
nix run .#rebuild-helper -- --flake /etc/nixos --host $(hostname -s) test
nix run .#rebuild-helper -- --flake /etc/nixos --host $(hostname -s) switch
```

### USB or Git checkout one-shot install

- From USB (folder contains this repository):

```
sudo ./scripts/bootstrap_nixos.sh --hostname $(hostname -s) --force --source $(pwd)
```

- From GitHub checkout:

```
git clone https://github.com/<your-org>/<your-repo>.git hypervisor
cd hypervisor
sudo ./scripts/bootstrap_nixos.sh --hostname $(hostname -s) --force --source $(pwd)
```

**Note:** By default, the bootstrapper will:
1. Copy source files to `/etc/hypervisor/src`
2. **Prompt**: "Check for and download updates from GitHub before installation?"
   - If **Yes**: Runs `dev_update_hypervisor.sh` to sync latest files
   - If **No**: Continues with current source files
   - Automatically skips if no network detected
3. **Automatically detect and migrate all base system settings:**
   - **Users**: Detects users with UID ≥ 1000, preserves password hashes, groups, home directories
   - **Locale**: Timezone, locale, console keymap, console font
   - **Keyboard**: X11/Wayland keyboard layout, variant, and options
   - **System**: State version (for compatibility), hostname
   - **Boot**: Swap devices, resume device for hibernation
   - No manual input required - all settings detected automatically
4. Test the configuration first (safe dry-run)
5. Automatically proceed with the full system switch

This ensures a safe, automated installation with the latest version while preserving your existing user accounts.

Flags:
- `--hostname NAME`: attribute and system hostname
- `--action {build|test|switch}`: override default behavior (if omitted, performs test then switch)
- `--force`: overwrite existing `/etc/hypervisor` without a prompt
- `--source PATH`: explicit source (defaults to auto-detected repo root)
- `--fast`: enable optimized parallel downloads (recommended)
- `--skip-update-check`: skip checking for updates from GitHub (offline mode)
- `--reboot`: automatically reboot after successful installation

### Build bootable ISO

```
nix build .#iso
```

Boot it (USB/IPMI). The first-boot service starts the setup wizard automatically.

## Notes
- Logging is in /var/log/hypervisor.
- Advanced features (VFIO, pinning, hugepages) are toggled per-VM JSON.
- Linux 6.18 toggles: in a VM profile you can set `cpu_features.shstk`, `cpu_features.ibt`, `cpu_features.avic`, `cpu_features.sev`/`sev_es`/`sev_snp`, and `memory_options.guest_memfd`/`private` where supported by the host.
- Multi-arch: set `arch` to `x86_64`, `aarch64`, `riscv64`, or `loongarch64` to choose the QEMU machine/firmware. On non‑x86, UEFI firmware may be optional.
 - Scripts are hardened (set -Eeuo pipefail, safe PATH, umask 077). Environment variables are sanitized where relevant.

## Where configurations live
- Repo is installed at `/etc/hypervisor`. Host flake is `/etc/nixos/flake.nix`.
- On bootstrap, the installer will auto-generate these optional modules if absent:
  - `/etc/hypervisor/configuration/users-local.nix` (0600): carries over local users (including password hashes when available) and ensures access groups like `kvm`, `libvirtd`, `video`, `wheel`.
  - `/etc/hypervisor/configuration/system-local.nix`: carries over base settings like `networking.hostName`, `time.timeZone`, `i18n.defaultLocale`, `console.keyMap`.
- Both modules are imported conditionally by `configuration/configuration.nix`.

## GUI environment on the hypervisor
- There is no desktop session. The management UI is a console TUI (whiptail/dialog) invoked at boot by a systemd service.
- `services.xserver.enable = false` on the host. Guests use OVMF (UEFI) and QEMU; host output uses KMS/DRM.

## Boot menu behavior
## Troubleshooting: NAR hash mismatch / cache issues
If you hit a NAR hash mismatch or similar cache error during `nixos-rebuild`, try the following:

1. Ensure time is sane (NixOS blocks timedatectl; use an NTP tool temporarily):
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nix run nixpkgs#chrony -c sudo chronyc -a makestep
```

2. Clear local narinfo/tarball caches and garbage-collect:
```bash
sudo rm -rf /root/.cache/nix ~/.cache/nix 2>/dev/null || true
sudo nix-collect-garbage -d
sudo nix store gc
```

3. Verify and repair the store:
```bash
sudo nix-store --verify --check-contents --repair
```

4. Rebuild with fresh fetch and zeroed TTLs:
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake "/etc/nixos#$(hostname -s)" \
  --refresh --option tarball-ttl 0 \
  --option narinfo-cache-positive-ttl 0 \
  --option narinfo-cache-negative-ttl 0
```

5. If still failing, restrict to the official cache:
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake "/etc/nixos#$(hostname -s)" --refresh \
  --option substituters "https://cache.nixos.org" \
  --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
```

6. Last resort: disable substituters (build locally):
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake "/etc/nixos#$(hostname -s)" --option substituters ""
```

Tip: The bootstrapper script already adds `--refresh` and zero TTLs to rebuilds to avoid stale cache issues on first install.
- The boot-time menu is two-tiered:
  - Main menu lists installed VMs, plus "Start GNOME management session (fallback GUI)" and "More Options".
  - More Options contains setup, ISO manager, VFIO tools, preflight, migration, and maintenance actions.
- Autostart: before the menu, the last-run VM will auto-start after a countdown. Configure seconds via `/etc/hypervisor/config.json` at `features.autostart_timeout_sec` (set `0` to disable).
