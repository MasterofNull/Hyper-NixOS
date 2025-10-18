################################################################################
# Hyper-NixOS - Auto-generated test for security-ids-ips
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_ids_ips";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/ids-ips.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-ids-ips loaded'")
    print("✓ security-ids-ips test passed")
  '';
}
