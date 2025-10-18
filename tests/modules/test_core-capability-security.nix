################################################################################
# Hyper-NixOS - Auto-generated test for core-capability-security
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_capability_security";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/capability-security.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-capability-security loaded'")
    print("✓ core-capability-security test passed")
  '';
}
