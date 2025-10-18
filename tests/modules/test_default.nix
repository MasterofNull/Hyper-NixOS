################################################################################
# Hyper-NixOS - Auto-generated test for default
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "default";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/default.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module default loaded'")
    print("✓ default test passed")
  '';
}
