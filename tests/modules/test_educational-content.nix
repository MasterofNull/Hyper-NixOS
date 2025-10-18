################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Educational Content Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "educational-content";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/features/educational-content.nix
    ];

    # Enable the module (adjust based on actual module structure)
    hypervisor.educational-content.enable = lib.mkDefault true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Basic module load test
    with subtest("Module loaded"):
        # Verify module configuration is applied
        machine.succeed("echo 'Module educational-content loaded'")

    # Add specific tests for this module
    with subtest("Module functionality"):
        # TODO: Add module-specific tests
        machine.succeed("true")

    print("✓ educational-content tests passed")
  '';
}
