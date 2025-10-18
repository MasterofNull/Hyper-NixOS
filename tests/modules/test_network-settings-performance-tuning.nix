################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-performance-tuning
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_performance_tuning";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/performance-tuning.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-performance-tuning loaded'")
    print("✓ network-settings-performance-tuning test passed")
  '';
}
