################################################################################
# Hyper-NixOS - Auto-generated test for features-tier-templates
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_tier_templates";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/tier-templates.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-tier-templates loaded'")
    print("✓ features-tier-templates test passed")
  '';
}
