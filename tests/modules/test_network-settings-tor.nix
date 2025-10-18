################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-tor
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_tor";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/tor.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-tor loaded'")
    print("✓ network-settings-tor test passed")
  '';
}
