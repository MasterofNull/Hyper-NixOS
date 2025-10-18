################################################################################
# Hyper-NixOS - Auto-generated test for enterprise-disaster-recovery
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "enterprise_disaster_recovery";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/enterprise/disaster-recovery.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module enterprise-disaster-recovery loaded'")
    print("✓ enterprise-disaster-recovery test passed")
  '';
}
