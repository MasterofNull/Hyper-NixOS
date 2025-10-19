{ config, lib, pkgs, ... }:

# Boot Configuration
# Bootloader and kernel settings

{
  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  
  # Kernel selection
  # Prefer latest stable kernel; allow override to hardened
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  
  # Note: Security hardening (auditd, sysctl) is configured in security modules
  # Note: Users can override with: boot.kernelPackages = pkgs.linuxPackages_hardened;
  
  # Hardware acceleration (NixOS 25.05 uses hardware.opengl)
  hardware.opengl.enable = lib.mkDefault true;
}
