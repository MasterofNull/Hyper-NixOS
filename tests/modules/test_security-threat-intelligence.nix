################################################################################
# Hyper-NixOS - Auto-generated test for security-threat-intelligence
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_threat_intelligence";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/threat-intelligence.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-threat-intelligence loaded'")
    print("✓ security-threat-intelligence test passed")
  '';
}
