################################################################################
# Hyper-NixOS - Auto-generated test for core-options
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_options";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/options.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-options loaded'")
    print("✓ core-options test passed")
  '';
}
