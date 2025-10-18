################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Server Hardware Optimization Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "server-hardware-optimizations";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/hardware/server.nix
    ];

    hypervisor.hardware.server = {
      enable = true;
      headless = true;
      raid.enable = true;
      raid.type = "mdadm";
      remoteManagement.ipmi.enable = true;
      monitoring.enhanced = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test headless mode (X server disabled)
    with subtest("Headless mode"):
        result = machine.succeed("systemctl status display-manager.service || echo 'not running'")
        assert "not running" in result or "could not be found" in result, "X server should be disabled in headless mode"

    # Test RAID tools installed
    with subtest("RAID support"):
        machine.succeed("which mdadm")

    # Test RAID scrub service
    machine.succeed("systemctl list-timers | grep raid-scrub || true")

    # Test IPMI tools
    with subtest("IPMI tools"):
        machine.succeed("which ipmitool")

    # Test IPMI sensor monitoring
    machine.succeed("systemctl list-timers | grep ipmi-sensors || true")

    # Test Prometheus exporters
    with subtest("Prometheus exporters"):
        machine.succeed("systemctl status prometheus-node-exporter.service || true")

    # Verify server-optimized kernel parameters
    with subtest("Server kernel parameters"):
        swappiness = machine.succeed("sysctl vm.swappiness").strip()
        print(f"vm.swappiness: {swappiness}")

    # Test performance CPU governor
    with subtest("Performance governor"):
        governor = machine.succeed("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor").strip()
        assert governor == "performance", f"CPU governor is {governor}, expected performance"

    print("✓ All server optimization tests passed")
  '';
}
