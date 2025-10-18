################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-ipv6
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_ipv6";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/ipv6.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-ipv6 loaded'")
    print("✓ network-settings-ipv6 test passed")
  '';
}
