# Test configuration to verify no infinite recursion
{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/core/options.nix
    ./modules/security/profiles.nix
    ./modules/core/directories.nix
    ./modules/gui/desktop.nix
  ];
  
  # Minimal system configuration
  system.stateVersion = "24.05";
}