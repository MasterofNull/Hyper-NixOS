{ config, lib, pkgs, ... }:

# Security Operational Profiles
# Mode-specific access control and operational logic
#
# Profile 1: Headless Zero-Trust (production VM operations)
# Profile 2: Management (system administration with sudo)
#
# Select profile via: hypervisor.security.profile option

let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  enableMenuAtBoot = lib.attrByPath ["hypervisor" "menu" "enableAtBoot"] true config;
  enableWizardAtBoot = lib.attrByPath ["hypervisor" "firstBootWizard" "enableAtBoot"] false config;
  enableGuiAtBoot = 
    if lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config 
    then lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config 
    else false;
  
  # Determine active profile
  # Default to "headless" for production zero-trust operations
  # Use "management" for system administration with expanded sudo
  activeProfile = lib.attrByPath ["hypervisor" "security" "profile"] "headless" config;
  
  isHeadless = activeProfile == "headless";
  isManagement = activeProfile == "management";
in {
  options.hypervisor.security.profile = lib.mkOption {
    type = lib.types.enum [ "headless" "management" ];
    default = "headless";
    description = ''
      Security operational profile:
      - headless: Zero-trust VM operations (polkit-based, no sudo)
      - management: System administration (sudo with expanded privileges)
    '';
  };

  config = lib.mkMerge [
    # ═══════════════════════════════════════════════════════════════
    # PROFILE: HEADLESS ZERO-TRUST
    # For production VM operations only
    # ═══════════════════════════════════════════════════════════════
    (lib.mkIf isHeadless {
      # Create dedicated operator user with NO sudo access
      users.users.hypervisor-operator = {
        isSystemUser = true;
        description = "Hypervisor Operator (Zero-Trust)";
        uid = 999;
        group = "hypervisor-operator";
        extraGroups = [ "kvm" "libvirtd" "qemu" ];
        shell = "${pkgs.bash}/bin/bash";
        createHome = true;
        home = "/var/lib/hypervisor-operator";
      };

      users.groups.hypervisor-operator = {};

      # Autologin to operator user
      services.getty.autologinUser = "hypervisor-operator";

      # Disable GUI autologin
      services.displayManager.autoLogin.enable = lib.mkForce false;

      # ALL sudo requires password
      security.sudo.wheelNeedsPassword = true;
      security.sudo.extraRules = [
        {
          groups = [ "wheel" ];
          commands = [ { command = "ALL"; } ];  # Password required
        }
      ];

      # Polkit for granular VM permissions (no sudo needed)
      security.polkit.enable = true;
      security.polkit.extraConfig = ''
        /* Hypervisor Operator - Zero Trust Permissions */
        
        polkit.addRule(function(action, subject) {
          if (subject.user == "hypervisor-operator" &&
              action.id == "org.libvirt.unix.monitor") {
            return polkit.Result.YES;
          }
        });
        
        polkit.addRule(function(action, subject) {
          if (subject.user == "hypervisor-operator" &&
              action.id == "org.libvirt.unix.manage") {
            return polkit.Result.YES;
          }
        });
        
        polkit.addRule(function(action, subject) {
          if (subject.user == "hypervisor-operator") {
            var actionId = action.id;
            if (actionId.indexOf("org.libvirt") == 0 &&
                actionId.indexOf("read") >= 0) {
              return polkit.Result.YES;
            }
            if (actionId.indexOf("org.libvirt") == 0) {
              var cmd = action.lookup("command_line");
              if (cmd && (cmd.indexOf("undefine") >= 0 ||
                          cmd.indexOf("destroy") >= 0 ||
                          cmd.indexOf("delete") >= 0)) {
                polkit.log("ADMIN OPERATION by operator: " + cmd);
              }
            }
          }
        });
        
        polkit.addRule(function(action, subject) {
          if (subject.user == "hypervisor-operator" &&
              action.id == "org.libvirt.unix.monitor" &&
              action.lookup("object_path").indexOf("/network/") >= 0) {
            return polkit.Result.YES;
          }
          return polkit.Result.NOT_HANDLED;
        });
        
        polkit.addRule(function(action, subject) {
          if (action.id.indexOf("org.libvirt") == 0 && subject.isInGroup("wheel")) {
            return polkit.Result.AUTH_ADMIN;
          }
          return polkit.Result.NOT_HANDLED;
        });
      '';

      # Directory ownership: root:libvirtd
      systemd.tmpfiles.rules = [
        "d /var/lib/hypervisor 0755 root libvirtd - -"
        "d /var/lib/hypervisor/isos 0775 root libvirtd - -"
        "d /var/lib/hypervisor/disks 0770 root libvirtd - -"
        "d /var/lib/hypervisor/xml 0775 root libvirtd - -"
        "d /var/lib/hypervisor/vm_profiles 0775 root libvirtd - -"
        "d /var/lib/hypervisor/backups 0770 root libvirtd - -"
        "d /var/log/hypervisor 0770 root libvirtd - -"
        "d /var/lib/hypervisor/logs 0770 root libvirtd - -"
        "d /var/lib/hypervisor-operator 0700 hypervisor-operator hypervisor-operator - -"
        "d /var/lib/hypervisor-operator/.gnupg 0700 hypervisor-operator hypervisor-operator - -"
      ];

      # Enhanced systemd security for menu
      systemd.services.hypervisor-menu.serviceConfig = {
        User = lib.mkForce "hypervisor-operator";
        Group = lib.mkForce "libvirtd";
        SupplementaryGroups = lib.mkForce [ "kvm" ];
        Restart = lib.mkForce "always";
        RestartSec = lib.mkForce "1";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = false;
        SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" "~@mount" ];
        SystemCallErrorNumber = "EPERM";
        ReadOnlyPaths = [ "/etc" "/usr" "/bin" "/nix" ];
        ReadWritePaths = [ "/var/lib/hypervisor" "/var/log/hypervisor" "/run/libvirt" ];
        InaccessiblePaths = [ "/root" "/home" "-/boot" "-/etc/nixos" "-/etc/ssh" ];
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        LimitNOFILE = 4096;
        LimitNPROC = 512;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        LockPersonality = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        MemoryDenyWriteExecute = true;
        SecureBits = [ "noroot" "noroot-locked" "no-setuid-fixup" "no-setuid-fixup-locked" ];
      };
    })

    # ═══════════════════════════════════════════════════════════════
    # PROFILE: MANAGEMENT
    # For system administration with expanded sudo privileges
    # ═══════════════════════════════════════════════════════════════
    (lib.mkIf isManagement {
      # Management user with sudo privileges
      users.users = lib.mkIf (mgmtUser == "hypervisor") {
        hypervisor = {
          isNormalUser = true;
          extraGroups = [ "wheel" "kvm" "libvirtd" "video" "input" ];
          createHome = false;
        };
      };

      # Conditional autologin for management convenience
      services.getty.autologinUser = lib.mkIf 
        ((enableMenuAtBoot || enableWizardAtBoot) && !enableGuiAtBoot)
        mgmtUser;

      # Sudo with NOPASSWD for VM operations
      security.sudo.wheelNeedsPassword = true;
      security.sudo.extraRules = [
        {
          users = [ mgmtUser ];
          commands = [
            { command = "${pkgs.libvirt}/bin/virsh list"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh start"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh shutdown"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh reboot"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh destroy"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh suspend"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh resume"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh dominfo"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh domstate"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh domuuid"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh domifaddr"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh console"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh define"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh undefine"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh snapshot-create-as"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh snapshot-list"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh snapshot-revert"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh snapshot-delete"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh net-list"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh net-info"; options = [ "NOPASSWD" ]; }
            { command = "${pkgs.libvirt}/bin/virsh net-dhcp-leases"; options = [ "NOPASSWD" ]; }
          ];
        }
        { users = [ mgmtUser ]; commands = [ { command = "ALL"; } ]; }
      ];

      # Directory ownership: management user
      systemd.tmpfiles.rules = [
        "d /var/lib/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
        "d /var/lib/hypervisor/isos 0750 ${mgmtUser} ${mgmtUser} - -"
        "d /var/lib/hypervisor/disks 0750 ${mgmtUser} ${mgmtUser} - -"
        "d /var/lib/hypervisor/xml 0750 ${mgmtUser} ${mgmtUser} - -"
        "d /var/lib/hypervisor/vm_profiles 0750 ${mgmtUser} ${mgmtUser} - -"
        "d /var/lib/hypervisor/gnupg 0700 ${mgmtUser} ${mgmtUser} - -"
        "d /var/lib/hypervisor/backups 0750 ${mgmtUser} ${mgmtUser} - -"
        "d /var/log/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
        "d /var/lib/hypervisor/logs 0750 ${mgmtUser} ${mgmtUser} - -"
      ];
    })
  ];
}
