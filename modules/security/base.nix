{ config, lib, pkgs, ... }:

# Base Security Configuration
# Core security settings that apply to all profiles
# Consolidated from security-production.nix

{
  # ═══════════════════════════════════════════════════════════════
  # Security Assertions
  # ═══════════════════════════════════════════════════════════════
  assertions = [
    {
      assertion = !(config.services.xserver.enable or false);
      message = ''
        SECURITY VIOLATION: X11 is PROHIBITED on this locked-down hypervisor.
        X11 has known security vulnerabilities and architecture flaws.
        Use Wayland/Sway for GUI: hypervisor.gui.enableAtBoot = true
      '';
    }
  ];

  # ═══════════════════════════════════════════════════════════════
  # Libvirt Security Configuration
  # ═══════════════════════════════════════════════════════════════
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

  # ═══════════════════════════════════════════════════════════════
  # Audit Logging
  # ═══════════════════════════════════════════════════════════════
  security.auditd.enable = true;
  security.audit.enable = true;
  security.audit.rules = [
    # Log all libvirt operations
    "-a always,exit -F arch=b64 -S execve -F path=/run/current-system/sw/bin/virsh -F key=vm-operation"
    
    # Log VM deletion attempts
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

  # ═══════════════════════════════════════════════════════════════
  # Journald Configuration
  # ═══════════════════════════════════════════════════════════════
  services.journald.extraConfig = ''
    # Retain logs for compliance (90 days)
    MaxRetentionSec=90d
    
    # Limit log size
    SystemMaxUse=1G
    RuntimeMaxUse=100M
    
    # Forward to syslog for centralized logging (if configured)
    ForwardToSyslog=yes
  '';

  # ═══════════════════════════════════════════════════════════════
  # AppArmor
  # ═══════════════════════════════════════════════════════════════
  security.apparmor.enable = true;
  security.apparmor.policies."qemu-system-x86_64".profile = builtins.readFile ../apparmor/qemu-system-x86_64;
  boot.kernelParams = [ "apparmor=1" "security=apparmor" ];

  # ═══════════════════════════════════════════════════════════════
  # Sudo Configuration
  # ═══════════════════════════════════════════════════════════════
  security.sudo.enable = true;

  # ═══════════════════════════════════════════════════════════════
  # Security Packages
  # ═══════════════════════════════════════════════════════════════
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
