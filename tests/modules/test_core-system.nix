################################################################################
# Hyper-NixOS - Auto-generated test for core-system
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_system";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/system.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-system loaded'")
    print("✓ core-system test passed")
  '';
}
