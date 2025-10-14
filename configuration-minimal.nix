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
    ./modules/features/feature-manager.nix  # We use hypervisor.featureManager
    ./modules/core/first-boot.nix  # First boot configuration wizard
    ./modules/system-tiers.nix  # System tier definitions
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
    users.admin = {
      isNormalUser = true;
      description = "System Administrator";
      extraGroups = [ "wheel" "libvirtd" "kvm" ];
      # hashedPassword = "..."; # Set this
    };
  };
  
  # Performance
  powerManagement.cpuFreqGovernor = "performance";
}