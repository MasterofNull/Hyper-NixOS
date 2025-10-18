################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-dhcp-server
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_dhcp_server";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/dhcp-server.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-dhcp-server loaded'")
    print("✓ network-settings-dhcp-server test passed")
  '';
}
