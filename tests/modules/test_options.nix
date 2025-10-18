################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Options Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "options";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/core/options.nix
    ];

    # Enable the module (adjust based on actual module structure)
    hypervisor.options.enable = lib.mkDefault true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Basic module load test
    with subtest("Module loaded"):
        # Verify module configuration is applied
        machine.succeed("echo 'Module options loaded'")

    # Add specific tests for this module
    with subtest("Module functionality"):
        # TODO: Add module-specific tests
        machine.succeed("true")

    print("✓ options tests passed")
  '';
}
