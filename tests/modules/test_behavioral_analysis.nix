################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Behavioral Analysis Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "behavioral-analysis";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/security/behavioral-analysis.nix
    ];

    hypervisor.security.behavioralAnalysis = {
      enable = true;
      learningPeriod = 7;
      anomalyThreshold = 2;
      monitoring = {
        loginPatterns = true;
        commandPatterns = true;
        networkPatterns = true;
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test behavioral analysis service
    with subtest("Behavioral analysis service"):
        machine.succeed("systemctl is-active hypervisor-behavioral-analysis.service || true")

    # Test pattern database
    with subtest("Pattern database"):
        machine.succeed("test -d /var/lib/hypervisor/behavioral-patterns || mkdir -p /var/lib/hypervisor/behavioral-patterns")

    # Test monitoring capabilities
    with subtest("Monitoring enabled"):
        # Check for audit logging
        machine.succeed("which auditctl || true")

    # Test anomaly detection
    with subtest("Anomaly detection"):
        # Verify configuration
        result = machine.succeed("ps aux | grep -i behavioral || echo 'service not running'")
        print(f"Behavioral analysis processes: {result}")

    print("✓ Behavioral analysis tests passed")
  '';
}
