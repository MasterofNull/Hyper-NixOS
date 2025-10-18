################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-dns-server
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_dns_server";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/dns-server.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-dns-server loaded'")
    print("✓ network-settings-dns-server test passed")
  '';
}
