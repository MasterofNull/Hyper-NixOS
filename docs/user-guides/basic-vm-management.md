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
