# Network Spoofing - Quick Start Guide

## ⚡ Fast Setup

### MAC Address Spoofing

**Run the wizard:**
```bash
sudo /etc/hypervisor/scripts/setup/mac-spoofing-wizard.sh
```

**What it does:**
1. Shows legal disclaimer (type "yes" to accept)
2. Backs up original MACs
3. Choose mode: Manual / Random / Vendor-Preserve
4. Select network interfaces
5. Configure MAC addresses
6. Generates NixOS config
7. Rebuilds system

**Result:** MAC addresses changed according to your configuration

---

### IP Address Management

**Run the wizard:**
```bash
sudo /etc/hypervisor/scripts/setup/ip-spoofing-wizard.sh
```

**What it does:**
1. Shows legal disclaimer (type "yes" to accept)
2. Choose mode: Alias / Rotation / Dynamic / Proxy
3. Select interfaces (if applicable)
4. Configure IPs or proxies
5. Generates NixOS config
6. Rebuilds system

**Result:** IP management active according to your configuration

---

## 🎯 Common Use Cases

### Privacy on Public WiFi
```bash
sudo /etc/hypervisor/scripts/setup/mac-spoofing-wizard.sh
# Select: Random mode, wlan0, randomize on boot
```

### Multiple IPs for Testing
```bash
sudo /etc/hypervisor/scripts/setup/ip-spoofing-wizard.sh
# Select: Alias mode, eth0, add multiple IPs
```

### Rotating IPs for Testing
```bash
sudo /etc/hypervisor/scripts/setup/ip-spoofing-wizard.sh
# Select: Rotation mode, configure IP pool and interval
```

### Proxy Anonymization
```bash
sudo /etc/hypervisor/scripts/setup/ip-spoofing-wizard.sh
# Select: Proxy mode, configure proxy chain
```

---

## 📊 Management Commands

### MAC Spoofing

**Check status:**
```bash
systemctl status mac-spoof
```

**View logs:**
```bash
journalctl -t mac-spoof -f
```

**See current MACs:**
```bash
ip link show
```

**View original MACs (backup):**
```bash
cat /var/lib/hypervisor/mac-spoof/original-macs.conf
```

**Restart service:**
```bash
sudo systemctl restart mac-spoof
```

---

### IP Management

**Alias Mode:**
```bash
# View IPs
ip addr show

# Check service
systemctl status ip-alias

# Restart
sudo systemctl restart ip-alias
```

**Rotation Mode:**
```bash
# Watch rotation
journalctl -t ip-rotation -f

# Check service
systemctl status ip-rotation

# Restart
sudo systemctl restart ip-rotation
```

**Proxy Mode:**
```bash
# Test proxy
proxychains curl ifconfig.me

# Use with any command
proxychains firefox
proxychains ssh user@host

# View config
cat /etc/proxychains/proxychains.conf
```

---

## 🔧 Configuration Files

**MAC Spoofing:**
- Config: `/etc/nixos/mac-spoof.nix`
- Backup: `/var/lib/hypervisor/mac-spoof/original-macs.conf`

**IP Management:**
- Config: `/etc/nixos/ip-spoof.nix`
- Proxy: `/etc/proxychains/proxychains.conf`

**Edit configurations:**
```bash
sudo nano /etc/nixos/mac-spoof.nix
sudo nano /etc/nixos/ip-spoof.nix
```

**Apply changes:**
```bash
sudo nixos-rebuild switch
```

---

## ❌ Disabling Features

**Disable MAC spoofing:**
```nix
# Edit /etc/nixos/mac-spoof.nix
hypervisor.network.macSpoof.enable = false;
```

**Disable IP management:**
```nix
# Edit /etc/nixos/ip-spoof.nix
hypervisor.network.ipSpoof.enable = false;
```

**Apply:**
```bash
sudo nixos-rebuild switch
```

---

## ⚠️ Important Warnings

**Legal:**
- ✅ Use only for legitimate purposes
- ✅ Obtain proper authorization
- ✅ Follow applicable laws and policies
- ❌ Do not use for unauthorized access
- ❌ Do not violate terms of service

**Technical:**
- ⚠️ Can cause network conflicts
- ⚠️ May disrupt connectivity if misconfigured
- ⚠️ Test in isolated environment first
- ⚠️ Monitor logs for issues

---

## 🆘 Troubleshooting

**MAC not changing?**
```bash
# Check service
systemctl status mac-spoof

# View logs
journalctl -u mac-spoof -n 50

# Test manually
sudo ip link set eth0 down
sudo ip link set eth0 address 02:1a:2b:3c:4d:5e
sudo ip link set eth0 up
```

**IP aliases not appearing?**
```bash
# Check service
systemctl status ip-alias

# View logs
journalctl -u ip-alias

# Test manually
sudo ip addr add 192.168.1.100/24 dev eth0
```

**Proxy not working?**
```bash
# Test configuration
proxychains curl -v http://example.com

# Check config
cat /etc/proxychains/proxychains.conf

# Test proxy directly
curl -x socks5://proxy.example.com:1080 http://example.com
```

---

## 📚 Full Documentation

**Complete guide:**
```bash
less /workspace/docs/NETWORK_SPOOFING_GUIDE.md
```

**Topics covered:**
- Detailed configuration examples
- All modes explained
- Security best practices
- Advanced use cases
- Troubleshooting guide
- Integration examples

---

## 🚀 Quick Examples

### Example 1: Random MAC on Boot
```nix
hypervisor.network.macSpoof = {
  enable = true;
  mode = "random";
  interfaces."wlan0".enable = true;
  interfaces."wlan0".randomizeOnBoot = true;
};
```

### Example 2: Multiple IPs
```nix
hypervisor.network.ipSpoof = {
  enable = true;
  mode = "alias";
  interfaces."eth0" = {
    enable = true;
    aliases = [
      "192.168.1.100/24"
      "192.168.1.101/24"
      "192.168.1.102/24"
    ];
  };
};
```

### Example 3: IP Rotation
```nix
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

---

## ✅ You're Ready!

**Start here:**
1. Run the wizard for your needs
2. Accept the legal terms
3. Follow the interactive prompts
4. Let it rebuild the system
5. Check status with management commands

**Need help?**
- Check logs: `journalctl`
- Read full docs: `/workspace/docs/NETWORK_SPOOFING_GUIDE.md`
- Review config: `/etc/nixos/*-spoof.nix`

**Remember:** Use responsibly and legally! 🔒
