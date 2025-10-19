# All Flake Profiles Updated with Universal Hardware Detection

## Overview

All Hyper-NixOS flake profiles have been updated to include:
1. **Universal hardware detection** for ALL CPU architectures
2. **Platform-specific hardware detection** (laptop/desktop/server features)
3. **Intelligent hibernation/resume authentication**
4. **Monthly NixOS update checking and notifications**
5. **NO hardcoded hardware settings** - everything is auto-detected

## Updated Profiles

### 1. configuration.nix (Main Configuration)
**Repository**: `Hyper-NixOS/configuration.nix`

**Added Modules**:
- `modules/core/universal-hardware-detection.nix`
- `modules/hardware/platform-detection.nix`
- `modules/system/hibernation-auth.nix`
- `modules/system/nixos-update-checker.nix`

**Removed**: All hardcoded CPU-specific settings (Intel IOMMU, kvm-intel, etc.)

**Status**: ✅ Complete

---

### 2. profiles/configuration-minimal.nix (Minimal Installation)
**Repository**: `Hyper-NixOS/profiles/configuration-minimal.nix`

**Added Modules**:
- `modules/core/universal-hardware-detection.nix`
- `modules/hardware/platform-detection.nix`
- `modules/system/hibernation-auth.nix`
- `modules/system/nixos-update-checker.nix`

**Removed**: All hardcoded CPU-specific settings

**Status**: ✅ Complete

---

### 3. profiles/configuration-complete.nix (Full-Featured Configuration)
**Repository**: `Hyper-NixOS/profiles/configuration-complete.nix`

**Added Modules**:
- `modules/core/universal-hardware-detection.nix`
- `modules/hardware/platform-detection.nix`
- `modules/system/hibernation-auth.nix`
- `modules/system/nixos-update-checker.nix`

**Removed**: All hardcoded CPU-specific settings

**Status**: ✅ Complete

---

### 4. profiles/configuration-enhanced.nix (Enhanced Security Configuration)
**Repository**: `Hyper-NixOS/profiles/configuration-enhanced.nix`

**Added Modules**:
- `modules/core/universal-hardware-detection.nix`
- `modules/hardware/platform-detection.nix`
- `modules/system/hibernation-auth.nix`
- `modules/system/nixos-update-checker.nix`

**Features**: Enhanced SSH security, Docker security, monitoring - now with universal hardware support

**Status**: ✅ Complete

---

### 5. profiles/configuration-privilege-separation.nix (Privilege Separation Model)
**Repository**: `Hyper-NixOS/profiles/configuration-privilege-separation.nix`

**Added Modules**:
- `modules/core/universal-hardware-detection.nix`
- `modules/hardware/platform-detection.nix`
- `modules/system/hibernation-auth.nix`
- `modules/system/nixos-update-checker.nix`

**Removed**: All hardcoded boot settings

**Features**: Multi-user privilege separation with passwordless VM operations - now works on ALL platforms

**Status**: ✅ Complete

---

### 6. profiles/configuration-minimal-recovery.nix (Recovery Configuration)
**Repository**: `Hyper-NixOS/profiles/configuration-minimal-recovery.nix`

**Added Modules**:
- `modules/core/universal-hardware-detection.nix`
- `modules/hardware/platform-detection.nix`
- `modules/system/hibernation-auth.nix`
- `modules/system/nixos-update-checker.nix`

**Removed**: Hardcoded Intel-specific kernel parameters and modules

**Features**: Emergency recovery with temporary passwords - now works on AMD, ARM, RISC-V, and all platforms

**Status**: ✅ Complete

---

## What Each Module Provides

### universal-hardware-detection.nix
- Detects CPU architecture: x86_64, ARM, RISC-V, PowerPC, MIPS, s390x
- Detects CPU vendor: Intel, AMD, ARM vendors (50+ total)
- Configures IOMMU automatically (intel_iommu, amd_iommu, ARM SMMU, etc.)
- Loads correct KVM modules (kvm-intel, kvm-amd, kvm-arm, kvm-hv, etc.)
- Enables virtualization extensions automatically
- Creates `/etc/hypervisor/hardware-info.json` for inspection
- Provides `hv-hardware-info` command
- Logs to `/var/log/hypervisor/hardware-detection.log`

### platform-detection.nix
- Detects platform type: Laptop, Desktop, Server/Headless
- **Laptop-specific**:
  - Touchpad configuration (libinput with tap-to-click, natural scrolling)
  - Backlight control (illum service)
  - Battery management (upower, tlp)
  - Power management optimizations
- **Desktop-specific**:
  - Multi-monitor support (autorandr)
  - Gaming peripheral detection (RGB keyboards)
- **All platforms**:
  - GPU detection and driver configuration (NVIDIA, AMD, Intel)
  - Bluetooth, WiFi, webcam, audio detection
  - Appropriate services enabled based on hardware
- Creates `/etc/hypervisor/platform-info.json`
- Provides `hv-platform-info` command
- Logs to `/var/log/hypervisor/platform-detection.log`

### hibernation-auth.nix
- Context-aware authentication for suspend/hibernate/resume
- Automatic swap device detection and configuration
- Prevents user lockouts when no passwords are set
- **Auto mode** (default):
  - Desktop with passwords: Requires password for resume
  - Headless with no passwords: Auto-resume without password
  - Single-user systems: Auto-login if no passwords set
- Configurable modes: always, never, desktop-only, auto
- Power management integration for laptops and desktops

### nixos-update-checker.nix
- Monthly automated NixOS update checking
- MOTD notifications when updates are available
- Admin-only upgrade commands:
  - `hv-check-updates`: Check for updates manually
  - `hv-upgrade-test`: Test upgrade without persisting changes
  - `hv-system-upgrade`: Apply permanent upgrade
- Safe testing workflow with diagnostics
- Rollback support if upgrade fails
- Logs to `/var/log/hypervisor/update-checker.log`

---

## Platform Support Matrix

| Platform | CPU Detection | Virtualization | Touchpad | Backlight | Battery | GPU Drivers | IOMMU |
|----------|---------------|----------------|----------|-----------|---------|-------------|-------|
| **x86_64 Intel** | ✅ Auto | ✅ kvm-intel | ✅ Auto | ✅ Auto | ✅ Auto | ✅ Auto | ✅ intel_iommu |
| **x86_64 AMD** | ✅ Auto | ✅ kvm-amd | ✅ Auto | ✅ Auto | ✅ Auto | ✅ Auto | ✅ amd_iommu |
| **ARM64 (Qualcomm)** | ✅ Auto | ✅ kvm-arm | ✅ Auto | ✅ Auto | ✅ Auto | ✅ Auto | ✅ ARM SMMU |
| **ARM64 (Apple)** | ✅ Auto | ✅ kvm-hv | ✅ Auto | ✅ Auto | ✅ Auto | ✅ Auto | ✅ ARM SMMU |
| **RISC-V** | ✅ Auto | ✅ kvm-riscv | ⚠️ Manual | ⚠️ Manual | ⚠️ Manual | ⚠️ Manual | ✅ riscv-iommu |
| **PowerPC** | ✅ Auto | ✅ kvm-hv | N/A | N/A | N/A | ⚠️ Manual | ✅ PowerPC IOMMU |
| **MIPS** | ✅ Auto | ✅ kvm-mips | N/A | N/A | N/A | ⚠️ Manual | ⚠️ Manual |
| **s390x** | ✅ Auto | ✅ kvm-s390 | N/A | N/A | N/A | N/A | N/A |

Legend:
- ✅ Auto: Automatically detected and configured
- ⚠️ Manual: Platform exists but needs manual configuration
- N/A: Feature not applicable to this platform

---

## Verification Commands

After updating to any profile, verify the detection:

### 1. Check Hardware Detection
```bash
hv-hardware-info
# Shows CPU architecture, vendor, virtualization, IOMMU, and modules
```

### 2. Check Platform Detection
```bash
hv-platform-info
# Shows laptop/desktop/server type and detected hardware features
```

### 3. View Detection Logs
```bash
cat /var/log/hypervisor/hardware-detection.log
cat /var/log/hypervisor/platform-detection.log
```

### 4. Inspect Detection JSON
```bash
cat /etc/hypervisor/hardware-info.json | jq .
cat /etc/hypervisor/platform-info.json | jq .
```

### 5. Verify Boot Parameters
```bash
cat /proc/cmdline
# Should show appropriate IOMMU and virtualization parameters for your CPU
```

### 6. Verify KVM Modules
```bash
lsmod | grep kvm
# Should show kvm-intel, kvm-amd, kvm-arm, or kvm-hv depending on your CPU
```

### 7. Check Update Checker
```bash
systemctl status nixos-update-checker.timer
sudo hv-check-updates
```

---

## Using Different Profiles

To switch between profiles in your repository:

### 1. Backup Current Configuration
```bash
cd Hyper-NixOS
cp configuration.nix configuration.nix.backup
```

### 2. Switch to Desired Profile
```bash
# Option 1: Copy profile to configuration.nix
cp profiles/configuration-minimal.nix configuration.nix

# Option 2: Build specific profile directly
sudo nixos-rebuild switch --flake .#minimal
# Available profiles: minimal, complete, enhanced, privilege-separation, minimal-recovery
```

### 3. Test the Configuration
```bash
sudo nixos-rebuild test --flake .
```

### 4. Verify Hardware Detection
```bash
hv-hardware-info
hv-platform-info
```

### 5. Apply Permanently
```bash
sudo nixos-rebuild switch --flake .
```

### 6. Reboot and Verify
```bash
sudo reboot
# After reboot:
hv-hardware-info
lsmod | grep kvm
cat /proc/cmdline
```

---

## Common Issues and Solutions

### Issue: "kvm-intel module not found" on AMD CPU
**Solution**: This is now fixed! The universal detection will load kvm-amd on AMD CPUs automatically.

### Issue: Configuration merge conflicts
**Solution**: The new profiles use `lib.mkDefault` properly, allowing your custom settings to take precedence.

### Issue: Locked out after hibernation with no password
**Solution**: The hibernation-auth module now detects passwordless systems and allows auto-resume.

### Issue: Wrong IOMMU parameters
**Solution**: Remove any hardcoded boot.kernelParams and let universal-hardware-detection handle it.

### Issue: System using wrong NixOS version
**Solution**: The flake.nix now uses stable nixos-24.05 matching system.stateVersion.

---

## Next Steps

1. **Choose your profile** based on your needs:
   - Basic: `configuration-minimal.nix`
   - Full-featured: `configuration-complete.nix`
   - Enhanced security: `configuration-enhanced.nix`
   - Multi-user: `configuration-privilege-separation.nix`
   - Recovery: `configuration-minimal-recovery.nix`

2. **Apply the profile** and test:
   ```bash
   cd Hyper-NixOS
   sudo nixos-rebuild test --flake .
   ```

3. **Verify detection** with the commands above

4. **Make it permanent** if everything works:
   ```bash
   sudo nixos-rebuild switch --flake .
   ```

5. **Enable update notifications** (enabled by default):
   - Monthly checks run automatically
   - Check manually: `sudo hv-check-updates`
   - Test upgrades: `sudo hv-upgrade-test`
   - Apply upgrades: `sudo hv-system-upgrade`

---

## Documentation References

- [Universal Hardware Support](./UNIVERSAL_HARDWARE_SUPPORT.md)
- [Hibernation and Authentication](./HIBERNATION_AND_AUTHENTICATION.md)
- [Upgrade Management](./UPGRADE_MANAGEMENT.md)
- [Fixes Summary](./FIXES_SUMMARY.md)

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
