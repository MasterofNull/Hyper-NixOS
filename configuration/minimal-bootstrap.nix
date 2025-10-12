{ config, lib, pkgs, ... }:

# Minimal Bootstrap Configuration
# Use this for fast initial installation with minimal bandwidth
# Add features later by disabling this module or setting overrides

{
  # Disable GUI by default (saves ~500MB download + build time)
  hypervisor.gui.enableAtBoot = lib.mkForce false;
  
  # Minimal package set - only essentials for VM management
  environment.systemPackages = lib.mkForce (with pkgs; [
    # Core hypervisor requirements
    qemu_full
    libvirt
    OVMF
    
    # Essential utilities
    jq
    python3
    python3Packages.jsonschema
    curl
    
    # User interface (lightweight)
    newt        # whiptail
    dialog
    nano
    
    # Basic tools
    pciutils
    gnupg
    swtpm
    openssh
    
    # Skip these initially (add later if needed):
    # virt-manager      # GUI (heavy)
    # gnome packages    # Desktop environment (heavy)
    # looking-glass     # Advanced graphics
    # monitoring tools  # Can add later
  ]);
  
  # Use standard kernel instead of hardened (faster boot, less download)
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  
  # Disable documentation generation (saves time and space)
  documentation.enable = lib.mkDefault false;
  documentation.man.enable = lib.mkDefault false;
  documentation.info.enable = lib.mkDefault false;
  documentation.doc.enable = lib.mkDefault false;
  documentation.nixos.enable = lib.mkDefault false;
  
  # Disable X server initially (can enable later)
  services.xserver.enable = lib.mkForce false;
  
  # Minimal console only
  console.earlySetup = true;
  
  # Skip some hardening initially (can enable later)
  security.apparmor.enable = lib.mkDefault false;
  
  # Smaller initrd
  boot.initrd.compressor = "xz";
  boot.initrd.compressorArgs = [ "-9" ];
  
  # Skip some audit rules initially
  security.auditd.enable = lib.mkDefault true;  # Keep enabled for security
  
  # Note about re-enabling features
  warnings = [
    ''
      Minimal bootstrap mode is active. This installs only essential packages.
      
      To add features later, create /var/lib/hypervisor/configuration/enable-features.nix:
      {
        hypervisor.gui.enableAtBoot = true;  # Enable GNOME
        boot.kernelPackages = pkgs.linuxPackages_hardened;  # Hardened kernel
        security.apparmor.enable = true;  # AppArmor
        documentation.enable = true;  # Documentation
      }
      
      Then rebuild: sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
    ''
  ];
}
