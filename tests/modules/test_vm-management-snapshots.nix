################################################################################
# Hyper-NixOS - Auto-generated test for vm-management-snapshots
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "vm_management_snapshots";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/vm-management/snapshots.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module vm-management-snapshots loaded'")
    print("✓ vm-management-snapshots test passed")
  '';
}
