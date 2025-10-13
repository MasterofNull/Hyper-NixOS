{ config, lib, pkgs, ... }:

# Core System Packages
# Essential packages for hypervisor operation

{
  environment.systemPackages = with pkgs; [
    # Virtualization
    qemu_full
    OVMF
    libvirt
    virt-manager
    pciutils
    swtpm
    
    # System utilities
    jq
    curl
    ripgrep
    git  # Required for flake operations and updates
    
    # Scripting and development
    python3
    python3Packages.jsonschema
    
    # Dialog/TUI tools
    newt
    dialog
    yad
    
    # Text editors
    nano
    
    # Looking Glass client for GPU passthrough
    looking-glass-client
    
    # Security
    gnupg
    openssh
    
    # ISO and disk management
    xorriso
    
    # Network file sharing
    nfs-utils
  ];
}
