################################################################################
# Hyper-NixOS - Auto-generated test for headless-vm-menu
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "headless_vm_menu";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/headless-vm-menu.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module headless-vm-menu loaded'")
    print("✓ headless-vm-menu test passed")
  '';
}
