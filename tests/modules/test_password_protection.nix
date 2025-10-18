# Test for the CRITICAL password protection module
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
nixosTest {
  name = "password-protection-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/password-protection.nix ];

    # Enable password protection
    hypervisor.security.passwordProtection.enable = true;

    # Create test users
    users.users.testadmin = {
      isNormalUser = true;
      password = "test123";
      extraGroups = [ "hypervisor-admins" ];
    };

    users.users.testoperator = {
      isNormalUser = true;
      password = "test456";
      extraGroups = [ "hypervisor-operators" ];
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test that password protection service is active
    machine.wait_for_unit("hypervisor-password-protection.service")

    # Verify password files are protected
    machine.succeed("test -d /var/lib/hypervisor/passwords")
    machine.succeed("test $(stat -c '%a' /var/lib/hypervisor/passwords) = '700'")

    # Test that users exist
    machine.succeed("id testadmin")
    machine.succeed("id testoperator")

    # Verify groups exist
    machine.succeed("getent group hypervisor-admins")
    machine.succeed("getent group hypervisor-operators")

    # Test password backup mechanism
    machine.succeed("systemctl status password-backup.service")

    print("Password protection module: PASS")
  '';
}
