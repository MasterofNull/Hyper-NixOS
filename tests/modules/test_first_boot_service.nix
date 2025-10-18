# Test for first-boot service module
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
nixosTest {
  name = "first-boot-service-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/first-boot.nix ];

    hypervisor.firstBoot.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify first-boot service is defined
    machine.succeed("systemctl cat hypervisor-first-boot.service")

    # Check that first-boot marker logic exists
    machine.succeed("test -f /etc/systemd/system/hypervisor-first-boot.service")

    # Verify first-boot wizard script exists
    machine.succeed("test -x /run/current-system/sw/bin/first-boot-wizard || test -f /etc/hypervisor/scripts/first-boot-wizard.sh")

    print("First-boot service module: PASS")
  '';
}
