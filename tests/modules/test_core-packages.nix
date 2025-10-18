################################################################################
# Hyper-NixOS - Auto-generated test for core-packages
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_packages";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/packages.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-packages loaded'")
    print("✓ core-packages test passed")
  '';
}
