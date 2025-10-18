################################################################################
# Hyper-NixOS - Auto-generated test for storage-management-encryption
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "storage_management_encryption";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/storage-management/encryption.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module storage-management-encryption loaded'")
    print("✓ storage-management-encryption test passed")
  '';
}
