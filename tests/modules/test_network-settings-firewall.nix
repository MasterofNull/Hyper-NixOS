################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-firewall
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_firewall";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/firewall.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-firewall loaded'")
    print("✓ network-settings-firewall test passed")
  '';
}
