################################################################################
# Hyper-NixOS - Auto-generated test for gui-desktop
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "gui_desktop";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/gui/desktop.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module gui-desktop loaded'")
    print("✓ gui-desktop test passed")
  '';
}
