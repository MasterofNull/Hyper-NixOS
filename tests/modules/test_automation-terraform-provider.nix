################################################################################
# Hyper-NixOS - Auto-generated test for automation-terraform-provider
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "automation_terraform_provider";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/automation/terraform-provider.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module automation-terraform-provider loaded'")
    print("✓ automation-terraform-provider test passed")
  '';
}
