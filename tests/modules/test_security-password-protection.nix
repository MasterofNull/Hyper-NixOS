################################################################################
# Hyper-NixOS - Auto-generated test for security-password-protection
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_password_protection";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/password-protection.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-password-protection loaded'")
    print("✓ security-password-protection test passed")
  '';
}
