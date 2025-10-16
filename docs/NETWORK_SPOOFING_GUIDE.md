# Network Spoofing Guide

## Overview

Hyper-NixOS provides MAC address and IP address management/spoofing capabilities for legitimate use cases including:

- **Privacy protection** on public networks
- **Authorized penetration testing** and security research
- **Development and testing** environments
- **Network troubleshooting** and diagnostics
- **Load balancing** and high availability setups

⚠️ **LEGAL WARNING**: Unauthorized use of these features may violate network policies, terms of service, or laws. You are responsible for ensuring your use is legal and authorized.

---

## MAC Address Spoofing

### Features

- **Manual Mode**: Specify exact MAC addresses for each interface
- **Random Mode**: Generate fully random MAC addresses
- **Vendor-Preserve Mode**: Keep vendor OUI prefix, randomize device part
- **Persistent MACs**: Optionally store and reuse generated MACs across reboots
- **Per-Interface Control**: Enable/disable on specific network interfaces
- **Automatic Backup**: Original MAC addresses are backed up

### Quick Start

Run the setup wizard:
```bash
sudo /etc/hypervisor/scripts/setup/mac-spoofing-wizard.sh
```

The wizard will guide you through:
1. Legal disclaimer acceptance
2. Mode selection (Manual/Random/Vendor-Preserve)
3. Interface selection
4. MAC address configuration
5. NixOS configuration generation
6. System rebuild

### Manual Configuration

Create `/etc/nixos/mac-spoof.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./modules/network-settings/mac-spoofing.nix ];
  
  hypervisor.network.macSpoof = {
    enable = true;
    mode = "random";  # or "manual", "vendor-preserve", "disabled"
    logChanges = true;
    persistMACs = false;
    
    interfaces = {
      "eth0" = {
        enable = true;
        randomizeOnBoot = true;
      };
      
      "eth1" = {
        enable = true;
        macAddress = "02:1a:2b:3c:4d:5e";  # Manual mode
      };
      
      "wlan0" = {
        enable = true;
        vendorPrefix = "00:1a:2b";  # Vendor-preserve mode
      };
    };
  };
}
```

Add to `configuration.nix`:
```nix
imports = [
  ./mac-spoof.nix
];
```

Apply configuration:
```bash
sudo nixos-rebuild switch
```

### Management Commands

**Check MAC spoofing status:**
```bash
systemctl status mac-spoof
```

**View MAC spoofing logs:**
```bash
journalctl -t mac-spoof -f
```

**Restart MAC spoofing service:**
```bash
sudo systemctl restart mac-spoof
```

**View current MAC addresses:**
```bash
ip link show
```

**View original MAC addresses (backup):**
```bash
cat /var/lib/hypervisor/mac-spoof/original-macs.conf
```

---

## IP Address Management

### Features

**Alias Mode**:
- Add multiple IP addresses to interfaces
- All IPs active simultaneously
- For load balancing, multiple services, failover

**Rotation Mode**:
- Rotate through a pool of IPs periodically
- Configurable rotation interval
- For privacy, testing, rate limit evasion

**Dynamic Mode**:
- Generate random IPs within specified CIDR ranges
- Automatic conflict detection
- For advanced testing and research

**Proxy Chain Mode**:
- Route traffic through SOCKS5/HTTP/HTTPS proxy chains
- Randomizable proxy order
- For anonymization and circumvention

### Quick Start

Run the setup wizard:
```bash
sudo /etc/hypervisor/scripts/setup/ip-spoofing-wizard.sh
```

The wizard will guide you through:
1. Legal disclaimer acceptance
2. Mode selection (Alias/Rotation/Dynamic/Proxy)
3. Interface selection (if applicable)
4. IP/proxy configuration
5. NixOS configuration generation
6. System rebuild

### Manual Configuration Examples

#### Alias Mode

Create `/etc/nixos/ip-spoof.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./modules/network-settings/ip-spoofing.nix ];
  
  hypervisor.network.ipSpoof = {
    enable = true;
    mode = "alias";
    logChanges = true;
    avoidConflicts = true;
    
    interfaces = {
      "eth0" = {
        enable = true;
        aliases = [
          "192.168.1.100/24"
          "192.168.1.101/24"
          "192.168.1.102/24"
        ];
      };
    };
  };
}
```

#### Rotation Mode

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./modules/network-settings/ip-spoofing.nix ];
  
  hypervisor.network.ipSpoof = {
    enable = true;
    mode = "rotation";
    logChanges = true;
    
    interfaces = {
      "eth0" = {
        enable = true;
        ipPool = [
          "10.0.0.100"
          "10.0.0.101"
          "10.0.0.102"
        ];
        rotationInterval = 3600;  # 1 hour
      };
    };
  };
}
```

#### Proxy Chain Mode

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./modules/network-settings/ip-spoofing.nix ];
  
  hypervisor.network.ipSpoof = {
    enable = true;
    mode = "proxy";
    
    proxy = {
      enable = true;
      randomizeOrder = true;
      
      proxies = [
        {
          type = "socks5";
          host = "proxy1.example.com";
          port = 1080;
        }
        {
          type = "http";
          host = "proxy2.example.com";
          port = 8080;
          username = "user";
          password = "pass";
        }
      ];
    };
  };
}
```

### Management Commands

**Alias Mode:**
```bash
# View IP aliases
ip addr show

# Check service status
systemctl status ip-alias

# Restart service
sudo systemctl restart ip-alias
```

**Rotation Mode:**
```bash
# View rotation logs
journalctl -t ip-rotation -f

# Check service status
systemctl status ip-rotation

# Restart rotation service
sudo systemctl restart ip-rotation
```

**Proxy Mode:**
```bash
# Test proxy chain
proxychains curl ifconfig.me

# View proxy config
cat /etc/proxychains/proxychains.conf

# Use with any command
proxychains firefox
proxychains ssh user@host
```

---

## Use Cases

### Privacy on Public WiFi

**Scenario**: Protecting identity on public networks

```nix
# MAC spoofing with random MACs
hypervisor.network.macSpoof = {
  enable = true;
  mode = "random";
  interfaces."wlan0".enable = true;
  interfaces."wlan0".randomizeOnBoot = true;
};
```

### Development Testing

**Scenario**: Testing multi-IP application behavior

```nix
# Multiple IP aliases for testing
hypervisor.network.ipSpoof = {
  enable = true;
  mode = "alias";
  interfaces."eth0" = {
    enable = true;
    aliases = [
      "10.0.0.10/24"
      "10.0.0.11/24"
      "10.0.0.12/24"
    ];
  };
};
```

### Authorized Penetration Testing

**Scenario**: Security testing with changing source IPs

```nix
# IP rotation for testing
hypervisor.network.ipSpoof = {
  enable = true;
  mode = "rotation";
  interfaces."eth0" = {
    enable = true;
    ipPool = ["10.0.0.100" "10.0.0.101" "10.0.0.102"];
    rotationInterval = 600;  # 10 minutes
  };
};
```

### Anonymization Research

**Scenario**: Research requiring anonymity layers

```nix
# Proxy chain + MAC spoofing
hypervisor.network.macSpoof.enable = true;
hypervisor.network.macSpoof.mode = "random";

hypervisor.network.ipSpoof = {
  enable = true;
  mode = "proxy";
  proxy = {
    enable = true;
    randomizeOrder = true;
    proxies = [ /* proxy list */ ];
  };
};
```

---

## Security Considerations

### Best Practices

1. **Document Your Use**: Keep records of when and why you use these features
2. **Test First**: Always test in isolated environments before production use
3. **Monitor Logs**: Review logs regularly for unexpected behavior
4. **Avoid Conflicts**: Use IP conflict detection (enabled by default)
5. **Backup Configs**: Keep backups of working configurations
6. **Stay Legal**: Ensure you have authorization for your use case

### Warnings

⚠️ **Network Conflicts**: IP spoofing can cause network conflicts if IPs are already in use

⚠️ **Service Disruption**: Misconfiguration can cause connectivity issues

⚠️ **Detection**: Many networks can detect MAC/IP spoofing attempts

⚠️ **Legal Risk**: Unauthorized use may violate laws and policies

⚠️ **Account Suspension**: May result in ban from networks/services

### Troubleshooting

**MAC spoofing not working:**
```bash
# Check service status
systemctl status mac-spoof

# View detailed logs
journalctl -u mac-spoof -n 50

# Check current MACs
ip link show

# Manually test MAC change
sudo ip link set eth0 down
sudo ip link set eth0 address 02:1a:2b:3c:4d:5e
sudo ip link set eth0 up
```

**IP aliases not appearing:**
```bash
# Check service
systemctl status ip-alias

# View logs
journalctl -u ip-alias

# Manually add alias
sudo ip addr add 192.168.1.100/24 dev eth0

# Check for conflicts
ip addr show
```

**Proxy chain not working:**
```bash
# Test proxy configuration
proxychains curl -v http://example.com

# Check proxy config
cat /etc/proxychains/proxychains.conf

# Test individual proxies
curl -x socks5://proxy1.example.com:1080 http://example.com
```

---

## Disabling Features

### Disable MAC Spoofing

Set `mode = "disabled"` in configuration:
```nix
hypervisor.network.macSpoof = {
  enable = false;
};
```

Or remove the import from `configuration.nix`:
```nix
imports = [
  # ./mac-spoof.nix  # Commented out
];
```

Rebuild:
```bash
sudo nixos-rebuild switch
```

### Disable IP Management

Set `mode = "disabled"` or remove entirely:
```nix
hypervisor.network.ipSpoof = {
  enable = false;
};
```

Rebuild system to apply changes.

---

## Integration with Other Features

### With VPN

Combine MAC spoofing with VPN for enhanced privacy:
```nix
# Enable both
hypervisor.network.macSpoof.enable = true;
hypervisor.vpn.enable = true;
```

### With Firewall

Ensure firewall rules accommodate IP aliases:
```nix
networking.firewall.interfaces."eth0".allowedTCPPorts = [ 80 443 ];
# Applies to all IPs on eth0
```

### With Virtual Machines

VMs can use host's spoofed interfaces or have their own spoofing:
- Host spoofing: Affects all VMs using bridged networking
- Per-VM spoofing: Configure within individual VMs

---

## Support and Resources

### Log Locations

- MAC spoofing: `journalctl -t mac-spoof`
- IP alias: `journalctl -u ip-alias`
- IP rotation: `journalctl -t ip-rotation`
- System journal: `journalctl -b`

### Configuration Files

- MAC config: `/etc/nixos/mac-spoof.nix`
- IP config: `/etc/nixos/ip-spoof.nix`
- Original MACs backup: `/var/lib/hypervisor/mac-spoof/original-macs.conf`
- Proxy config: `/etc/proxychains/proxychains.conf`

### Useful Commands

```bash
# Check network status
ip addr show
ip link show
ip route show

# View active services
systemctl list-units | grep -E '(mac-spoof|ip-)'

# Test connectivity
ping -c 3 8.8.8.8
curl ifconfig.me
```

---

## Legal Disclaimer

**⚠️ READ CAREFULLY ⚠️**

These network spoofing features are provided for:
- **Legitimate privacy protection**
- **Authorized security research and testing**
- **Educational purposes**
- **Network diagnostics and troubleshooting**

**Prohibited Uses:**
- Unauthorized access to networks or systems
- Bypassing network security without authorization
- Evading bans or restrictions without permission
- Illegal activities of any kind
- Violating terms of service

**Responsibility:**
- Users are solely responsible for their use of these features
- Users must ensure compliance with all applicable laws
- Users must obtain proper authorization before use
- The developers assume no liability for misuse

**By using these features, you agree to use them legally and responsibly.**

---

*For more information, see the [Security Guide](SECURITY_CONSIDERATIONS.md) and [Network Configuration Guide](NETWORK_CONFIGURATION.md).*
