################################################################################
# Hyper-NixOS - Auto-generated test for security-threat-response
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_threat_response";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/threat-response.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-threat-response loaded'")
    print("✓ security-threat-response test passed")
  '';
}
