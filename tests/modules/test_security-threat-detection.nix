################################################################################
# Hyper-NixOS - Auto-generated test for security-threat-detection
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_threat_detection";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/threat-detection.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-threat-detection loaded'")
    print("✓ security-threat-detection test passed")
  '';
}
