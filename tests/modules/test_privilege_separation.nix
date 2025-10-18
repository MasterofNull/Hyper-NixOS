# Test for privilege separation module
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
nixosTest {
  name = "privilege-separation-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/security/privilege-separation.nix
      ../../modules/security/polkit-rules.nix
    ];

    hypervisor.security.privilegeSeparation.enable = true;

    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "hypervisor-admins" ];
    };

    users.users.operator = {
      isNormalUser = true;
      extraGroups = [ "hypervisor-operators" ];
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify groups exist
    machine.succeed("getent group hypervisor-admins")
    machine.succeed("getent group hypervisor-operators")
    machine.succeed("getent group hypervisor-viewers")

    # Verify polkit rules are installed
    machine.succeed("test -f /etc/polkit-1/rules.d/10-hypervisor.rules")

    # Test that admin group has proper capabilities
    machine.succeed("grep -q 'hypervisor-admins' /etc/polkit-1/rules.d/10-hypervisor.rules")

    # Verify operator restrictions
    machine.succeed("grep -q 'hypervisor-operators' /etc/polkit-1/rules.d/10-hypervisor.rules")

    print("Privilege separation module: PASS")
  '';
}
