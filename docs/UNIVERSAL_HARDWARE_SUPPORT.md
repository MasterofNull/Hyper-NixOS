# Universal Hardware Support

## Overview

Hyper-NixOS provides **intelligent hardware discovery** for all supported CPU architectures with **NO HARDCODED SETTINGS**. The system automatically detects and configures optimal settings for any platform.

## Supported Architectures

### x86 / x86_64 (Intel, AMD, VIA, Hygon)
- ✅ Intel processors (VT-x, EPT)
- ✅ AMD processors (AMD-V, NPT)
- ✅ VIA processors
- ✅ Hygon processors (Chinese x86)
- Auto-detects:
  - CPU vendor
  - Virtualization extensions (VMX/SVM)
  - IOMMU configuration (intel_iommu/amd_iommu)
  - Appropriate KVM module (kvm-intel/kvm-amd)

### ARM / ARM64 (Qualcomm, Broadcom, NVIDIA, Apple, etc.)
- ✅ Qualcomm Snapdragon
- ✅ Broadcom (Raspberry Pi)
- ✅ NVIDIA Jetson
- ✅ Apple Silicon (M-series)
- ✅ Rockchip
- ✅ Allwinner
- ✅ Amlogic
- ✅ MediaTek
- ✅ Marvell
- ✅ Samsung (ODROID)
- Auto-detects:
  - ARM vendor from /proc/cpuinfo
  - Device tree information
  - ARM virtualization extensions
  - SMMU configuration

### RISC-V (SiFive, StarFive, Allwinner)
- ✅ SiFive boards
- ✅ StarFive VisionFive
- ✅ Allwinner D1
- Auto-detects:
  - RISC-V vendor
  - Hypervisor extension support
  - KVM configuration

### PowerPC (IBM POWER)
- ✅ IBM POWER8, POWER9, POWER10
- ✅ Little-endian (ppc64le) and big-endian (ppc64)
- Auto-detects:
  - PowerPC platform
  - KVM-HV (hypervisor mode)
  - Virtualization capabilities

### MIPS (Loongson, Cavium)
- ✅ Loongson processors
- ✅ Cavium OCTEON
- Auto-detects:
  - MIPS vendor
  - 32-bit and 64-bit modes

### s390x (IBM Z Mainframe)
- ✅ IBM Z mainframe systems
- Full virtualization support

## How It Works

### 1. Build-Time Detection

During `nixos-rebuild`, the system:

```bash
# Runs universal hardware detection
/path/to/detect-cpu-vendor.sh json

# Output example (AMD Ryzen):
{
  "architecture": "x86_64",
  "vendor": "amd",
  "virtualization_capability": "svm",
  "iommu_param": "amd_iommu=on",
  "virt_params": "kvm_amd.nested=1",
  "kvm_module": "kvm-amd",
  "virt_modules": "vfio vfio_iommu_type1 vfio_pci vfio_virqfd"
}
```

### 2. Automatic Configuration

The detected values are automatically applied to:

- `boot.kernelParams` - Architecture-specific parameters
- `boot.kernelModules` - Correct KVM and VFIO modules
- `boot.initrd.kernelModules` - Early boot modules
- `services.udev.extraRules` - Platform-specific optimizations

### 3. No Hardcoded Values

**Old approach** (hardcoded - BAD):
```nix
boot.kernelParams = [ "intel_iommu=on" "kvm_intel.nested=1" ];  # Breaks on AMD!
boot.kernelModules = [ "kvm-intel" ];  # Breaks on AMD!
```

**New approach** (intelligent discovery - GOOD):
```nix
# NO hardcoded values!
# modules/core/universal-hardware-detection.nix does it all automatically
```

## Commands

### Check Detected Hardware

```bash
# Full hardware information
hv-hardware-info

# Just run detection
hv-detect-hardware

# Check detection log
cat /var/log/hypervisor/hardware-detection.log
```

### Manual Detection

```bash
# Get architecture
/path/to/detect-cpu-vendor.sh architecture
# Output: x86_64, aarch64, riscv64, etc.

# Get vendor
/path/to/detect-cpu-vendor.sh vendor
# Output: amd, intel, broadcom, qualcomm, etc.

# Get virtualization capability
/path/to/detect-cpu-vendor.sh virt-capability
# Output: svm, vmx, arm-virt, riscv-h, etc.

# Get all info as JSON
/path/to/detect-cpu-vendor.sh json
```

## Configuration

### Enable/Disable Auto-Detection

```nix
# In configuration.nix
hypervisor.hardware = {
  enableAutoDetection = true;   # Default: enabled
  logDetection = true;           # Default: enabled
  allowFallback = true;          # Default: enabled
};
```

### Override Detection (Advanced)

If auto-detection fails, you can override:

```nix
# Disable auto-detection
hypervisor.hardware.enableAutoDetection = false;

# Manually specify (NOT recommended)
boot.kernelParams = [ "your-custom-params" ];
boot.kernelModules = [ "your-custom-modules" ];
```

## Platform-Specific Notes

### Raspberry Pi

- Automatically detected via device tree (`/proc/device-tree/model`)
- Vendor set to "broadcom"
- Appropriate SD card optimizations applied
- GPIO and hardware PWM support enabled

### NVIDIA Jetson

- Detected as "nvidia" vendor on ARM64
- CUDA and TensorRT optimizations available
- Tegra-specific drivers loaded

### Apple Silicon (M1/M2/M3)

- Detected as "apple" vendor on ARM64
- Note: Virtualization support depends on Asahi Linux progress
- May require custom kernel for full functionality

### IBM POWER

- Automatically uses KVM-HV (hypervisor mode)
- POWER-specific optimizations enabled
- Big-endian and little-endian support

### Single Board Computers

Common SBCs automatically detected:
- Raspberry Pi (all models)
- ODROID (N2, C4, XU4, etc.)
- Rock64 / RockPro64
- Orange Pi
- Banana Pi
- NanoPi
- BeagleBone

## Troubleshooting

### Detection Failed

If detection fails, check:

```bash
# View detection log
cat /var/log/hypervisor/hardware-detection.log

# Check /proc/cpuinfo
cat /proc/cpuinfo | grep -E "vendor|model|flags"

# Check device tree (ARM/RISC-V)
ls /proc/device-tree/
cat /proc/device-tree/model 2>/dev/null
```

### Wrong Vendor Detected

Report an issue with:
```bash
# Include this output
uname -a
cat /proc/cpuinfo | head -20
hv-detect-hardware
```

### Virtualization Not Detected

**x86_64**:
- Check BIOS/UEFI for VT-x (Intel) or AMD-V (AMD)
- Look for "vmx" or "svm" in /proc/cpuinfo flags

**ARM**:
- Ensure CPU has virtualization extensions
- Check kernel config: `zcat /proc/config.gz | grep KVM`

**RISC-V**:
- Ensure hypervisor extension (H) is available
- May need recent kernel (5.17+)

### Performance Issues

If VMs are slow:

```bash
# Check if KVM is loaded
lsmod | grep kvm

# Check virtualization extensions
egrep '(vmx|svm|virt)' /proc/cpuinfo

# Verify IOMMU
dmesg | grep -i iommu
```

## Examples

### Example 1: Intel Desktop

```bash
$ hv-detect-hardware
{
  "architecture": "x86_64",
  "vendor": "intel",
  "virtualization_capability": "vmx",
  "iommu_param": "intel_iommu=on",
  "virt_params": "kvm_intel.nested=1",
  "kvm_module": "kvm-intel",
  "virt_modules": "vfio vfio_iommu_type1 vfio_pci vfio_virqfd"
}
```

Automatically configured:
- ✅ Intel IOMMU enabled
- ✅ Nested virtualization enabled
- ✅ KVM-Intel module loaded
- ✅ VFIO for GPU passthrough

### Example 2: AMD Laptop

```bash
$ hv-detect-hardware
{
  "architecture": "x86_64",
  "vendor": "amd",
  "virtualization_capability": "svm",
  "iommu_param": "amd_iommu=on",
  "virt_params": "kvm_amd.nested=1",
  "kvm_module": "kvm-amd",
  "virt_modules": "vfio vfio_iommu_type1 vfio_pci vfio_virqfd"
}
```

Automatically configured:
- ✅ AMD IOMMU enabled
- ✅ Nested virtualization enabled
- ✅ KVM-AMD module loaded
- ✅ VFIO for GPU passthrough

### Example 3: Raspberry Pi 4

```bash
$ hv-detect-hardware
{
  "architecture": "aarch64",
  "vendor": "broadcom",
  "virtualization_capability": "arm-virt",
  "iommu_param": "iommu.passthrough=0",
  "virt_params": "kvm-arm.mode=nvhe",
  "kvm_module": "kvm",
  "virt_modules": "vfio vfio_platform vfio_platform_base"
}
```

Automatically configured:
- ✅ ARM SMMU configured
- ✅ KVM ARM in non-VHE mode
- ✅ Generic KVM module
- ✅ VFIO platform drivers

### Example 4: RISC-V SBC

```bash
$ hv-detect-hardware
{
  "architecture": "riscv64",
  "vendor": "starfive",
  "virtualization_capability": "riscv-h",
  "iommu_param": "",
  "virt_params": "",
  "kvm_module": "kvm",
  "virt_modules": "vfio"
}
```

Automatically configured:
- ✅ RISC-V hypervisor extension detected
- ✅ KVM module for RISC-V
- ✅ Basic VFIO support

## Benefits

### 1. Cross-Platform Compatibility
- Same configuration works on Intel, AMD, ARM, RISC-V, etc.
- No manual tweaking needed
- Easy migration between platforms

### 2. Future-Proof
- New CPU vendors automatically supported
- Detection logic easily extended
- No need to update configuration for new hardware

### 3. Error Prevention
- Eliminates "wrong CPU settings" bugs
- Prevents boot failures from incorrect modules
- Automatic fallback for unknown hardware

### 4. Simplified Deployment
- One configuration for all hardware
- Easier to maintain
- Less documentation needed

## Technical Details

### Detection Order

1. **Architecture** - `uname -m`
2. **Vendor** - `/proc/cpuinfo`, `/proc/device-tree`
3. **Virtualization** - CPU flags, device tree, kernel config
4. **IOMMU** - Architecture and vendor specific
5. **Modules** - Based on architecture and capabilities

### Priority System

Settings are applied with proper NixOS priorities:

```nix
boot.kernelParams = mkBefore [...]     # Priority 500 (before base config)
boot.kernelModules = mkBefore [...]    # Priority 500
```

This allows user overrides while ensuring detection runs first.

### Caching

Detection runs at build time and results are cached in:
- `/etc/hypervisor/hardware-info.json`
- `/var/log/hypervisor/hardware-detection.log`

Re-detection happens on every `nixos-rebuild`.

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
