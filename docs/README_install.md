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
sudo ./scripts/bootstrap_nixos.sh --hostname $(hostname -s) --action switch --force --source $(pwd)
```

- From GitHub checkout:

```
git clone https://github.com/<your-org>/<your-repo>.git hypervisor
cd hypervisor
sudo ./scripts/bootstrap_nixos.sh --hostname $(hostname -s) --action switch --force --source $(pwd)
```

Flags:
- `--hostname NAME`: attribute and system hostname
- `--action {build|test|switch}`: choose dry-run, temporary activation, or full switch
- `--force`: overwrite existing `/etc/hypervisor` without a prompt
- `--source PATH`: explicit source (defaults to auto-detected repo root)

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
