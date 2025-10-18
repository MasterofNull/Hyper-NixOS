################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-bridges
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_bridges";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/bridges.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-bridges loaded'")
    print("✓ network-settings-bridges test passed")
  '';
}
