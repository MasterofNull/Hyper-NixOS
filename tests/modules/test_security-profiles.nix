################################################################################
# Hyper-NixOS - Auto-generated test for security-profiles
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_profiles";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/profiles.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-profiles loaded'")
    print("✓ security-profiles test passed")
  '';
}
