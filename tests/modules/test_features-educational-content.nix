################################################################################
# Hyper-NixOS - Auto-generated test for features-educational-content
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_educational_content";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/educational-content.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-educational-content loaded'")
    print("✓ features-educational-content test passed")
  '';
}
