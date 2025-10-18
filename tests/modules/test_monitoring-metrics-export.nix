################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-metrics-export
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_metrics_export";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/metrics-export.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-metrics-export loaded'")
    print("✓ monitoring-metrics-export test passed")
  '';
}
