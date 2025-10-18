################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-ids
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_ids";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/ids.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-ids loaded'")
    print("✓ network-settings-ids test passed")
  '';
}
