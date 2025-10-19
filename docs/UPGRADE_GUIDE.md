# Hyper-NixOS Upgrade Guide

## Overview

Hyper-NixOS is designed with flexibility in mind, allowing easy upgrades to newer NixOS releases while maintaining stability. This guide covers channel management, upgrade procedures, and rollback strategies.

## Channel System

### Current Design

Hyper-NixOS uses a **flexible channel system** that:
- **Defaults to latest stable** (currently NixOS 24.11)
- **Supports easy switching** between channels
- **Allows temporary overrides** for testing
- **Maintains upgrade path** clarity

### Available Channels

| Channel | Description | Update Frequency | Recommended For |
|---------|-------------|------------------|-----------------|
| `nixos-unstable` | Bleeding edge, latest features | Daily/Weekly | Advanced users, testing |
| `nixos-24.11` | Latest stable release | Every 6 months | **Production (Recommended)** |
| `nixos-24.05` | Previous stable | Security updates only | Legacy compatibility |

## Switching Channels

### Method 1: Interactive Channel Switcher (Recommended)

```bash
# Run the interactive channel switcher
./scripts/switch-channel.sh

# Or specify channel directly
./scripts/switch-channel.sh unstable
./scripts/switch-channel.sh 24.11
./scripts/switch-channel.sh 24.05
```

The script will:
1. Show current channel
2. Update `flake.nix`
3. Update `flake.lock`
4. Optionally rebuild system
5. Create backups for safety

### Method 2: Manual Flake Update

```bash
# Edit flake.nix manually
vim flake.nix

# Change this line:
nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

# To your desired channel:
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

# Update flake lock
nix flake update

# Rebuild system
sudo nixos-rebuild switch --flake .
```

### Method 3: Temporary Override (Testing)

Test a different channel without permanent changes:

```bash
# Test unstable without changing flake.nix
sudo nixos-rebuild switch --flake . \
  --override-input nixpkgs github:NixOS/nixpkgs/nixos-unstable

# If it works, make it permanent with switch-channel.sh
```

## Upgrade Procedures

### Standard Upgrade (Same Channel)

```bash
# Update to latest packages on current channel
nix flake update

# Rebuild system
sudo nixos-rebuild switch --flake .
```

### Major Version Upgrade (Channel Change)

```bash
# Example: 24.05 → 24.11
./scripts/switch-channel.sh 24.11

# Script handles:
# 1. Flake update
# 2. Lock file update
# 3. System rebuild (optional)
```

### Pre-Upgrade Checklist

Before upgrading:

- [ ] **Backup important data**
- [ ] **Check release notes** at https://nixos.org/manual/nixos/stable/release-notes.html
- [ ] **Review breaking changes** for your NixOS version
- [ ] **Ensure adequate disk space** (10GB+ recommended)
- [ ] **Test in VM** if possible
- [ ] **Note current generation** for rollback:
      ```bash
      sudo nixos-rebuild list-generations
      ```

### Post-Upgrade Verification

```bash
# Check system version
nixos-version

# Verify services are running
systemctl --failed

# Check logs for errors
journalctl -p err -b

# Test VM operations
virsh list --all

# Verify libvirt
systemctl status libvirtd
```

## Rollback Procedures

### Rollback to Previous Generation

If upgrade causes issues:

```bash
# List available generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or boot into specific generation from GRUB menu
# (Select "NixOS - All configurations" at boot)
```

### Rollback Channel Change

If channel switch was recent:

```bash
# Restore backup flake
cp flake.nix.backup flake.nix

# Update and rebuild
nix flake update
sudo nixos-rebuild switch --flake .
```

### Emergency Recovery

If system won't boot:

1. **Boot from older generation** in GRUB
2. **Boot from installation media**
3. **Mount system and chroot**
4. **Restore working configuration**

## Version Compatibility

### API Changes Between Versions

Hyper-NixOS automatically handles API differences:

#### NixOS 24.05 → 24.11
- `hardware.opengl` → `hardware.graphics`
- `hardware.opengl.driSupport` → `hardware.graphics.enable`
- `hardware.opengl.enable32Bit` → `hardware.graphics.enable32Bit`

#### NixOS 24.11 → 25.05 (Future)
- TBD - will be documented when released

### Compatibility Matrix

| Hyper-NixOS Version | NixOS 24.05 | NixOS 24.11 | NixOS Unstable |
|---------------------|-------------|-------------|----------------|
| 1.0.0+ | ✅ Compatible | ✅ **Recommended** | ✅ Supported |

## Automated Upgrades

### Enable Automatic Updates (Optional)

Add to your configuration:

```nix
{
  # Auto-upgrade to latest packages on current channel
  system.autoUpgrade = {
    enable = true;
    flake = "/etc/hypervisor/src";  # Or your repo path
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
      "--commit-lock-file"
    ];
    dates = "weekly";  # or "daily", "monthly"
  };
}
```

**⚠️ Warning**: Auto-upgrades can occasionally break systems. Recommended only for:
- Development/testing environments
- Users comfortable with rollbacks
- Systems with good backups

## Troubleshooting

### Issue: Build Failures After Channel Switch

```bash
# Clear build cache
sudo nix-collect-garbage -d

# Retry build
sudo nixos-rebuild switch --flake .
```

### Issue: Flake Lock Conflicts

```bash
# Remove lock file and regenerate
rm flake.lock
nix flake update
```

### Issue: Package Not Available in New Channel

```bash
# Check package availability
nix search nixpkgs <package-name>

# Use overlay or different version if needed
```

### Issue: Module Incompatibility

Some modules may not work on older/newer channels:

```bash
# Check module documentation
# Disable incompatible modules temporarily
# Report issue at: https://github.com/MasterofNull/Hyper-NixOS/issues
```

## Best Practices

### For Production Systems
1. **Stay on stable channels** (24.11, 24.05)
2. **Test upgrades in staging** first
3. **Schedule upgrades** during maintenance windows
4. **Monitor after upgrade** for 24-48 hours
5. **Keep 2-3 working generations** minimum

### For Development Systems
1. **Use unstable** for latest features
2. **Update frequently** to catch issues early
3. **Report bugs** upstream to NixOS
4. **Share fixes** with Hyper-NixOS community

### For Learning/Testing
1. **Try different channels** to learn differences
2. **Use VMs** for risky experiments
3. **Document discoveries** for community
4. **Practice rollbacks** to build confidence

## Release Calendar

### NixOS Release Schedule
- **Stable releases**: Every 6 months (May, November)
- **Support duration**: Until next-next release (~12 months)
- **Security updates**: For supported versions only

### Hyper-NixOS Upgrade Strategy
- **Track latest stable** by default
- **Test unstable** proactively
- **Update promptly** when new stable released
- **Maintain compatibility** with stable-1

## Getting Help

### Before Asking
1. Check [COMMON_ISSUES_AND_SOLUTIONS.md](COMMON_ISSUES_AND_SOLUTIONS.md)
2. Review [NixOS Release Notes](https://nixos.org/manual/nixos/stable/release-notes.html)
3. Search [GitHub Issues](https://github.com/MasterofNull/Hyper-NixOS/issues)

### Where to Ask
- **Hyper-NixOS Issues**: Project-specific problems
- **NixOS Discourse**: General NixOS questions
- **NixOS Matrix/IRC**: Real-time help

## Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Pills](https://nixos.org/guides/nix-pills/) - Learn Nix fundamentals
- [NixOS Weekly](https://weekly.nixos.org/) - Stay updated
- [Hyper-NixOS Documentation](https://github.com/MasterofNull/Hyper-NixOS/tree/main/docs)

---

**Last Updated**: 2025-10-19
**Applies To**: Hyper-NixOS 1.0.0+
**Default Channel**: NixOS 24.11 (stable)
