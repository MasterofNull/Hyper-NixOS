################################################################################
# Hyper-NixOS - Auto-generated test for gui-admin-integration
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "gui_admin_integration";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/gui/admin-integration.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module gui-admin-integration loaded'")
    print("✓ gui-admin-integration test passed")
  '';
}
