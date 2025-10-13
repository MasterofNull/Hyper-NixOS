{ config, lib, pkgs, ... }:

# Security Operational Profiles
# Mode-specific access control and operational logic
#
# Profile 1: Headless Zero-Trust (production VM operations)
# Profile 2: Management (system administration with sudo)
#
# Select profile via: hypervisor.security.profile option

{
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
    (lib.mkIf (config.hypervisor.security.profile == "headless") {
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

      # Autologin to operator user (only when menu/wizard boots and GUI is disabled)
      services.getty.autologinUser = lib.mkDefault (
        if ((config.hypervisor.menu.enableAtBoot || config.hypervisor.firstBootWizard.enableAtBoot) && !(config.hypervisor.gui.enableAtBoot or false))
        then "hypervisor-operator"
        else null
      );

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

      # Note: Directory permissions are managed by modules/core/directories.nix

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
    (lib.mkIf (config.hypervisor.security.profile == "management") {
      # Management user with sudo privileges
      users.users = lib.optionalAttrs (config.hypervisor.management.userName == "hypervisor") {
        hypervisor = {
          isNormalUser = true;
          extraGroups = [ "wheel" "kvm" "libvirtd" "video" "input" ];
          createHome = false;
        };
      };

      # Conditional autologin for management convenience
      services.getty.autologinUser = lib.mkDefault (
        if ((config.hypervisor.menu.enableAtBoot || config.hypervisor.firstBootWizard.enableAtBoot) && !(config.hypervisor.gui.enableAtBoot or false))
        then config.hypervisor.management.userName
        else null
      );

      # Sudo with NOPASSWD for VM operations
      security.sudo.wheelNeedsPassword = true;
      security.sudo.extraRules = let
        # Helper function to create virsh command rules
        virshBin = "${pkgs.libvirt}/bin/virsh";
        virshCmd = cmd: { command = "${virshBin} ${cmd}"; options = [ "NOPASSWD" ]; };
        
        # VM management commands that management user can run without password
        vmCommands = [
          "list" "start" "shutdown" "reboot" "destroy" "suspend" "resume"
          "dominfo" "domstate" "domuuid" "domifaddr" "console"
          "define" "undefine" 
          "snapshot-create-as" "snapshot-list" "snapshot-revert" "snapshot-delete"
          "net-list" "net-info" "net-dhcp-leases"
        ];
      in [
        {
          users = [ config.hypervisor.management.userName ];
          commands = map virshCmd vmCommands;
        }
        { users = [ config.hypervisor.management.userName ]; commands = [ { command = "ALL"; } ]; }
      ];

      # Note: Directory permissions are managed by modules/core/directories.nix
    })
  ];
}
