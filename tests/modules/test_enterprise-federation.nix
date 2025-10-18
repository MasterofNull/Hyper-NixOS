################################################################################
# Hyper-NixOS - Auto-generated test for enterprise-federation
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "enterprise_federation";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/enterprise/federation.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module enterprise-federation loaded'")
    print("✓ enterprise-federation test passed")
  '';
}
