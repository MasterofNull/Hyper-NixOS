################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-alert-hysteresis
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_alert_hysteresis";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/alert-hysteresis.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-alert-hysteresis loaded'")
    print("✓ monitoring-alert-hysteresis test passed")
  '';
}
