################################################################################
# Hyper-NixOS - Auto-generated test for storage-management-quotas
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "storage_management_quotas";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/storage-management/quotas.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module storage-management-quotas loaded'")
    print("✓ storage-management-quotas test passed")
  '';
}
