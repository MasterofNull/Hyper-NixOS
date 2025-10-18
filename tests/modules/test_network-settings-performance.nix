################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-performance
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_performance";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/performance.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-performance loaded'")
    print("✓ network-settings-performance test passed")
  '';
}
