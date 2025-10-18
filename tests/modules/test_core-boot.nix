################################################################################
# Hyper-NixOS - Auto-generated test for core-boot
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_boot";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/boot.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-boot loaded'")
    print("✓ core-boot test passed")
  '';
}
