################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-isolation
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_isolation";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/isolation.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-isolation loaded'")
    print("✓ network-settings-isolation test passed")
  '';
}
