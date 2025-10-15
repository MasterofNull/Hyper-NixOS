{ config, lib, pkgs, ... }:

# Hyper-NixOS Libvirt and Virtualization Configuration
# Core virtualization settings for KVM/QEMU
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# This module configures:
# - Libvirt (LGPL-2.1+, Red Hat, Inc. and contributors)
# - QEMU (GPL-2.0, Fabrice Bellard and contributors)
# - KVM (GPL-2.0, Linux kernel contributors)
# - PolicyKit for privilege management (LGPL-2.1+)
#
# These components are used as provided by nixpkgs without modifications.
# See THIRD_PARTY_LICENSES.md for complete license information.
#
# Attribution:
# - Libvirt: https://libvirt.org/
# - QEMU: https://www.qemu.org/
# - KVM: https://www.linux-kvm.org/

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
