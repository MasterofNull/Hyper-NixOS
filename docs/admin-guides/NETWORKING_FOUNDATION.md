# Foundational Networking Setup

## Overview

Networking is now configured **FIRST** as the foundation for all other operations.

## Why Networking First?

Many processes depend on network access:
- ✓ ISO downloads require internet connectivity
- ✓ Package installation needs network access
- ✓ VM creation requires network bridges
- ✓ Network discovery and DHCP configuration
- ✓ Security zones depend on network infrastructure

## Automatic Setup

The setup wizard now runs foundational networking as **Step 1** automatically.

## Manual Setup

Run the comprehensive networking wizard standalone:

```bash
sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
```

## What It Does

### Phase 1: Network Capability Assessment
- Detects all physical network interfaces
- Filters out virtual/loopback interfaces
- Assesses each interface (state, speed, IP, primary status)
- Identifies primary/active network connection

### Phase 2: Intelligent Interface Selection
- Automatically selects best interface
- Shows detailed information about each option
- Highlights primary interface (★PRIMARY★)
- Explains binding process clearly
- Provides interactive selection with recommendations

### Phase 3: Bridge Configuration
- Creates high-performance network bridge
- Offers performance profiles:
  - **Standard (MTU 1500)** - Compatible with all networks
  - **Performance (MTU 9000)** - Jumbo frames for LAN
- Automatically binds interface to bridge
- Applies configuration safely

### Phase 4: Bridge Validation
- Verifies bridge creation
- Checks interface binding
- Waits for DHCP IP address
- Reports detailed status

### Phase 5: Libvirt Network Configuration
- Creates libvirt bridge network definition
- Defines and starts network
- Enables autostart
- Integrates with VM management

### Phase 6: Connectivity Validation
- Tests gateway reachability
- Tests internet connectivity  
- Tests DNS resolution
- Reports connectivity status

### Phase 7: Readiness Marker
- Creates `/var/lib/hypervisor/.network_ready`
- Stores configuration details (JSON)
- Enables other scripts to check prerequisites

## Binding Explanation

The wizard explains clearly what "binding" means:

> **When an interface is 'bound' to a bridge:**
> - The interface becomes part of the bridge
> - Network configuration moves from interface to bridge
> - The bridge gets the IP address (via DHCP)
> - VMs connect through the bridge to your network
> - Your interface continues to work normally
>
> **This is automatic and safe!**

## Checking Network Readiness

Other scripts can check if networking is configured:

```bash
/etc/hypervisor/scripts/check_network_ready.sh -v
```

View readiness details:
```bash
cat /var/lib/hypervisor/.network_ready | jq
```

## Setup Wizard Integration

The `setup_wizard.sh` now:
1. Checks for existing network configuration first
2. Runs networking setup as Step 1 if needed
3. Skips network-dependent steps if network unavailable
4. Shows appropriate warnings
5. Validates connectivity before proceeding

## Configuration Files Created

- `/etc/systemd/network/br0.netdev` - Bridge device
- `/etc/systemd/network/br0.network` - Bridge network config
- `/etc/systemd/network/<interface>.network` - Interface binding
- `/etc/libvirt/qemu/networks/host-bridge.xml` - Libvirt network
- `/var/lib/hypervisor/.network_ready` - Readiness marker

## Logs

All operations are logged to:
```
/var/lib/hypervisor/logs/foundational_networking.log
```

## Non-Interactive Mode

For automation:
```bash
sudo NON_INTERACTIVE=true /etc/hypervisor/scripts/foundational_networking_setup.sh
```

## Benefits

### Automation
No manual IP commands or configuration file editing

### Guidance  
Every step explained clearly with context

### Intelligence
Automatic detection and smart recommendations

### Safety
Validation at every phase with error handling

### Transparency
Full logging and status reporting at each step
