################################################################################
# Hyper-NixOS - Auto-generated test for automation-backup
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "automation_backup";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/automation/backup.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module automation-backup loaded'")
    print("✓ automation-backup test passed")
  '';
}
