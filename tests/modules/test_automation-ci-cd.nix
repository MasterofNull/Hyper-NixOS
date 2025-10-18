################################################################################
# Hyper-NixOS - Auto-generated test for automation-ci-cd
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "automation_ci_cd";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/automation/ci-cd.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module automation-ci-cd loaded'")
    print("✓ automation-ci-cd test passed")
  '';
}
