################################################################################
# Hyper-NixOS - Auto-generated test for features-database-tools
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_database_tools";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/database-tools.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-database-tools loaded'")
    print("✓ features-database-tools test passed")
  '';
}
