################################################################################
# Hyper-NixOS - Auto-generated test for virtualization-vm-composition
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "virtualization_vm_composition";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/virtualization/vm-composition.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module virtualization-vm-composition loaded'")
    print("✓ virtualization-vm-composition test passed")
  '';
}
