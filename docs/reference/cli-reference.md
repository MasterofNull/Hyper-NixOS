# CLI Reference

Complete command reference for Hyper-NixOS.

## hv Command

The main Hyper-NixOS management command.

### Global Options
- `--help, -h` - Show help
- `--version` - Show version
- `--verbose, -v` - Verbose output
- `--quiet, -q` - Quiet output

### Commands

#### VM Management
```bash
hv vm create <name> [options]     # Create new VM
hv vm start <name>                # Start VM
hv vm stop <name>                 # Stop VM
hv vm delete <name>               # Delete VM
hv vm list                        # List all VMs
hv vm info <name>                 # Show VM details
```

#### Template Management
```bash
hv template list                  # List templates
hv template info <name>           # Template details
hv template create <name>         # Create template
```

#### System Management
```bash
hv system status                  # System status
hv system update                  # Update system
hv system backup                  # Backup system
```

#### Security
```bash
hv security status                # Security status
hv security scan                  # Run security scan
hv security update                # Update security
```

## virsh Commands

Standard libvirt commands are also available.

### Common Commands
```bash
virsh list --all                  # List all VMs
virsh start <vm>                  # Start VM
virsh shutdown <vm>               # Graceful shutdown
virsh destroy <vm>                # Force stop
virsh console <vm>                # Connect to console
virsh dominfo <vm>                # VM information
```

### Snapshot Commands
```bash
virsh snapshot-create-as <vm> <name> [description]
virsh snapshot-list <vm>
virsh snapshot-revert <vm> <snapshot>
virsh snapshot-delete <vm> <snapshot>
```

### Network Commands
```bash
virsh net-list --all
virsh net-info <network>
virsh net-start <network>
```

### Storage Commands
```bash
virsh pool-list --all
virsh vol-list <pool>
virsh vol-create-as <pool> <volume> <size>
```

## Helper Scripts

### VM Lifecycle
- `vm-start <name>` - Start VM with checks
- `vm-stop <name>` - Graceful shutdown
- `vm-restart <name>` - Restart VM

### Maintenance
- `hypervisor-update` - Update system
- `hypervisor-backup` - Backup VMs
- `hypervisor-clean` - Clean old data

## Configuration Commands

### First Boot
```bash
first-boot-wizard                 # Run configuration wizard
/etc/hypervisor/bin/reconfigure-tier  # Change system tier
```

### Feature Management
```bash
hv feature list                   # List features
hv feature enable <feature>       # Enable feature
hv feature disable <feature>      # Disable feature
```
