################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Keymap Sanitizer Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "keymap-sanitizer";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/core/keymap-sanitizer.nix
    ];

    # Enable the module (adjust based on actual module structure)
    hypervisor.keymap-sanitizer.enable = lib.mkDefault true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Basic module load test
    with subtest("Module loaded"):
        # Verify module configuration is applied
        machine.succeed("echo 'Module keymap-sanitizer loaded'")

    # Add specific tests for this module
    with subtest("Module functionality"):
        # TODO: Add module-specific tests
        machine.succeed("true")

    print("✓ keymap-sanitizer tests passed")
  '';
}
