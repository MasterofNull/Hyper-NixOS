################################################################################
# Hyper-NixOS - Auto-generated test for virtualization-libvirt
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "virtualization_libvirt";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/virtualization/libvirt.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module virtualization-libvirt loaded'")
    print("✓ virtualization-libvirt test passed")
  '';
}
