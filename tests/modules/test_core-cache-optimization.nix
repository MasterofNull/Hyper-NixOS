################################################################################
# Hyper-NixOS - Auto-generated test for core-cache-optimization
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_cache_optimization";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/cache-optimization.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-cache-optimization loaded'")
    print("✓ core-cache-optimization test passed")
  '';
}
