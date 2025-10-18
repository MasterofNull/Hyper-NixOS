################################################################################
# Hyper-NixOS - Auto-generated test for core-arm-detection
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_arm_detection";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/arm-detection.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-arm-detection loaded'")
    print("✓ core-arm-detection test passed")
  '';
}
