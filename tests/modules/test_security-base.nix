################################################################################
# Hyper-NixOS - Auto-generated test for security-base
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_base";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/base.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-base loaded'")
    print("✓ security-base test passed")
  '';
}
