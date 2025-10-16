# Network Enhancements - Features & Recommendations

## Overview

Comprehensive network discovery, VLAN support, and intelligent recommendations have been added to the Hyper-NixOS network configuration system.

---

## ✨ New Features Implemented

### 1. Network Discovery Library

**File**: `/workspace/scripts/lib/network-discovery.sh`

**Capabilities**:
- ✅ Physical interface detection
- ✅ Wireless interface detection  
- ✅ Network range detection (CIDR)
- ✅ Active host scanning (ping sweep/nmap)
- ✅ Gateway and router discovery
- ✅ DNS server detection
- ✅ DHCP server detection
- ✅ VLAN discovery and recommendations
- ✅ MAC vendor lookup (OUI database)
- ✅ Safe IP recommendations (conflict avoidance)
- ✅ Network speed/bandwidth detection
- ✅ Wireless network scanning
- ✅ ARP cache analysis
- ✅ Comprehensive network profiling

### 2. Network Discovery Utility

**File**: `/workspace/scripts/network-discover.sh`

**Modes**:
- Quick Scan - Fast active host detection
- Full Scan - Comprehensive network analysis
- Interface Info - Detailed interface stats
- Gateway Scan - Service detection on gateway
- VLAN Discovery - Find existing VLANs
- Wireless Scan - WiFi network enumeration
- ARP Analysis - Cache inspection
- Safe IP Recommendations - Unused IP finder
- MAC Vendor Lookup - Identify hardware

**Usage**:
```bash
# Interactive menu
sudo /etc/hypervisor/scripts/network-discover.sh

# Quick scan
sudo /etc/hypervisor/scripts/network-discover.sh quick eth0

# Full network analysis
sudo /etc/hypervisor/scripts/network-discover.sh full eth0

# Find safe IPs
sudo /etc/hypervisor/scripts/network-discover.sh safe-ips eth0
```

### 3. VLAN Configuration Module

**File**: `/workspace/modules/network-settings/vlan.nix`

**Features**:
- ✅ 802.1Q VLAN tagging
- ✅ Multiple VLANs per physical interface
- ✅ VLAN ID management (1-4094)
- ✅ Per-VLAN IP configuration (static/DHCP)
- ✅ VLAN priority (802.1p)
- ✅ MTU configuration
- ✅ Trunk port configuration
- ✅ Native VLAN support
- ✅ VLAN filtering

### 4. VLAN Setup Wizard

**File**: `/workspace/scripts/setup/vlan-wizard.sh`

**Features**:
- Interactive VLAN configuration
- Parent interface selection
- VLAN ID recommendations (avoid conflicts)
- IP addressing modes (DHCP/Static/None)
- Safe IP suggestions based on network scan
- Automatic NixOS config generation
- Multiple VLAN support in one session

---

## 🎯 Intelligent Recommendations

### Network Discovery Intelligence

The system now provides **smart recommendations** based on actual network scanning:

**1. Safe IP Address Recommendations**
- Scans network for active hosts
- Identifies used IP addresses
- Recommends IPs outside DHCP range (typically .100-.250)
- Avoids conflicts automatically

**2. VLAN ID Recommendations**
- Detects existing VLANs
- Recommends unused VLAN IDs
- Follows standard VLAN ranges:
  - 10-99: User/Department VLANs
  - 100-199: Server VLANs
  - 200-299: Guest/DMZ VLANs

**3. MAC Vendor Intelligence**
- Identifies MAC address vendors
- Provides common vendor prefixes for spoofing
- Helps choose realistic MAC addresses

**4. Network Topology Mapping**
- Discovers gateway
- Identifies DNS servers
- Detects DHCP server
- Maps active hosts

---

## 🚀 Suggested Additional Features

### Priority 1: High Value, Easy to Implement

**1. IPv6 Support** ⭐⭐⭐⭐⭐
- IPv6 address spoofing
- IPv6 neighbor discovery
- SLAAC configuration
- DHCPv6 support

**2. Traffic Shaping** ⭐⭐⭐⭐⭐
- Bandwidth limiting per interface/VLAN
- QoS (Quality of Service) rules
- Traffic prioritization
- Rate limiting

**3. Network Bonding/Teaming** ⭐⭐⭐⭐
- Link aggregation (802.3ad)
- Load balancing modes
- Failover support
- Active-backup configuration

**4. Bridge Management** ⭐⭐⭐⭐
- Software bridge creation
- Bridge VLAN filtering
- STP/RSTP support
- Bridge port management

**5. Network Namespaces** ⭐⭐⭐⭐
- Isolated network environments
- Per-VM network namespaces
- Namespace-based testing
- Container-like isolation

### Priority 2: Advanced Features

**6. DNS Management** ⭐⭐⭐
- Local DNS server (dnsmasq/bind)
- DNS spoofing for testing
- Split-horizon DNS
- Custom DNS records

**7. DHCP Server** ⭐⭐⭐
- Per-VLAN DHCP pools
- Static IP reservations
- DHCP relay agent
- Boot options (PXE)

**8. Network Monitoring** ⭐⭐⭐
- Real-time traffic monitoring
- Bandwidth usage graphs
- Connection tracking
- Flow analysis (NetFlow)

**9. Packet Capture** ⭐⭐⭐
- tcpdump integration
- Wireshark capture support
- Filtered packet capture
- Automated packet analysis

**10. Firewall Zones** ⭐⭐⭐
- Zone-based firewall
- Per-VLAN security policies
- DMZ configuration
- Inter-zone rules

### Priority 3: Security & Privacy

**11. Tor Integration** ⭐⭐⭐⭐
- Transparent Tor proxy
- Per-VM Tor routing
- Tor bridge configuration
- Hidden service support

**12. VPN Management** ⭐⭐⭐⭐
- OpenVPN server/client
- WireGuard configuration
- IPsec/IKEv2 support
- VPN kill switch

**13. IDS/IPS** ⭐⭐⭐
- Suricata integration
- Snort rules
- Intrusion detection
- Automated blocking

**14. SSL/TLS Inspection** ⭐⭐
- Certificate management
- MITM proxy (for testing)
- Certificate pinning detection
- TLS fingerprinting

### Priority 4: Advanced Networking

**15. SD-WAN Features** ⭐⭐
- Multi-path routing
- Path optimization
- Failover automation
- Application-aware routing

**16. Network Virtualization** ⭐⭐⭐
- VXLANs
- GRE tunnels
- GENEVE support
- Overlay networks

**17. Load Balancing** ⭐⭐⭐
- Round-robin
- Least connections
- Source IP hashing
- Health checking

**18. Protocol Analysis** ⭐⭐
- Deep packet inspection
- Protocol decoding
- Traffic classification
- Anomaly detection

---

## 📊 Recommended Settings by Use Case

### Use Case 1: Privacy-Focused Home Lab

**Recommended Settings**:
```nix
hypervisor.network = {
  # MAC spoofing for privacy
  macSpoof = {
    enable = true;
    mode = "random";
    interfaces."wlan0" = {
      enable = true;
      randomizeOnBoot = true;
    };
  };
  
  # VPN for all traffic
  vpn = {
    enable = true;
    killSwitch = true;  # Suggested feature
  };
  
  # DNS privacy
  dns = {
    servers = [ "1.1.1.1" "1.0.0.1" ];  # Cloudflare DNS
    dnssec = true;  # Suggested feature
  };
};
```

### Use Case 2: Development/Testing Lab

**Recommended Settings**:
```nix
hypervisor.network = {
  # Multiple isolated VLANs
  vlan = {
    enable = true;
    interfaces = {
      "vlan10" = {  # Development
        id = 10;
        interface = "eth0";
        addresses = [ "192.168.10.1/24" ];
      };
      "vlan20" = {  # Testing
        id = 20;
        interface = "eth0";
        addresses = [ "192.168.20.1/24" ];
      };
      "vlan30" = {  # Staging
        id = 30;
        interface = "eth0";
        addresses = [ "192.168.30.1/24" ];
      };
    };
  };
  
  # IP aliases for multi-IP testing
  ipSpoof = {
    enable = true;
    mode = "alias";
    interfaces."eth0".aliases = [
      "10.0.0.10/24"
      "10.0.0.11/24"
      "10.0.0.12/24"
    ];
  };
  
  # Bridge for VM networking
  bridges = {  # Suggested feature
    "br0" = {
      interfaces = [ "vlan10" ];
    };
  };
};
```

### Use Case 3: Penetration Testing Lab

**Recommended Settings**:
```nix
hypervisor.network = {
  # MAC and IP rotation
  macSpoof = {
    enable = true;
    mode = "random";
    interfaces."eth0".randomizeOnBoot = true;
  };
  
  ipSpoof = {
    enable = true;
    mode = "rotation";
    interfaces."eth0" = {
      ipPool = [ "10.0.0.100" "10.0.0.101" "10.0.0.102" ];
      rotationInterval = 600;  # 10 minutes
    };
  };
  
  # Proxy chains for anonymity
  ipSpoof.proxy = {
    enable = true;
    randomizeOrder = true;
    proxies = [
      { type = "socks5"; host = "proxy1.local"; port = 1080; }
      { type = "socks5"; host = "proxy2.local"; port = 1080; }
    ];
  };
  
  # Packet capture
  monitoring = {  # Suggested feature
    packetCapture = true;
    captureFilter = "not port 22";  # Exclude SSH
  };
};
```

### Use Case 4: Multi-Tenant/VLAN Isolation

**Recommended Settings**:
```nix
hypervisor.network = {
  vlan = {
    enable = true;
    
    # Management VLAN
    interfaces."vlan1" = {
      id = 1;
      interface = "eth0";
      addresses = [ "192.168.1.2/24" ];
      priority = 7;  # Highest priority
    };
    
    # Tenant VLANs
    interfaces."vlan10" = {
      id = 10;
      interface = "eth0";
      addresses = [ "192.168.10.1/24" ];
    };
    
    interfaces."vlan20" = {
      id = 20;
      interface = "eth0";
      addresses = [ "192.168.20.1/24" ];
    };
    
    # DMZ VLAN
    interfaces."vlan200" = {
      id = 200;
      interface = "eth0";
      addresses = [ "192.168.200.1/24" ];
    };
  };
  
  # Firewall zones per VLAN
  firewall = {  # Enhanced suggested feature
    zones = {
      management = {
        vlans = [ 1 ];
        allowFrom = [ "192.168.1.0/24" ];
      };
      tenant1 = {
        vlans = [ 10 ];
        isolate = true;  # No inter-VLAN
      };
      dmz = {
        vlans = [ 200 ];
        allowFrom = [ "0.0.0.0/0" ];  # Internet-facing
      };
    };
  };
};
```

### Use Case 5: High-Performance Server

**Recommended Settings**:
```nix
hypervisor.network = {
  # Network bonding for bandwidth
  bonding = {  # Suggested feature
    enable = true;
    "bond0" = {
      interfaces = [ "eth0" "eth1" ];
      mode = "802.3ad";  # LACP
      transmit-hash-policy = "layer3+4";
    };
  };
  
  # Jumbo frames
  mtu = {
    enable = true;
    interfaces = {
      "eth0".mtu = 9000;
      "eth1".mtu = 9000;
    };
  };
  
  # Traffic shaping
  qos = {  # Suggested feature
    enable = true;
    interfaces."bond0" = {
      uploadLimit = "900mbit";
      downloadLimit = "900mbit";
      priorityClasses = [
        { name = "high"; ports = [ 22 443 ]; bandwidth = "30%"; }
        { name = "medium"; ports = [ 80 8080 ]; bandwidth = "50%"; }
        { name = "low"; default = true; bandwidth = "20%"; }
      ];
    };
  };
};
```

---

## 🔧 Implementation Suggestions

### Quick Wins (Easy to Add)

**1. IPv6 Support**
```nix
# modules/network-settings/ipv6-spoofing.nix
hypervisor.network.ipv6Spoof = {
  enable = true;
  mode = "random-suffix";  # Keep prefix, randomize suffix
  interfaces."eth0".enable = true;
};
```

**2. DNS Server**
```nix
# modules/network-settings/dns-server.nix
hypervisor.network.dns = {
  enable = true;
  type = "dnsmasq";  # or "bind"
  vlans = {
    "vlan10" = {
      range = "192.168.10.100,192.168.10.200";
      leaseTime = "24h";
    };
  };
};
```

**3. Traffic Monitoring**
```nix
# modules/network-settings/traffic-monitor.nix
hypervisor.network.monitoring = {
  enable = true;
  interfaces = [ "eth0" "vlan10" ];
  prometheus = true;  # Export metrics
};
```

### Medium Effort (Valuable Features)

**4. Network Bonding**
```nix
# modules/network-settings/bonding.nix
hypervisor.network.bonding = {
  enable = true;
  bonds = {
    "bond0" = {
      interfaces = [ "eth0" "eth1" ];
      mode = "active-backup";  # or "802.3ad", "balance-rr"
      miimon = 100;
      primary = "eth0";
    };
  };
};
```

**5. Firewall Zones**
```nix
# modules/network-settings/firewall-zones.nix
hypervisor.network.firewall.zones = {
  trusted = {
    interfaces = [ "vlan1" ];
    allowAll = true;
  };
  public = {
    interfaces = [ "eth0" ];
    allowedServices = [ "ssh" "http" "https" ];
  };
  dmz = {
    interfaces = [ "vlan200" ];
    allowedPorts = [ 80 443 ];
    forwardTo = [ "internal" ];
  };
};
```

---

## 📝 Configuration Examples

### Example 1: Complete Privacy Setup

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./modules/network-settings/mac-spoofing.nix
    ./modules/network-settings/ip-spoofing.nix
    ./modules/network-settings/vpn.nix  # Suggested
  ];
  
  hypervisor.network = {
    # Random MAC on every boot
    macSpoof = {
      enable = true;
      mode = "random";
      persistMACs = false;
      interfaces."wlan0".randomizeOnBoot = true;
    };
    
    # Proxy chain
    ipSpoof = {
      enable = true;
      mode = "proxy";
      proxy = {
        enable = true;
        randomizeOrder = true;
        proxies = [
          { type = "socks5"; host = "proxy1.onion"; port = 9050; }
          { type = "socks5"; host = "proxy2.onion"; port = 9050; }
        ];
      };
    };
    
    # VPN kill switch (suggested)
    vpn.killSwitch = true;
  };
}
```

### Example 2: Multi-VLAN Lab

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./modules/network-settings/vlan.nix
    ./modules/network-settings/dns-server.nix  # Suggested
  ];
  
  hypervisor.network = {
    vlan = {
      enable = true;
      interfaces = {
        "vlan10" = { id = 10; interface = "eth0"; addresses = [ "192.168.10.1/24" ]; };
        "vlan20" = { id = 20; interface = "eth0"; addresses = [ "192.168.20.1/24" ]; };
        "vlan30" = { id = 30; interface = "eth0"; addresses = [ "192.168.30.1/24" ]; };
      };
    };
    
    # DHCP per VLAN (suggested)
    dhcp = {
      enable = true;
      vlans = {
        "vlan10" = { range = "192.168.10.100-192.168.10.200"; };
        "vlan20" = { range = "192.168.20.100-192.168.20.200"; };
      };
    };
  };
}
```

---

## 🎓 Best Practices

### Network Discovery
1. **Run discovery before configuration** - Know your network
2. **Use safe IP recommendations** - Avoid conflicts
3. **Check for VLAN conflicts** - Don't reuse IDs
4. **Monitor network changes** - Detect unauthorized devices

### VLAN Configuration
1. **Plan VLAN ranges** - Use standard ranges
2. **Document VLANs** - Keep track of assignments
3. **Test isolation** - Verify VLAN separation
4. **Use priorities** - Prioritize management traffic

### MAC/IP Spoofing
1. **Have authorization** - Legal and policy compliance
2. **Test in isolation** - Avoid production disruption
3. **Monitor logs** - Watch for issues
4. **Backup originals** - Easy restoration

### Performance
1. **Use jumbo frames** - For high-speed networks (9000 MTU)
2. **Enable QoS** - Prioritize important traffic
3. **Monitor bandwidth** - Identify bottlenecks
4. **Test failover** - Verify redundancy works

---

## 📚 Additional Documentation Needed

**Suggested Docs**:
1. VLAN Planning Guide
2. Network Security Best Practices
3. IPv6 Configuration Guide
4. Traffic Shaping Tutorial
5. VPN Integration Guide
6. Network Troubleshooting Playbook
7. Performance Tuning Guide
8. Multi-Tenant Network Design

---

## 🚀 Next Steps

**To maximize the network features:**

1. **Try the Network Discovery Tool**
   ```bash
   sudo /etc/hypervisor/scripts/network-discover.sh
   ```

2. **Configure VLANs**
   ```bash
   sudo /etc/hypervisor/scripts/setup/vlan-wizard.sh
   ```

3. **Explore Safe IP Recommendations**
   ```bash
   sudo /etc/hypervisor/scripts/network-discover.sh safe-ips eth0
   ```

4. **Review Suggested Features** - Prioritize based on your needs

5. **Test Configurations** - Always test in non-production first

---

**The network system is now intelligent, flexible, and comprehensive!** 🎉
