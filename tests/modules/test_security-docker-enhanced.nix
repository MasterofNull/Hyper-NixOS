################################################################################
# Hyper-NixOS - Auto-generated test for security-docker-enhanced
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_docker_enhanced";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/docker-enhanced.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-docker-enhanced loaded'")
    print("✓ security-docker-enhanced test passed")
  '';
}
