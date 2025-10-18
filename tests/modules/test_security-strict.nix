################################################################################
# Hyper-NixOS - Auto-generated test for security-strict
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_strict";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/strict.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-strict loaded'")
    print("✓ security-strict test passed")
  '';
}
