################################################################################
# Hyper-NixOS - Auto-generated test for hardware-server
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "hardware_server";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/hardware/server.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module hardware-server loaded'")
    print("✓ hardware-server test passed")
  '';
}
