# Test for feature manager module
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in
nixosTest {
  name = "feature-manager-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/features/feature-manager.nix
      ../../modules/features/feature-categories.nix
      ../../modules/core/options.nix
    ];

    hypervisor.features.management.enable = true;

    # Set system tier
    hypervisor.systemTier = "enhanced";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify feature manager CLI is available
    machine.succeed("command -v hv-features")

    # Test listing available features
    output = machine.succeed("hv-features list")
    assert "vm-management" in output

    # Test feature status reporting
    machine.succeed("hv-features status")

    # Verify feature configuration directory
    machine.succeed("test -d /etc/hypervisor/features")

    print("Feature manager module: PASS")
  '';
}
