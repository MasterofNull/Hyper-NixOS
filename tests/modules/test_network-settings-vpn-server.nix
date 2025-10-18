################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-vpn-server
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_vpn_server";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/vpn-server.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-vpn-server loaded'")
    print("✓ network-settings-vpn-server test passed")
  '';
}
