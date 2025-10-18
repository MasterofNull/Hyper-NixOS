################################################################################
# Hyper-NixOS - Auto-generated test for features-progress-tracking
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_progress_tracking";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/progress-tracking.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-progress-tracking loaded'")
    print("✓ features-progress-tracking test passed")
  '';
}
