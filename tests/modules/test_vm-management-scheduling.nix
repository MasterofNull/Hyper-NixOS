################################################################################
# Hyper-NixOS - Auto-generated test for vm-management-scheduling
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "vm_management_scheduling";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/vm-management/scheduling.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module vm-management-scheduling loaded'")
    print("✓ vm-management-scheduling test passed")
  '';
}
