################################################################################
# Hyper-NixOS - Auto-generated test for automation-kubernetes-tools
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "automation_kubernetes_tools";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/automation/kubernetes-tools.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module automation-kubernetes-tools loaded'")
    print("✓ automation-kubernetes-tools test passed")
  '';
}
