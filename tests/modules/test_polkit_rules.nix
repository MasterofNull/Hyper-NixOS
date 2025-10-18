################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Polkit Rules Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "polkit-rules";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/security/polkit-rules.nix
      ../../modules/security/privilege-separation.nix
    ];

    hypervisor = {
      enable = true;
      security.privilegeSeparation.enable = true;
      users.operator = "testoperator";
      users.admin = "testadmin";
    };

    users.users = {
      testoperator = {
        isNormalUser = true;
        extraGroups = [ "libvirtd" ];
      };
      testadmin = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test polkit service
    with subtest("Polkit service"):
        machine.succeed("systemctl is-active polkit.service")

    # Test polkit rules files exist
    with subtest("Polkit rules configuration"):
        machine.succeed("test -d /etc/polkit-1/rules.d || test -d /usr/share/polkit-1/rules.d")

    # Test user groups for privilege separation
    with subtest("User privilege groups"):
        operator_groups = machine.succeed("groups testoperator")
        assert "libvirtd" in operator_groups, "Operator not in libvirtd group"

        admin_groups = machine.succeed("groups testadmin")
        assert "wheel" in admin_groups, "Admin not in wheel group"

    print("✓ Polkit rules tests passed")
  '';
}
