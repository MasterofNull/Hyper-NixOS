# Hardware-Aware Wizard System

## Overview

Hyper-NixOS wizards dynamically adjust their options based on detected hardware capabilities. This ensures users only see features that are actually available on their system, preventing configuration errors and providing educational feedback about hardware limitations.

## Design Philosophy

**Third Pillar: Learning Through Guidance**

Hardware-aware wizards embody the third pillar of Hyper-NixOS design ethos by:
1. **Teaching users about their hardware** - Showing what features are available and why
2. **Preventing frustration** - Hiding/greying out unavailable options instead of letting users configure features that won't work
3. **Providing context** - Explaining WHY certain features are unavailable
4. **Guiding toward alternatives** - Suggesting compatible options when preferred features aren't available

## Visual Indicators

### Available Features
```
✓ GPU Passthrough (NVIDIA GTX 1080 detected)
✓ SR-IOV Networking (IOMMU enabled)
✓ Nested Virtualization (VMX supported)
```

### Unavailable Features (Greyed Out)
```
○ GPU Passthrough (unavailable: Only one GPU detected)
○ SR-IOV Networking (unavailable: IOMMU not enabled in BIOS)
○ Touchpad Configuration (unavailable: No touchpad detected on this system)
```

## Hardware Capabilities Library

### Location
`scripts/lib/hardware-capabilities.sh`

### Core Functions

#### Detection Functions
```bash
get_cpu_architecture()    # Returns: x86_64, aarch64, riscv64, etc.
get_cpu_vendor()          # Returns: Intel, AMD, Qualcomm, etc.
get_platform_type()       # Returns: laptop, desktop, server

has_virtualization()      # Check if CPU supports KVM
has_iommu()              # Check if IOMMU is available
has_gpu_passthrough()    # Check if GPU passthrough is possible
is_laptop()              # Check if system is a laptop
is_desktop()             # Check if system is a desktop
is_server()              # Check if system is headless
```

#### Hardware Feature Checks
```bash
has_touchpad()           # Laptop touchpad present
has_backlight()          # Display backlight control
has_battery()            # Battery detected
has_nvidia_gpu()         # NVIDIA GPU present
has_amd_gpu()            # AMD GPU present
has_intel_gpu()          # Intel GPU present
has_wifi()               # WiFi adapter present
has_bluetooth()          # Bluetooth adapter present
```

#### Feature Availability
```bash
is_feature_available "feature_name"
# Returns: 0 if available, 1 if not

get_unavailable_reason "feature_name"
# Returns: Human-readable explanation
```

### Supported Features

| Feature ID | Description | Requirements |
|------------|-------------|--------------|
| `kvm` | Hardware virtualization | VMX/SVM CPU extensions |
| `nested_virtualization` | VMs inside VMs | Nested virt support |
| `gpu_passthrough` | Dedicate GPU to VM | IOMMU + 2+ GPUs |
| `vfio` | PCI device passthrough | IOMMU enabled |
| `iommu` | I/O memory management | CPU/chipset support |
| `laptop_mode` | Laptop optimizations | Battery detected |
| `touchpad_config` | Touchpad settings | Touchpad device |
| `backlight_control` | Screen brightness | Backlight device |
| `battery_optimization` | Power management | Battery present |
| `nvidia_drivers` | NVIDIA features | NVIDIA GPU |
| `amd_rocm` | AMD GPU compute | AMD GPU |
| `intel_vaapi` | Intel video accel | Intel GPU |
| `wifi_config` | WiFi management | WiFi adapter |
| `bluetooth_config` | Bluetooth management | Bluetooth adapter |
| `multi_monitor` | Multiple displays | Desktop/laptop |
| `gaming_optimizations` | Gaming features | Desktop + dGPU |
| `x86_optimizations` | x86-specific tuning | x86/x86_64 CPU |
| `arm_optimizations` | ARM-specific tuning | ARM/ARM64 CPU |

## Wizard Integration

### Setup Wizard

**File**: `scripts/setup-wizard.sh`

**Hardware-Aware Features**:
- Displays hardware summary at startup
- Filters features by hardware availability
- Shows greyed-out options with reasons
- Adapts security recommendations to platform

**Example**:
```bash
# Feature will only be shown if hardware supports it
prompt_feature "$cat_name" "gpuPassthrough" "moderate" \
    "GPU Passthrough for Storage" \
    "Pass through GPU for hardware-accelerated compression/encryption" \
    "gpu_passthrough" \    # Hardware requirement
    "Requires IOMMU and multiple GPUs" \
    "Direct hardware access to VMs"
```

**Visual Output**:
```
✓ Storage Encryption (Available)
✓ Storage Deduplication (Available)
○ GPU Passthrough for Storage (unavailable: Only one GPU detected)
```

### VM Creation Wizard

**File**: `scripts/create-vm-wizard.sh`

**Library**: `scripts/lib/vm-hardware-options.sh`

**Hardware-Aware Features**:
- Shows available VM hardware options
- Detects if GPU passthrough is possible
- Warns about architecture emulation
- Recommends CPU/memory based on host

**Functions**:
```bash
show_vm_hardware_summary "my-vm"
# Displays what hardware features are available for this VM

can_use_gpu_passthrough
# Returns true if GPU can be passed through

get_recommended_vm_arch
# Suggests best architecture for VM based on host

show_emulation_warning "aarch64"
# Warns if VM arch differs from host (emulation mode)
```

**Example Interaction**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VM Hardware Configuration: my-gaming-vm
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Platform: desktop
  CPU Architecture: x86_64
  CPU Vendor: AMD

  Available Features:
    ✓ GPU Passthrough (NVIDIA RTX 3080 detected)
    ✓ Nested Virtualization (SVM supported)
    ✓ SR-IOV Networking (AMD IOMMU enabled)
    ✓ Huge Pages (1G and 2M configured)
    ✓ AMD GPU Features (Radeon RX 6800 XT detected)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Network Configuration Wizard

**File**: `scripts/network-configuration-wizard.sh`

**Hardware-Aware Features**:
- Shows SR-IOV option only if IOMMU available
- Displays WiFi management only if WiFi present
- Explains why features are unavailable
- Suggests alternatives

**Example**:
```
Configuration Options:

  nat     - NAT networking (secure, isolated)
  bridge  - Bridge networking (performance, direct access)
  sriov   - SR-IOV networking (unavailable: IOMMU not enabled in BIOS)
  wifi    - WiFi management (WiFi adapter detected)
  custom  - Custom configuration

Select network mode: sriov
✗ SR-IOV unavailable: IOMMU not supported by CPU or not enabled in BIOS
→ Try bridge mode for high-performance networking without SR-IOV
```

### Security Configuration Wizard

**File**: `scripts/security-configuration-wizard.sh`

**Hardware-Aware Features**:
- Adapts security profiles to platform type
- Different recommendations for laptop vs server
- Hardware-based security features detection

## Platform-Specific Behavior

### Laptops
**Detected by**: Battery presence (`/sys/class/power_supply/BAT*`)

**Available Features**:
- Touchpad configuration
- Backlight control
- Battery optimization
- Power management profiles
- WiFi management (if WiFi present)
- Bluetooth management (if BT present)
- VM suspend synchronization (experimental)

**Unavailable Features**:
- Server-specific optimizations
- Multiple GPU passthrough (usually)
- SR-IOV (usually)

### Desktops
**Detected by**: No battery + graphical target active

**Available Features**:
- GPU passthrough (if 2+ GPUs)
- SR-IOV networking (if IOMMU enabled)
- Gaming optimizations (if discrete GPU)
- Multi-monitor support
- RGB peripheral support
- High-performance tuning

**Unavailable Features**:
- Battery management
- Touchpad configuration
- Backlight control

### Servers/Headless
**Detected by**: No battery + no graphical target

**Available Features**:
- IPMI/BMC management
- Remote console access
- HA clustering features
- Enterprise storage backends
- RAID management

**Unavailable Features**:
- Desktop GUI features
- Gaming optimizations
- Laptop power management

## Architecture-Specific Features

### x86_64 (Intel/AMD)
**Detected by**: `uname -m` = x86_64

**Available**:
- KVM with hardware acceleration
- IOMMU (Intel VT-d / AMD-Vi)
- Nested virtualization
- GPU passthrough (if 2+ GPUs)
- x86-specific optimizations

### ARM64 (aarch64)
**Detected by**: `uname -m` = aarch64

**Available**:
- KVM with hardware acceleration
- ARM SMMU (IOMMU equivalent)
- Platform-specific device passthrough
- Thermal management (SBCs)
- ARM-specific optimizations

**Note**: GPU passthrough support varies by SoC

### RISC-V
**Detected by**: `uname -m` = riscv64

**Available**:
- KVM (if supported by SoC)
- RISC-V IOMMU (if available)
- RISC-V-specific optimizations

**Limited**: GPU passthrough, peripheral support

### PowerPC
**Detected by**: `uname -m` = ppc64le

**Available**:
- KVM-HV (hypervisor mode)
- PowerNV IOMMU
- IBM-specific features

## Implementation Examples

### Example 1: Conditional Feature in Wizard

```bash
# In a wizard script

# Load hardware capabilities
source "${SCRIPT_DIR}/lib/hardware-capabilities.sh"

# Only show GPU passthrough if available
if is_feature_available "gpu_passthrough"; then
    echo "GPU Passthrough: Available"
    read -p "Enable GPU passthrough? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        enable_gpu_passthrough
    fi
else
    echo "GPU Passthrough: Unavailable"
    echo "  Reason: $(get_unavailable_reason 'gpu_passthrough')"
    echo "  Alternative: Use virtual graphics (VirtIO-GPU)"
fi
```

### Example 2: Hardware Summary Display

```bash
# Show comprehensive hardware summary
show_hardware_summary

# Output:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   Hardware Detected
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#   Architecture:  x86_64
#   CPU Vendor:    AMD
#   Platform Type: desktop
#
#   Capabilities:
#   ✓ Hardware Virtualization (KVM)
#   ✓ IOMMU / PCI Passthrough
#   ✓ GPU Passthrough
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Example 3: Feature Availability Check

```bash
# Check if feature is available and show appropriate UI

if is_feature_available "nested_virtualization"; then
    menu_items+=("nested_virt" "Nested Virtualization" "OFF")
else
    reason=$(get_unavailable_reason "nested_virtualization")
    menu_items+=("nested_virt_disabled" "Nested Virtualization (unavailable: $reason)" "OFF")
fi
```

## Capabilities Cache

### Location
`/var/cache/hypervisor/capabilities.json`

### Format
```json
{
  "timestamp": "2025-01-15T10:30:00-05:00",
  "architecture": "x86_64",
  "vendor": "AMD",
  "platform_type": "desktop",
  "capabilities": {
    "virtualization": true,
    "iommu": true,
    "gpu_passthrough": true,
    "touchpad": false,
    "backlight": false,
    "battery": false,
    "nvidia_gpu": true,
    "amd_gpu": false,
    "intel_gpu": false,
    "wifi": true,
    "bluetooth": true
  },
  "platform_features": {
    "is_laptop": false,
    "is_desktop": true,
    "is_server": false
  }
}
```

### Cache Management
- Auto-generated on first use
- Refreshed every 60 minutes
- Manually refresh: `rm /var/cache/hypervisor/capabilities.json`

## Testing on Different Platforms

### Intel x86_64 Desktop
```bash
# Should show:
# ✓ KVM with VMX
# ✓ Intel IOMMU
# ✓ GPU passthrough (if 2+ GPUs)
```

### AMD x86_64 Desktop
```bash
# Should show:
# ✓ KVM with SVM
# ✓ AMD IOMMU
# ✓ GPU passthrough (if 2+ GPUs)
```

### Laptop (any CPU)
```bash
# Should show:
# ✓ Touchpad configuration
# ✓ Backlight control
# ✓ Battery management
# ○ GPU passthrough (usually unavailable - single GPU)
```

### ARM64 SBC (Raspberry Pi 4)
```bash
# Should show:
# ✓ KVM-ARM
# ○ GPU passthrough (unavailable - no SMMU on RPi4)
# ✓ Thermal management
# ✓ ARM optimizations
```

## Troubleshooting

### Feature Shows as Unavailable But Should Work

1. **Check hardware detection**:
   ```bash
   hv-hardware-info
   hv-platform-info
   ```

2. **Verify detection logs**:
   ```bash
   cat /var/log/hypervisor/hardware-detection.log
   cat /var/log/hypervisor/platform-detection.log
   ```

3. **Manually check hardware**:
   ```bash
   # For IOMMU:
   cat /proc/cmdline | grep iommu
   ls /sys/kernel/iommu_groups/

   # For virtualization:
   grep -E 'vmx|svm' /proc/cpuinfo

   # For touchpad:
   ls /dev/input/by-path/ | grep touchpad

   # For WiFi:
   ip link | grep wl
   ```

4. **Refresh capabilities cache**:
   ```bash
   rm /var/cache/hypervisor/capabilities.json
   # Run wizard again
   ```

### Wizard Not Showing Hardware-Aware Features

1. **Check if library is sourced**:
   ```bash
   grep "hardware-capabilities.sh" /home/hyperd/Documents/Hyper-NixOS/scripts/setup-wizard.sh
   ```

2. **Verify library exists**:
   ```bash
   ls -l /home/hyperd/Documents/Hyper-NixOS/scripts/lib/hardware-capabilities.sh
   ```

3. **Test library manually**:
   ```bash
   source /home/hyperd/Documents/Hyper-NixOS/scripts/lib/hardware-capabilities.sh
   show_hardware_summary
   ```

## Benefits

### For Users
- **No Frustration**: Can't select features that won't work
- **Learning**: Understand hardware limitations
- **Guidance**: Get suggestions for alternatives
- **Confidence**: Know configurations will work

### For Administrators
- **Reduced Support**: Fewer "why doesn't this work?" questions
- **Better Deployments**: Configurations match hardware
- **Documentation**: Hardware requirements are self-documenting

### For Developers
- **Reusable**: Hardware detection library works across all wizards
- **Consistent**: Same visual indicators everywhere
- **Maintainable**: One place to update hardware checks

## Future Enhancements

1. **Benchmark-based recommendations**: Test actual hardware performance
2. **Cloud instance detection**: Recognize AWS/GCP/Azure instance types
3. **Hardware suggestions**: Recommend specific hardware for desired features
4. **Compatibility database**: Track which features work on which hardware
5. **Remote hardware detection**: Detect hardware on target systems for remote deployments

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
