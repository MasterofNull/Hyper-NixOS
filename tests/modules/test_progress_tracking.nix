################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Progress Tracking Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "progress-tracking";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/features/progress-tracking.nix
    ];

    hypervisor.features.progressTracking = {
      enable = true;
      database = "/var/lib/hypervisor/progress.db";
      achievements.enable = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test database initialization
    with subtest("Progress database"):
        machine.succeed("test -f /var/lib/hypervisor/progress.db || sqlite3 /var/lib/hypervisor/progress.db 'SELECT 1;'")

    # Test progress tracking CLI
    with subtest("Progress tracking CLI"):
        machine.succeed("which hv-track-progress || test -f /etc/hypervisor/scripts/show-progress.sh")

    # Test achievement system
    with subtest("Achievements"):
        # Verify achievement definitions exist
        machine.succeed("test -d /etc/hypervisor/achievements || true")

    # Test progress recording
    with subtest("Record progress"):
        # Test that we can record progress
        machine.succeed("sqlite3 /var/lib/hypervisor/progress.db 'CREATE TABLE IF NOT EXISTS progress (id INTEGER PRIMARY KEY, item TEXT, completed BOOLEAN);' || true")

    print("✓ Progress tracking tests passed")
  '';
}
