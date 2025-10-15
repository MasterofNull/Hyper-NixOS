# Hyper-NixOS Minimal Configuration
# This demonstrates the proper minimal configuration pattern
# Only imports what is actually used in this file

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration (always needed)
    ./hardware-configuration.nix
    
    # Core options module (defines hypervisor.enable and other core options)
    ./modules/core/options.nix
    ./modules/core/hypervisor-base.nix  # Base hypervisor setup when enabled
    
    # Only import modules whose options we're actually setting below
    ./modules/features/feature-categories.nix  # Defines hypervisor.features
    ./modules/features/feature-manager.nix  # We use hypervisor.featureManager
    ./modules/core/first-boot.nix  # First boot configuration wizard
    ./modules/system-tiers.nix  # System tier definitions
  ] ++ lib.optionals (builtins.pathExists ./modules/users-local.nix) [
    # Import local user configuration if it exists (created by installer)
    ./modules/users-local.nix
  ] ++ lib.optionals (builtins.pathExists ./modules/system-local.nix) [
    # Import local system configuration if it exists (created by installer)
    ./modules/system-local.nix
  ];

  # System identification
  networking.hostName = "hyper-nixos";
  system.stateVersion = "24.05";
  
  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    
    # Kernel parameters for virtualization
    kernelParams = [ 
      "intel_iommu=on"
      "iommu=pt"
      "kvm_intel.nested=1"
      "transparent_hugepage=madvise"
    ];
    
    kernelModules = [ 
      "kvm-intel"
      "vfio"
      "vfio_iommu_type1"
      "vfio_pci"
    ];
    
    initrd.kernelModules = [ "vfio_pci" ];
  };
  
  # Feature selection - this determines what modules get loaded
  hypervisor = {
    enable = true;
    
    featureManager = {
      enable = true;
      profile = "balanced";
      riskTolerance = "balanced";
      generateReport = true;
    };
    
    # Enable first boot wizard
    firstBoot = {
      enable = true;
      autoStart = true;
    };
  };
  
  # Basic networking
  networking = {
    firewall = {
      enable = true;
      trustedInterfaces = [ "virbr0" ];
    };
    
    bridges."virbr0".interfaces = [ ];
    
    nat = {
      enable = true;
      internalInterfaces = [ "virbr0" ];
      externalInterface = null;
    };
  };
  
  # Essential packages only
  environment.systemPackages = with pkgs; [
    vim
    git
    virt-manager
    virt-viewer
  ];
  
  # Basic services
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  
  services.chrony.enable = true;
  
  # Users
  users = {
    mutableUsers = false;
    
    # Only define default admin user if installer hasn't created users-local.nix
    users = lib.optionalAttrs (!(builtins.pathExists ./modules/users-local.nix)) {
      admin = {
        isNormalUser = true;
        description = "System Administrator";
        extraGroups = [ "wheel" "libvirtd" "kvm" ];
        # IMPORTANT: Set one of these to avoid being locked out:
        
        # Option 1: Set initial password (recommended for first boot)
        # Generate with: mkpasswd -m sha-512
        # Default password "changeme" - MUST be changed on first login
        hashedPassword = "$6$rounds=10000$changeme$3VfUkYX5tHSZrgqmQH5z5gkLTKCw1N0e4A7cFaHnqKwYOt8lJ5xfDJPKoGupW.8nKmZM5vnkGYz0R9XoYqJlM0";
        
        # Option 2: SSH public key (for remote access)
        # openssh.authorizedKeys.keys = [
        #   "ssh-rsa AAAAB3... your-key"
        # ];
      };
    };
  };
  
  # Performance
  powerManagement.cpuFreqGovernor = "performance";
}