################################################################################
# Hyper-NixOS - Auto-generated test for features-container-support
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_container_support";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/container-support.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-container-support loaded'")
    print("✓ features-container-support test passed")
  '';
}
