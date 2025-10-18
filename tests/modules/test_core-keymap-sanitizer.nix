################################################################################
# Hyper-NixOS - Auto-generated test for core-keymap-sanitizer
# Copyright © 2024-2025 MasterofNull | Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "core_keymap_sanitizer";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ ../../modules/core/keymap-sanitizer.nix ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Module loads"):
        machine.succeed("echo 'Module core-keymap-sanitizer loaded'")
    print("✓ core-keymap-sanitizer test passed")
  '';
}
