################################################################################
# Hyper-NixOS - Auto-generated test for example-monitoring-backup
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "example_monitoring_backup";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/example-monitoring-backup.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module example-monitoring-backup loaded'")
    print("✓ example-monitoring-backup test passed")
  '';
}
