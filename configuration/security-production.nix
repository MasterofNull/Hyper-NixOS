{ config, lib, pkgs, ... }:

# Production Security Configuration
# Universal security hardening that applies to ALL operational profiles
# 
# This module contains security settings that protect the system regardless
# of which operational profile is active (headless or management).
#
# Profile-specific access control is handled by security-profiles.nix

{

  # Libvirt configuration for access control
  virtualisation.libvirtd = {
    enable = true;
    
    # Run QEMU as dedicated user, not root
    qemu.runAsRoot = false;
    
    # Access control configuration
    onBoot = "ignore";  # Don't auto-start VMs
    onShutdown = "shutdown";  # Graceful shutdown on host shutdown
    
    # Security driver configuration
    extraConfig = ''
      # Authentication and access control
      unix_sock_group = "libvirtd"
      unix_sock_ro_perms = "0770"
      unix_sock_rw_perms = "0770"
      unix_sock_admin_perms = "0700"
      
      # Security features
      security_driver = "apparmor"
      dynamic_ownership = 1
      clear_emulator_capabilities = 1
      seccomp_sandbox = 1
      
      # Namespaces for isolation
      namespaces = [ "mount", "uts", "ipc", "pid", "net" ]
      
      # Audit logging
      audit_level = 2
      audit_logging = 1
      
      # Log filters for security events
      log_filters="1:libvirt 1:qemu 1:security"
      log_outputs="1:file:/var/log/libvirt/libvirtd.log"
    '';
  };

  # Audit logging configuration
  security.auditd.enable = true;
  security.audit.enable = true;
  security.audit.rules = [
    # Log all libvirt operations
    "-a always,exit -F arch=b64 -S execve -F path=/run/current-system/sw/bin/virsh -F key=vm-operation"
    
    # Log VM deletion attempts (should be rare)
    "-a always,exit -F arch=b64 -S execve -F path=/run/current-system/sw/bin/virsh -F a1=undefine -F key=vm-deletion"
    "-a always,exit -F arch=b64 -S execve -F path=/run/current-system/sw/bin/virsh -F a1=destroy -F key=vm-destroy"
    
    # Log sudo usage
    "-a always,exit -F arch=b64 -S execve -F path=/run/wrappers/bin/sudo -F key=sudo-command"
    
    # Log file access to sensitive areas
    "-w /etc/nixos -p wa -k nixos-config"
    "-w /etc/hypervisor/src -p wa -k hypervisor-config"
    
    # Log authentication events
    "-w /var/log/auth.log -p wa -k auth-log"
    "-w /var/log/lastlog -p wa -k logins"
    
    # Log user/group modifications
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/group -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
  ];

  # SSH configuration - no password auth, keys only
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      ChallengeResponseAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      
      # Only allow admin users via SSH
      AllowUsers = [ "admin" ];  # Add your admin usernames here
      DenyUsers = [ "hypervisor-operator" ];  # Operator only on console
      
      # Strong key exchange
      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group16-sha512"
        "diffie-hellman-group18-sha512"
      ];
      
      # Modern ciphers only
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
        "aes256-ctr"
      ];
      
      # Strong MACs
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "hmac-sha2-512"
      ];
    };
  };

  # Logging configuration
  services.journald.extraConfig = ''
    # Retain logs for compliance (90 days)
    MaxRetentionSec=90d
    
    # Limit log size
    SystemMaxUse=1G
    RuntimeMaxUse=100M
    
    # Forward to syslog for centralized logging (if configured)
    ForwardToSyslog=yes
  '';

  # Enable fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    ignoreIP = [
      "127.0.0.1/8"
      "::1"
      # Add your trusted networks here
    ];
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    
    # Only allow SSH
    allowedTCPPorts = [ 22 ];
    
    # Log dropped packets for monitoring
    logRefusedConnections = true;
    logRefusedPackets = true;
  };

  # System hardening
  boot.kernel.sysctl = {
    # Kernel hardening
    "kernel.unprivileged_userns_clone" = 0;
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 2;  # Strict ptrace
    "kernel.kexec_load_disabled" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    
    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    
    # Filesystem hardening
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;
  };

  # Additional security packages
  environment.systemPackages = with pkgs; [
    # Audit tools
    audit
    
    # Security tools
    gnupg
    
    # Monitoring
    htop
    iotop
    
    # Network tools (for diagnostics)
    tcpdump
    netcat
    
    # Compliance reporting
    lynis
  ];
}
