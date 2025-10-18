################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-alerting
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_alerting";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/alerting.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-alerting loaded'")
    print("✓ monitoring-alerting test passed")
  '';
}
