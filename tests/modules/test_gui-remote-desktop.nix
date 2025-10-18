################################################################################
# Hyper-NixOS - Auto-generated test for gui-remote-desktop
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "gui_remote_desktop";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/gui/remote-desktop.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module gui-remote-desktop loaded'")
    print("✓ gui-remote-desktop test passed")
  '';
}
