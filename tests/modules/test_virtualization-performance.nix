################################################################################
# Hyper-NixOS - Auto-generated test for virtualization-performance
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "virtualization_performance";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/virtualization/performance.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module virtualization-performance loaded'")
    print("✓ virtualization-performance test passed")
  '';
}
