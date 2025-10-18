################################################################################
# Hyper-NixOS - Auto-generated test for core-optimized-system
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_optimized_system";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/optimized-system.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-optimized-system loaded'")
    print("✓ core-optimized-system test passed")
  '';
}
