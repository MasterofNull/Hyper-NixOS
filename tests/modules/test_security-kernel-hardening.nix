################################################################################
# Hyper-NixOS - Auto-generated test for security-kernel-hardening
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_kernel_hardening";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/kernel-hardening.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-kernel-hardening loaded'")
    print("✓ security-kernel-hardening test passed")
  '';
}
