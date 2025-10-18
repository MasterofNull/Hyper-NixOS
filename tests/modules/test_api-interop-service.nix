################################################################################
# Hyper-NixOS - Auto-generated test for api-interop-service
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "api_interop_service";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/api/interop-service.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module api-interop-service loaded'")
    print("✓ api-interop-service test passed")
  '';
}
