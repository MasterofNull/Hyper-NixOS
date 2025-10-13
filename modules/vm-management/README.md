# VM Management Module

This directory contains all VM management and lifecycle configurations.

## Module Organization

### `resource-quotas.nix`
VM resource quota management:
- CPU quotas (percentage limits per VM)
- Memory limits (RAM allocation)
- Network bandwidth limits
- Disk I/O limits (IOPS)
- Prevents resource exhaustion
- Fair resource sharing

**When to edit**: Setting resource limits, preventing VMs from consuming too much CPU/memory

### `snapshots.nix`
VM snapshot lifecycle management:
- Automated snapshot creation
- Retention policies (hourly, daily, weekly, monthly)
- Snapshot cleanup and rotation
- Point-in-time recovery
- Snapshot verification

**When to edit**: Configuring automatic snapshots, setting retention policies

### `scheduling.nix`
VM scheduling and automation:
- Scheduled VM operations (start, stop, restart)
- Automated resource reporting
- Cron-like scheduling for VM tasks
- Daily/weekly/monthly automation

**When to edit**: Setting up automatic VM start/stop, scheduling backups

## Common Tasks

### Set Resource Quotas for a VM
```bash
/etc/hypervisor/scripts/quota_manager.sh set web-server \
  --cpu 200 --memory 4096 --disk 100 --network 100
```

Or edit `resource-quotas.nix` to set default quotas.

### Configure Automatic Snapshots
```bash
# Keep 7 daily and 4 weekly snapshots
/etc/hypervisor/scripts/snapshot_manager.sh set-policy web-server "daily:7,weekly:4"

# Create automatic snapshot
/etc/hypervisor/scripts/snapshot_manager.sh auto-snapshot web-server
```

Or edit `snapshots.nix` to configure snapshot automation service.

### Schedule VM Operations
```bash
# Schedule VM to start at 8 AM weekdays
/etc/hypervisor/scripts/vm_scheduler.sh add web-server start "0 8 * * 1-5"

# Schedule VM to stop at 6 PM
/etc/hypervisor/scripts/vm_scheduler.sh add web-server stop "0 18 * * *"
```

Or edit `scheduling.nix` to configure systemd timers.

### View Resource Usage
```bash
# Get current quotas and usage
/etc/hypervisor/scripts/quota_manager.sh get web-server

# View daily report
cat /var/lib/hypervisor/reports/daily-$(date +%Y-%m-%d).txt
```

## Best Practices

1. **Resource Quotas**: 
   - Set quotas to prevent individual VMs from starving others
   - Leave ~20% headroom on host for system overhead
   - Monitor quota violations in logs

2. **Snapshots**:
   - Use retention policies to prevent disk exhaustion
   - Test snapshot restores periodically
   - Keep pre-update snapshots for critical VMs

3. **Scheduling**:
   - Schedule resource-intensive operations during off-hours
   - Stagger VM starts to avoid resource spikes
   - Review daily reports for capacity planning

## See Also

- Storage management: `../storage-management/`
- Automation: `../automation/`
- Monitoring: `../monitoring/`
