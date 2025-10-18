# Test for security profiles module
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
nixosTest {
  name = "security-profiles-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/security/profiles.nix
      ../../modules/security/firewall.nix
    ];

    hypervisor.security.profile = "strict";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify firewall is enabled in strict mode
    machine.succeed("systemctl is-active firewalld.service || systemctl is-active iptables.service")

    # Check that security hardening is applied
    machine.succeed("test -f /etc/hypervisor/security-profile")

    output = machine.succeed("cat /etc/hypervisor/security-profile")
    assert "strict" in output

    # Verify audit logging is enabled in strict mode
    machine.succeed("systemctl is-active auditd.service")

    print("Security profiles module: PASS")
  '';
}
