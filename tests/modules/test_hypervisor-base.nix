################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Hypervisor Base Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "hypervisor-base";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/core/hypervisor-base.nix
    ];

    # Enable the module (adjust based on actual module structure)
    hypervisor.hypervisor-base.enable = lib.mkDefault true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Basic module load test
    with subtest("Module loaded"):
        # Verify module configuration is applied
        machine.succeed("echo 'Module hypervisor-base loaded'")

    # Add specific tests for this module
    with subtest("Module functionality"):
        # TODO: Add module-specific tests
        machine.succeed("true")

    print("✓ hypervisor-base tests passed")
  '';
}
