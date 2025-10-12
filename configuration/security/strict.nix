{ config, lib, pkgs, ... }:

# Strict Security Model (OPTIONAL)
# Maximum security hardening for high-security environments
#
# This configuration builds on top of the default production security model
# and adds additional restrictions for compliance-critical deployments.
#
# Enable by creating: /var/lib/hypervisor/configuration/security-strict.nix
#
# Additional restrictions:
# - Disable autologin completely (manual login required)
# - Require password for ALL operations (including VM start/stop)
# - Enhanced audit logging with more events
# - Stricter file permissions
# - Additional AppArmor profiles
# - Kernel hardening parameters

{
  # Disable ALL autologin
  services.getty.autologinUser = lib.mkForce null;
  
  # Remove polkit rules - EVERYTHING requires sudo with password
  security.polkit.enable = lib.mkForce false;
  
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
  
  # Enhanced audit rules
  security.auditd.enable = true;
  security.audit.rules = [
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
  
  # Stricter file permissions
  systemd.tmpfiles.rules = [
    "z /var/lib/hypervisor 0750 root root -"
    "z /var/lib/hypervisor/vm_profiles 0750 root root -"
    "z /var/lib/hypervisor/isos 0750 root root -"
    "z /etc/hypervisor 0750 root root -"
  ];
  
  # Additional AppArmor profiles for QEMU
  security.apparmor.enable = lib.mkForce true;
  security.apparmor.packages = [ pkgs.apparmor-profiles ];
  
  # Kernel hardening
  boot.kernel.sysctl = {
    # Prevent information leaks
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    
    # Restrict kernel pointers in /proc
    "kernel.perf_event_paranoid" = 3;
    
    # Disable unprivileged BPF
    "kernel.unprivileged_bpf_disabled" = 1;
    
    # Enable ASLR
    "kernel.randomize_va_space" = 2;
    
    # Restrict ptrace
    "kernel.yama.ptrace_scope" = 2;
    
    # Restrict userfaultfd
    "vm.unprivileged_userfaultfd" = 0;
  };
  
  # Disable USB automount (prevent BadUSB attacks)
  services.udisks2.enable = lib.mkForce false;
  
  # Disable Bluetooth (attack surface reduction)
  hardware.bluetooth.enable = lib.mkForce false;
  
  # Stricter SSH configuration
  services.openssh = {
    settings = {
      # Only key-based auth
      PasswordAuthentication = lib.mkForce false;
      PermitRootLogin = lib.mkForce "no";
      
      # Stricter ciphers
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
      ];
      
      # Stricter MACs
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];
      
      # Stricter key exchange
      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
      
      # Limit connections
      MaxAuthTries = 2;
      MaxSessions = 2;
      LoginGraceTime = 30;
    };
  };
  
  # Firewall: deny all by default, explicit allowlist only
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];  # Empty - add explicitly as needed
    allowedUDPPorts = [ ];  # Empty - add explicitly as needed
    
    # Drop all other traffic
    rejectPackets = true;
    
    # Log dropped packets for forensics
    logRefusedConnections = true;
    logRefusedPackets = true;
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
      - No polkit (sudo required for all operations)
      - Password required for every sudo command
      - Enhanced audit logging
      - Stricter kernel parameters
      - Reduced attack surface (disabled services)
      
      If this is too restrictive, remove:
      /var/lib/hypervisor/configuration/security-strict.nix
      
      And rebuild:
      sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
    ''
  ];
}
