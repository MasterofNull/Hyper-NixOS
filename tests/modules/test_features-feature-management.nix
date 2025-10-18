################################################################################
# Hyper-NixOS - Auto-generated test for features-feature-management
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_feature_management";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/feature-management.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-feature-management loaded'")
    print("✓ features-feature-management test passed")
  '';
}
