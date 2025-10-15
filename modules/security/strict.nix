{ config, lib, pkgs, ... }:

# Strict Security Model (OPTIONAL)
# Maximum security hardening for high-security environments
#
# This configuration builds on top of the default production security model
# and adds additional restrictions for compliance-critical deployments.
#
# Enable by creating /var/lib/hypervisor/configuration/security-strict.nix with:
#   { imports = [ /etc/hypervisor/modules/security/strict.nix ]; }
#
# Then rebuild: sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
#
# Additional restrictions:
# - Disable autologin completely (manual login required)
# - Require password for ALL operations (including VM start/stop)
# - Enhanced audit logging with more events
# - Stricter file permissions
# - Additional AppArmor profiles
# - Kernel hardening parameters

{
  config = lib.mkMerge [
    {
      # Disable ALL autologin
      services.getty.autologinUser = lib.mkForce null;
      
      # Remove polkit rules - EVERYTHING requires sudo with password
      # EXCEPTION: Keep polkit enabled if libvirtd is enabled (it's required)
      security.polkit.enable = lib.mkForce config.virtualisation.libvirtd.enable;
      
      # Stricter sudo timeout (must re-authenticate frequently)
      security.sudo.extraConfig = lib.mkAfter ''
        # Require password every time (no caching)
        Defaults timestamp_timeout=0
        
        # Log all sudo commands
        Defaults log_input
        Defaults log_output
        Defaults iolog_dir=/var/log/sudo-io
        
        # Require password even for trivial commands
        Defaults !authenticate = false
      '';
    }
    
    # Enhanced audit rules - only if audit is available
    (lib.mkIf (config.services ? auditd) {
      services.auditd = {
        enable = true;
      };
    })
    
    (lib.mkIf (config.security ? audit) {
      security.audit = {
        rules = [
          # Log all sudo usage
          "-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k admin_commands"
          
          # Log all file access in sensitive directories
          "-w /etc/nixos/ -p wa -k nixos_config"
          "-w /etc/hypervisor/ -p wa -k hypervisor_config"
          "-w /var/lib/hypervisor/ -p wa -k hypervisor_data"
          
          # Log all VM operations
          "-w /var/lib/libvirt/ -p wa -k libvirt_ops"
          "-w /etc/libvirt/ -p wa -k libvirt_config"
          
          # Log user/group changes
          "-w /etc/passwd -p wa -k user_modification"
          "-w /etc/group -p wa -k group_modification"
          "-w /etc/shadow -p wa -k shadow_modification"
          
          # Log network configuration changes
          "-w /etc/systemd/network/ -p wa -k network_config"
          
          # Log service changes
          "-w /etc/systemd/system/ -p wa -k systemd_config"
          
          # Immutable rules (prevent disabling audit)
          "-e 2"
        ];
      };
    })
    
    {
      # Stricter file permissions
      systemd.tmpfiles.rules = [
    "z /var/lib/hypervisor 0750 root root -"
    "z /var/lib/hypervisor/vm_profiles 0750 root root -"
    "z /var/lib/hypervisor/isos 0750 root root -"
    "z /etc/hypervisor 0750 root root -"
  ];
  
  # Additional AppArmor profiles for QEMU - only if available
  security.apparmor = lib.mkIf (config.security ? apparmor) {
    enable = lib.mkForce true;
    packages = [ pkgs.apparmor-profiles ];
  };
  
  # Kernel hardening overrides (stricter than default)
  # Note: Base hardening is in security/kernel-hardening.nix
  boot.kernel.sysctl = {
    # Stricter performance event restriction (default is 2, strict is 3)
    "kernel.perf_event_paranoid" = lib.mkForce 3;
    
    # Stricter userfaultfd restriction (default is 0, force it)
    "vm.unprivileged_userfaultfd" = lib.mkForce 0;
  };
  
  # Disable USB automount (prevent BadUSB attacks)
  services.udisks2.enable = lib.mkForce false;
  
  # Disable Bluetooth (attack surface reduction)
  hardware.bluetooth.enable = lib.mkForce false;
  
  # Enable strict SSH mode (configured in security/ssh.nix)
  hypervisor.security.sshStrictMode = true;
  
  # Override SSH with even stricter settings
  services.openssh.settings = {
    # Stricter connection limits
    MaxAuthTries = lib.mkForce 2;
    MaxSessions = lib.mkForce 2;
    LoginGraceTime = lib.mkForce 30;
  };
  
  # Enable strict firewall mode (configured in security/firewall.nix)
  hypervisor.security.strictFirewall = true;
  
  # Additional firewall restrictions
  networking.firewall = {
    # Reject packets instead of just dropping
    rejectPackets = lib.mkForce true;
  };
  
  # Disable unnecessary services
  services.avahi.enable = lib.mkForce false;  # mDNS
  services.printing.enable = lib.mkForce false;  # CUPS
  
  # Harden systemd services
  systemd.services.hypervisor-menu.serviceConfig = lib.mkForce {
    Type = "simple";
    ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/menu.sh";
    StandardInput = "tty";
    StandardOutput = "inherit";
    StandardError = "journal";
    TTYPath = "/dev/tty1";
    TTYReset = "yes";
    TTYVHangup = "yes";
    
    # Maximum security restrictions
    Restart = "always";
    RestartSec = "2";
    
    # Process restrictions
    User = "hypervisor-operator";
    NoNewPrivileges = true;
    
    # Filesystem restrictions (very strict)
    ProtectSystem = "strict";
    ProtectHome = "tmpfs";
    PrivateTmp = true;
    ReadWritePaths = [
      "/var/lib/hypervisor"
      "/var/lib/libvirt"
    ];
    ReadOnlyPaths = [
      "/etc/hypervisor"
    ];
    
    # Capability restrictions
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    
    # Namespace isolation
    PrivateDevices = false;  # Need access to /dev/kvm
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    RestrictNamespaces = true;
    LockPersonality = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    PrivateMounts = true;
    
    # System call filtering
    SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
    SystemCallArchitectures = "native";
    SystemCallErrorNumber = "EPERM";
      };
      
      # Warning message
      warnings = [
        ''
          STRICT SECURITY MODE ENABLED
          
          This is the maximum security configuration for Hyper-NixOS.
          
          RESTRICTIONS:
          - No autologin (manual login required)
          - No polkit (sudo required for all operations)*
          - Password required for every sudo command
          - Enhanced audit logging
          - Stricter kernel parameters
          - Reduced attack surface (disabled services)
          
          *Polkit is kept enabled when libvirtd is active (required dependency)
          
          If this is too restrictive, remove:
          /var/lib/hypervisor/configuration/security-strict.nix
          
          And rebuild:
          sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
        ''
      ];
    }
  ];
}
