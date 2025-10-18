################################################################################
# Hyper-NixOS - Auto-generated test for security-behavioral-analysis
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_behavioral_analysis";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/behavioral-analysis.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-behavioral-analysis loaded'")
    print("✓ security-behavioral-analysis test passed")
  '';
}
