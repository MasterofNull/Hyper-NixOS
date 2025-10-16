# Network Discovery and VLAN Configuration Guide

## Overview

Hyper-NixOS now includes comprehensive network discovery tools and VLAN management capabilities with intelligent recommendations powered by real-time network scanning.

---

## 🔍 Network Discovery

### Quick Start

**Interactive Discovery Tool:**
```bash
sudo /etc/hypervisor/scripts/network-discover.sh
```

**Command Line Usage:**
```bash
# Quick scan
sudo /etc/hypervisor/scripts/network-discover.sh quick eth0

# Full network analysis
sudo /etc/hypervisor/scripts/network-discover.sh full eth0

# Find safe (unused) IPs
sudo /etc/hypervisor/scripts/network-discover.sh safe-ips eth0

# Discover VLANs
sudo /etc/hypervisor/scripts/network-discover.sh vlan

# Wireless scan
sudo /etc/hypervisor/scripts/network-discover.sh wireless wlan0
```

### Discovery Capabilities

**Interface Discovery:**
- Physical network interfaces
- Wireless interfaces
- Virtual interfaces
- Interface state and configuration
- Link speed and capabilities

**Network Mapping:**
- Network range detection (CIDR)
- Active host scanning
- Gateway identification
- DNS server detection
- DHCP server discovery

**VLAN Analysis:**
- Existing VLAN detection
- VLAN ID recommendations
- Unused VLAN identification
- VLAN configuration analysis

**MAC Analysis:**
- MAC vendor lookup (OUI database)
- Common vendor prefixes
- MAC conflict detection
- ARP cache inspection

**IP Intelligence:**
- Used IP detection
- Safe IP recommendations
- IP conflict avoidance
- Available IP range calculation

**Performance Testing:**
- Network latency measurement
- Bandwidth detection
- Link speed testing
- MTU discovery

### Discovery Output

**Quick Scan Example:**
```
Quick Network Scan - eth0
════════════════════════════════════════

Interface Information:
  MAC:   52:54:00:12:34:56
  IP:    192.168.1.10/24
  State: UP

Network Range:
  192.168.1.0/24

Gateway:
  192.168.1.1

Scanning for active hosts...
  Found 15 active hosts

  Active IPs:
    192.168.1.1
    192.168.1.5
    192.168.1.10
    ...
```

**Full Scan Output:**
```json
{
  "interface": "eth0",
  "mac": "52:54:00:12:34:56",
  "ipv4": "192.168.1.10/24",
  "network_range": "192.168.1.0/24",
  "gateway": "192.168.1.1",
  "dns_servers": "192.168.1.1,8.8.8.8",
  "dhcp_server": "192.168.1.1",
  "active_hosts": 15,
  "recommended_ips": "192.168.1.100,192.168.1.101,192.168.1.102",
  "bandwidth": "1000Mb/s",
  "scan_time": "2025-10-16T10:30:00+00:00"
}
```

---

## 🏷️ VLAN Configuration

### Quick Start

**VLAN Setup Wizard:**
```bash
sudo /etc/hypervisor/scripts/setup/vlan-wizard.sh
```

The wizard will:
1. Detect available interfaces
2. Recommend unused VLAN IDs
3. Configure IP addressing (DHCP/Static)
4. Generate NixOS configuration
5. Apply changes automatically

### VLAN Features

**Supported:**
- 802.1Q VLAN tagging
- Multiple VLANs per interface
- VLAN IDs 1-4094
- Static or DHCP addressing
- Per-VLAN gateways
- VLAN priority (802.1p)
- Custom MTU per VLAN
- Trunk port configuration

**Use Cases:**
- Network segmentation
- Multi-tenant isolation
- Department separation
- DMZ creation
- Traffic prioritization
- Security zones

### Manual Configuration

**Basic VLAN:**
```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./modules/network-settings/vlan.nix ];
  
  hypervisor.network.vlan = {
    enable = true;
    
    interfaces = {
      "vlan10" = {
        id = 10;
        interface = "eth0";
        addresses = [ "192.168.10.2/24" ];
        gateway = "192.168.10.1";
      };
    };
  };
}
```

**Multiple VLANs:**
```nix
hypervisor.network.vlan = {
  enable = true;
  
  interfaces = {
    # Management VLAN
    "vlan1" = {
      id = 1;
      interface = "eth0";
      addresses = [ "10.0.1.10/24" ];
      priority = 7;  # Highest priority
      mtu = 1500;
    };
    
    # Server VLAN
    "vlan100" = {
      id = 100;
      interface = "eth0";
      addresses = [ "10.0.100.10/24" ];
      priority = 5;
    };
    
    # Guest VLAN  
    "vlan200" = {
      id = 200;
      interface = "eth0";
      dhcp = true;  # Use DHCP
    };
  };
};
```

**Trunk Configuration:**
```nix
hypervisor.network.vlan = {
  enable = true;
  
  # Trunk port for switch connection
  trunking = {
    "uplink" = {
      interface = "eth1";
      allowedVlans = [ 10 20 30 100 200 ];
      nativeVlan = 1;
    };
  };
  
  # VLAN interfaces
  interfaces = {
    "vlan10" = { id = 10; interface = "eth0"; addresses = [ "192.168.10.1/24" ]; };
    "vlan20" = { id = 20; interface = "eth0"; addresses = [ "192.168.20.1/24" ]; };
  };
};
```

---

## 🧠 Intelligent Recommendations

### How It Works

The wizards use network discovery to provide smart recommendations:

**1. Network Scanning**
```bash
# Wizard runs discovery
→ Scanning network 192.168.1.0/24...
→ Found 15 active hosts
→ Analyzing IP usage...
```

**2. Safe IP Recommendations**
```bash
💡 Recommended safe IPs:
  192.168.1.100
  192.168.1.101  
  192.168.1.102
```

**3. VLAN ID Recommendations**
```bash
💡 Recommended unused VLAN IDs:
  10 (User VLAN)
  20 (User VLAN)
  100 (Server VLAN)
```

**4. MAC Vendor Suggestions**
```bash
💡 Common vendor prefixes for spoofing:
  00:1A:2B - Intel Corporation
  00:50:56 - VMware
  52:54:00 - QEMU/KVM
```

### Using Discovery in Scripts

```bash
#!/usr/bin/env bash
source /etc/hypervisor/scripts/lib/network-discovery.sh

# Get safe IPs
SAFE_IPS=$(recommend_safe_ips "eth0" 5)

# Get unused VLAN IDs
VLAN_IDS=$(recommend_vlan_ids 3)

# Detect network range
NETWORK=$(detect_network_range "eth0")

# Find active hosts
HOSTS=$(scan_active_hosts "eth0")
```

---

## 🎯 Wizard Enhancements

### Enhanced MAC Spoofing Wizard

**New Features:**
- Network discovery before configuration
- Vendor prefix recommendations
- Conflict detection
- Current MAC backup with vendor info

**Future Enhancement:**
```bash
# Scan network and recommend vendor
→ Scanning network...
→ Detected vendors: VMware (3), Intel (2), Realtek (5)
💡 Recommendation: Use Intel prefix for blend-in
```

### Enhanced IP Spoofing Wizard

**New Features:**
- Active host scanning
- Safe IP recommendations
- Conflict avoidance
- Network range detection

**Example Flow:**
```
Select mode: Alias
→ Scanning network for active hosts...
→ Found 12 active IPs
💡 Recommended safe IPs: 192.168.1.100, .101, .102
Enter IPs or use recommendations [Y/n]: Y
✓ Using recommended IPs
```

### VLAN Wizard

**Features:**
- Parent interface selection
- VLAN ID recommendations
- IP configuration (DHCP/Static)
- Safe IP suggestions
- Multiple VLAN creation
- Auto-integration with configuration.nix

---

## 💼 Enterprise Use Cases

### Use Case: Segregated Development Environment

**Scenario:** Separate dev, staging, and production networks

```nix
hypervisor.network.vlan = {
  enable = true;
  interfaces = {
    "vlan10" = {  # Development
      id = 10;
      interface = "eth0";
      addresses = [ "10.0.10.1/24" ];
    };
    "vlan20" = {  # Staging
      id = 20;
      interface = "eth0";
      addresses = [ "10.0.20.1/24" ];
    };
    "vlan30" = {  # Production
      id = 30;
      interface = "eth0";
      addresses = [ "10.0.30.1/24" ];
      priority = 7;  # Highest priority
    };
  };
};

# Firewall isolation (suggested feature)
hypervisor.network.firewall.zones = {
  dev = { vlans = [ 10 ]; allowFrom = [ "10.0.10.0/24" ]; };
  staging = { vlans = [ 20 ]; allowFrom = [ "10.0.20.0/24" "10.0.30.0/24" ]; };
  prod = { vlans = [ 30 ]; allowFrom = [ "10.0.30.0/24" ]; };
};
```

### Use Case: Guest Network Isolation

**Scenario:** Isolated guest network with internet access only

```nix
hypervisor.network.vlan = {
  enable = true;
  interfaces = {
    "vlan200" = {  # Guest network
      id = 200;
      interface = "eth0";
      dhcp = true;  # DHCP for guests
    };
  };
};

# Firewall rules (suggested)
hypervisor.network.firewall = {
  zones.guest = {
    vlans = [ 200 ];
    allowInternet = true;
    blockLocal = true;  # Can't access internal networks
  };
};
```

---

## 🔧 Advanced Features

### Combined MAC + VLAN + IP

**Complete network transformation:**
```nix
{
  imports = [
    ./modules/network-settings/mac-spoofing.nix
    ./modules/network-settings/ip-spoofing.nix
    ./modules/network-settings/vlan.nix
  ];
  
  hypervisor.network = {
    # Random MAC per VLAN
    macSpoof = {
      enable = true;
      mode = "random";
      interfaces = {
        "eth0".enable = true;
        "vlan10".enable = true;
        "vlan20".enable = true;
      };
    };
    
    # VLANs
    vlan = {
      enable = true;
      interfaces = {
        "vlan10" = { id = 10; interface = "eth0"; addresses = [ "192.168.10.2/24" ]; };
        "vlan20" = { id = 20; interface = "eth0"; addresses = [ "192.168.20.2/24" ]; };
      };
    };
    
    # IP rotation per VLAN
    ipSpoof = {
      enable = true;
      mode = "rotation";
      interfaces = {
        "vlan10".ipPool = [ "192.168.10.100" "192.168.10.101" ];
        "vlan20".ipPool = [ "192.168.20.100" "192.168.20.101" ];
      };
    };
  };
}
```

---

## 📊 Performance Impact

### Resource Usage

**Network Discovery:**
- Quick scan: ~2-5 seconds
- Full scan: ~10-30 seconds  
- Wireless scan: ~5-15 seconds
- Minimal CPU/memory impact

**VLAN Overhead:**
- CPU: <1% per VLAN
- Memory: ~1MB per VLAN
- Bandwidth: 4 bytes per packet (VLAN tag)
- Latency: Negligible (<0.1ms)

**MAC Spoofing:**
- One-time at boot
- No runtime overhead

**IP Rotation:**
- Minimal (timer-based)
- ~0.1% CPU during rotation

### Optimization Tips

1. **Cache Discovery Results** - Reuse scan data
2. **Limit Scan Range** - Scan only needed subnets
3. **Use nmap** - Faster than ping sweep
4. **Adjust Timeouts** - Balance speed vs accuracy
5. **Schedule Scans** - Off-peak hours for full scans

---

## 🛡️ Security Considerations

### Network Discovery

**Safe:**
- Passive interface inspection ✅
- Local network scanning ✅
- Gateway detection ✅

**Potentially Detectable:**
- Active host scanning ⚠️
- Service port scanning ⚠️
- Wireless scanning ⚠️

**Recommendation:** Use discovery tools only on networks you own or have permission to scan.

### VLAN Security

**Benefits:**
- Network segmentation ✅
- Traffic isolation ✅
- Security zone creation ✅

**Risks:**
- VLAN hopping attacks ⚠️
- Misconfiguration ⚠️
- Inter-VLAN routing issues ⚠️

**Mitigation:**
- Use firewall rules between VLANs
- Disable unused VLANs
- Monitor VLAN traffic
- Implement access controls

---

## 📖 Complete Examples

### Example 1: Home Lab with VLANs

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./modules/network-settings/vlan.nix
  ];
  
  hypervisor.network.vlan = {
    enable = true;
    
    interfaces = {
      # Management VLAN
      "vlan1" = {
        id = 1;
        interface = "eth0";
        addresses = [ "192.168.1.10/24" ];
        gateway = "192.168.1.1";
        priority = 7;
      };
      
      # VM Network
      "vlan10" = {
        id = 10;
        interface = "eth0";
        addresses = [ "192.168.10.1/24" ];
      };
      
      # Storage Network
      "vlan20" = {
        id = 20;
        interface = "eth1";  # Dedicated storage interface
        addresses = [ "10.0.20.1/24" ];
        mtu = 9000;  # Jumbo frames
      };
      
      # Guest Network
      "vlan200" = {
        id = 200;
        interface = "eth0";
        dhcp = true;
      };
    };
  };
}
```

### Example 2: Discovery-Driven Configuration

```bash
#!/usr/bin/env bash
# Auto-configure network using discovery

# Discover network
sudo /etc/hypervisor/scripts/network-discover.sh full eth0

# Get recommendations
SAFE_IPS=$(sudo /etc/hypervisor/scripts/network-discover.sh safe-ips eth0 | grep "Recommended" -A 10)
VLAN_IDS=$(sudo /etc/hypervisor/scripts/network-discover.sh vlan | grep "Recommended" -A 5)

# Use in configuration
cat > /etc/nixos/auto-network.nix <<EOF
{ config, lib, pkgs, ... }:
{
  imports = [
    ./modules/network-settings/vlan.nix
    ./modules/network-settings/ip-spoofing.nix
  ];
  
  # Auto-generated config using discovered settings
  hypervisor.network = {
    vlan.interfaces."vlan10" = {
      id = 10;  # From recommendation
      interface = "eth0";
      addresses = [ "192.168.10.100/24" ];  # From safe IPs
    };
    
    ipSpoof.mode = "alias";
    ipSpoof.interfaces."eth0".aliases = [
      "192.168.1.100/24"  # From safe IP scan
      "192.168.1.101/24"
      "192.168.1.102/24"
    ];
  };
}
EOF
```

### Example 3: Complete Network Stack

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./modules/network-settings/mac-spoofing.nix
    ./modules/network-settings/ip-spoofing.nix
    ./modules/network-settings/vlan.nix
  ];
  
  hypervisor.network = {
    # MAC spoofing
    macSpoof = {
      enable = true;
      mode = "vendor-preserve";
      interfaces."eth0" = {
        enable = true;
        vendorPrefix = "00:1A:2B";  # Intel
      };
    };
    
    # VLANs
    vlan = {
      enable = true;
      interfaces = {
        "vlan10" = { id = 10; interface = "eth0"; addresses = [ "192.168.10.1/24" ]; };
        "vlan20" = { id = 20; interface = "eth0"; addresses = [ "192.168.20.1/24" ]; };
      };
    };
    
    # IP aliases
    ipSpoof = {
      enable = true;
      mode = "alias";
      interfaces = {
        "vlan10".aliases = [ "192.168.10.2/24" "192.168.10.3/24" ];
      };
    };
  };
}
```

---

## 🎓 Best Practices

### Network Discovery

1. **Scan Responsibly**
   - Only scan networks you own/control
   - Respect network policies
   - Avoid aggressive scanning

2. **Use Discovery for Planning**
   - Run discovery before configuration
   - Identify conflicts early
   - Plan IP allocation

3. **Cache Results**
   - Discovery results saved in `/var/lib/hypervisor/network-discovery/`
   - Reuse recent scans
   - Update periodically

4. **Validate Recommendations**
   - Verify suggested IPs are truly unused
   - Test VLAN IDs before committing
   - Cross-reference with network documentation

### VLAN Management

1. **Plan VLAN Scheme**
   - Document VLAN assignments
   - Use consistent ID ranges
   - Reserve IDs for future expansion

2. **Test Isolation**
   - Verify VLANs are actually isolated
   - Test inter-VLAN routing
   - Confirm firewall rules work

3. **Monitor Performance**
   - Check for VLAN congestion
   - Measure latency per VLAN
   - Track bandwidth usage

4. **Secure Configuration**
   - Disable unused VLANs
   - Implement VLAN ACLs
   - Use VLAN pruning on trunks

---

## 🔍 Troubleshooting

### Discovery Issues

**"No hosts found"**
```bash
# Check network connectivity
ping $(detect_gateway eth0)

# Try with nmap
sudo nmap -sn 192.168.1.0/24

# Check firewall
sudo iptables -L -n
```

**"Cannot detect network range"**
```bash
# Check interface has IP
ip addr show eth0

# Verify routing
ip route show

# Check link status
ip link show eth0
```

### VLAN Issues

**"VLAN interface not created"**
```bash
# Check kernel module
lsmod | grep 8021q

# Load module manually
sudo modprobe 8021q

# Verify configuration
ip -d link show | grep vlan
```

**"No connectivity on VLAN"**
```bash
# Check VLAN is up
ip link show vlan10

# Verify IP address
ip addr show vlan10

# Test routing
ip route show

# Check switch configuration
# (VLAN must be configured on connected switch)
```

**"VLAN traffic not isolated"**
```bash
# Verify VLAN IDs
ip -d link show | grep "vlan id"

# Check firewall rules
sudo iptables -L -n -v

# Test isolation
ping -I vlan10 <host_on_vlan20>  # Should fail
```

---

## 📊 Monitoring and Diagnostics

### VLAN Monitoring

**View VLAN status:**
```bash
# List all VLANs
ip -d link show type vlan

# Show VLAN details
ip -d link show vlan10

# Check VLAN traffic stats
ip -s link show vlan10
```

**Monitor VLAN traffic:**
```bash
# Watch traffic
watch -n 1 'ip -s link show vlan10'

# Capture VLAN traffic
sudo tcpdump -i vlan10

# View logs
journalctl -t vlan -f
```

### Discovery Monitoring

**Cache locations:**
```bash
# Discovery results
ls -la /var/lib/hypervisor/network-discovery/

# View cached scan
cat /var/lib/hypervisor/network-discovery/eth0_discovery.json | jq

# Interface info
cat /var/lib/hypervisor/network-discovery/eth0_info.json
```

**Update discovery:**
```bash
# Re-scan network
sudo /etc/hypervisor/scripts/network-discover.sh full eth0

# Clear cache
sudo rm -rf /var/lib/hypervisor/network-discovery/*
```

---

## 🚀 Quick Reference

### Network Discovery Commands

```bash
# Interactive menu
sudo network-discover.sh

# Quick scan
sudo network-discover.sh quick eth0

# Safe IPs
sudo network-discover.sh safe-ips eth0

# VLAN discovery
sudo network-discover.sh vlan

# Wireless scan
sudo network-discover.sh wireless wlan0
```

### VLAN Commands

```bash
# Setup wizard
sudo vlan-wizard.sh

# View VLANs
ip -d link show type vlan

# Add VLAN manually
sudo ip link add link eth0 name vlan10 type vlan id 10
sudo ip addr add 192.168.10.1/24 dev vlan10
sudo ip link set vlan10 up

# Remove VLAN
sudo ip link delete vlan10
```

### Discovery Library Functions

```bash
source /etc/hypervisor/scripts/lib/network-discovery.sh

get_physical_interfaces         # List physical NICs
detect_network_range eth0       # Get CIDR
scan_active_hosts eth0          # Find active hosts
recommend_safe_ips eth0 5       # Get 5 safe IPs
recommend_vlan_ids 3            # Get 3 unused VLAN IDs
detect_gateway eth0             # Find gateway
lookup_mac_vendor "00:1A:2B..." # Identify vendor
```

---

## 📚 Related Documentation

- [Network Spoofing Guide](NETWORK_SPOOFING_GUIDE.md) - MAC/IP spoofing
- [Network Spoofing Quick Start](NETWORK_SPOOFING_QUICK_START.md) - Quick reference
- [Network Configuration](NETWORK_CONFIGURATION.md) - General networking
- [Security Considerations](SECURITY_CONSIDERATIONS.md) - Security best practices

---

**Network discovery and VLANs make your network configuration intelligent and conflict-free!** 🎯
