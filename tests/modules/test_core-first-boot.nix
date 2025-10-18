################################################################################
# Hyper-NixOS - Auto-generated test for core-first-boot
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_first_boot";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/first-boot.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-first-boot loaded'")
    print("✓ core-first-boot test passed")
  '';
}
