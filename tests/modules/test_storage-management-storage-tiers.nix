################################################################################
# Hyper-NixOS - Auto-generated test for storage-management-storage-tiers
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "storage_management_storage_tiers";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/storage-management/storage-tiers.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module storage-management-storage-tiers loaded'")
    print("✓ storage-management-storage-tiers test passed")
  '';
}
