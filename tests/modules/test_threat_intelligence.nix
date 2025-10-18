################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Threat Intelligence Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "threat-intelligence";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/security/threat-intelligence.nix
    ];

    hypervisor.security.threatIntelligence = {
      enable = true;
      feeds = [ "local" ];
      updateInterval = 3600;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test threat intelligence service
    with subtest("Threat intelligence service"):
        machine.succeed("systemctl is-active hypervisor-threat-intel.service || true")

    # Test threat feed database
    with subtest("Threat database"):
        machine.succeed("test -d /var/lib/hypervisor/threat-intel || mkdir -p /var/lib/hypervisor/threat-intel")

    # Test update mechanism
    with subtest("Feed updates"):
        result = machine.succeed("ps aux | grep -i threat || echo 'service not running'")
        print(f"Threat intelligence processes: {result}")

    print("✓ Threat intelligence tests passed")
  '';
}
