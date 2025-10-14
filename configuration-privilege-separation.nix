# Hyper-NixOS Configuration with Privilege Separation
# This configuration demonstrates the complete privilege separation model

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration
    ./hardware-configuration.nix
    
    # Core modules
    ./modules/core/options.nix
    ./modules/core/hypervisor-base.nix
    ./modules/core/system.nix
    ./modules/core/packages.nix
    ./modules/core/directories.nix
    ./modules/core/portable-base.nix
    ./modules/core/optimized-system.nix
    
    # Security modules
    ./modules/security/base.nix
    ./modules/security/profiles.nix
    ./modules/security/privilege-separation.nix
    ./modules/security/polkit-rules.nix
    
    # Virtualization
    ./modules/virtualization/libvirt.nix
    ./modules/virtualization/performance.nix
    
    # Note: Networking and service configurations are handled directly in this file
  ];

  # System identification
  networking.hostName = "hyper-nixos";
  
  # Enable hypervisor
  hypervisor.enable = true;
  
  # Enable privilege separation
  hypervisor.security.privileges = {
    enable = true;
    
    # Define user categories
    vmUsers = [ "alice" "bob" "charlie" ];  # Basic VM operations
    vmOperators = [ "alice" ];              # Advanced VM operations
    systemAdmins = [ "admin" ];             # System administration
    
    # Allow passwordless VM operations
    allowPasswordlessVMOperations = true;
  };
  
  # Enable polkit rules
  hypervisor.security.polkit = {
    enable = true;
    enableVMRules = true;
    enableOperatorRules = true;
    
    # Custom rules for specific needs
    customRules = ''
      // Allow VM users to view system logs
      polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.login1.view-logs" &&
              subject.isInGroup("hypervisor-users")) {
              return polkit.Result.YES;
          }
      });
    '';
  };
  
  # Configure users with appropriate groups
  users.users = {
    # Regular VM user
    alice = {
      isNormalUser = true;
      description = "Alice (VM User)";
      extraGroups = [ "libvirtd" "kvm" ];  # Automatically added by privilege module
      hashedPassword = "$6$..."; # Set proper password hash
    };
    
    # VM operator with additional privileges
    bob = {
      isNormalUser = true;
      description = "Bob (VM User)";
      extraGroups = [ "libvirtd" "kvm" ];
      hashedPassword = "$6$..."; # Set proper password hash
    };
    
    # Another VM user
    charlie = {
      isNormalUser = true;
      description = "Charlie (VM User)";
      extraGroups = [ "libvirtd" "kvm" ];
      hashedPassword = "$6$..."; # Set proper password hash
    };
    
    # System administrator
    admin = {
      isNormalUser = true;
      description = "System Administrator";
      extraGroups = [ "wheel" "libvirtd" "kvm" ];  # wheel for sudo
      hashedPassword = "$6$..."; # Set proper password hash
    };
  };
  
  # Security settings
  security = {
    # Sudo configuration (handled by privilege-separation module)
    sudo.wheelNeedsPassword = true;  # Admins need password for sudo
    
    # Enable audit framework
    audit = {
      enable = true;
      rules = [
        # Audit sudo usage
        "-a exit,always -F arch=b64 -S execve -F path=/run/wrappers/bin/sudo -k sudo"
        
        # Audit VM operations
        "-w /var/lib/libvirt/images -p wa -k vm_storage"
        "-w /etc/libvirt -p wa -k vm_config"
      ];
    };
  };
  
  # System services with appropriate permissions
  systemd.services = {
    # VM manager service (runs as non-root)
    "hypervisor-vm-manager" = {
      description = "Hypervisor VM Manager";
      after = [ "libvirtd.service" ];
      wants = [ "libvirtd.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "hypervisor-vm";
        Group = "hypervisor-users";
        ExecStart = "${pkgs.bash}/bin/bash -c 'echo VM Manager Started'";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          "/var/lib/hypervisor/vms"
          "/var/lib/hypervisor/backups"
          "/var/run/libvirt"
        ];
      };
    };
  };
  
  # Environment configuration
  environment = {
    # System packages
    systemPackages = with pkgs; [
      # VM management tools (no sudo required)
      virt-manager
      virt-viewer
      virsh
      
      # System tools (sudo required for system operations)
      nixos-rebuild
      nix-prefetch-git
      
      # Monitoring tools
      htop
      iotop
      
      # Our custom scripts
      (pkgs.writeScriptBin "vm-start" ''
        #!${pkgs.bash}/bin/bash
        exec ${./scripts/vm_start.sh} "$@"
      '')
      (pkgs.writeScriptBin "vm-stop" ''
        #!${pkgs.bash}/bin/bash
        exec ${./scripts/vm_stop.sh} "$@"
      '')
      (pkgs.writeScriptBin "system-config" ''
        #!${pkgs.bash}/bin/bash
        exec ${./scripts/system_config.sh} "$@"
      '')
    ];
    
    # Session variables for privilege awareness
    sessionVariables = {
      HYPERVISOR_PRIVILEGE_MODEL = "enabled";
      HYPERVISOR_VM_NO_SUDO = "true";
    };
    
    # Login message about privileges
    etc."motd".text = ''
      
      ╔═══════════════════════════════════════════════════════════════╗
      ║              Welcome to Hyper-NixOS                           ║
      ╠═══════════════════════════════════════════════════════════════╣
      ║                                                               ║
      ║  Privilege Model:                                             ║
      ║  • VM Operations: NO sudo required (libvirtd group)           ║
      ║  • System Config: SUDO required (explicit acknowledgment)     ║
      ║                                                               ║
      ║  Quick Commands:                                              ║
      ║  • vm-start <name>    - Start a VM (no sudo)                 ║
      ║  • vm-stop <name>     - Stop a VM (no sudo)                  ║
      ║  • menu               - Interactive menu                      ║
      ║  • system-config      - System configuration (sudo required)  ║
      ║                                                               ║
      ╚═══════════════════════════════════════════════════════════════╝
      
    '';
  };
  
  # Firewall configuration
  networking.firewall = {
    enable = true;
    
    # Allow VM-related ports
    allowedTCPPorts = [
      5900  # VNC
      5901  # VNC
      5902  # VNC
    ];
  };
  
  # Enable libvirtd with proper settings
  virtualisation.libvirtd = {
    enable = true;
    
    # Allow regular users in libvirtd group to manage VMs
    qemu = {
      runAsRoot = false;
      ovmf.enable = true;
    };
    
    # Socket permissions
    extraConfig = ''
      unix_sock_group = "libvirtd"
      unix_sock_ro_perms = "0770"
      unix_sock_rw_perms = "0770"
      
      # Allow VM operations without password
      auth_unix_ro = "none"
      auth_unix_rw = "none"
    '';
  };
  
  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # This value determines the NixOS release
  system.stateVersion = "24.05";
}