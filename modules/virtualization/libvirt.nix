{ config, lib, pkgs, ... }:

# Libvirt and Virtualization Configuration
# Core virtualization settings for KVM/QEMU

{
  # Enable libvirt virtualization
  virtualisation.libvirtd.enable = true;

  # Enable Polkit (required by libvirtd)
  security.polkit.enable = true;

  # Ensure required groups exist
  users.groups.libvirtd = {};
  users.groups.kvm = {};
  
  # Environment configuration for libvirt
  environment.etc."libvirt/hooks/qemu".source = ../../scripts/libvirt_hooks/qemu;
}
