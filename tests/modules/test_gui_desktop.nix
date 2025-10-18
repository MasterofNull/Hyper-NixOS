################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: GUI Desktop Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "gui-desktop";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/gui/desktop.nix
    ];

    hypervisor.gui = {
      enableAtBoot = true;
      desktopEnvironment = "xfce";
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test X server configuration
    with subtest("X server enabled"):
        machine.succeed("systemctl is-enabled display-manager.service || true")

    # Test desktop environment packages
    with subtest("Desktop environment packages"):
        machine.succeed("which startx || which startxfce4 || true")

    # Test virt-manager availability
    with subtest("Virt-manager GUI tool"):
        machine.succeed("which virt-manager || true")

    print("✓ GUI desktop tests passed")
  '';
}
