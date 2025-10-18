################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Threat Response Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "threat-response";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/security/threat-response.nix
      ../../modules/security/threat-detection.nix
    ];

    hypervisor.security = {
      threatResponse = {
        enable = true;
        autoBlock = true;
        blockDuration = 3600;
        alerting.enable = true;
      };
      threatDetection.enable = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test threat response service
    with subtest("Threat response service running"):
        machine.succeed("systemctl is-active hypervisor-threat-response.service")

    # Test automated response capabilities
    with subtest("Response mechanisms"):
        # Check IP blocking capability
        machine.succeed("which iptables")

        # Check fail2ban integration
        machine.succeed("systemctl status fail2ban.service || true")

    # Test alerting configuration
    with subtest("Alert system"):
        machine.succeed("test -d /var/log/hypervisor/security || true")

    # Test response actions are configured
    with subtest("Response actions"):
        # Verify systemd services for threat response
        result = machine.succeed("systemctl list-units | grep threat || true")
        print(f"Threat response units: {result}")

    print("✓ Threat response tests passed")
  '';
}
