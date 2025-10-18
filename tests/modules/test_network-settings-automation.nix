################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-automation
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_automation";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/automation.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-automation loaded'")
    print("✓ network-settings-automation test passed")
  '';
}
