# Network Settings Module

This directory contains all network-related configuration for the Hyper-NixOS hypervisor.

## Module Organization

### `base.nix`
Core networking configuration including:
- Hostname settings
- DNS configuration
- Network management daemon settings
- IPv6 settings
- DHCP configuration

**When to edit**: Changing hostname, DNS servers, or basic network behavior

### `firewall.nix`
Firewall and network security configuration:
- iptables-based firewall (standard mode)
- nftables-based firewall (strict mode)
- Port access rules (SSH, web dashboard, etc.)
- Connection logging and monitoring

**When to edit**: Opening ports, changing firewall rules, enabling strict mode

### `ssh.nix`
SSH server hardening and configuration:
- SSH authentication methods (key-only by default)
- Allowed users and access control
- Cryptographic algorithms (modern ciphers only)
- Fail2ban integration for brute-force protection
- Strict mode for maximum security

**When to edit**: Managing SSH access, adding users, changing security policies

### `isolation.nix`
VM network isolation and segmentation:
- VLAN configuration and tagging
- Private networks (VM-to-VM communication only)
- Network bridge management
- Libvirt network configuration
- Network isolation management scripts

**When to edit**: Setting up VLANs, creating isolated networks, managing VM network attachments

## Common Tasks

### Open a new port in the firewall
Edit `firewall.nix` and add the port to `allowedTCPPorts` or `allowedUDPPorts`.

### Change the hostname
Edit `base.nix` and change `networking.hostName` value.

### Add SSH access for a new user
Edit `ssh.nix` and add the username to `AllowUsers` list.

### Create an isolated network for VMs
Use the network isolation script:
```bash
/etc/hypervisor/scripts/network_isolation.sh create-private <network-name> <subnet>
```

Or edit `isolation.nix` to configure permanent isolated networks.

### Enable strict firewall mode
Create `/var/lib/hypervisor/configuration/security-local.nix` with:
```nix
{
  hypervisor.security.strictFirewall = true;
}
```

## Security Best Practices

1. **Firewall**: Keep firewall enabled at all times (default: on)
2. **SSH**: Use key-based authentication only (passwords disabled by default)
3. **Isolation**: Use VLANs or private networks to segment VM traffic
4. **Monitoring**: Review firewall logs regularly for suspicious activity
5. **Updates**: Keep SSH algorithms current as cryptographic standards evolve

## See Also

- Main configuration: `../../configuration.nix`
- Security modules: `../security/`
- VM management: `../virtualization/`
