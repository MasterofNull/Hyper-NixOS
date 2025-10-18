# Template for testing NixOS modules
# Usage: Copy this template and customize for specific module testing
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
nixosTest {
  name = "module-name-test";

  nodes.machine = { config, pkgs, ... }: {
    # Import the module you want to test
    imports = [ ../../modules/path/to/module.nix ];

    # Enable the module features
    hypervisor.module.enable = true;

    # Additional configuration needed for testing
    # hypervisor.module.someOption = "value";
  };

  testScript = ''
    # Wait for system to boot
    machine.wait_for_unit("multi-user.target")

    # Test that services are running
    # machine.wait_for_unit("service-name.service")

    # Test configuration files exist
    # machine.succeed("test -f /etc/config-file")

    # Test commands work
    # machine.succeed("command-to-test")

    # Test output matches expectations
    # output = machine.succeed("command")
    # assert "expected-string" in output

    # Test failure conditions
    # machine.fail("command-that-should-fail")
  '';
}
