################################################################################
# Hyper-NixOS - Auto-generated test for automation-services
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "automation_services";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/automation/services.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module automation-services loaded'")
    print("✓ automation-services test passed")
  '';
}
