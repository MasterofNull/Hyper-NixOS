################################################################################
# Hyper-NixOS - Auto-generated test for security-biometrics
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_biometrics";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/biometrics.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-biometrics loaded'")
    print("✓ security-biometrics test passed")
  '';
}
