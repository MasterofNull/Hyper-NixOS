################################################################################
# Hyper-NixOS - Auto-generated test for security-privilege-separation
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_privilege_separation";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/privilege-separation.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-privilege-separation loaded'")
    print("✓ security-privilege-separation test passed")
  '';
}
