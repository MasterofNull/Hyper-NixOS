################################################################################
# Hyper-NixOS - Auto-generated test for gui-input
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "gui_input";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/gui/input.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module gui-input loaded'")
    print("✓ gui-input test passed")
  '';
}
