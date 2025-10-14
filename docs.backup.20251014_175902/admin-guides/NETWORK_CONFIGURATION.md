# Network Configuration Guide

Complete guide to network configuration for optimal VM performance.

---

## Table of Contents

- [Network Bridge Overview](#network-bridge-overview)
- [Bridge Configuration Wizard](#bridge-configuration-wizard)
- [Performance Optimization](#performance-optimization)
- [Network Modes Comparison](#network-modes-comparison)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Network Bridge Overview

### What is a Network Bridge?

A network bridge connects your VMs directly to your physical network, making them appear as physical devices with their own IP addresses.

**Without Bridge (NAT mode):**
```
Internet → Router → Host (192.168.1.10)
                     ↓ NAT
                     VM (10.0.2.15)
```

**With Bridge:**
```
Internet → Router → Host (192.168.1.10)
                 ↘
                   VM (192.168.1.20)
```

### Benefits of Bridged Networking

✅ **Direct Network Access**
- VMs get IP addresses from your router (DHCP)
- VMs can be accessed directly from other devices
- No port forwarding needed

✅ **Better Performance**
- Reduced latency (no NAT overhead)
- Full network speed available to VMs
- Hardware offloading capabilities

✅ **Network Services**
- Run servers that other devices can access
- Network discovery works (mDNS, Bonjour)
- Easier network management

✅ **Multiple VMs**
- Each VM gets its own IP address
- VMs can communicate with each other
- Isolated from host network stack

### When to Use Bridged vs NAT

**Use Bridge When:**
- 🏠 Running on a home network with DHCP
- 🌐 VMs need to provide network services
- ⚡ Performance is critical (storage, databases)
- 🔌 Multiple VMs need to communicate

**Use NAT When:**
- 🔒 Stricter isolation needed from host network
- 📱 On untrusted networks (public WiFi, hotels)
- 🚫 Can't modify network infrastructure
- 💻 Testing/development only

---

## Bridge Configuration Wizard

### Running the Wizard

From the first-boot setup wizard or manually:
```bash
sudo bash /etc/hypervisor/scripts/bridge_helper.sh
```

### Wizard Steps

#### 1. Interface Detection

The wizard automatically detects physical network interfaces:
- ✅ Filters out virtual/loopback interfaces
- ✅ Shows interface status (UP/DOWN)
- ✅ Displays network speed and duplex
- ✅ Indicates active interfaces with IP addresses

**Example output:**
```
eth0    UP 1000Mb/s (Active)
eth1    UP 100Mb/s
wlan0   DOWN
```

**Recommendation:** Choose the interface marked `(Active)` - this is your primary connection.

#### 2. Interface Validation

The wizard validates your selection:
- ✅ Interface exists and is accessible
- ⚠️ Warns if interface is DOWN
- ⚠️ Warns if already part of another bridge
- ✅ Shows detailed interface information

#### 3. Performance Profile Selection

Choose the optimal configuration:

**Standard Profile (MTU 1500) - Recommended**
- ✅ Compatible with all networks
- ✅ Works over internet connections
- ✅ Reliable for most use cases
- ✅ No special network requirements

**Performance Profile (MTU 9000) - Advanced**
- ⚡ 5-15% higher throughput for large transfers
- ⚡ Better for storage/backup workloads
- ⚠️ Requires ALL devices support jumbo frames
- ⚠️ LAN-only (doesn't work over internet)
- ⚠️ May cause issues if not supported

**Custom Profile**
- 🔧 Manual MTU configuration
- 🔧 For specific requirements (VLANs, tunnels)
- 🔧 Advanced users only

#### 4. Bridge Configuration

The wizard creates three systemd-networkd files:

**`/etc/systemd/network/br0.netdev`** - Bridge device
```ini
[NetDev]
Name=br0
Kind=bridge
MTUBytes=1500

[Bridge]
DefaultPVID=none
VLANFiltering=no
STP=no  # STP off for performance
```

**`/etc/systemd/network/br0.network`** - Bridge network config
```ini
[Match]
Name=br0

[Network]
DHCP=yes
IPv6AcceptRA=yes

[Link]
MTUBytes=1500
Multicast=yes
AllMulticast=yes
```

**`/etc/systemd/network/eth0.network`** - Physical interface
```ini
[Match]
Name=eth0

[Network]
Bridge=br0

[Link]
MTUBytes=1500
```

#### 5. Application Options

**Restart Network (Quick)**
- ✅ Applies immediately
- ⚠️ May drop network connections briefly
- ✅ Best for local/console access

**Reboot System (Safest)**
- ✅ Guaranteed clean state
- ✅ No service interruption
- ✅ Best for remote/SSH access

**Manual Application**
- Configuration saved for later
- Apply when ready: `sudo systemctl restart systemd-networkd`

---

## Performance Optimization

### MTU Configuration

**MTU (Maximum Transmission Unit)** is the largest packet size that can be sent.

#### MTU Values Explained

**1500 (Standard Ethernet)**
- Default for all Ethernet networks
- Maximum for internet traffic
- Compatible everywhere
- Use for: General purpose, WAN, mixed networks

**9000 (Jumbo Frames)**
- 5-15% better throughput for large files
- ~30% fewer packets for bulk transfers
- Reduces CPU overhead
- Use for: Storage, backups, high-throughput LAN

**1450 (Reduced MTU)**
- Accounts for VLAN tags (4 bytes)
- Accounts for tunnel overhead (50+ bytes)
- Use for: VPN, GRE tunnels, VXLAN

**Custom Values:**
- 1472: For ICMP ping testing
- 1492: For PPPoE connections
- 4000-8000: Custom jumbo frame sizes

#### MTU Performance Testing

Test actual network MTU:
```bash
# Test standard MTU
ping -M do -s 1472 -c 4 192.168.1.1  # 1472 + 28 = 1500

# Test jumbo frames (if supported)
ping -M do -s 8972 -c 4 192.168.1.1  # 8972 + 28 = 9000
```

If packets are fragmented, MTU is too high.

### Network Offloading

Modern NICs offload processing to hardware for better performance.

#### Check Current Offloading Settings

```bash
# View all offloading features
ethtool -k br0

# Common features:
#   tx-checksumming: on    ← Good for performance
#   rx-checksumming: on    ← Good for performance
#   scatter-gather: on     ← Enables TSO/GSO
#   tcp-segmentation-offload: on  ← Critical for throughput
#   generic-segmentation-offload: on
#   generic-receive-offload: on
```

#### Enable All Offloading (Maximum Performance)

```bash
# Enable hardware offloading features
sudo ethtool -K br0 tx on rx on sg on tso on gso on gro on

# Make permanent: add to systemd-networkd config
```

Add to `/etc/systemd/network/br0.network`:
```ini
[Link]
GenericSegmentationOffload=yes
TCPSegmentationOffload=yes
GenericReceiveOffload=yes
```

### Bridge Performance Tuning

#### Disable STP (Spanning Tree Protocol)

STP adds latency for topology changes. Safe to disable for simple bridges.

```ini
[Bridge]
STP=no  # Saves ~2-30 seconds on bridge startup
```

#### Multicast/Broadcast Optimization

```ini
[Link]
Multicast=yes        # Enable multicast (needed for mDNS, DHCP)
AllMulticast=yes     # Don't filter multicast addresses
```

### VM Network Performance Settings

In your VM profiles, use VirtIO for best performance:

```json
{
  "network": {
    "bridge": "br0",
    "model": "virtio",
    "mtu": 9000
  }
}
```

**VirtIO benefits:**
- 2-3x better throughput vs e1000
- Lower CPU usage
- Direct guest/host communication
- Modern driver support

---

## Network Modes Comparison

| Feature | NAT (default) | Bridge (br0) | Bridge + Jumbo |
|---------|---------------|--------------|----------------|
| **Setup Complexity** | None | Easy | Medium |
| **VM → Internet** | ✅ Yes | ✅ Yes | ✅ Yes |
| **VM → Host** | ✅ Yes | ✅ Yes | ✅ Yes |
| **VM ← Network** | ❌ No (port forward) | ✅ Yes | ✅ Yes |
| **VM ← Internet** | ❌ No | ✅ Yes (if exposed) | ✅ Yes |
| **Throughput** | ~1-5 Gbps | ~5-10 Gbps | ~9-10 Gbps |
| **Latency** | +1-2ms (NAT) | ~0.1ms | ~0.1ms |
| **IP Assignment** | 10.0.2.x (QEMU) | Router DHCP | Router DHCP |
| **Network Requirements** | None | Physical interface | Jumbo frame support |

### Typical Performance Results

**Storage/Backup Workloads (1GB file transfer):**
- NAT: 800 MB/s, 90% CPU
- Bridge (1500 MTU): 1100 MB/s, 60% CPU
- Bridge (9000 MTU): 1200 MB/s, 40% CPU

**Web Server (many small requests):**
- NAT: 5,000 req/s
- Bridge: 5,800 req/s (NAT overhead minimal here)

**Database (mixed workload):**
- NAT: +2ms average latency
- Bridge: +0.1ms average latency

---

## Troubleshooting

### Bridge Not Created After Restart

**Symptoms:** Bridge doesn't appear in `ip addr show`

**Causes & Fixes:**

1. **systemd-networkd not enabled**
   ```bash
   sudo systemctl enable --now systemd-networkd
   sudo systemctl restart systemd-networkd
   ```

2. **Configuration syntax error**
   ```bash
   # Check logs
   sudo journalctl -u systemd-networkd -n 50
   
   # Validate config
   sudo networkctl status br0
   ```

3. **Interface conflict**
   ```bash
   # Check if interface is managed by NetworkManager
   nmcli device status
   
   # Disable NetworkManager for that interface
   sudo nmcli device set eth0 managed no
   ```

### Bridge Has No IP Address

**Symptoms:** Bridge exists but no IP: `ip addr show br0`

**Causes & Fixes:**

1. **DHCP not running**
   ```bash
   # Check DHCP client status
   sudo journalctl -u systemd-networkd | grep -i dhcp
   
   # Restart DHCP
   sudo systemctl restart systemd-networkd
   ```

2. **Router not assigning IP**
   ```bash
   # Manual DHCP request
   sudo dhclient br0
   
   # Check if DHCP server responds
   sudo dhcpcd -d br0
   ```

3. **Static IP needed**
   
   Edit `/etc/systemd/network/br0.network`:
   ```ini
   [Network]
   Address=192.168.1.50/24
   Gateway=192.168.1.1
   DNS=192.168.1.1
   ```

### VMs Not Getting Network Access

**Symptoms:** VM can't reach internet or network

**Diagnostic steps:**

1. **Check bridge status**
   ```bash
   ip link show br0  # Should be UP
   ip addr show br0  # Should have IP
   bridge link       # Should show eth0 as member
   ```

2. **Check VM is connected to bridge**
   ```bash
   virsh domiflist your-vm-name
   # Should show bridge 'br0'
   ```

3. **Check VM network configuration**
   ```bash
   # Inside VM
   ip addr show      # Should have IP
   ip route show     # Should have default gateway
   ping 8.8.8.8      # Test connectivity
   ```

4. **Check firewall**
   ```bash
   # Ensure bridge traffic is allowed
   sudo iptables -L -n | grep br0
   ```

### Jumbo Frames Not Working

**Symptoms:** High packet loss, poor performance with MTU 9000

**Fix:**

1. **Verify switch support**
   - All switches between hosts must support jumbo frames
   - Check switch documentation/configuration

2. **Test with ping**
   ```bash
   # This should work without fragmentation
   ping -M do -s 8972 -c 4 <destination>
   ```

3. **Check all devices in path**
   ```bash
   # On each device
   ip link show | grep mtu
   
   # All should show 9000
   ```

4. **Fall back to standard MTU**
   ```bash
   # Edit bridge config
   sudo vim /etc/systemd/network/br0.netdev
   # Change MTUBytes=9000 to MTUBytes=1500
   
   sudo systemctl restart systemd-networkd
   ```

---

## Advanced Configuration

### Multiple Bridges

Create separate bridges for different purposes:

```bash
# Create DMZ bridge
sudo bash /etc/hypervisor/scripts/bridge_helper.sh
# Choose eth1, name it br-dmz

# Create management bridge  
sudo bash /etc/hypervisor/scripts/bridge_helper.sh
# Choose eth2, name it br-mgmt
```

Use cases:
- `br0` (br-lan): Primary network for general VMs
- `br-dmz`: Public-facing VMs (web servers)
- `br-mgmt`: Management network (monitoring, backups)

### VLAN Support

Add VLAN tagging to bridge:

Create `/etc/systemd/network/br0.netdev`:
```ini
[NetDev]
Name=br0
Kind=bridge

[Bridge]
DefaultPVID=100
VLANFiltering=yes
```

Add VLAN to interface:
```bash
# Create VLAN interface
ip link add link eth0 name eth0.100 type vlan id 100
ip link set eth0.100 master br0
```

### Bridge Firewall Rules

Filter traffic at bridge level:

```bash
# Enable bridge netfilter
sudo modprobe br_netfilter

# Add to /etc/sysctl.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Apply
sudo sysctl -p
```

Then use iptables rules on FORWARD chain.

### Static IP Assignment

Edit `/etc/systemd/network/br0.network`:
```ini
[Network]
# Static IP instead of DHCP
Address=192.168.1.50/24
Gateway=192.168.1.1
DNS=192.168.1.1
DNS=8.8.8.8

# Remove DHCP=yes line
```

### Bonding + Bridge (High Availability)

Create bond, then bridge it:

1. Create bond0 from eth0 + eth1
2. Create br0 on top of bond0
3. VMs connect to br0
4. Automatic failover if one NIC fails

---

## Performance Monitoring

### Monitor Bridge Statistics

```bash
# Interface statistics
ip -s link show br0

# Packet counters
watch -n 1 'ip -s link show br0 | grep -A 2 "RX:"'

# Detailed statistics
ethtool -S br0
```

### Network Performance Testing

**iPerf3 between VMs:**
```bash
# On VM1 (server)
iperf3 -s

# On VM2 (client)
iperf3 -c <VM1-IP> -t 60

# Expected results:
# Standard bridge (MTU 1500): 5-10 Gbps
# Jumbo frames (MTU 9000): 9-10 Gbps
```

**Latency testing:**
```bash
# Ping test
ping -c 100 <VM-IP> | tail -1

# Expected:
# NAT: ~1-2ms
# Bridge: ~0.1-0.3ms
```

---

## Summary

✅ **Use the bridge configuration wizard** - automated detection and optimal settings
✅ **Choose Standard profile** for most networks (MTU 1500)
✅ **Choose Performance profile** only for LAN with jumbo frame support (MTU 9000)
✅ **Enable hardware offloading** for maximum throughput
✅ **Use VirtIO** network drivers in VMs
✅ **Monitor and test** performance after configuration

The bridge wizard handles all complexity and provides high-performance networking out of the box!

---

## Quick Reference

```bash
# Create bridge (wizard)
sudo bash /etc/hypervisor/scripts/bridge_helper.sh

# Check bridge status
ip addr show br0
bridge link

# Restart networking
sudo systemctl restart systemd-networkd

# View logs
sudo journalctl -u systemd-networkd -f

# Test performance
iperf3 -s  # On one VM
iperf3 -c <IP> -t 60  # On another VM
```
