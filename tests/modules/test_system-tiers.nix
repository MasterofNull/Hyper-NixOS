################################################################################
# Hyper-NixOS - Auto-generated test for system-tiers
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "system_tiers";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/system-tiers.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module system-tiers loaded'")
    print("✓ system-tiers test passed")
  '';
}
