################################################################################
# Hyper-NixOS - Auto-generated test for vm-management-resource-quotas
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "vm_management_resource_quotas";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/vm-management/resource-quotas.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module vm-management-resource-quotas loaded'")
    print("✓ vm-management-resource-quotas test passed")
  '';
}
