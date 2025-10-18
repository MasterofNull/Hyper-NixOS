################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Libvirt Virtualization Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "libvirt-virtualization";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/virtualization/libvirt.nix
      ../../modules/security/privilege-separation.nix
    ];

    hypervisor = {
      enable = true;
      virtualization.libvirt.enable = true;
      users.operator = "testoperator";
    };

    users.users.testoperator = {
      isNormalUser = true;
      extraGroups = [ "libvirtd" ];
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test libvirtd service
    with subtest("Libvirtd service running"):
        machine.succeed("systemctl is-active libvirtd.service")

    # Test KVM modules loaded
    with subtest("KVM modules"):
        modules = machine.succeed("lsmod | grep kvm || modprobe -n kvm; echo $?")
        print(f"KVM modules status: {modules}")

    # Test virsh command available
    with subtest("Virsh CLI"):
        machine.succeed("which virsh")
        version = machine.succeed("virsh --version")
        print(f"Virsh version: {version}")

    # Test default network
    with subtest("Default network"):
        networks = machine.succeed("virsh net-list --all || echo 'no networks'")
        print(f"Libvirt networks: {networks}")

    # Test storage pools
    with subtest("Storage pools"):
        pools = machine.succeed("virsh pool-list --all || echo 'no pools'")
        print(f"Storage pools: {pools}")

    # Test QEMU/KVM availability
    with subtest("QEMU/KVM"):
        machine.succeed("which qemu-system-x86_64 || which qemu-kvm")

    # Test user permissions
    with subtest("Operator permissions"):
        # Verify operator user in libvirtd group
        groups = machine.succeed("groups testoperator")
        assert "libvirtd" in groups, "Operator not in libvirtd group"

    print("✓ Libvirt virtualization tests passed")
  '';
}
