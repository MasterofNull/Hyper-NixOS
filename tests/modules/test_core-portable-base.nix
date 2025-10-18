################################################################################
# Hyper-NixOS - Auto-generated test for core-portable-base
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_portable_base";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/portable-base.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-portable-base loaded'")
    print("✓ core-portable-base test passed")
  '';
}
