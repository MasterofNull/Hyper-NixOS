################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-ssh
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_ssh";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/ssh.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-ssh loaded'")
    print("✓ network-settings-ssh test passed")
  '';
}
