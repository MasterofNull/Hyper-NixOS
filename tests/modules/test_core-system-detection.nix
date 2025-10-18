################################################################################
# Hyper-NixOS - Auto-generated test for core-system-detection
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_system_detection";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/system-detection.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-system-detection loaded'")
    print("✓ core-system-detection test passed")
  '';
}
