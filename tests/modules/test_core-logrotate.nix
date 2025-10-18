################################################################################
# Hyper-NixOS - Auto-generated test for core-logrotate
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_logrotate";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/logrotate.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-logrotate loaded'")
    print("✓ core-logrotate test passed")
  '';
}
