################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-logging
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_logging";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/logging.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-logging loaded'")
    print("✓ monitoring-logging test passed")
  '';
}
