################################################################################
# Hyper-NixOS - Auto-generated test for gui-local.example
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "gui_local.example";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/gui-local.example.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module gui-local.example loaded'")
    print("✓ gui-local.example test passed")
  '';
}
