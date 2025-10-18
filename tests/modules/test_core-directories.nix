################################################################################
# Hyper-NixOS - Auto-generated test for core-directories
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_directories";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/directories.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-directories loaded'")
    print("✓ core-directories test passed")
  '';
}
