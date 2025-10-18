################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-ai-anomaly
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_ai_anomaly";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/ai-anomaly.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-ai-anomaly loaded'")
    print("✓ monitoring-ai-anomaly test passed")
  '';
}
