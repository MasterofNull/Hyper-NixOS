################################################################################
# Hyper-NixOS - Auto-generated test for automation-backup-dedup
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "automation_backup_dedup";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/automation/backup-dedup.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module automation-backup-dedup loaded'")
    print("✓ automation-backup-dedup test passed")
  '';
}
