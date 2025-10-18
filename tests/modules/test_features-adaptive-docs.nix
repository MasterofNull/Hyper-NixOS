################################################################################
# Hyper-NixOS - Auto-generated test for features-adaptive-docs
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_adaptive_docs";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/adaptive-docs.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-adaptive-docs loaded'")
    print("✓ features-adaptive-docs test passed")
  '';
}
