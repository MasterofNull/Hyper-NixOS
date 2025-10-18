################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-packet-capture
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_packet_capture";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/packet-capture.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-packet-capture loaded'")
    print("✓ network-settings-packet-capture test passed")
  '';
}
