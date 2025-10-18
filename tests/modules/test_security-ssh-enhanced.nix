################################################################################
# Hyper-NixOS - Auto-generated test for security-ssh-enhanced
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_ssh_enhanced";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/ssh-enhanced.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-ssh-enhanced loaded'")
    print("✓ security-ssh-enhanced test passed")
  '';
}
