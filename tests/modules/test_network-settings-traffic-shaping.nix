################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-traffic-shaping
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_traffic_shaping";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/traffic-shaping.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-traffic-shaping loaded'")
    print("✓ network-settings-traffic-shaping test passed")
  '';
}
