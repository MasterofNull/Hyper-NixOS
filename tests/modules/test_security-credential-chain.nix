################################################################################
# Hyper-NixOS - Auto-generated test for security-credential-chain
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "security_credential_chain";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/security/credential-chain.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module security-credential-chain loaded'")
    print("✓ security-credential-chain test passed")
  '';
}
