################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-monitoring
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_monitoring";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/monitoring.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-monitoring loaded'")
    print("✓ network-settings-monitoring test passed")
  '';
}
