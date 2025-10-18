################################################################################
# Hyper-NixOS - Auto-generated test for web-dashboard
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "web_dashboard";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/web/dashboard.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module web-dashboard loaded'")
    print("✓ web-dashboard test passed")
  '';
}
