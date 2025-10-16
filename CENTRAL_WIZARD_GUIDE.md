# Hyper-NixOS Central Wizard Guide

## 🎯 Overview

The **Hyper-NixOS Central Wizard** (`hyper-wizard`) is your one-stop interface for all system configuration. It intelligently adapts to your environment (admin host vs VM) and provides guided access to all configuration tools.

---

## 🚀 Quick Start

```bash
# Launch the central wizard
sudo hyper-wizard

# The wizard will automatically:
# • Detect your environment (Admin or VM)
# • Show available features based on environment
# • Provide guided navigation to all tools
```

---

## 🏗️ Architecture

### Environment Detection

The wizard automatically detects where it's running:

**Admin Host Environment:**
- All features available
- Full system configuration
- Network management
- Security hardening
- VM creation and management

**VM Environment:**
- Limited to VM management
- Cannot modify host network
- Cannot change security phase
- Safe operations only

### Detection Logic

```
Is virtualized? → VM Environment
libvirtd running? → Admin Environment
KVM modules loaded? → Admin Environment
Admin marker exists? → Admin Environment
Default → Admin Environment
```

---

## 📋 Main Menu Structure

### 1. Network Configuration (Admin Only)
**Wizard:** `unified-network-wizard.sh`

**Features:**
- IPv6 Configuration
- Traffic Shaping (QoS)
- Network Bonding
- DHCP Server
- VPN + Kill Switch
- Firewall Zones
- DNS Server
- Monitoring
- Bridges
- Performance Tuning
- Tor Integration
- Packet Capture
- IDS/IPS
- Load Balancing
- Automation

**Sub-menu:**
- Unified Network Wizard (all-in-one)
- MAC Address Spoofing
- IP Address Management
- VLAN Configuration
- Network Discovery

### 2. Virtual Machine Management (Both Environments)
**Available to:** Admin and VM users

**Features:**
- Create New VM
- Manage Existing VMs
- VM Templates
- VM Snapshots
- VM Cloning
- VM Monitoring
- VM Console Access

**Why Available in VMs?**
VMs can create nested VMs for testing, development, or specific use cases. The wizard provides safe, guided VM management without exposing host configuration.

### 3. System Configuration (Admin Only)
**Features:**
- Storage Management
- Backup Configuration
- User Management
- System Monitoring

### 4. Security & Hardening (Admin Only)
**Features:**
- Phase Management (Setup ↔ Hardened)
- Firewall Configuration
- Access Control
- Audit Settings

### 5. Network Discovery
**Tool:** `network-discover.sh`

**Features:**
- Interface scanning
- Active host detection
- Network topology mapping
- Safe IP recommendations
- VLAN discovery

### 6. Templates & Examples

**Pre-configured Templates:**
- Privacy Stack (IPv6 + VPN + Tor + Spoofing)
- Performance Stack (Bonding + QoS + Tuning)
- Security Stack (Firewall + IDS/IPS + VPN)
- Enterprise Multi-Tenant (VLANs + DHCP + Isolation)
- Development Lab (VLANs + DNS + Bridges)

### 7. Help & Documentation

**Resources:**
- Quick Start Guide
- Network Configuration Guide
- VM Management Guide
- Security Best Practices
- Troubleshooting
- FAQ
- Full Documentation Index

### 8. Security Phase Management (Admin Only)
**Tool:** `hv-phase`

**Actions:**
- View current phase
- Transition to Hardened
- Rollback to Setup

### 9. System Status & Information

**Displays:**
- Current environment
- Security phase
- System information
- Network modules count
- Running VMs count

---

## 🔐 Security Model

### Admin-Only Features

Features restricted to admin environment:
- Network configuration
- System configuration
- Security hardening
- Phase switching

**Why?**
These features can affect the entire host system and all VMs. Restricting them prevents VMs from modifying host configuration or escaping virtualization boundaries.

### Universal Features

Features available everywhere:
- VM management
- VM creation
- VM status/monitoring
- VM console access

**Why?**
VM operations don't affect the host system. Users can safely manage VMs from any environment.

---

## 🎨 User Experience Features

### 1. Visual Hierarchy

```
Main Menu → Category → Sub-Menu → Wizard → Configuration → Apply
```

Each level provides:
- Clear options
- Feature descriptions
- Star ratings (importance)
- Color-coded status
- Navigation hints

### 2. Context Awareness

The wizard adapts to:
- **Environment:** Admin vs VM
- **Phase:** Setup vs Hardened
- **Permissions:** Root vs non-root
- **State:** Available tools and features

### 3. Guided Navigation

Every screen shows:
- Where you are
- What you can do
- How to go back
- Related options

### 4. Help Integration

At every level:
- Feature descriptions
- Use case examples
- Configuration tips
- Links to documentation

---

## 📖 Usage Examples

### Example 1: First-Time Setup (Admin)

```bash
# 1. Launch wizard
sudo hyper-wizard

# 2. Select: Network Configuration (1)
# 3. Select: Unified Network Wizard (1)
# 4. Select: Configure All (16)
# 5. Apply configuration (18)

# Result: Complete network stack configured with defaults
```

### Example 2: Create VM (Any Environment)

```bash
# 1. Launch wizard
hyper-wizard  # No sudo needed for VM management

# 2. Select: Virtual Machine Management (2)
# 3. Select: Create New VM (1)
# 4. Follow prompts:
#    - Name: my-test-vm
#    - Memory: 8 GB (option 3)
#    - CPUs: 4
#    - Disk: 50 GB
# 5. Confirm creation

# Result: New VM created and ready to use
```

### Example 3: Apply Privacy Template

```bash
# 1. Launch wizard
sudo hyper-wizard

# 2. Select: Templates & Examples (6)
# 3. Select: Privacy Stack Template (1)
# 4. Review features
# 5. Apply template

# Result: Complete privacy configuration applied
```

### Example 4: Phase Transition

```bash
# 1. Launch wizard
sudo hyper-wizard

# 2. Select: Security Phase Management (8)
# 3. Current shows: setup
# 4. Confirm transition to hardened
# 5. System locks down

# Result: Production-ready security mode activated
```

---

## 🎯 Navigation Patterns

### Forward Navigation

```
Main Menu → Select category → Sub-menu → Select wizard → Configure
```

### Backward Navigation

Every sub-menu has:
- `0) ← Back to Main Menu` or
- `0) ← Back to Previous Menu`

Press `0` at any level to go back.

### Quick Exit

Press `Ctrl+C` at any time to exit (with confirmation).

---

## 🎓 Best Practices

### For Admin Users

1. **Start with Templates**
   - Use pre-configured templates for common scenarios
   - Customize after seeing what works

2. **Test in Setup Phase**
   - Configure everything in setup phase
   - Test thoroughly
   - Then switch to hardened

3. **Use Network Discovery**
   - Scan network before configuring
   - Use recommended IPs and VLANs
   - Avoid conflicts

4. **Document Changes**
   - Templates show what was applied
   - Review generated configurations
   - Keep notes on customizations

### For VM Users

1. **Use VM Templates**
   - Start with appropriate template
   - Adjust resources as needed

2. **Monitor Resources**
   - Check VM monitoring regularly
   - Adjust CPUs/memory if needed

3. **Take Snapshots**
   - Before major changes
   - For quick rollback
   - For testing

---

## 🔧 Customization

### Adding Custom Templates

Create template in `/workspace/templates/network/`:

```nix
# /workspace/templates/network/custom-stack.nix
{ config, lib, pkgs, ... }:
{
  imports = [ /* modules */ ];
  hypervisor.network = { /* config */ };
}
```

The wizard will automatically detect and list it.

### Adding Custom Wizards

1. Create wizard script in `/workspace/scripts/setup/`
2. Make executable: `chmod +x script.sh`
3. Add to wizard menu in `hyper-wizard`
4. Update navigation

### Environment Markers

Set environment explicitly:

```bash
# Mark as admin host
sudo touch /etc/hypervisor/.admin_host

# Remove marker (auto-detect)
sudo rm /etc/hypervisor/.admin_host
```

---

## 🐛 Troubleshooting

### "Feature not available in this environment"

**Cause:** Running in VM environment, trying to access admin-only feature

**Solution:**
- Run wizard on admin host, not in VM
- Or use VM management features instead

### "This wizard must be run as root"

**Cause:** Admin features require root privileges

**Solution:**
```bash
sudo hyper-wizard
```

### Wizard doesn't detect environment correctly

**Check detection:**
```bash
# Source library
source /workspace/scripts/lib/environment-detection.sh

# Check detection
detect_environment
# Should output: admin or vm
```

**Force environment:**
```bash
# For admin
sudo touch /etc/hypervisor/.admin_host

# Check again
detect_environment
```

### Cannot navigate back to main menu

**Solution:**
- Look for `0) ← Back` option
- Or press `Ctrl+C` to exit (then restart)

---

## 📊 File Locations

**Central Wizard:**
- `/workspace/scripts/hyper-wizard` - Main wizard

**Environment Detection:**
- `/workspace/scripts/lib/environment-detection.sh` - Detection library

**Wizards:**
- `/workspace/scripts/setup/unified-network-wizard.sh` - Network configuration
- `/workspace/scripts/setup/mac-spoofing-wizard.sh` - MAC spoofing
- `/workspace/scripts/setup/ip-spoofing-wizard.sh` - IP management
- `/workspace/scripts/setup/vlan-wizard.sh` - VLAN configuration

**Tools:**
- `/workspace/scripts/hv-phase` - Phase switching
- `/workspace/scripts/network-discover.sh` - Network discovery

**Templates:**
- `/workspace/templates/network/privacy-stack.nix`
- `/workspace/templates/network/performance-stack.nix`
- `/workspace/templates/network/enterprise-stack.nix`

**Modules:**
- `/workspace/modules/network-settings/*.nix` - 25 network modules

---

## 🎉 Summary

The Central Wizard provides:

✅ **Unified Interface** - One command for all tools  
✅ **Environment Awareness** - Adapts to admin/VM context  
✅ **Guided Navigation** - Clear paths to all features  
✅ **Security** - Enforces admin-only restrictions  
✅ **Help Integration** - Documentation at every step  
✅ **Templates** - Pre-configured common scenarios  
✅ **Phase Management** - Easy security transitions  

**Start exploring:**
```bash
sudo hyper-wizard
```

---

**Date:** 2025-10-16  
**Version:** 1.0  
**Status:** Production Ready
