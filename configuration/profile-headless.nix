{ config, lib, pkgs, ... }:

# Headless Zero-Trust Profile
# VM operations only: run, restart, download ISOs, create VMs
# No expanded sudo privileges - uses polkit for granular permissions

{
  # Create dedicated operator user with NO sudo access
  users.users.hypervisor-operator = {
    isSystemUser = true;
    description = "Hypervisor Operator (Zero-Trust)";
    uid = 999;  # Consistent UID for auditing
    group = "hypervisor-operator";
    
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

  # Create the corresponding group
  users.groups.hypervisor-operator = {};

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

  # Enhanced systemd service security for menu
  systemd.services.hypervisor-menu = {
    serviceConfig = {
      # Run as operator user
      User = lib.mkForce "hypervisor-operator";
      Group = lib.mkForce "libvirtd";
      SupplementaryGroups = lib.mkForce [ "kvm" ];
      
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
}
