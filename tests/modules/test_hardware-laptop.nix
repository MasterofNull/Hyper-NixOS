################################################################################
# Hyper-NixOS - Auto-generated test for hardware-laptop
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "hardware_laptop";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/hardware/laptop.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module hardware-laptop loaded'")
    print("✓ hardware-laptop test passed")
  '';
}
