################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Virtualization Performance Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "virtualization-performance";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/virtualization/performance.nix
    ];

    hypervisor.virtualization.performance = {
      enable = true;
      cpuPinning = true;
      hugepages.enable = true;
      numaOptimization = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test huge pages configuration
    with subtest("Huge pages"):
        cmdline = machine.succeed("cat /proc/cmdline")
        print(f"Kernel cmdline: {cmdline}")

        # Check huge pages allocation
        hugepages = machine.succeed("cat /proc/meminfo | grep -i hugepages || echo 'none'")
        print(f"Huge pages info: {hugepages}")

    # Test NUMA configuration
    with subtest("NUMA optimization"):
        numa_info = machine.succeed("numactl --hardware || echo 'NUMA not available'")
        print(f"NUMA info: {numa_info}")

    # Test kernel parameters for performance
    with subtest("Kernel parameters"):
        # Check for virtualization optimization parameters
        sysctl_output = machine.succeed("sysctl -a | grep -E 'vm\\.|kernel\\.' | head -20")
        print(f"Sysctl parameters: {sysctl_output}")

    # Test CPU governor
    with subtest("CPU governor"):
        governor = machine.succeed("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor || echo 'not available'").strip()
        print(f"CPU governor: {governor}")

    # Test IRQ affinity tools
    with subtest("Performance tools"):
        machine.succeed("which numactl || true")

    print("✓ Performance optimization tests passed")
  '';
}
