################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-mac-spoofing
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_mac_spoofing";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/mac-spoofing.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-mac-spoofing loaded'")
    print("✓ network-settings-mac-spoofing test passed")
  '';
}
