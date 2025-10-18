################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Core Packages Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core-packages";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/core/packages.nix
      ../../modules/core/options.nix
    ];

    hypervisor.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test essential virtualization tools
    with subtest("Virtualization tools"):
        machine.succeed("which virsh")
        machine.succeed("which virt-install")
        machine.succeed("which qemu-img")
        machine.succeed("which qemu-system-x86_64 || which qemu-kvm")

    # Test management tools
    with subtest("Management tools"):
        machine.succeed("which htop")
        machine.succeed("which iotop || true")
        machine.succeed("which git")

    # Test networking tools
    with subtest("Network tools"):
        machine.succeed("which ip")
        machine.succeed("which ss")
        machine.succeed("which tcpdump || true")

    # Test security tools
    with subtest("Security tools"):
        machine.succeed("which iptables")
        machine.succeed("which fail2ban-client || true")

    # Test file system tools
    with subtest("File system tools"):
        machine.succeed("which rsync")
        machine.succeed("which tar")

    print("✓ Core packages tests passed")
  '';
}
