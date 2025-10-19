# Hyper-NixOS Minimal Configuration - RECOVERY VERSION
# This configuration ensures you can log in to fix the system

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration (always needed)
    ../hardware-configuration.nix

    # Core options module (defines hypervisor.enable and other core options)
    ../modules/core/options.nix
    ../modules/core/hypervisor-base.nix  # Base hypervisor setup when enabled
    ../modules/core/universal-hardware-detection.nix  # Universal hardware detection (ALL architectures)

    # Hardware platform modules
    ../modules/hardware/platform-detection.nix  # Laptop/Desktop/Server detection

    # System management
    ../modules/system/nixos-update-checker.nix  # Monthly update notifications
    ../modules/system/hibernation-auth.nix  # Intelligent hibernation/resume authentication

    # Only import modules whose options we're actually setting below
    ../modules/features/feature-categories.nix  # Defines hypervisor.features
    ../modules/features/feature-manager.nix  # We use hypervisor.featureManager
    ../modules/core/first-boot.nix  # First boot configuration wizard
    ../modules/system-tiers.nix  # System tier definitions
  ];

  # System identification
  networking.hostName = "hyper-nixos";
  system.stateVersion = "25.05";
  
  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
      timeout = 3;
    };

    # NOTE: All hardware-specific settings are automatically detected
    # by modules/core/universal-hardware-detection.nix
    #
    # NO HARDCODED SETTINGS - intelligent discovery for all platforms!
    # Run 'hv-hardware-info' to see what was detected.
    #
    # Recovery mode: Basic virtualization support auto-configured
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
      # TEMPORARILY allow password auth for recovery
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };
  
  services.chrony.enable = true;
  
  # Users - FIXED for recovery
  users = {
    # Allow changing passwords
    mutableUsers = true;
    
    users.root = {
      # Set a temporary password for recovery
      # Password is "recovery" - CHANGE THIS IMMEDIATELY
      hashedPassword = "$6$rounds=100000$temp.recovery$7M0CpBVZJ4VxBZwGXJKXh4Nk8PFYBCmqHsBXz/qGZpD6h.LMzwKByYxBqP5vqI8wW7J/z0q2qVWkZw4Oq0EZ80";
    };
    
    users.admin = {
      isNormalUser = true;
      description = "System Administrator";
      extraGroups = [ "wheel" "libvirtd" "kvm" ];
      # Password is "admin" - CHANGE THIS IMMEDIATELY
      hashedPassword = "$6$rounds=100000$temp.admin$eSptaOnhJQHXg8YpmXEW5WhfLBq0pGdaK3V.4QJ8o47kKlDh.vg7tYvyPXH2zU7Xl5nShZyWYvM5hH0LgUjH91";
    };
  };
  
  # Create a recovery service that shows on console
  systemd.services.recovery-info = {
    description = "Show recovery login info";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"RECOVERY MODE: Login with user 'admin' password 'admin' or root password 'recovery'\"'";
    };
  };
  
  # Performance
  powerManagement.cpuFreqGovernor = "performance";
}