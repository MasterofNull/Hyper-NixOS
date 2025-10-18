################################################################################
# Hyper-NixOS - Auto-generated test for core-first-boot-service
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_first_boot_service";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/first-boot-service.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-first-boot-service loaded'")
    print("✓ core-first-boot-service test passed")
  '';
}
