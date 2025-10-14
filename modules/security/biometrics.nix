{ config, lib, pkgs, ... }:

# Biometric Authentication Configuration
# Provides fingerprint reader support via fprintd and libfprint
# Integrates with PAM for system-wide fingerprint authentication

{
  # ═══════════════════════════════════════════════════════════════
  # Fingerprint Reader Support
  # ═══════════════════════════════════════════════════════════════
  
  # Enable fprintd daemon for fingerprint authentication
  services.fprintd = {
    enable = true;
    
    # Enable Time-of-Check-Time-of-Use (TOC/TOU) protection
    # Prevents attacks where fingerprint data is modified between verification steps
    tod.enable = true;
    
    # Enable driver for devices requiring Time-of-Day protocol
    tod.driver = pkgs.libfprint-2-tod1-vfs0090;
  };

  # ═══════════════════════════════════════════════════════════════
  # PAM Configuration for Fingerprint Authentication
  # ═══════════════════════════════════════════════════════════════
  
  # Enable fingerprint authentication for login
  security.pam.services.login = {
    fprintAuth = true;
    
    # Allow fingerprint as sufficient authentication (no password required if fingerprint succeeds)
    # Set to false if you want fingerprint + password for extra security
    text = lib.mkDefault ''
      # Fingerprint authentication
      auth       sufficient   pam_fprintd.so
      auth       include      common-auth
      
      # Account management
      account    include      common-account
      
      # Password management
      password   include      common-password
      
      # Session management
      session    include      common-session
    '';
  };
  
  # Enable fingerprint authentication for sudo
  security.pam.services.sudo = {
    fprintAuth = true;
  };
  
  # Enable fingerprint authentication for polkit (GUI authentication dialogs)
  security.pam.services.polkit-1 = {
    fprintAuth = true;
  };
  
  # Enable fingerprint authentication for display manager (if GUI is enabled)
  security.pam.services.sddm = lib.mkIf config.programs.sway.enable {
    fprintAuth = true;
  };
  
  # Enable fingerprint authentication for screen unlock
  security.pam.services.swaylock = lib.mkIf config.programs.sway.enable {
    fprintAuth = true;
  };

  # ═══════════════════════════════════════════════════════════════
  # Biometric Packages
  # ═══════════════════════════════════════════════════════════════
  
  environment.systemPackages =  [
    # Fingerprint reader daemon and libraries
    pkgs.fprintd
    pkgs.libfprint
    pkgs.libfprint-2-tod1-vfs0090  # Additional driver for some devices
    
    # Fingerprint enrollment and management tools
    # Use: fprintd-enroll to register fingerprints
    # Use: fprintd-verify to test fingerprint authentication
    # Use: fprintd-list to list enrolled fingerprints
    # Use: fprintd-delete to remove enrolled fingerprints
  ];

  # ═══════════════════════════════════════════════════════════════
  # Udev Rules for Fingerprint Readers
  # ═══════════════════════════════════════════════════════════════
  
  services.udev.extraRules = ''
    # Common fingerprint reader vendors
    # Validity Sensors
    SUBSYSTEM=="usb", ATTRS{idVendor}=="138a", MODE="0664", GROUP="plugdev"
    
    # Synaptics
    SUBSYSTEM=="usb", ATTRS{idVendor}=="06cb", MODE="0664", GROUP="plugdev"
    
    # AuthenTec
    SUBSYSTEM=="usb", ATTRS{idVendor}=="08ff", MODE="0664", GROUP="plugdev"
    
    # Upek/ELAN
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", MODE="0664", GROUP="plugdev"
    
    # Generic fingerprint device permissions
    SUBSYSTEM=="usb", ENV{ID_FINGERPRINT}=="1", MODE="0664", GROUP="plugdev"
  '';

  # ═══════════════════════════════════════════════════════════════
  # User Groups
  # ═══════════════════════════════════════════════════════════════
  
  # Ensure plugdev group exists for fingerprint reader access
  users.groups.plugdev = {};

  # ═══════════════════════════════════════════════════════════════
  # System Configuration
  # ═══════════════════════════════════════════════════════════════
  
  # Enable D-Bus (required by fprintd)
  services.dbus.enable = true;

  # ═══════════════════════════════════════════════════════════════
  # Documentation and Usage Notes
  # ═══════════════════════════════════════════════════════════════
  # 
  # To enroll fingerprints:
  #   1. Run: fprintd-enroll <username>
  #   2. Follow prompts to scan your finger multiple times
  #
  # To verify fingerprint authentication:
  #   Run: fprintd-verify
  #
  # To list enrolled fingerprints:
  #   Run: fprintd-list <username>
  #
  # To delete enrolled fingerprints:
  #   Run: fprintd-delete <username>
  #
  # Supported devices can be checked at:
  #   https://fprint.freedesktop.org/supported-devices.html
  #
  # ═══════════════════════════════════════════════════════════════
}
