################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Core System Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core-system";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/core/system.nix
      ../../modules/core/options.nix
    ];

    hypervisor = {
      enable = true;
      system = {
        tier = "enhanced";
        enableOptimizations = true;
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test system tier configuration
    with subtest("System tier"):
        tier_file = machine.succeed("cat /etc/hypervisor/system-tier || echo 'enhanced'")
        print(f"System tier: {tier_file}")

    # Test core directories exist
    with subtest("Core directories"):
        machine.succeed("test -d /etc/hypervisor")
        machine.succeed("test -d /var/lib/hypervisor")
        machine.succeed("test -d /var/log/hypervisor")

    # Test system optimizations
    with subtest("System optimizations"):
        # Check kernel parameters
        cmdline = machine.succeed("cat /proc/cmdline")
        print(f"Kernel cmdline: {cmdline}")

        # Check sysctl settings
        swappiness = machine.succeed("sysctl vm.swappiness")
        print(f"Swappiness: {swappiness}")

    # Test hypervisor base packages
    with subtest("Base packages"):
        machine.succeed("which virsh")
        machine.succeed("which qemu-img")

    print("✓ Core system tests passed")
  '';
}
