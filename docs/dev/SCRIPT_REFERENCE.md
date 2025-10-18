# Hyper-NixOS Script Reference

Complete reference documentation for all Hyper-NixOS management scripts.

---

## Table of Contents

- [System Installer](#system-installer)
- [Development Update](#development-update)
- [Smart Sync](#smart-sync)
- [Rebuild Helper](#rebuild-helper)
- [Validation Script](#validation-script)

---

## System Installer

**Script:** `scripts/system_installer.sh`  
**Flake app:** `nix run .#system-installer`  
**Purpose:** Install Hyper-NixOS on an existing NixOS system with hardware detection, user migration, and safe system configuration.

### Synopsis

```bash
sudo ./scripts/system_installer.sh [OPTIONS]
sudo nix run .#system-installer -- [OPTIONS]
```

### Options

| Option | Argument | Default | Description |
|--------|----------|---------|-------------|
| `--hostname` | `NAME` | Current hostname | Set the system hostname and NixOS configuration attribute |
| `--action` | `build\|test\|switch` | Interactive prompt | Installation action:<br>• `build` - Build configuration without activating<br>• `test` - Temporary activation (reverts on reboot)<br>• `switch` - Full persistent installation |
| `--force` | - | Enabled | Overwrite existing `/etc/hypervisor/src` without prompting |
| `--source` | `PATH` | Auto-detect | Source directory containing Hyper-NixOS files |
| `--reboot` | - | Disabled | Automatically reboot after successful `switch` |
| `--fast` | - | Disabled | Enable optimized parallel downloads (recommended) |
| `--skip-update-check` | - | Disabled | Skip checking for updates from GitHub (offline mode) |
| `-h, --help` | - | - | Display help information |

### What It Does

The system installer performs a comprehensive, safe installation process:

1. **Hostname Configuration**
   - Prompts to keep current hostname or enter custom name
   - Uses hostname for NixOS configuration attribute

2. **Source File Management**
   - Copies repository to `/etc/hypervisor/src`
   - Creates `/etc/nixos/flake.nix` symlink to `/etc/hypervisor/src/flake.nix`
   - Preserves existing configurations with backup

3. **Update Check** (unless `--skip-update-check`)
   - Prompts to check for updates from GitHub
   - Uses smart sync to download only changed files
   - Falls back to full clone if needed

4. **Hardware Detection**
   - Generates or preserves `/etc/nixos/hardware-configuration.nix`
   - Detects CPU, GPU, storage, and network hardware
   - Configures kernel modules and drivers

5. **User Migration**
   - **Auto-detects invoking user** (the user who ran `sudo`)
   - Identifies all users with UID ≥ 1000
   - **Highlights current user** in selection dialog
   - Preserves password hashes, groups, home directories
   - Adds users to required groups: `wheel`, `kvm`, `libvirtd`, `video`, `input`
   - Interactive selection for multiple users (TUI)
   - Generates `/etc/hypervisor/configuration/users-local.nix`

6. **System Settings Migration**
   - Timezone and locale settings
   - Console keymap and font
   - System state version
   - Swap and hibernation configuration
   - Generates `/etc/hypervisor/configuration/system-local.nix`

7. **Safe Installation**
   - Interactive TUI menu for action selection
   - Options: Build, Test, Switch, Shell, Quit
   - Full control over installation process

### Examples

**Basic installation with fast mode (recommended):**
```bash
sudo nix run .#system-installer -- --fast
```

**One-liner quick install:**
```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/system_installer.sh --fast --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
```

**Custom hostname with test run:**
```bash
sudo ./scripts/system_installer.sh --hostname my-hypervisor --action test --fast
```

**Offline installation from USB:**
```bash
sudo ./scripts/system_installer.sh --skip-update-check --force --source /mnt/usb/hyper-nixos
```

**Automated installation for scripting:**
```bash
sudo ./scripts/system_installer.sh \
  --hostname hypervisor01 \
  --action switch \
  --force \
  --fast \
  --skip-update-check \
  --reboot
```

### Performance

**Standard Installation:**
- Time: ~30-45 minutes
- Download: ~2GB
- Parallel downloads: 5 connections

**Fast Mode (--fast):**
- Time: ~15 minutes
- Download: ~2GB
- Parallel downloads: 25 connections
- Maximum CPU parallelism
- Optimized binary cache settings

### Security Notes

- Users require passwords for system administration
- Passwordless sudo is restricted to VM operations only
- Password hashes are preserved during migration
- All scripts run with hardened settings (`set -Eeuo pipefail`)
- Temporary files use secure permissions (umask 077)

---

## Development Update

**Script:** `scripts/dev_update_hypervisor.sh`  
**Purpose:** Fast development workflow for updating an existing Hyper-NixOS installation from GitHub.

### Synopsis

```bash
sudo ./scripts/dev_update_hypervisor.sh [OPTIONS]
```

### Options

| Option | Argument | Default | Description |
|--------|----------|---------|-------------|
| `--ref` | `BRANCH\|TAG\|SHA` | `main` | Update to specific branch, tag, or commit |
| `--check-only` | - | Disabled | Only check for updates, don't download or rebuild |
| `--skip-rebuild` | - | Disabled | Download updates but don't rebuild system |
| `--force-full` | - | Disabled | Force full git clone instead of smart sync |
| `--rebuild-action` | `build\|test\|switch` | `switch` | Build action after sync |
| `--verbose` | - | Disabled | Show detailed output |
| `-h, --help` | - | - | Display help information |

### What It Does

Combines validation, smart sync, and rebuild into one command:

1. **Validates** current installation health
2. **Smart syncs** only changed files from GitHub (10-50x faster)
3. **Rebuilds** system with updates (optional)

### Examples

**Standard development update:**
```bash
sudo ./scripts/dev_update_hypervisor.sh
```

**Check what needs updating:**
```bash
sudo ./scripts/dev_update_hypervisor.sh --check-only
```

**Update from development branch:**
```bash
sudo ./scripts/dev_update_hypervisor.sh --ref develop
```

**Just sync files, no rebuild:**
```bash
sudo ./scripts/dev_update_hypervisor.sh --skip-rebuild
```

**Test new changes without switching:**
```bash
sudo ./scripts/dev_update_hypervisor.sh --rebuild-action test
```

### Performance

- **Smart Sync:** Only downloads changed files
- **Speed:** 10-50x faster than full git clone
- **Bandwidth:** Minimal (only changed files)
- **Perfect for:** Rapid development iterations

---

## Smart Sync

**Script:** `scripts/smart_sync_hypervisor.sh`  
**Purpose:** Intelligently sync files from GitHub by downloading only what changed.

### Synopsis

```bash
sudo ./scripts/smart_sync_hypervisor.sh [OPTIONS]
```

### Options

| Option | Argument | Default | Description |
|--------|----------|---------|-------------|
| `--ref` | `BRANCH\|TAG\|SHA` | `main` | Sync to specific branch, tag, or commit |
| `--force-full` | - | Disabled | Force full download (don't use smart sync) |
| `--dry-run` | - | Disabled | Show what would be done without making changes |
| `--check-only` | - | Disabled | Only check for changes, don't download |
| `--skip-validation` | - | Disabled | Skip checksum validation (faster but less safe) |
| `--verbose` | - | Disabled | Show detailed progress |
| `-h, --help` | - | - | Display help information |

### What It Does

1. **Resolves** the specified ref to a commit SHA
2. **Fetches** remote file tree from GitHub API
3. **Compares** local files with remote using SHA1 hashes
4. **Downloads** only changed or missing files
5. **Validates** file integrity with checksums
6. **Falls back** to full clone if needed

### How It Works

Smart sync uses the GitHub API to compare local and remote files:

- Calculates Git blob SHA1 for local files: `sha1("blob <size>\0<content>")`
- Fetches file tree from GitHub API recursively
- Compares SHA1 hashes to identify changes
- Downloads only changed files from raw GitHub
- Validates downloads match expected SHA1

This approach is 10-50x faster than full git clone for updates.

### Examples

**Smart sync from main branch:**
```bash
sudo ./scripts/smart_sync_hypervisor.sh
```

**Sync to specific version:**
```bash
sudo ./scripts/smart_sync_hypervisor.sh --ref v2.1
```

**Check what needs updating:**
```bash
sudo ./scripts/smart_sync_hypervisor.sh --check-only
```

**Preview changes:**
```bash
sudo ./scripts/smart_sync_hypervisor.sh --dry-run --verbose
```

**Fast sync (skip validation):**
```bash
sudo ./scripts/smart_sync_hypervisor.sh --skip-validation
```

**Force full clone:**
```bash
sudo ./scripts/smart_sync_hypervisor.sh --force-full
```

### Performance Benefits

| Scenario | Full Clone | Smart Sync | Speedup |
|----------|-----------|------------|---------|
| Initial install | ~2-3 min | ~2-3 min | 1x (same) |
| Small update (5 files) | ~2-3 min | ~5-10 sec | 20-30x |
| Medium update (50 files) | ~2-3 min | ~30-60 sec | 3-6x |
| Large update (500 files) | ~2-3 min | ~2-3 min | 1x (same) |

### File Exclusions

The following paths are automatically excluded (matching system installer behavior):

- `.git/` - Git metadata
- `result/` - Nix build results
- `target/` - Build artifacts
- `tools/target/` - Tool build artifacts
- `var/` - Variable data
- `*.socket` - Unix sockets

### Requirements

Smart sync requires:

- `curl` - HTTP client for GitHub API
- `jq` - JSON processor for API responses (auto-installs if missing)
- Network access to GitHub
- `/etc/hypervisor/src` directory (created on first run)

### GitHub API

- **Rate limit:** 60 requests/hour (unauthenticated)
- **Rate limit:** 5,000 requests/hour (with token)
- **Set token:** `export GITHUB_TOKEN=your_token` or save to `~/.config/github/token`

---

## Rebuild Helper

**Script:** `scripts/rebuild_helper.sh`  
**Flake app:** `nix run .#rebuild-helper`  
**Purpose:** Wrapper around `nixos-rebuild` with flake support and safety checks.

### Synopsis

```bash
sudo ./scripts/rebuild_helper.sh [OPTIONS] ACTION
sudo nix run .#rebuild-helper -- [OPTIONS] ACTION
```

### Actions

- `build` - Build system configuration without activating
- `test` - Test activation (temporary, reverts on reboot)
- `switch` - Full system switch (persistent)
- `boot` - Set configuration as next boot default
- `dry-build` - Show what would be built
- `dry-activate` - Show what would be activated

### Options

| Option | Argument | Default | Description |
|--------|----------|---------|-------------|
| `--flake` | `PATH` | `/etc/nixos` | Path to flake directory |
| `--host` | `NAME` | Current hostname | NixOS configuration attribute |
| `--show-trace` | - | Disabled | Show detailed Nix evaluation trace |
| `--impure` | - | Enabled | Allow impure evaluation (recommended) |
| `-h, --help` | - | - | Display help information |

### Examples

**Build configuration:**
```bash
sudo ./scripts/rebuild_helper.sh build
```

**Test new configuration:**
```bash
sudo ./scripts/rebuild_helper.sh --show-trace test
```

**Switch to new configuration:**
```bash
sudo ./scripts/rebuild_helper.sh switch
```

**Build for different host:**
```bash
sudo ./scripts/rebuild_helper.sh --host hypervisor02 build
```

---

## Validation Script

**Script:** `scripts/validate_hypervisor_install.sh`  
**Purpose:** Validate Hyper-NixOS installation health and configuration.

### Synopsis

```bash
sudo ./scripts/validate_hypervisor_install.sh [OPTIONS]
```

### Options

| Option | Argument | Default | Description |
|--------|----------|---------|-------------|
| `--quick` | - | Disabled | Quick validation (essential checks only) |
| `--fix` | - | Disabled | Attempt to fix common issues |
| `--verbose` | - | Disabled | Show detailed validation output |
| `-h, --help` | - | - | Display help information |

### What It Checks

1. **Core Directories**
   - `/etc/hypervisor` existence and permissions
   - `/etc/hypervisor/src` source files
   - `/etc/nixos/flake.nix` symlink

2. **Configuration Files**
   - `flake.nix` syntax and structure
   - `configuration.nix` imports
   - `hardware-configuration.nix` presence

3. **System Services**
   - Essential services running
   - LibVirt daemon status
   - Network connectivity

4. **Security**
   - File permissions
   - User group memberships
   - Sudo configuration

5. **Resources**
   - Disk space
   - Memory availability
   - CPU virtualization support

### Examples

**Full validation:**
```bash
sudo ./scripts/validate_hypervisor_install.sh
```

**Quick validation:**
```bash
sudo ./scripts/validate_hypervisor_install.sh --quick
```

**Validate and fix issues:**
```bash
sudo ./scripts/validate_hypervisor_install.sh --fix
```

---

## Environment Variables

### Common Variables

- `NIX_CONFIG` - Set to `"experimental-features = nix-command flakes"` for flake support
- `GITHUB_TOKEN` - GitHub API token for increased rate limits (smart sync)
- `PATH` - Automatically set to include system and Nix profile binaries

### Setting GitHub Token

For increased API rate limits (5,000 req/hour vs 60 req/hour):

```bash
# Temporary (current session)
export GITHUB_TOKEN=your_github_token

# Persistent (all sessions)
mkdir -p ~/.config/github
echo "your_github_token" > ~/.config/github/token
chmod 600 ~/.config/github/token
```

---

## Exit Codes

All scripts use consistent exit codes:

- `0` - Success
- `1` - General error
- `2` - Missing dependency
- `3` - Permission denied
- `4` - Invalid arguments
- `5` - Network error
- `6` - Configuration error

---

## Logging

All scripts log to standard output with consistent prefixes:

- `[system-installer]` - System installer messages
- `[dev-update]` - Development update messages
- `[smart-sync]` - Smart sync messages
- `[smart-sync ERROR]` - Smart sync errors
- `[validator]` - Validation messages

Detailed logs are also written to:
- `/var/log/hypervisor/` - System-wide logs
- `/var/log/nixos/` - NixOS rebuild logs

---

## Safety Features

All scripts include:

1. **Strict Error Handling**
   - `set -Eeuo pipefail` - Fail on any error
   - Trap cleanup on exit
   - Proper signal handling

2. **Secure Operations**
   - `umask 077` - Restrictive file permissions
   - Safe `PATH` - Only trusted directories
   - Input validation and sanitization

3. **User Control**
   - Interactive confirmations
   - Dry-run options
   - Verbose output modes
   - Help documentation

4. **Backup & Recovery**
   - Automatic backups before overwrite
   - State file tracking
   - Rollback support (NixOS generations)

---

## Troubleshooting

### Common Issues

**Issue:** Permission denied  
**Solution:** Run scripts with `sudo`

**Issue:** Missing `jq` command  
**Solution:** Smart sync auto-installs, or run: `nix profile install nixpkgs#jq`

**Issue:** GitHub API rate limit  
**Solution:** Set `GITHUB_TOKEN` environment variable

**Issue:** Network timeout  
**Solution:** Use `--skip-update-check` for offline mode

**Issue:** Flake not found  
**Solution:** Ensure running from repository directory or use `--source PATH`

**Issue:** Build fails  
**Solution:** Run with `--show-trace` for detailed error information

### Getting Help

- Check script help: `./script.sh --help`
- View logs: `journalctl -xe`
- Validate installation: `sudo ./scripts/validate_hypervisor_install.sh`
- See documentation: `/etc/hypervisor/docs/`

---

## See Also

- [README.md](../README.md) - Main documentation
- [QUICK_START_SMART_SYNC.md](QUICK_START_SMART_SYNC.md) - Smart sync guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting guide
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Testing documentation
- [ORGANIZATION.md](ORGANIZATION.md) - Repository structure

---

**Last Updated:** 2025-10-13  
**Version:** 2.0.0
