# VM Limits Administration Guide

## Overview

Hyper-NixOS provides comprehensive VM creation limits to prevent resource exhaustion and maintain system stability. This guide explains how to configure, manage, and monitor these limits.

## Quick Start

### Check Current Limits
```bash
hv-check-vm-limits status
```

### Configure Limits (Interactive Wizard)
```bash
sudo vm-limits-wizard
```

### Reconfigure During Setup
```bash
sudo system-setup-wizard
```

## Understanding VM Limits

VM limits control three main areas:

### 1. **Global Limits**
- **Max Total VMs**: Maximum number of VMs (running + stopped) on the system
- **Max Running VMs**: Maximum VMs that can run concurrently
- **Creation Rate Limit**: Maximum VMs that can be created per hour

### 2. **Per-User Limits**
- **Max VMs Per User**: Total VMs a single user can create
- **Max Running VMs Per User**: Concurrent running VMs per user
- **User Exceptions**: Custom limits for specific users

### 3. **Storage Limits**
- **Max Disk Per VM**: Maximum disk size for a single VM
- **Max Total Storage**: Total storage allocated for all VMs
- **Max Snapshots Per VM**: Maximum snapshots per VM

## Available Presets

### Personal Workstation
**Best for**: Single user, development and testing

| Limit | Value |
|-------|-------|
| Total VMs | 20 |
| Running VMs | 10 |
| Rate Limit | 5/hour |
| Storage | 1 TB total |
| Per-VM Disk | 200 GB |
| Snapshots | 5 per VM |

### Small Team Server
**Best for**: 3-5 users, shared development

| Limit | Value |
|-------|-------|
| Total VMs | 50 |
| Running VMs | 25 |
| Rate Limit | 10/hour |
| Per-User VMs | 15 |
| Per-User Running | 8 |
| Storage | 2 TB total |
| Per-VM Disk | 300 GB |

### Medium Organization
**Best for**: 10-20 users, departmental server
**DEFAULT CONFIGURATION**

| Limit | Value |
|-------|-------|
| Total VMs | 100 |
| Running VMs | 50 |
| Rate Limit | 15/hour |
| Per-User VMs | 20 |
| Per-User Running | 10 |
| Storage | 5 TB total |
| Per-VM Disk | 500 GB |

### Large Enterprise
**Best for**: 50+ users, production environment

| Limit | Value |
|-------|-------|
| Total VMs | 500 |
| Running VMs | 250 |
| Rate Limit | 30/hour |
| Per-User VMs | 30 |
| Per-User Running | 15 |
| Storage | 20 TB total |
| Per-VM Disk | 1000 GB |

### Cloud/Hosting Provider
**Best for**: Multi-tenant hosting

| Limit | Value |
|-------|-------|
| Total VMs | 1000 |
| Running VMs | 500 |
| Rate Limit | 50/hour |
| Per-User VMs | 50 |
| Per-User Running | 25 |
| Storage | 50 TB total |
| Per-VM Disk | 2000 GB |

### Education/Training Lab
**Best for**: Many users, temporary VMs

| Limit | Value |
|-------|-------|
| Total VMs | 200 |
| Running VMs | 100 |
| Rate Limit | 25/hour |
| Per-User VMs | 10 |
| Per-User Running | 5 |
| Storage | 3 TB total |
| Per-VM Disk | 100 GB |

### Testing/CI Environment
**Best for**: Automated testing, high churn

| Limit | Value |
|-------|-------|
| Total VMs | 150 |
| Running VMs | 75 |
| Rate Limit | 50/hour |
| Per-User VMs | 50 |
| Enforcement | Warning mode |

### Minimal/Resource-Constrained
**Best for**: Low-end hardware

| Limit | Value |
|-------|-------|
| Total VMs | 10 |
| Running VMs | 5 |
| Rate Limit | 3/hour |
| Storage | 500 GB total |
| Per-VM Disk | 100 GB |

## Configuration

### Method 1: Interactive Wizard

```bash
sudo vm-limits-wizard
```

This wizard will:
1. Show you all available presets
2. Allow custom configuration
3. Preview the configuration
4. Apply changes to `configuration.nix`

### Method 2: Manual Configuration

Edit `/etc/nixos/configuration.nix`:

```nix
hypervisor.vmLimits = {
  enable = true;

  global = {
    maxTotalVMs = 100;       # Adjust to your needs
    maxRunningVMs = 50;
    maxVMsPerHour = 15;
  };

  perUser = {
    enable = true;           # Set false for single-user systems
    maxVMsPerUser = 20;
    maxRunningVMsPerUser = 10;

    # Optional: Custom limits for specific users
    userExceptions = {
      alice = 50;             # Alice can create 50 VMs
      bob = 30;               # Bob can create 30 VMs
    };
  };

  storage = {
    maxDiskPerVM = 500;      # GB
    maxTotalStorage = 5000;  # GB
    maxSnapshotsPerVM = 10;
  };

  enforcement = {
    blockExcessCreation = true;    # Block or warn
    notifyOnApproach = true;       # Notify at 90%
    adminOverride = true;          # Allow --force flag
  };
};
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

### Method 3: Using Presets as Templates

Import a preset from the templates directory:

```nix
{ config, lib, pkgs, ... }:

let
  vmLimitsPresets = import ./templates/vm-limits-presets.nix;
in {
  hypervisor.vmLimits = {
    enable = true;
  } // vmLimitsPresets.mediumOrg;  # Use medium org preset
}
```

## Monitoring and Management

### Check Current Status
```bash
hv-check-vm-limits status
```

Example output:
```
════════════════════════════════════════════════════════════
  VM Creation Limits Check
════════════════════════════════════════════════════════════

Current Status:
  Total VMs:       45 / 100
  Running VMs:     15 / 50
  Storage Used:    1200 GB / 5000 GB
  Created/Hour:    3 / 10

User Limits (alice):
  Total VMs:       12 / 20
  Running VMs:     5 / 10

✓ All limits satisfied - VM creation allowed
════════════════════════════════════════════════════════════
```

### Check If VM Creation Allowed
```bash
# Check if user can create a 50GB VM
hv-check-vm-limits check $(whoami) 50
```

### Log VM Creation
```bash
# Log when a VM is created (for tracking)
hv-check-vm-limits log my-new-vm
```

### View Limits Documentation
```bash
cat /etc/hypervisor/docs/vm-limits.md
```

## Admin Override

System administrators (in `wheel` or `hypervisor-admins` groups) can override limits when necessary.

When creating a VM that exceeds limits:
```bash
# In VM creation wizard or script, use:
hv-check-vm-limits check $(whoami) 100 true
#                                         ↑
#                                    override flag
```

The system will:
1. Check if user is an admin
2. Display limits that would be exceeded
3. Allow creation with admin override
4. Log the override for audit purposes

## Troubleshooting

### VM Creation Blocked

**Symptom**: Cannot create VMs, getting "limit exceeded" errors

**Solution**:
1. Check current status:
   ```bash
   hv-check-vm-limits status
   ```

2. Identify which limit is exceeded:
   - Global VM limit
   - Running VM limit
   - Per-user limit
   - Storage limit
   - Rate limit

3. Options:
   - Stop/delete unused VMs
   - Delete old snapshots
   - Request limit increase from admin
   - Use admin override (if you're an admin)

### Approaching Limits Warning

**Symptom**: Getting "approaching limit" warnings at 90%

**Solution**:
- This is informational - you can still create VMs
- Plan to clean up resources soon
- Consider requesting higher limits

### Rate Limit Exceeded

**Symptom**: "Rate limit exceeded: X VMs created in last hour"

**Solution**:
- Wait for the hour window to pass
- This prevents rapid VM creation storms
- Admins can override if needed

### Per-User Limits Not Working

**Symptom**: All users can create unlimited VMs

**Check**:
```bash
grep "perUser.enable" /etc/nixos/configuration.nix
```

**Solution**:
```nix
hypervisor.vmLimits.perUser.enable = true;
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

## Security Considerations

### Why VM Limits Matter

1. **Resource Exhaustion Prevention**: Prevents users from consuming all system resources
2. **Fair Sharing**: Ensures equitable resource distribution among users
3. **DoS Protection**: Rate limiting prevents VM creation floods
4. **Storage Protection**: Prevents disk space exhaustion
5. **System Stability**: Maintains predictable system performance

### Best Practices

1. **Set Conservative Limits Initially**
   - Start with lower limits
   - Increase based on actual usage patterns
   - Monitor and adjust

2. **Enable Per-User Limits**
   - Always enable for multi-user systems
   - Prevents single user from monopolizing resources
   - Admins should be in exceptions list

3. **Monitor Usage Patterns**
   - Check `/var/log/hypervisor/vm-creation.log` regularly
   - Look for unusual creation patterns
   - Adjust limits based on trends

4. **Regular Cleanup**
   - Implement policies for VM lifecycle
   - Auto-delete stopped VMs after X days
   - Regular snapshot cleanup

5. **Document Your Limits**
   - Communicate limits to users
   - Provide clear escalation path
   - Document override procedures

## Integration with Other Systems

### Integration with VM Creation Wizard

The VM creation wizard automatically checks limits before creating VMs:

```bash
create-vm-wizard.sh
# Automatically runs: hv-check-vm-limits check
```

### Integration with Resource Quotas

VM limits work alongside per-VM resource quotas:

- **VM Limits**: Control HOW MANY VMs
- **Resource Quotas**: Control HOW MUCH each VM uses

See [resource-quotas documentation](resource-quotas.md) for per-VM limits.

### Automation and APIs

Check limits programmatically:

```bash
# Exit code 0 = allowed, 1 = blocked
if hv-check-vm-limits check "$USER" "$DISK_SIZE" "$OVERRIDE"; then
    create_vm
else
    echo "VM creation not allowed"
fi
```

## Files and Locations

| File/Directory | Purpose |
|---------------|---------|
| `/etc/hypervisor/vm-limits.conf` | Current limits configuration |
| `/var/lib/hypervisor/vm-limits.db` | VM limits database |
| `/var/log/hypervisor/vm-creation.log` | VM creation history (7 days) |
| `/etc/hypervisor/docs/vm-limits.md` | User-facing limits documentation |
| `/etc/nixos/configuration.nix` | Main configuration file |
| `/home/hyperd/Documents/Hyper-NixOS/templates/vm-limits-presets.nix` | Preset templates |

## Advanced Topics

### Custom Per-User Limits

Grant different limits to power users:

```nix
hypervisor.vmLimits.perUser.userExceptions = {
  developer1 = 100;  # Lead developer
  developer2 = 100;
  tester1 = 50;      # QA team
  intern1 = 5;       # Limited access
};
```

### Disabling Specific Limits

Warning mode only (no blocking):

```nix
hypervisor.vmLimits.enforcement.blockExcessCreation = false;
```

This logs warnings but allows creation.

### Dynamic Limits Based on Hardware

Calculate limits based on detected hardware:

```nix
let
  totalRAM = 64 * 1024;  # 64 GB in MB
  vmRAM = 2048;          # 2 GB per VM average
  maxVMs = totalRAM / vmRAM;
in {
  hypervisor.vmLimits.global.maxTotalVMs = maxVMs;
}
```

## FAQ

**Q: Can I disable VM limits entirely?**

A: Yes, but not recommended:
```nix
hypervisor.vmLimits.enable = false;
```

**Q: Do limits apply to admins?**

A: Per-user limits don't apply to `wheel` or `hypervisor-admins` groups. Global limits still apply but admins can override.

**Q: How do I temporarily increase limits?**

A: Admins can override limits with the `--force-override` flag or temporarily adjust in `configuration.nix`.

**Q: Are stopped VMs counted toward limits?**

A: Yes, total VM limits include both running and stopped VMs. Running VM limits only count active VMs.

**Q: Can limits be different for different VM types?**

A: Not currently. All VMs count equally toward limits regardless of their resources or purpose.

**Q: What happens to existing VMs if I lower limits?**

A: Existing VMs are grandfathered. Limits only prevent NEW VM creation. You can have more VMs than the limit if they were created before the limit was lowered.

## Support

For questions or issues:
1. Check this documentation
2. Run `hv-check-vm-limits status` for diagnostics
3. Review `/var/log/hypervisor/vm-creation.log`
4. Contact your system administrator
5. File issues at the Hyper-NixOS repository

---

**Last Updated**: 2025-10-18
**Version**: 1.0.0
