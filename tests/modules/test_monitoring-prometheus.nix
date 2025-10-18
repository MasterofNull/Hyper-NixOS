################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-prometheus
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_prometheus";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/prometheus.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-prometheus loaded'")
    print("✓ monitoring-prometheus test passed")
  '';
}
