# ARM Platform Support

Hyper-NixOS provides full support for ARM-based single-board computers and servers, bringing enterprise-grade virtualization to affordable hardware.

## Supported Platforms

### Fully Tested
- **Raspberry Pi 4** (4GB/8GB models recommended)
- **Raspberry Pi 5** (8GB+ recommended)
- **RockPro64**

### Community Supported
- Raspberry Pi 3 (limited performance)
- ODROID-N2/N2+
- Orange Pi 5
- Generic ARM64 servers

## Quick Start

### 1. Installation

Download the ARM-specific ISO:
```bash
# For Raspberry Pi 4/5
nix build .#packages.aarch64-linux.iso-rpi

# For generic ARM64
nix build .#packages.aarch64-linux.iso
```

Write to SD card:
```bash
dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress
sync
```

### 2. First Boot

The system will automatically detect your ARM platform:
```bash
sudo hv-detect-system
```

### 3. Enable ARM Optimizations

The ARM profile is automatically activated during installation, but you can verify:
```nix
# In /etc/nixos/configuration.nix
hypervisor.hardware.arm.enable = true;
```

## Platform-Specific Notes

### Raspberry Pi 4

**Strengths:**
- Excellent community support
- Well-documented hardware
- Multiple RAM options (2/4/8GB)
- Good GPIO support

**Limitations:**
- PCIe bandwidth limited
- No native NVMe (requires USB adapter)
- Maximum 8GB RAM

**Recommended Configuration:**
```nix
hypervisor.hardware.arm = {
  enable = true;
  platform = "rpi4";
  virtualization.enable = true;

  optimizations = {
    enableCpuGovernor = true;  # Performance mode
    enableZram = true;         # Memory compression
  };
};

# Limit VMs based on RAM
hypervisor.systemTier = "enhanced"; # For 8GB model
# hypervisor.systemTier = "minimal"; # For 4GB model
```

**Performance Tips:**
- Use high-quality SD card (UHS-I or better) OR USB 3.0 SSD
- Active cooling recommended for sustained virtualization loads
- Boot from SSD for better VM performance
- Enable zram (enabled by default in ARM profile)

### Raspberry Pi 5

**Strengths:**
- Improved CPU performance (2-3x vs Pi 4)
- Native PCIe 2.0 support
- Better USB 3.0 performance
- Improved thermal design

**Configuration:**
```nix
hypervisor.hardware.arm = {
  enable = true;
  platform = "rpi5";
  virtualization.nestedVirtualization = false; # Not yet stable
};
```

**Known Issues:**
- Nested virtualization experimental
- Some kernel modules may need updates

### RockPro64

**Strengths:**
- PCIe x4 slot (NVMe support)
- Up to 4GB RAM
- Better thermal performance
- Good for storage-heavy workloads

**Configuration:**
```nix
hypervisor.hardware.arm = {
  enable = true;
  platform = "rockpro64";
};
```

## ARM-Specific Features

### KVM Virtualization

ARM KVM support is automatically detected and enabled:
```bash
# Verify KVM is available
ls /dev/kvm

# Check virtualization extensions
grep -E 'Features.*fp' /proc/cpuinfo
```

### Memory Management

ARM boards typically have limited RAM. Hyper-NixOS includes:

1. **Zram** - Compressed swap in RAM
   - Automatically enabled
   - Typically 50% of physical RAM
   - Reduces disk I/O

2. **Kernel memory tuning**
   - Reduced swappiness
   - Optimized cache pressure
   - Better memory allocation for VMs

### CPU Performance

ARM CPUs often have dynamic frequency scaling:
```bash
# Check current frequency
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Set to performance mode (already done if enabled)
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

## Virtualization Performance

### Expected VM Performance

**Raspberry Pi 4 (8GB):**
- 2-3 concurrent VMs comfortable
- Each VM: 1-2 vCPUs, 1-2GB RAM
- Use cases: Development, testing, home services

**Raspberry Pi 5 (8GB):**
- 3-4 concurrent VMs
- Each VM: 2 vCPUs, 2GB RAM
- Improved I/O performance

**RockPro64:**
- 2-3 concurrent VMs
- Better for storage-intensive workloads
- NVMe significantly improves performance

### VM Guest Recommendations

For best performance on ARM:

1. **Use lightweight distributions:**
   - Alpine Linux
   - Debian minimal
   - Ubuntu Server (minimal)
   - Void Linux

2. **Avoid resource-heavy guests:**
   - Windows (not ARM-native)
   - Ubuntu Desktop
   - Heavy development environments

3. **Optimize guest configuration:**
   ```bash
   # Create lightweight VM
   hv vm-create \
     --name alpine-test \
     --memory 1024 \
     --cpus 2 \
     --disk 10G \
     --os alpine
   ```

## Storage Recommendations

### Best: NVMe SSD
- RockPro64 native support
- Raspberry Pi via USB 3.0 adapter
- 10x+ performance vs SD card

### Good: USB 3.0 SSD
- Works on all platforms
- 5x+ performance vs SD card
- Widely available

### Acceptable: High-quality SD card
- UHS-I (U3) or better
- A2 rating preferred
- Only for testing/learning

### Configuration:
```nix
# Use external storage for VMs
hypervisor.storage.poolPath = "/mnt/ssd/vms";
```

## Networking

### Bridge Configuration

ARM boards typically have single Ethernet:
```nix
hypervisor.networking = {
  bridge = {
    enable = true;
    interface = "eth0"; # Usually eth0 on ARM
  };
};
```

### WiFi Considerations

Many ARM boards have built-in WiFi:
```bash
# Bridge WiFi (not recommended for production)
hypervisor.networking.bridge.interface = "wlan0";
```

**Note:** WiFi bridging is unreliable. Use Ethernet for VMs.

## Cooling and Power

### Thermal Management

ARM boards can throttle under heavy load:
```bash
# Monitor temperature
watch -n 1 'vcgencmd measure_temp' # Raspberry Pi

# Check throttling (Raspberry Pi)
vcgencmd get_throttled
```

**Recommendations:**
- Active cooling (fan) for sustained loads
- Heat sinks on CPU, RAM, and network chips
- Adequate case ventilation

### Power Supply

Underpowered systems cause instability:
- **Raspberry Pi 4/5:** Official 3A+ power supply
- **RockPro64:** 3A 5V supply minimum
- Avoid cheap USB chargers

## Troubleshooting

### KVM Not Available

```bash
# Check module loaded
lsmod | grep kvm

# Load manually if needed
sudo modprobe kvm

# Verify device
ls -l /dev/kvm
```

### Performance Issues

```bash
# Check CPU governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Should be "performance" - set in ARM profile

# Monitor system load
htop

# Check for thermal throttling
journalctl -b | grep -i throttl
```

### VMs Won't Start

```bash
# Check libvirt status
sudo systemctl status libvirtd

# Verify QEMU ARM support
qemu-system-aarch64 --version

# Check logs
sudo journalctl -u libvirtd -n 50
```

## Limitations

### No GPU Passthrough

Most ARM SBCs have integrated GPUs that cannot be passed through to VMs.

**Workaround:** Use VNC/SPICE for graphical VMs

### Limited PCI Devices

Few ARM boards have PCIe slots for device passthrough.

**Exception:** RockPro64 has PCIe x4 slot

### Architecture Compatibility

ARM VMs can only run:
- ARM64/aarch64 guests
- ARM32 (armv7l) guests on some platforms

Cannot run x86/x64 without emulation (slow).

## Best Practices

### 1. Start Small
- Test with 1-2 VMs initially
- Monitor resource usage
- Scale based on performance

### 2. Use Appropriate Storage
- SD cards for OS only
- External SSD/NVMe for VM storage
- Regular backups

### 3. Monitor Resources
```bash
# CPU and memory
htop

# Temperature
watch sensors

# Network
nethogs

# Disk I/O
iotop
```

### 4. Regular Maintenance
```bash
# Update system
sudo nixos-rebuild switch --upgrade

# Clean old generations
sudo nix-collect-garbage -d

# Check disk space
df -h
```

## Example Configurations

### Home Server (Raspberry Pi 4 8GB)
```nix
{
  imports = [ ./profiles/arm-hypervisor.nix ];

  hypervisor = {
    systemTier = "enhanced";

    hardware.arm = {
      platform = "rpi4";
      optimizations.enableZram = true;
    };

    features = {
      vm-management.enable = true;
      networking.enable = true;
      backup.enable = true;
    };
  };

  # Boot from SSD
  boot.loader.raspberryPi.firmwareConfig = ''
    boot_order=0xf14
  '';
}
```

### Development Environment (RockPro64)
```nix
{
  imports = [ ./profiles/arm-hypervisor.nix ];

  hypervisor = {
    systemTier = "enhanced";

    hardware.arm.platform = "rockpro64";

    storage.poolPath = "/mnt/nvme/vms";

    features = {
      vm-management.enable = true;
      snapshot-management.enable = true;
    };
  };
}
```

## Further Resources

- [Raspberry Pi Virtualization Guide](https://www.raspberrypi.org/documentation)
- [ARM KVM Documentation](https://www.linux-kvm.org/page/ARM)
- [NixOS ARM Wiki](https://nixos.wiki/wiki/NixOS_on_ARM)

## Community

Join discussions:
- GitHub Issues: Report ARM-specific bugs
- Matrix/Discord: Get help from other ARM users
- Wiki: Share your ARM configurations
