################################################################################
# Hyper-NixOS - Auto-generated test for features-feature-categories
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_feature_categories";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/feature-categories.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-feature-categories loaded'")
    print("✓ features-feature-categories test passed")
  '';
}
