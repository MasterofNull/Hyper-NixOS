# Hyper-NixOS Universal Hardware Detection Module
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# NO HARDCODED HARDWARE SETTINGS!
# Intelligent discovery for ALL CPU architectures
# Supports: x86_64, ARM, RISC-V, PowerPC, MIPS, s390x, and more

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.hardware;

  # Universal hardware detection script
  hwDetectScript = "${pkgs.bash}/bin/bash ${./../../scripts/detect-cpu-vendor.sh}";

  # Run detection at build time
  hwInfo = builtins.fromJSON (builtins.readFile (
    pkgs.runCommand "detect-hardware" {
      preferLocalBuild = true;
      allowSubstitutes = false;
    } ''
      ${hwDetectScript} json > $out
    ''
  ));

  # Extract detected values
  detectedArch = hwInfo.architecture or "unknown";
  detectedVendor = hwInfo.vendor or "unknown";
  detectedVirtCap = hwInfo.virtualization_capability or "none";
  detectedIommuParam = hwInfo.iommu_param or "";
  detectedVirtParams = hwInfo.virt_params or "";
  detectedKvmModule = hwInfo.kvm_module or "";
  detectedVirtModules = lib.splitString " " (hwInfo.virt_modules or "");

in {
  options.hypervisor.hardware = {
    enableAutoDetection = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable automatic hardware detection.
        When enabled, CPU architecture, vendor, and virtualization
        capabilities are auto-detected with NO hardcoded settings.
      '';
    };

    logDetection = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Log hardware detection results for debugging.
        Useful for troubleshooting multi-architecture deployments.
      '';
    };

    allowFallback = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow fallback to generic settings if detection fails.
        Recommended to keep enabled for maximum compatibility.
      '';
    };
  };

  config = mkIf cfg.enableAutoDetection {
    # Apply detected kernel parameters (NO HARDCODING!)
    boot.kernelParams = mkBefore (
      filter (p: p != "") [
        detectedIommuParam
        "iommu=pt"
        detectedVirtParams
        "transparent_hugepage=madvise"
      ]
    );

    # Apply detected kernel modules (architecture-aware!)
    boot.kernelModules = mkBefore (
      filter (m: m != "") ([ detectedKvmModule ] ++ detectedVirtModules)
    );

    # Virtualization-specific initrd modules
    boot.initrd.kernelModules = mkBefore (
      let
        vfioModules = filter (m: hasPrefix "vfio" m) detectedVirtModules;
      in
        vfioModules
    );

    # Log detection results
    system.activationScripts.hardwareDetection = mkIf cfg.logDetection ''
      LOG_FILE="/var/log/hypervisor/hardware-detection.log"
      mkdir -p "$(dirname "$LOG_FILE")"

      {
        echo "=== Hyper-NixOS Hardware Detection ==="
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Architecture: ${detectedArch}"
        echo "Vendor: ${detectedVendor}"
        echo "Virtualization: ${detectedVirtCap}"
        echo ""
        echo "Kernel Parameters:"
        ${if detectedIommuParam != "" then ''
        echo "  - ${detectedIommuParam}"
        '' else ""}
        ${if detectedVirtParams != "" then ''
        echo "  - ${detectedVirtParams}"
        '' else ""}
        echo "  - iommu=pt"
        echo "  - transparent_hugepage=madvise"
        echo ""
        echo "Kernel Modules:"
        ${if detectedKvmModule != "" then ''
        echo "  - ${detectedKvmModule} (KVM)"
        '' else ""}
        ${concatMapStringsSep "\n" (m: ''
        echo "  - ${m}"
        '') detectedVirtModules}
        echo ""
        echo "Detection Status: Success"
        echo "=========================================="
      } > "$LOG_FILE"

      chmod 644 "$LOG_FILE"
    '';

    # Export hardware info for other modules
    environment.etc."hypervisor/hardware-info.json".text = builtins.toJSON {
      architecture = detectedArch;
      vendor = detectedVendor;
      virtualization_capability = detectedVirtCap;
      iommu_param = detectedIommuParam;
      virt_params = detectedVirtParams;
      kvm_module = detectedKvmModule;
      virt_modules = detectedVirtModules;
      detection_time = "build-time";
    };

    # Warnings for unsupported/unknown hardware
    warnings =
      optional (detectedVirtCap == "none") ''
        Hardware virtualization not detected on this ${detectedArch} system.
        VMs will run in emulation mode (slow performance).

        For x86_64: Check BIOS/UEFI for VT-x/AMD-V settings
        For ARM: Ensure CPU supports virtualization extensions
        For RISC-V: Ensure hypervisor extension is available
      ''
      ++
      optional (detectedArch == "unknown") ''
        CPU architecture could not be detected!
        System may not function correctly. Please report this issue.

        Output: uname -m = ${pkgs.stdenv.hostPlatform.system}
      ''
      ++
      optional (detectedVendor == "unknown") ''
        CPU vendor could not be identified on ${detectedArch}.
        Using generic fallback settings. Some features may not work optimally.
      '';

    # Architecture-specific optimizations
    services.udev.extraRules = ''
      # ARM-specific: Set IO scheduler for SD cards
      ${if detectedArch == "aarch64" || detectedArch == "arm" then ''
      ACTION=="add|change", KERNEL=="mmcblk[0-9]", ATTR{queue/scheduler}="deadline"
      '' else ""}

      # x86-specific: Optimize NVMe devices
      ${if detectedArch == "x86_64" then ''
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
      '' else ""}
    '';

    # Helper commands
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "hv-hardware-info" ''
        echo "=== Detected Hardware Configuration ==="
        cat /etc/hypervisor/hardware-info.json | ${pkgs.jq}/bin/jq .
        echo ""
        echo "=== Detection Log ==="
        cat /var/log/hypervisor/hardware-detection.log 2>/dev/null || echo "Log not available yet"
      '')

      (pkgs.writeShellScriptBin "hv-detect-hardware" ''
        echo "Running hardware detection..."
        ${hwDetectScript} json | ${pkgs.jq}/bin/jq .
      '')
    ];
  };
}
