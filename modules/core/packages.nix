{ config, lib, pkgs, ... }:

# Core System Packages
# Essential packages for hypervisor operation

{
  environment.systemPackages =  [
    # Virtualization
    pkgs.qemu_full
    pkgs.OVMF
    pkgs.libvirt
    pkgs.virt-manager
    pkgs.pciutils
    pkgs.swtpm
    
    # System utilities
    pkgs.jq
    pkgs.curl
    pkgs.ripgrep
    pkgs.git  # Required for flake operations and updates
    
    # Scripting and development
    pkgs.python3
    python3Packages.jsonschema
    
    # Dialog/TUI tools
    pkgs.newt
    pkgs.dialog
    pkgs.yad
    
    # Text editors
    pkgs.nano
    
    # Looking Glass client for GPU passthrough
    pkgs.looking-glass-client
    
    # Security
    pkgs.gnupg
    pkgs.openssh
    
    # ISO and disk management
    pkgs.xorriso
    
    # Network file sharing
    pkgs.nfs-utils
  ];
}
