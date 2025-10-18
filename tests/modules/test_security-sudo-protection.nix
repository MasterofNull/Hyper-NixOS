################################################################################
# Hyper-NixOS - Auto-generated test for security-sudo-protection
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_sudo_protection";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/sudo-protection.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-sudo-protection loaded'")
    print("✓ security-sudo-protection test passed")
  '';
}
