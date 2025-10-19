# Hyper-NixOS Upgrade Management

## Overview

Hyper-NixOS includes a comprehensive update management system that:

1. **Automatically checks** for NixOS updates monthly
2. **Notifies administrators** when updates are available
3. **Provides safe testing** before permanent upgrades
4. **Ensures compatibility** with system configuration

## Update Check System

### Automatic Monthly Checks

The system automatically checks for NixOS updates on the first of each month. When updates are available:

- An entry is added to `/etc/motd.d/updates-available` (shown on login)
- Details are saved to `/var/lib/hypervisor/update-available`
- A broadcast notification is sent to logged-in administrators

### Manual Update Check

Check for updates immediately:

```bash
sudo hv-check-updates
```

This command:
- Queries the NixOS package repository
- Compares available versions with your current system
- Creates notifications if updates are found
- Shows the log of the check operation

## Safe Upgrade Workflow

### Step 1: Check for Updates

```bash
sudo hv-check-updates
```

Or wait for the automatic monthly check.

### Step 2: Test the Upgrade

**IMPORTANT**: Always test upgrades before applying them permanently.

```bash
sudo hv-upgrade-test
```

This command:
- Downloads and builds the new configuration
- Activates the upgrade temporarily
- Tests that services start correctly
- **Does NOT persist** across reboots
- Saves test results to `/var/lib/hypervisor/upgrade-test-result`

### Step 3: Verify System Functionality

While the test upgrade is active:

1. Check critical services:
   ```bash
   systemctl status libvirtd
   systemctl status hypervisor-menu
   hv system-status
   ```

2. Verify VMs still work:
   ```bash
   virsh list --all
   hv vm-list
   ```

3. Test any custom configurations

4. Review logs:
   ```bash
   journalctl -xe
   cat /var/lib/hypervisor/upgrade-test-result
   ```

### Step 4: Apply Permanent Upgrade

If testing was successful:

```bash
sudo hv-system-upgrade
```

This command:
- Checks that testing passed
- Applies the upgrade permanently
- Updates the system generation
- Persists across reboots

## Handling Failed Upgrades

### If Testing Fails

When `hv-upgrade-test` fails, the system:

1. **Remains on the current version** (your system is safe)
2. Saves error details to `/var/lib/hypervisor/upgrade-test-result`
3. Provides troubleshooting guidance

Common issues and fixes:

#### Configuration Conflicts

**Symptom**: Errors about deprecated options or conflicting settings

**Fix**:
1. Review `Hyper-NixOS/configuration.nix` in your repository
2. Check for deprecated options in the error message
3. Update or remove conflicting settings
4. Consult NixOS release notes: https://nixos.org/manual/nixos/stable/release-notes.html

#### Hardware Changes

**Symptom**: Errors about missing hardware or boot configuration

**Fix**:
```bash
sudo nixos-generate-config --force
sudo hv-upgrade-test  # Try again
```

#### Build Failures

**Symptom**: Compilation errors or download failures

**Fix**:
1. Check available disk space:
   ```bash
   df -h /nix
   ```

2. Clean up old generations:
   ```bash
   nix-collect-garbage -d
   ```

3. Retry the test:
   ```bash
   sudo hv-upgrade-test
   ```

### Rolling Back

If you applied an upgrade and encounter issues:

```bash
sudo nixos-rebuild switch --rollback
```

This instantly reverts to the previous working configuration.

## Version Pinning

### Staying on Stable Releases

Hyper-NixOS uses NixOS 24.05 stable by default (matches `system.stateVersion`).

To verify your channel:

```bash
cat /etc/hypervisor/flake.nix | grep nixpkgs.url
```

Expected output:
```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
```

### Upgrading to Newer Releases

When NixOS 24.11 (or newer) is released and you want to upgrade:

1. **Update the flake.nix**:
   ```bash
   sudo vim /etc/hypervisor/flake.nix
   # Change: nixos-24.05 → nixos-24.11
   ```

2. **Update flake lock**:
   ```bash
   cd /etc/hypervisor
   sudo nix flake update
   ```

3. **Follow safe upgrade workflow** (test first!)

4. **Update stateVersion** (only if recommended in release notes):
   ```bash
   cd Hyper-NixOS
   vim configuration.nix
   # Update system.stateVersion = "25.05";
   sudo nixos-rebuild switch --flake .
   ```

## Channel Compatibility

### Avoiding Downgrades

The system is configured to **prevent accidental downgrades** to older NixOS versions.

If you accidentally:
- Switch to an older channel (e.g., 24.05 → 23.11)
- Use an older flake input

The upgrade test will likely fail due to:
- Configuration option incompatibilities
- Package version conflicts
- State version mismatches

**Always upgrade forward, never downgrade.**

### Configuration Merge Priority

Hyper-NixOS uses `lib.mkDefault` for base settings, allowing you to override:

1. **Base settings** (lowest priority) - Hyper-NixOS defaults
2. **Hardware detection** (medium priority) - Auto-detected settings
3. **User configuration** (highest priority) - Your custom settings in configuration.nix

This prevents the installer from overwriting your custom settings during upgrades.

## Best Practices

### 1. Test Before Production

Never apply upgrades to production systems without testing first.

### 2. Schedule Maintenance Windows

Plan upgrades during low-usage periods:
- Off-peak hours
- Weekends
- Scheduled maintenance windows

### 3. Back Up Configuration

Before major upgrades:

```bash
sudo cp -r /etc/nixos /root/nixos-backup-$(date +%Y%m%d)
sudo cp -r /etc/hypervisor /root/hypervisor-backup-$(date +%Y%m%d)
```

### 4. Monitor Logs

Watch for warnings during upgrade testing:

```bash
sudo journalctl -u nixos-upgrade.service -f
tail -f /var/log/hypervisor/upgrade-test.log
```

### 5. Read Release Notes

Before upgrading to a new NixOS release:
- Read: https://nixos.org/manual/nixos/stable/release-notes.html
- Check for breaking changes
- Review migration guides

### 6. Keep Dependencies Updated

Between major NixOS upgrades, keep packages current:

```bash
cd /etc/hypervisor
sudo nix flake update nixpkgs
sudo hv-upgrade-test
```

## Troubleshooting

### Update Check Fails

**Check network connectivity**:
```bash
ping github.com
curl -I https://github.com/NixOS/nixpkgs
```

**Review check logs**:
```bash
sudo journalctl -u nixos-update-checker.service -n 50
cat /var/log/hypervisor/update-checker.log
```

### Flake Lock Issues

**Reset flake lock** (safe, just refreshes inputs):
```bash
cd /etc/hypervisor
sudo rm flake.lock
sudo nix flake update
```

### Permission Errors

**Ensure proper ownership**:
```bash
sudo chown -R root:root /etc/hypervisor
sudo chmod -R u+rw /etc/hypervisor
```

## Advanced Usage

### Custom Update Schedule

Change update check frequency:

```nix
# In configuration.nix
hypervisor.updateChecker = {
  enable = true;
  schedule = "weekly";  # or "Mon *-*-* 02:00:00" for custom
};
```

### Disable Automatic Checks

```nix
# In configuration.nix
hypervisor.updateChecker = {
  enable = false;  # Manual checks only
};
```

### Integration with CI/CD

Use the upgrade test in automation:

```bash
#!/bin/bash
# Automated upgrade testing script

if sudo hv-upgrade-test; then
  echo "✓ Upgrade test passed"
  # Could automatically apply in non-production
  exit 0
else
  echo "✗ Upgrade test failed"
  # Alert administrators
  exit 1
fi
```

## Security Considerations

### Only Administrators Can Upgrade

All upgrade commands require root privileges:
- `hv-check-updates` - root only
- `hv-upgrade-test` - root only
- `hv-system-upgrade` - root only

Regular users (even in `libvirtd` group) cannot modify the system.

### Update Verification

NixOS verifies all downloads:
- Package signatures checked
- Hash verification for all inputs
- Reproducible builds ensure integrity

### Audit Trail

All upgrade operations are logged:
- `/var/log/hypervisor/update-checker.log` - Update checks
- `/var/log/hypervisor/upgrade-test.log` - Test results
- `journalctl -u nixos-rebuild` - System upgrades

## Support

For upgrade issues:

1. Check logs: `/var/log/hypervisor/upgrade-test.log`
2. Review: `/var/lib/hypervisor/upgrade-test-result`
3. Report issues: https://github.com/MasterofNull/Hyper-NixOS/issues
4. Include:
   - Current NixOS version: `nixos-version`
   - Error messages from test
   - Configuration differences

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
