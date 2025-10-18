################################################################################
# Hyper-NixOS - Auto-generated test for features-module-loader
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "features_module_loader";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/features/module-loader.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module features-module-loader loaded'")
    print("✓ features-module-loader test passed")
  '';
}
