# Hyper-NixOS Minimal Configuration
# This demonstrates the proper minimal configuration pattern
# Only imports what is actually used in this file

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration (always needed)
    ../hardware-configuration.nix
    
    # Core options module (defines hypervisor.enable and other core options)
    ../modules/core/options.nix
    ../modules/core/hypervisor-base.nix  # Base hypervisor setup when enabled
    
    # Only import modules whose options we're actually setting below
    ../modules/features/feature-categories.nix  # Defines hypervisor.features
    ../modules/features/feature-manager.nix  # We use hypervisor.featureManager
    ../modules/core/first-boot.nix  # First boot comprehensive setup wizard
    ../modules/system-tiers.nix  # System tier definitions
    ../modules/headless-vm-menu.nix  # Headless VM menu for boot-time
    ../modules/security/sudo-protection.nix  # Sudo password reset protection
    ../modules/security/credential-chain.nix  # Credential migration and tamper detection
  ] ++ lib.optionals (builtins.pathExists ./modules/users-migrated.nix) [
    # Import migrated user configuration if it exists (from host system)
    ../modules/users-migrated.nix
  ] ++ lib.optionals (builtins.pathExists ./modules/users-local.nix) [
    # Import local user configuration if it exists (created by installer)
    ../modules/users-local.nix
  ] ++ lib.optionals (builtins.pathExists ./modules/system-local.nix) [
    # Import local system configuration if it exists (created by installer)
    ../modules/system-local.nix
  ];

  # System identification
  networking.hostName = lib.mkDefault "hyper-nixos";  # Can be overridden by installer
  system.stateVersion = "24.05";
  
  # Helpful message on login
  environment.etc."motd".text = lib.mkDefault ''
    ╔═══════════════════════════════════════════════════════════╗
    ║              Welcome to Hyper-NixOS                       ║
    ║         Next-Generation Virtualization Platform           ║
    ╚═══════════════════════════════════════════════════════════╝
    
    This system is ready for configuration.
    
    Run 'first-boot-menu' to start the setup wizard.
    Or run 'system-setup-wizard' to configure your tier directly.
    
    Documentation: /etc/hypervisor/docs/
  '';
  
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
  
  # Base packages for smooth hypervisor experience
  environment.systemPackages = with pkgs; [
    # Essential editors and tools
    vim
    nano
    git
    curl
    wget
    htop
    tmux
    
    # Virtualization management
    virt-manager
    virt-viewer
    libvirt
    qemu_kvm
    
    # System utilities
    pciutils      # lspci for hardware detection
    usbutils      # lsusb
    dmidecode     # Hardware info
    smartmontools # Disk health
    
    # Network tools
    bridge-utils
    iproute2
    iptables
    nftables
    
    # Helpful utilities for setup
    dialog        # TUI dialogs
    ncurses       # Terminal UI library
    bashInteractive
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
    
    # Only define default users if no migration or local config exists
    users = lib.optionalAttrs (
      !(builtins.pathExists ./modules/users-migrated.nix) &&
      !(builtins.pathExists ./modules/users-local.nix)
    ) {
      admin = {
        isNormalUser = true;
        description = "System Administrator";
        extraGroups = [ "wheel" "libvirtd" "kvm" ];
        # Initial login password: "hyper-nixos" (MUST be changed)
        # This is only for initial login - sudo password set separately during first boot
        hashedPassword = "$6$rounds=100000$initialsalt$YLZlz9DVQlUWroSMpOY6JXp1zAZUxqSSjJ.36BkY.4Swl5XKJ7Z.0KYwL4HRdKqUZt4HZjAQPUGvBD8A2CY0g0";
      };
      
      # Create a separate operator user for VM management without sudo
      operator = {
        isNormalUser = true;
        description = "VM Operator (no sudo)";
        extraGroups = [ "libvirtd" "kvm" ];
        # Initial password: "operator" (MUST be changed)
        hashedPassword = "$6$rounds=100000$operatorsalt$g3dS1M9HM8H2WLRmUw1ZSF1LHnZdvUvKZrJq9N5QC.9rY2AdnXPFMTZJXpN0lYbAWS9nQBfXAuKkLkvYBRl.a.";
      };
    };
  };
  
  # Performance
  powerManagement.cpuFreqGovernor = "performance";
}