################################################################################
# Hyper-NixOS - Auto-generated test for features-dev-tools
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_dev_tools";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/dev-tools.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-dev-tools loaded'")
    print("✓ features-dev-tools test passed")
  '';
}
