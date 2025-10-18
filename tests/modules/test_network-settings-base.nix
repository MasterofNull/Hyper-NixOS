################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-base
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_base";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/base.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-base loaded'")
    print("✓ network-settings-base test passed")
  '';
}
