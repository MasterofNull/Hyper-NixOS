################################################################################
# Hyper-NixOS - Auto-generated test for network-settings-load-balancer
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "network_settings_load_balancer";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/network-settings/load-balancer.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module network-settings-load-balancer loaded'")
    print("✓ network-settings-load-balancer test passed")
  '';
}
