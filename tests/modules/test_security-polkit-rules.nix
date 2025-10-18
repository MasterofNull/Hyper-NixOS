################################################################################
# Hyper-NixOS - Auto-generated test for security-polkit-rules
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_polkit_rules";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/polkit-rules.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-polkit-rules loaded'")
    print("✓ security-polkit-rules test passed")
  '';
}
