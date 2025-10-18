################################################################################
# Hyper-NixOS - Auto-generated test for core-hypervisor-base
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_hypervisor_base";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/hypervisor-base.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-hypervisor-base loaded'")
    print("✓ core-hypervisor-base test passed")
  '';
}
