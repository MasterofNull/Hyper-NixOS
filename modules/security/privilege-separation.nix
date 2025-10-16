# Privilege Separation Module for Hyper-NixOS
# Implements clear separation between user VM operations and system operations

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.security.privileges;
  
  # Helper to create sudo rules
  mkSudoRule = group: commands: {
    groups = [ group ];
    inherit commands;
  };
  
in {
  options.hypervisor.security.privileges = {
    enable = mkEnableOption "privilege separation for VM and system operations";
    
    vmUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Users who can manage VMs without sudo";
      example = [ "alice" "bob" ];
    };
    
    vmOperators = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Users with advanced VM operations (snapshots, storage)";
      example = [ "alice" ];
    };
    
    systemAdmins = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Users who can perform system administration with sudo";
      example = [ "admin" ];
    };
    
    allowPasswordlessVMOperations = mkOption {
      type = types.bool;
      default = true;
      description = "Allow VM operations without password prompts (via polkit)";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Ensure mutableUsers is set to true if not explicitly configured
    users.mutableUsers = lib.mkDefault true;
    
    # User groups for different access levels
    users.groups = {
      # Basic VM management - no sudo needed
      hypervisor-users = {
        gid = 2000;
        members = cfg.vmUsers ++ cfg.vmOperators ++ cfg.systemAdmins;
      };
      
      # Advanced VM operations - no sudo needed
      hypervisor-operators = {
        gid = 2001;
        members = cfg.vmOperators ++ cfg.systemAdmins;
      };
      
      # System administrators - sudo required
      hypervisor-admins = {
        gid = 2002;
        members = cfg.systemAdmins;
      };
    };
    
    # Add users to required system groups
    users.users = mkMerge ([
      # User group assignments
      (mkMerge (
        map (user: {
          ${user} = {
            extraGroups = [ "libvirtd" "kvm" ] ++ 
              optional (elem user cfg.vmOperators) "disk" ++
              optional (elem user cfg.systemAdmins) "wheel";
          };
        }) (cfg.vmUsers ++ cfg.vmOperators ++ cfg.systemAdmins)
      ))
      
      # System service user
      # This is a locked system user (no password needed)
      {
        hypervisor-vm = {
          isSystemUser = true;
          group = "hypervisor-users";
          description = "Hypervisor VM management service user";
          extraGroups = [ "libvirtd" "kvm" ];
          # System users don't need passwords - they're locked by default
        };
      }
    ]);
    
    # Sudo rules - minimal and specific
    security.sudo.extraRules = [
      # VM operators - limited sudo for storage operations only
      (mkSudoRule "hypervisor-operators" [
        {
          command = "${pkgs.coreutils}/bin/mkdir -p /var/lib/libvirt/images/*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.coreutils}/bin/chown :libvirtd /var/lib/libvirt/images/*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.e2fsprogs}/bin/resize2fs /var/lib/libvirt/images/*";
          options = [ "NOPASSWD" ];
        }
      ])
      
      # System admins - specific system operations with password
      (mkSudoRule "hypervisor-admins" [
        {
          command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild *";
          options = [ "PASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl * hypervisor-*";
          options = [ "PASSWD" ];
        }
        {
          command = "${config.system.build.toplevel}/sw/bin/hypervisor-*";
          options = [ "PASSWD" ];
        }
        {
          command = "ALL";
          options = [ "PASSWD" ];
        }
      ])
    ];
    
    # Polkit rules for passwordless VM operations
    security.polkit.extraConfig = mkIf cfg.allowPasswordlessVMOperations ''
      // Allow hypervisor-users to manage VMs without password
      polkit.addRule(function(action, subject) {
          if ((action.id == "org.libvirt.unix.manage" ||
               action.id == "org.libvirt.unix.monitor") &&
              subject.isInGroup("hypervisor-users")) {
              return polkit.Result.YES;
          }
      });
      
      // Allow VM console access without password
      polkit.addRule(function(action, subject) {
          if (action.id == "org.libvirt.unix.read" &&
              subject.isInGroup("hypervisor-users")) {
              return polkit.Result.YES;
          }
      });
      
      // System operations still require authentication
      polkit.addRule(function(action, subject) {
          if (action.id.indexOf("org.freedesktop.systemd1.manage") == 0 &&
              !subject.isInGroup("hypervisor-admins")) {
              return polkit.Result.AUTH_ADMIN;
          }
      });
    '';
    
    # File permissions for different access levels
    systemd.tmpfiles.rules = [
      # VM management areas - accessible to all VM users
      "d /var/lib/hypervisor/vms 2775 root hypervisor-users - -"
      "d /var/lib/hypervisor/backups 2775 root hypervisor-users - -"
      "d /var/lib/hypervisor/snapshots 2775 root hypervisor-users - -"
      "d /var/lib/hypervisor/logs 2775 root hypervisor-users - -"
      
      # Operator areas - restricted to operators
      "d /var/lib/hypervisor/images 2775 root hypervisor-operators - -"
      "d /var/lib/hypervisor/templates 2775 root hypervisor-operators - -"
      
      # System areas - restricted to admins
      "d /etc/hypervisor 0750 root hypervisor-admins - -"
      "d /var/lib/hypervisor/system 0750 root hypervisor-admins - -"
      "d /var/lib/hypervisor/secure 0700 root root - -"
    ];
    
    # Environment variables for scripts
    environment.sessionVariables = {
      HYPERVISOR_REQUIRE_SUDO_FOR_SYSTEM = "true";
      HYPERVISOR_VM_OPS_NO_SUDO = "true";
    };
    
    # Add informational message to login
    environment.etc."motd.d/50-hypervisor-privileges".text = ''
      
      Hyper-NixOS Privilege Model:
      ───────────────────────────────────────────────────────────
      • VM Operations: NO sudo required (libvirtd group members)
      • System Config: SUDO required (explicit acknowledgment)
      
      Your groups: ${toString config.users.users.${config.users.defaultUser or "user"}.extraGroups or []}
      
    '';
    
    # Script wrapper to enforce privilege requirements
    environment.systemPackages = [
      (pkgs.writeScriptBin "hypervisor-check-privileges" ''
        #!${pkgs.bash}/bin/bash
        
        operation="''${1:-}"
        
        case "$operation" in
          vm:*)
            # VM operations - check group membership
            if ! groups | grep -q '\blibvirtd\b'; then
              echo "ERROR: You need to be in the 'libvirtd' group for VM operations"
              echo "Run: sudo usermod -aG libvirtd $USER"
              echo "Then logout and login again"
              exit 1
            fi
            ;;
          system:*)
            # System operations - require sudo
            if [[ $EUID -ne 0 ]]; then
              echo "ERROR: This operation requires sudo"
              echo "Please run with: sudo $0 $*"
              exit 1
            fi
            ;;
        esac
      '')
    ];
    
    # Systemd service security for VM operations
    systemd.services = {
      "hypervisor-vm-manager" = {
        serviceConfig = {
          # Runs as regular user, not root
          User = "hypervisor-vm";
          Group = "hypervisor-users";
          
          # Security restrictions
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [
            "/var/lib/hypervisor/vms"
            "/var/lib/hypervisor/backups"
            "/var/run/libvirt"
          ];
          
          # Capabilities needed for VM management
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
        };
      };
    };
    
  };
}