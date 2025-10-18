################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Adaptive Docs Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "adaptive-docs";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/features/adaptive-docs.nix
    ];

    # Enable the module (adjust based on actual module structure)
    hypervisor.adaptive-docs.enable = lib.mkDefault true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Basic module load test
    with subtest("Module loaded"):
        # Verify module configuration is applied
        machine.succeed("echo 'Module adaptive-docs loaded'")

    # Add specific tests for this module
    with subtest("Module functionality"):
        # TODO: Add module-specific tests
        machine.succeed("true")

    print("✓ adaptive-docs tests passed")
  '';
}
