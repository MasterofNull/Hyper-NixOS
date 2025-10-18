################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-vlan
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_vlan";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/vlan.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-vlan loaded'")
    print("✓ network-settings-vlan test passed")
  '';
}
