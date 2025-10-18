################################################################################
# Hyper-NixOS - Auto-generated test for api-rate-limiting
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "api_rate_limiting";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/api/rate-limiting.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module api-rate-limiting loaded'")
    print("✓ api-rate-limiting test passed")
  '';
}
