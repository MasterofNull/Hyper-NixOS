# Hyper-NixOS Smart Sync Guide

**Fast development workflow with intelligent file synchronization**

## Overview

The Smart Sync system dramatically speeds up development by only downloading files that have changed, rather than cloning the entire repository every time. This is especially useful when:

- Testing rapid iterations during development
- Validating installations on fresh NixOS systems
- Working with limited bandwidth
- Frequently updating from the repository

## Benefits

✅ **10-50x faster than full git clone** for updates  
✅ **Saves bandwidth** - only downloads changed files  
✅ **File integrity validation** with SHA checksums  
✅ **Automatic fallback** to full clone if needed  
✅ **Perfect for development** - update in seconds, not minutes

## Quick Start

### For Development (Recommended)

Use the all-in-one development update script:

```bash
# Fast update: validate, sync changed files, and rebuild
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh

# Check what would be updated (no changes made)
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh --check-only

# Update from a specific branch
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh --ref develop

# Sync files but don't rebuild (useful for testing)
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh --skip-rebuild
```

### Just Sync Files

If you only want to sync files without rebuilding:

```bash
# Smart sync from main branch
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh

# Sync from specific branch/tag/commit
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh --ref v2.1

# Check what needs updating (no downloads)
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh --check-only

# Verbose output for debugging
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh --verbose
```

### Just Validate Installation

Check your installation health:

```bash
# Quick validation
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh

# Full validation with all checks
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh --verbose

# Attempt to fix common issues automatically
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh --fix
```

## How It Works

### Smart Sync Process

1. **Fetch Remote Tree**: Gets list of all files and their SHA hashes from GitHub API
2. **Calculate Local Hashes**: Computes SHA hashes for your local files
3. **Compare**: Identifies which files are missing, changed, or unchanged
4. **Selective Download**: Only downloads changed/missing files
5. **Verify**: Validates downloaded files match expected checksums
6. **Fallback**: If API fails, falls back to full git clone

### File Comparison

The smart sync uses Git's blob SHA algorithm for comparison:

```
sha1("blob <size>\0<content>")
```

This ensures accurate detection of even small changes while being fast to compute.

## Detailed Usage

### dev_update_hypervisor.sh

The main script for development workflow.

```bash
Usage: dev_update_hypervisor.sh [OPTIONS]

Options:
  --ref BRANCH|TAG|SHA    Update to specific branch/tag/commit (default: main)
  --check-only            Only check for updates, don't download or rebuild
  --skip-rebuild          Download updates but don't rebuild
  --force-full            Force full git clone instead of smart sync
  --rebuild-action ACTION Build action: build|test|switch (default: switch)
  --verbose               Show detailed output
  -h, --help              Show this help
```

**Workflow:**
```
┌──────────────────────────────────────┐
│ 1. Validate Installation             │ ← Checks system health
├──────────────────────────────────────┤
│ 2. Smart Sync from GitHub            │ ← Only downloads changed files!
├──────────────────────────────────────┤
│ 3. Rebuild System (optional)         │ ← Applies updates
└──────────────────────────────────────┘
```

### smart_sync_hypervisor.sh

Lower-level script for just file synchronization.

```bash
Usage: smart_sync_hypervisor.sh [OPTIONS]

Options:
  --ref BRANCH|TAG|SHA    Sync to specific branch/tag/commit (default: main)
  --force-full            Force full download (don't use smart sync)
  --dry-run               Show what would be done without making changes
  --check-only            Only check for changes, don't download
  --skip-validation       Skip checksum validation (faster but less safe)
  --verbose               Show detailed progress
  -h, --help              Show this help
```

### validate_hypervisor_install.sh

Installation validation and health checks.

```bash
Usage: validate_hypervisor_install.sh [OPTIONS]

Options:
  --quick             Quick validation (skip optional checks)
  --fix               Attempt to fix common issues
  --verbose           Show detailed output
  -h, --help          Show this help

Exit codes:
  0 - All checks passed
  1 - Critical failures detected
  2 - Warnings present but no failures
```

**What it checks:**
- Core directories exist
- Critical configuration files present
- Flake configuration valid
- Scripts executable
- User configuration
- Nix features enabled
- Virtualization support
- Network configuration
- Required tools available
- File integrity
- Permissions correct
- Disk space sufficient

## Common Workflows

### Rapid Development Iteration

```bash
# 1. Make changes to your local repo
cd /path/to/your/Hyper-NixOS
git pull origin develop

# 2. Test the changes on your NixOS system
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh \
  --ref develop \
  --rebuild-action test

# 3. If good, switch to make permanent
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh \
  --ref develop \
  --rebuild-action switch
```

### Testing New Features

```bash
# Check what would change
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh \
  --ref feature-branch \
  --check-only

# Download but don't rebuild yet
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh \
  --ref feature-branch \
  --skip-rebuild

# Build without activating
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh \
  --ref feature-branch \
  --rebuild-action build
```

### Fresh NixOS Validation

After installing on a fresh NixOS system:

```bash
# 1. Validate the installation
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh --fix

# 2. Sync to latest
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh

# 3. Verify everything works
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh --verbose
```

### Bandwidth-Constrained Updates

```bash
# Check what needs updating first
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh --check-only

# Only sync files, no rebuild (saves more bandwidth)
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh

# Rebuild later when you're ready
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

## Performance Comparison

### Traditional Full Clone
```
Time: 2-5 minutes (depending on connection)
Bandwidth: ~50-100 MB (entire repository)
Steps: git clone → copy files → rebuild
```

### Smart Sync
```
Time: 5-30 seconds (for typical updates)
Bandwidth: 100KB - 10MB (only changed files)
Steps: compare hashes → download changed → rebuild
```

**Real-world example:**
- Full clone: 3 minutes, 75 MB
- Smart sync (10 files changed): 15 seconds, 2.3 MB
- **Speedup: 12x faster, 97% less bandwidth**

## Troubleshooting

### Rate Limits

GitHub API has rate limits (60 requests/hour unauthenticated, 5000/hour authenticated).

**Solution**: Set GitHub token for higher limits:

```bash
# Create token at https://github.com/settings/tokens
# Save it securely
echo "your_token_here" > ~/.config/github/token
chmod 600 ~/.config/github/token

# Or set environment variable
export GITHUB_TOKEN="your_token_here"
```

### Smart Sync Fails

If smart sync fails, it automatically falls back to full clone:

```bash
# Or force full clone manually
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh --force-full
```

### Checksum Mismatches

If you get SHA mismatch errors:

```bash
# Force full clone to reset everything
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh --force-full

# Or skip validation (use with caution)
sudo bash /etc/hypervisor/scripts/smart_sync_hypervisor.sh --skip-validation
```

### Files Not Executable

If scripts aren't executable after sync:

```bash
# Fix permissions
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh --fix

# Or manually
sudo find /etc/hypervisor/src/scripts -type f -name "*.sh" -exec chmod +x {} \;
```

## Advanced Usage

### Custom GitHub Repository

Edit the script to use your fork:

```bash
# Edit smart_sync_hypervisor.sh
sudo nano /etc/hypervisor/scripts/smart_sync_hypervisor.sh

# Change these lines:
GITHUB_REPO="YourUsername/Hyper-NixOS"
DEFAULT_BRANCH="your-branch"
```

### Sync State Tracking

Smart sync saves state to `/var/lib/hypervisor/cache/sync-state.json`:

```bash
# View last sync info
cat /var/lib/hypervisor/cache/sync-state.json | jq .

# Example output:
{
  "last_sync": {
    "commit_sha": "abc123...",
    "ref": "main",
    "timestamp": "2025-10-12T10:30:00Z"
  },
  "stats": {
    "checked": 150,
    "changed": 5,
    "downloaded": 5,
    "errors": 0
  }
}
```

### Integration with CI/CD

```bash
#!/bin/bash
# deploy.sh - Automated deployment script

set -e

# Validate before update
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh || exit 1

# Update to latest
sudo bash /etc/hypervisor/scripts/dev_update_hypervisor.sh \
  --ref main \
  --rebuild-action switch

# Validate after update
sudo bash /etc/hypervisor/scripts/validate_hypervisor_install.sh --verbose

echo "Deployment complete!"
```

## See Also

- [Troubleshooting Guide](TROUBLESHOOTING.md) - General troubleshooting
- [Quick Reference](QUICK_REFERENCE.md) - Command quick reference
- [Development Guide](../README.md#development) - Contributing to Hyper-NixOS

---

**Questions or issues?** Open an issue on [GitHub](https://github.com/MasterofNull/Hyper-NixOS/issues)
