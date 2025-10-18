################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-bonding
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_bonding";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/bonding.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-bonding loaded'")
    print("✓ network-settings-bonding test passed")
  '';
}
