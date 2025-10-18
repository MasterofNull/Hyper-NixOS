# Hyper-NixOS CPU Detection Module
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Automatic CPU vendor detection for Intel vs AMD
# This module ensures correct kernel parameters and modules are set
# based on the actual CPU in the system

{ config, lib, pkgs, ... }:

with lib;

let
  # Detect CPU vendor from /proc/cpuinfo
  cpuVendorDetection =
    if builtins.match ".*AuthenticAMD.*" (builtins.readFile /proc/cpuinfo) != null
    then "amd"
    else if builtins.match ".*GenuineIntel.*" (builtins.readFile /proc/cpuinfo) != null
    then "intel"
    else "unknown";

  # CPU-specific configuration
  cpuConfig = {
    amd = {
      iommuParam = "amd_iommu=on";
      nestedParam = "kvm_amd.nested=1";
      kvmModule = "kvm-amd";
    };
    intel = {
      iommuParam = "intel_iommu=on";
      nestedParam = "kvm_intel.nested=1";
      kvmModule = "kvm-intel";
    };
    unknown = {
      iommuParam = "iommu=on";
      nestedParam = "";
      kvmModule = "kvm";
    };
  };

  detectedConfig = cpuConfig.${cpuVendorDetection};

in {
  options.hypervisor.cpu = {
    vendor = mkOption {
      type = types.enum [ "amd" "intel" "unknown" "auto" ];
      default = "auto";
      description = ''
        CPU vendor for this system.
        Set to "auto" for automatic detection, or manually specify "amd" or "intel".
      '';
    };

    autoDetect = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Automatically detect CPU vendor and configure appropriate settings.
        When enabled, kernel parameters and modules are set based on detected CPU.
      '';
    };
  };

  config = mkIf config.hypervisor.cpu.autoDetect {
    # Provide detected vendor info
    environment.etc."hypervisor/cpu-vendor".text = cpuVendorDetection;

    # Apply CPU-specific kernel parameters
    boot.kernelParams = mkBefore [
      detectedConfig.iommuParam
      detectedConfig.nestedParam
    ];

    # Apply CPU-specific kernel modules
    boot.kernelModules = mkBefore [
      detectedConfig.kvmModule
    ];

    # Add friendly message to help users understand the detection
    warnings = mkIf (cpuVendorDetection == "unknown") [
      ''
        CPU vendor could not be automatically detected.
        Using generic KVM settings. If virtualization doesn't work properly,
        manually set hypervisor.cpu.vendor to "amd" or "intel".
      ''
    ];

    # Log detection for debugging
    system.activationScripts.cpuDetection = ''
      echo "[Hyper-NixOS] Detected CPU vendor: ${cpuVendorDetection}" >> /var/log/hypervisor-cpu-detection.log
      echo "[Hyper-NixOS] Using KVM module: ${detectedConfig.kvmModule}" >> /var/log/hypervisor-cpu-detection.log
      echo "[Hyper-NixOS] Using IOMMU param: ${detectedConfig.iommuParam}" >> /var/log/hypervisor-cpu-detection.log
    '';
  };
}
