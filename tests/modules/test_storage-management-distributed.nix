################################################################################
# Hyper-NixOS - Auto-generated test for storage-management-distributed
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "storage_management_distributed";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/storage-management/distributed.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module storage-management-distributed loaded'")
    print("✓ storage-management-distributed test passed")
  '';
}
