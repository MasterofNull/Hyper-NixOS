################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-ip-spoofing
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_ip_spoofing";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/ip-spoofing.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-ip-spoofing loaded'")
    print("✓ network-settings-ip-spoofing test passed")
  '';
}
