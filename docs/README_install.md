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

### Build bootable ISO

```
nix build .#iso
```

Boot it (USB/IPMI). The first-boot service starts the setup wizard automatically.

## Notes
- Logging is in /var/log/hypervisor.
- Advanced features (VFIO, pinning, hugepages) are toggled per-VM JSON.
 - Scripts are hardened (set -Eeuo pipefail, safe PATH, umask 077). Environment variables are sanitized where relevant.
