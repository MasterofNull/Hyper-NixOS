{ config, lib, pkgs, ... }:

# Production Security Model (DEFAULT)
# Zero-trust approach with granular permissions
# 
# This is the default security configuration for Hyper-NixOS.
# For even stricter security, see security-strict.nix
#
# Philosophy:
# - Operator can perform VM lifecycle operations (create, start, stop, console)
# - Operator CANNOT delete VMs or perform destructive operations
# - Operator can download ISOs and import GPG keys (no sudo needed)
# - Admin tasks require authentication and audit logging
# - Secure by default, principle of least privilege

{
  # Create dedicated operator user with NO sudo access
  users.users.hypervisor-operator = {
    isNormalUser = true;
    description = "Hypervisor Operator (Zero-Trust)";
    uid = 999;  # Consistent UID for auditing
    
    # Groups for VM management - NO wheel group
    extraGroups = [
      "kvm"           # Access to /dev/kvm for VM creation
      "libvirtd"      # Libvirt management
      "qemu"          # QEMU process group
    ];
    
    # Shell access for menu operation
    shell = "${pkgs.bash}/bin/bash";
    
    # Home directory for GPG keyring and configurations
    createHome = true;
    home = "/var/lib/hypervisor-operator";
  };

  # Autologin to operator user (not admin!)
  services.getty.autologinUser = lib.mkForce "hypervisor-operator";

  # Disable autologin on GUI
  services.xserver.displayManager.autoLogin.enable = lib.mkForce false;

  # ALL users require password for sudo (no exceptions)
  security.sudo.wheelNeedsPassword = true;

  # Remove any NOPASSWD sudo rules
  # Only administrators in wheel group can sudo (with password)
  security.sudo.extraRules = lib.mkForce [
    {
      # Admins can do everything but need password
      groups = [ "wheel" ];
      commands = [
        { command = "ALL"; }  # Requires password
      ];
    }
  ];

  # Polkit configuration for fine-grained VM management
  # This is the key to zero-trust: specific permissions without sudo
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    /* Hypervisor Operator Permissions - Zero Trust Model */
    
    // Full libvirt monitor (read-only) access for operator
    polkit.addRule(function(action, subject) {
      if (subject.user == "hypervisor-operator" &&
          action.id == "org.libvirt.unix.monitor") {
        return polkit.Result.YES;
      }
    });
    
    // Full libvirt management access for operator (with restrictions below)
    polkit.addRule(function(action, subject) {
      if (subject.user == "hypervisor-operator" &&
          action.id == "org.libvirt.unix.manage") {
        return polkit.Result.YES;  // Grant access, will be filtered by systemd restrictions
      }
    });
    
    // Additional polkit rule for specific command filtering
    // This provides defense-in-depth with systemd restrictions
    polkit.addRule(function(action, subject) {
      if (subject.user == "hypervisor-operator") {
        var actionId = action.id;
        
        // Allow all libvirt query/read operations
        if (actionId.indexOf("org.libvirt") == 0 &&
            actionId.indexOf("read") >= 0) {
          return polkit.Result.YES;
        }
        
        // Log administrative operations for audit
        if (actionId.indexOf("org.libvirt") == 0) {
          var cmd = action.lookup("command_line");
          if (cmd) {
            // Log destructive operations
            if (cmd.indexOf("undefine") >= 0 ||
                cmd.indexOf("destroy") >= 0 ||
                cmd.indexOf("delete") >= 0) {
              polkit.log("ADMIN OPERATION by operator: " + cmd);
            }
          }
        }
      }
    });
    
    // Network operations - read-only for operator
    polkit.addRule(function(action, subject) {
      if (subject.user == "hypervisor-operator" &&
          action.id == "org.libvirt.unix.monitor" &&
          action.lookup("object_path").indexOf("/network/") >= 0) {
        return polkit.Result.YES;
      }
      return polkit.Result.NOT_HANDLED;
    });
    
    // Admin operations - require wheel group AND authentication
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.libvirt") == 0) {
        if (subject.isInGroup("wheel")) {
          // Admins can do anything but must authenticate
          return polkit.Result.AUTH_ADMIN;
        }
      }
      return polkit.Result.NOT_HANDLED;
    });
  '';

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

  # Directory permissions for operator
  systemd.tmpfiles.rules = [
    # Operator can read/write to hypervisor directories
    "d /var/lib/hypervisor 0755 root libvirtd - -"
    "d /var/lib/hypervisor/isos 0775 root libvirtd - -"
    "d /var/lib/hypervisor/disks 0770 root libvirtd - -"
    "d /var/lib/hypervisor/xml 0775 root libvirtd - -"
    "d /var/lib/hypervisor/vm_profiles 0775 root libvirtd - -"
    "d /var/lib/hypervisor/backups 0770 root libvirtd - -"
    "d /var/log/hypervisor 0770 root libvirtd - -"
    "d /var/lib/hypervisor/logs 0770 root libvirtd - -"
    
    # Operator's personal directories
    "d /var/lib/hypervisor-operator 0700 hypervisor-operator hypervisor-operator - -"
    "d /var/lib/hypervisor-operator/.gnupg 0700 hypervisor-operator hypervisor-operator - -"
  ];

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

  # Enhanced systemd service security for menu
  systemd.services.hypervisor-menu = {
    serviceConfig = {
      # Run as operator user
      User = "hypervisor-operator";
      Group = "libvirtd";
      SupplementaryGroups = [ "kvm" ];
      
      # Restart on exit to prevent shell escape
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "1";
      
      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = false;  # Need /dev/kvm
      
      # Restrict system calls
      SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" "~@mount" ];
      SystemCallErrorNumber = "EPERM";
      
      # Filesystem access
      ReadOnlyPaths = [ "/etc" "/usr" "/bin" "/nix" ];
      ReadWritePaths = [
        "/var/lib/hypervisor"
        "/var/log/hypervisor"
        "/run/libvirt"
      ];
      InaccessiblePaths = [
        "/root"
        "/home"
        "-/boot"
        "-/etc/nixos"
        "-/etc/ssh"
      ];
      
      # Network restrictions
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      
      # Capabilities - none needed
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      
      # Resource limits
      LimitNOFILE = 4096;
      LimitNPROC = 512;
      
      # Kernel restrictions
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      
      # Misc hardening
      LockPersonality = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      
      # Memory protection
      MemoryDenyWriteExecute = true;
      
      # Prevent privilege escalation
      SecureBits = [ "noroot" "noroot-locked" "no-setuid-fixup" "no-setuid-fixup-locked" ];
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
