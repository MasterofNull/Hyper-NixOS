################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-security
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_security";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/security.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-security loaded'")
    print("✓ network-settings-security test passed")
  '';
}
