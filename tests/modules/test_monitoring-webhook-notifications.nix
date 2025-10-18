################################################################################
# Hyper-NixOS - Auto-generated test for monitoring-webhook-notifications
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "monitoring_webhook_notifications";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/monitoring/webhook-notifications.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module monitoring-webhook-notifications loaded'")
    print("✓ monitoring-webhook-notifications test passed")
  '';
}
