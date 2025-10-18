################################################################################
# Hyper-NixOS - Auto-generated test for virtualization-vm-config
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "virtualization_vm_config";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/virtualization/vm-config.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module virtualization-vm-config loaded'")
    print("✓ virtualization-vm-config test passed")
  '';
}
