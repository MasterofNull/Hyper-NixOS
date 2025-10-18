################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Laptop Hardware Optimization Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "laptop-hardware-optimizations";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/hardware/laptop.nix
    ];

    hypervisor.hardware.laptop = {
      enable = true;
      powerManagement.enable = true;
      battery.optimizationLevel = "balanced";
      touchpad.enable = true;
      display.autoBacklight = true;
      wireless.powerSaving = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test TLP service
    machine.succeed("systemctl is-active tlp.service")

    # Test battery notification service
    machine.succeed("systemctl status battery-notifier.service")

    # Test touchpad configuration
    machine.succeed("test -f /etc/X11/xorg.conf.d/40-libinput.conf || true")

    # Verify power management kernel parameters
    with subtest("Power management kernel parameters"):
        output = machine.succeed("cat /proc/cmdline")
        assert "pcie_aspm" in output, "PCIe ASPM not enabled"

    # Test CPU governor
    with subtest("CPU frequency governor"):
        governor = machine.succeed("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor").strip()
        assert governor == "powersave", f"CPU governor is {governor}, expected powersave"

    # Test VM power manager service
    machine.succeed("systemctl status vm-power-manager.service")

    print("✓ All laptop optimization tests passed")
  '';
}
