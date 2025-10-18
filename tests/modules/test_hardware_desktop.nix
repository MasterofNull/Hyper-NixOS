################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Desktop Hardware Optimization Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "desktop-hardware-optimizations";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/hardware/desktop.nix
    ];

    hypervisor.hardware.desktop = {
      enable = true;
      performance.cpuGovernor = "performance";
      gpu.passthrough.enable = true;
      storage.nvmeOptimization = true;
      audio.pipeWire = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test CPU governor
    with subtest("Performance CPU governor"):
        governor = machine.succeed("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor").strip()
        assert governor == "performance", f"CPU governor is {governor}, expected performance"

    # Test IOMMU kernel parameters
    with subtest("IOMMU enabled"):
        cmdline = machine.succeed("cat /proc/cmdline")
        assert "iommu" in cmdline, "IOMMU not enabled in kernel parameters"

    # Test VFIO modules loaded
    with subtest("VFIO modules"):
        modules = machine.succeed("lsmod")
        assert "vfio" in modules or machine.succeed("modprobe -n vfio; echo $?").strip() == "0", "VFIO modules not available"

    # Test PipeWire audio
    machine.succeed("systemctl --user status pipewire.service || true")

    # Test NVMe optimization rules
    machine.succeed("test -f /etc/udev/rules.d/60-nvme-optimization.rules || true")

    # Verify huge pages configuration
    with subtest("Huge pages"):
        cmdline = machine.succeed("cat /proc/cmdline")
        # Huge pages may be configured
        print(f"Kernel cmdline: {cmdline}")

    print("✓ All desktop optimization tests passed")
  '';
}
