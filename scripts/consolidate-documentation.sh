#!/usr/bin/env bash
#
# Documentation Consolidation Script
# Consolidates and reorganizes Hyper-NixOS documentation
#

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Base directory
readonly DOCS_DIR="/workspace/docs"

echo -e "${GREEN}Starting documentation consolidation...${NC}"

# Create backup
echo "Creating backup..."
cp -r "$DOCS_DIR" "${DOCS_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

# Step 1: Consolidate main documentation index
echo -e "\n${YELLOW}Step 1: Creating main documentation index${NC}"
cat > "$DOCS_DIR/README.md" << 'EOF'
# Hyper-NixOS Documentation

Welcome to the Hyper-NixOS documentation. This guide will help you find the information you need quickly.

## 📚 Documentation Structure

### Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Get up and running in 5 minutes
- **[Installation Guide](INSTALLATION_GUIDE.md)** - Complete installation instructions
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

### User Documentation
- **[User Guides](user-guides/)** - Day-to-day usage guides
  - [Basic VM Management](user-guides/basic-vm-management.md)
  - [Advanced Features](user-guides/advanced-features.md)
  - [Automation Recipes](user-guides/automation-cookbook.md)

### Administrator Documentation
- **[Admin Guides](admin-guides/)** - System administration
  - [System Administration](admin-guides/system-administration.md)
  - [Security Configuration](admin-guides/security-configuration.md)
  - [Network Configuration](admin-guides/network-configuration.md)
  - [Monitoring Setup](admin-guides/monitoring-setup.md)

### Reference Documentation
- **[Reference](reference/)** - Technical reference
  - [Configuration Options](reference/configuration-reference.md)
  - [CLI Reference](reference/cli-reference.md)
  - [Architecture Overview](reference/architecture-overview.md)
  - [API Documentation](reference/api-reference.md)

### Development Documentation
- **[Developer Resources](dev/)** - For contributors (not included in public releases)

## 🔍 Quick Links

### By Task
- **Installing**: [Installation Guide](INSTALLATION_GUIDE.md)
- **First VM**: [Quick Start](QUICK_START.md#create-your-first-vm)
- **Troubleshooting**: [Common Issues](TROUBLESHOOTING.md)
- **Security Setup**: [Security Configuration](admin-guides/security-configuration.md)
- **Network Setup**: [Network Configuration](admin-guides/network-configuration.md)

### By User Type
- **New Users**: Start with [Quick Start](QUICK_START.md)
- **System Admins**: See [Admin Guides](admin-guides/)
- **Developers**: See [Developer Resources](dev/)

## 📖 Documentation Versions

- **Version**: 1.0.0
- **Last Updated**: $(date +%Y-%m-%d)
- **License**: See [LICENSE](/LICENSE) in project root
EOF

# Step 2: Consolidate troubleshooting documentation
echo -e "\n${YELLOW}Step 2: Consolidating troubleshooting guides${NC}"
{
    echo "# Troubleshooting Guide"
    echo ""
    echo "This guide consolidates all troubleshooting information for Hyper-NixOS."
    echo ""
    
    # Include current common issues
    cat "$DOCS_DIR/COMMON_ISSUES_AND_SOLUTIONS.md" | sed '1d'  # Remove first header
    
    echo -e "\n---\n"
    echo "## Additional Troubleshooting Resources"
    echo ""
    echo "- [Admin Guide Troubleshooting](admin-guides/system-administration.md#troubleshooting)"
    echo "- [Network Troubleshooting](admin-guides/network-configuration.md#troubleshooting)"
    echo "- [Security Issues](admin-guides/security-configuration.md#common-issues)"
} > "$DOCS_DIR/TROUBLESHOOTING.md"

# Step 3: Consolidate user guides
echo -e "\n${YELLOW}Step 3: Consolidating user guides${NC}"

# Create basic VM management guide
cat > "$DOCS_DIR/user-guides/basic-vm-management.md" << 'EOF'
# Basic VM Management

This guide covers day-to-day VM operations in Hyper-NixOS.

## Creating VMs

### Using Templates
```bash
# List available templates
hv template list

# Create VM from template
hv vm create my-vm --template debian-11
```

### Manual Creation
```bash
# Create custom VM
virt-install \
  --name my-custom-vm \
  --memory 2048 \
  --vcpus 2 \
  --disk size=20 \
  --cdrom /path/to/iso \
  --network bridge=virbr0
```

## Managing VMs

### Basic Operations
```bash
# List VMs
virsh list --all

# Start/Stop
vm-start my-vm
vm-stop my-vm

# Console access
virsh console my-vm
```

### Snapshots
```bash
# Create snapshot
virsh snapshot-create-as my-vm snapshot1 "Before updates"

# List snapshots
virsh snapshot-list my-vm

# Revert
virsh snapshot-revert my-vm snapshot1
```

## Resource Management

### CPU and Memory
```bash
# View current allocation
virsh dominfo my-vm

# Adjust memory (VM must be off)
virsh setmaxmem my-vm 4096 --config
virsh setmem my-vm 4096 --config

# Adjust CPUs
virsh setvcpus my-vm 4 --config --maximum
virsh setvcpus my-vm 4 --config
```

### Storage
```bash
# Add disk
virsh attach-disk my-vm /var/lib/libvirt/images/extra.qcow2 vdb --persistent

# Resize disk
qemu-img resize /var/lib/libvirt/images/my-vm.qcow2 +10G
```

## Networking

### Basic NAT (Default)
VMs automatically get NAT networking through virbr0.

### Bridge Networking
See [Network Configuration](../admin-guides/network-configuration.md) for bridge setup.

## Next Steps
- [Advanced Features](advanced-features.md)
- [Automation](automation-cookbook.md)
- [Admin Guide](../admin-guides/)
EOF

# Consolidate advanced features from multiple sources
echo "Creating advanced features guide..."
{
    echo "# Advanced Features"
    echo ""
    echo "This guide covers advanced Hyper-NixOS features."
    echo ""
    
    # Pull from existing advanced_features.md
    if [[ -f "$DOCS_DIR/advanced_features.md" ]]; then
        cat "$DOCS_DIR/advanced_features.md" | sed '1,3d'
    fi
    
    # Add sections from other docs
    echo -e "\n## GPU Passthrough\n"
    echo "See [GPU Passthrough Guide](gpu-passthrough.md) for detailed instructions."
    
    echo -e "\n## Live Migration\n"
    echo "Available in Professional and Enterprise tiers. See [Migration Guide](live-migration.md)."
    
    echo -e "\n## Storage Pools\n"
    echo "See [Storage Management](../admin-guides/system-administration.md#storage-pools)."
} > "$DOCS_DIR/user-guides/advanced-features.md"

# Step 4: Consolidate admin guides
echo -e "\n${YELLOW}Step 4: Consolidating admin guides${NC}"

# Create consolidated system administration guide
cat > "$DOCS_DIR/admin-guides/system-administration.md" << 'EOF'
# System Administration Guide

This guide covers system administration tasks for Hyper-NixOS.

## System Management

### Service Management
```bash
# Check all hypervisor services
systemctl status hypervisor-*

# Restart services
sudo systemctl restart libvirtd
sudo systemctl restart hypervisor-api
```

### User Management
```bash
# Add user to virtualization groups
sudo usermod -aG libvirtd,kvm username

# Create hypervisor admin
sudo useradd -m -G wheel,libvirtd,kvm hvadmin
```

### Storage Pools

#### Creating Pools
```bash
# Directory-based pool
virsh pool-define-as mypool dir --target /data/vms
virsh pool-start mypool
virsh pool-autostart mypool

# LVM pool
virsh pool-define-as lvmpool logical --source-name vg0 --target /dev/vg0
```

#### Managing Pools
```bash
# List pools
virsh pool-list --all

# Pool info
virsh pool-info mypool

# Refresh pool
virsh pool-refresh mypool
```

### Backup and Recovery

#### VM Backups
```bash
# Backup VM
virsh dumpxml my-vm > my-vm.xml
cp /var/lib/libvirt/images/my-vm.qcow2 /backup/

# Restore VM
virsh define my-vm.xml
cp /backup/my-vm.qcow2 /var/lib/libvirt/images/
```

#### System Backups
See [Backup Guide](backup-recovery.md) for comprehensive backup strategies.

### Performance Tuning

#### CPU Pinning
```bash
# Pin VM to specific CPUs
virsh vcpupin my-vm 0 2
virsh vcpupin my-vm 1 3
```

#### Memory Optimization
- Enable huge pages
- Configure memory ballooning
- Set memory limits appropriately

### Troubleshooting

#### Common Issues
1. **VM won't start**: Check logs with `virsh domlog my-vm`
2. **Network issues**: Verify bridge configuration
3. **Storage full**: Check with `virsh pool-info`
4. **Permission denied**: Verify group membership

#### Debug Commands
```bash
# System logs
journalctl -u libvirtd -f

# VM logs
virsh domlog my-vm

# Check resources
virsh nodeinfo
```

## Security Hardening

See [Security Configuration](security-configuration.md) for detailed security setup.

## Monitoring

See [Monitoring Setup](monitoring-setup.md) for Prometheus/Grafana configuration.
EOF

# Create consolidated security configuration guide
echo "Creating security configuration guide..."
{
    echo "# Security Configuration Guide"
    echo ""
    echo "This guide covers security configuration for Hyper-NixOS."
    echo ""
    
    # Merge content from multiple security docs
    if [[ -f "$DOCS_DIR/admin-guides/SECURITY_CONSIDERATIONS.md" ]]; then
        cat "$DOCS_DIR/admin-guides/SECURITY_CONSIDERATIONS.md" | sed '1,3d'
    fi
    
    if [[ -f "$DOCS_DIR/admin-guides/security_best_practices.md" ]]; then
        echo -e "\n## Best Practices\n"
        cat "$DOCS_DIR/admin-guides/security_best_practices.md" | sed '1,3d'
    fi
    
    echo -e "\n## Common Security Issues\n"
    echo "See [Troubleshooting Guide](../TROUBLESHOOTING.md#security-issues) for security-related troubleshooting."
} > "$DOCS_DIR/admin-guides/security-configuration.md"

# Step 5: Consolidate reference documentation
echo -e "\n${YELLOW}Step 5: Creating reference documentation${NC}"

# Create architecture overview
cat > "$DOCS_DIR/reference/architecture-overview.md" << 'EOF'
# Architecture Overview

This document provides a comprehensive overview of the Hyper-NixOS architecture.

## System Architecture

### Core Components

1. **NixOS Base System**
   - Declarative configuration
   - Atomic updates
   - Rollback capability

2. **Virtualization Layer**
   - libvirt for VM management
   - QEMU/KVM for hypervisor
   - virt-manager for GUI (optional)

3. **Management Layer**
   - CLI tools (hv command)
   - Web dashboard (tier-dependent)
   - REST API (tier-dependent)

4. **Security Layer**
   - Multiple security profiles
   - AI/ML threat detection (Professional/Enterprise)
   - Automated responses

### Module System

Hyper-NixOS uses a modular architecture:

```
modules/
├── core/           # Core system modules
├── security/       # Security modules
├── features/       # Feature management
├── virtualization/ # VM management
└── automation/     # Automation modules
```

### Configuration Tiers

| Tier | Components | Use Case |
|------|------------|----------|
| Minimal | Core + libvirt | Basic virtualization |
| Standard | + Monitoring + Security | Production ready |
| Enhanced | + GUI + Advanced networking | Power users |
| Professional | + AI/ML + Automation | Enterprise features |
| Enterprise | + HA + Clustering | Large deployments |

## Data Flow

1. **User Input** → CLI/Web/API
2. **Management Layer** → Validates and processes
3. **libvirt** → Executes VM operations
4. **QEMU/KVM** → Runs virtual machines
5. **Monitoring** → Collects metrics
6. **Security** → Analyzes and responds

## Security Architecture

See [Security Model](../admin-guides/security-configuration.md) for detailed security architecture.

## Networking Architecture

See [Network Configuration](../admin-guides/network-configuration.md) for networking details.
EOF

# Create CLI reference
echo "Creating CLI reference..."
cat > "$DOCS_DIR/reference/cli-reference.md" << 'EOF'
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
EOF

# Step 6: Clean up redundant files
echo -e "\n${YELLOW}Step 6: Moving redundant files to archive${NC}"
mkdir -p "$DOCS_DIR/archive/summaries"
mkdir -p "$DOCS_DIR/archive/old-guides"

# Move summary files
for file in DOCUMENTATION-INDEX.md DOCUMENTATION_ORGANIZATION_SUMMARY.md DOCUMENTATION-UPDATE-SUMMARY.md \
           FILE-ORGANIZATION-SUMMARY.md FINAL-DELIVERY-SUMMARY.md IMPLEMENTATION_SUMMARY.md \
           ORGANIZATION.md PROJECT_SUMMARY.md COMPLETE_FEATURES_SUMMARY.md; do
    if [[ -f "$DOCS_DIR/$file" ]]; then
        mv "$DOCS_DIR/$file" "$DOCS_DIR/archive/summaries/"
        echo "  Archived: $file"
    fi
done

# Move outdated guides
for file in PLATFORM-OVERVIEW.md SCALABLE-SECURITY-FRAMEWORK.md THREAT_DEFENSE_SYSTEM.md \
           USER_SETUP_GUIDE.md MINIMAL_INSTALL_WORKFLOW.md; do
    if [[ -f "$DOCS_DIR/$file" ]]; then
        mv "$DOCS_DIR/$file" "$DOCS_DIR/archive/old-guides/"
        echo "  Archived: $file"
    fi
done

# Step 7: Create navigation indexes for subdirectories
echo -e "\n${YELLOW}Step 7: Creating navigation indexes${NC}"

# User guides index
cat > "$DOCS_DIR/user-guides/README.md" << 'EOF'
# User Guides

Guides for day-to-day usage of Hyper-NixOS.

## Available Guides

1. **[Basic VM Management](basic-vm-management.md)**
   - Creating and managing VMs
   - Snapshots and backups
   - Resource management

2. **[Advanced Features](advanced-features.md)**
   - GPU passthrough
   - Live migration
   - Advanced networking

3. **[Automation Cookbook](automation-cookbook.md)**
   - Automation recipes
   - Scripting examples
   - Integration guides

## Quick Tasks

- **Create a VM**: See [Basic VM Management](basic-vm-management.md#creating-vms)
- **Take a snapshot**: See [Snapshots](basic-vm-management.md#snapshots)
- **Setup automation**: See [Automation Cookbook](automation-cookbook.md)

## Need Help?

- **Troubleshooting**: See [Troubleshooting Guide](../TROUBLESHOOTING.md)
- **Admin Tasks**: See [Admin Guides](../admin-guides/)
EOF

# Admin guides index
cat > "$DOCS_DIR/admin-guides/README.md" << 'EOF'
# Administrator Guides

System administration guides for Hyper-NixOS.

## Core Guides

1. **[System Administration](system-administration.md)**
   - Service management
   - User management
   - Storage pools
   - Backup and recovery

2. **[Security Configuration](security-configuration.md)**
   - Security hardening
   - Access control
   - Audit logging
   - Threat detection

3. **[Network Configuration](network-configuration.md)**
   - Bridge setup
   - VLAN configuration
   - Firewall rules
   - Network isolation

4. **[Monitoring Setup](monitoring-setup.md)**
   - Prometheus configuration
   - Grafana dashboards
   - Alert rules
   - Performance metrics

## Quick Reference

- **Add user to libvirt**: `sudo usermod -aG libvirtd,kvm username`
- **Check services**: `systemctl status hypervisor-*`
- **View logs**: `journalctl -u libvirtd -f`

## Advanced Topics

- **[Enterprise Features](ENTERPRISE_FEATURES.md)** - For Professional/Enterprise tiers
- **[Automation Guide](AUTOMATION_GUIDE.md)** - Automation and orchestration
EOF

# Reference index
cat > "$DOCS_DIR/reference/README.md" << 'EOF'
# Reference Documentation

Technical reference for Hyper-NixOS.

## Available References

1. **[Architecture Overview](architecture-overview.md)**
   - System architecture
   - Component overview
   - Data flow

2. **[CLI Reference](cli-reference.md)**
   - Command reference
   - Options and flags
   - Examples

3. **[Configuration Reference](configuration-reference.md)**
   - All configuration options
   - Module options
   - Examples

4. **[API Reference](api-reference.md)**
   - REST API endpoints
   - Authentication
   - Examples

## Quick Links

- **All commands**: [CLI Reference](cli-reference.md)
- **Config options**: [Configuration Reference](configuration-reference.md)
- **System design**: [Architecture Overview](architecture-overview.md)
EOF

echo -e "\n${GREEN}Documentation consolidation complete!${NC}"
echo -e "\nSummary:"
echo "- Created unified documentation structure"
echo "- Consolidated overlapping content"
echo "- Archived redundant files to docs/archive/"
echo "- Created clear navigation indexes"
echo ""
echo "Next steps:"
echo "1. Review the new structure in docs/"
echo "2. Update any broken links in code/scripts"
echo "3. Remove docs/archive/ when confident"