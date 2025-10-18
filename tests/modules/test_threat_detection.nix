# Test for threat detection module
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
nixosTest {
  name = "threat-detection-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/security/threat-detection.nix
      ../../modules/monitoring/metrics.nix
    ];

    hypervisor.security.threatDetection.enable = true;
    hypervisor.security.threatDetection.behavioralAnalysis = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify threat detection service is running
    machine.wait_for_unit("hypervisor-threat-detection.service")

    # Check that monitoring is active
    machine.succeed("systemctl is-active hypervisor-threat-detection.service")

    # Verify configuration files
    machine.succeed("test -f /etc/hypervisor/threat-detection.conf")

    # Test alert mechanism exists
    machine.succeed("test -d /var/lib/hypervisor/threats")

    print("Threat detection module: PASS")
  '';
}
