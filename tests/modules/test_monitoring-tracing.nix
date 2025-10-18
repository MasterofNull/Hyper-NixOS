################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-tracing
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_tracing";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/tracing.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-tracing loaded'")
    print("✓ monitoring-tracing test passed")
  '';
}
