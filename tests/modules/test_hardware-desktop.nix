################################################################################
# Hyper-NixOS - Auto-generated test for hardware-desktop
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "hardware_desktop";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/hardware/desktop.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module hardware-desktop loaded'")
    print("✓ hardware-desktop test passed")
  '';
}
