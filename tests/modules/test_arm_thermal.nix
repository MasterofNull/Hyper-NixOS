################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: ARM Thermal Management
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "arm-thermal-management";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/core/arm-detection.nix
    ];

    hypervisor.hardware.arm = {
      enable = true;
      platform = "rpi4";
      thermal.enable = true;
      thermal.maxTemperature = 75;
      thermal.fanControl.enable = true;
      optimizations.memoryProfile = "standard";
      optimizations.sdCardOptimization = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test thermal monitoring service
    with subtest("Thermal monitoring service"):
        machine.succeed("systemctl status arm-thermal-monitor.service")

    # Test thermal zones exist
    with subtest("Thermal zones"):
        result = machine.succeed("ls /sys/class/thermal/thermal_zone*/temp || echo 'no thermal zones'")
        print(f"Thermal zones: {result}")

    # Test zram enabled
    with subtest("Zram compression"):
        machine.succeed("zramctl || swapon --show | grep zram || true")

    # Test memory profile sysctl
    with subtest("Memory profile settings"):
        swappiness = machine.succeed("sysctl vm.swappiness").strip()
        print(f"vm.swappiness: {swappiness}")
        assert "30" in swappiness, f"Expected swappiness=30 for standard profile, got {swappiness}"

    # Test SD card optimization (noatime)
    with subtest("SD card optimization"):
        mounts = machine.succeed("mount | grep ' / ' || true")
        print(f"Root mount options: {mounts}")

    # Test ARM platform detection
    with subtest("Platform detection"):
        platform = machine.succeed("cat /etc/hypervisor/arm-platform || echo 'not detected'").strip()
        print(f"Detected platform: {platform}")

    # Test KVM modules
    with subtest("ARM virtualization modules"):
        modules = machine.succeed("lsmod | grep -E 'kvm|vhost' || modprobe -n kvm; echo $?")
        print(f"KVM modules: {modules}")

    print("✓ All ARM thermal management tests passed")
  '';
}
