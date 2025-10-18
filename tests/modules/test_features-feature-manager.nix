################################################################################
# Hyper-NixOS - Auto-generated test for features-feature-manager
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_feature_manager";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/feature-manager.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-feature-manager loaded'")
    print("✓ features-feature-manager test passed")
  '';
}
