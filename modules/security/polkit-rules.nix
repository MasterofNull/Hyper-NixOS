# Polkit Rules for VM Operations
# Allows VM operations without password prompts for authorized users

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.security.polkit;
  
  # Polkit rules for VM operations
  vmOperationsRules = pkgs.writeTextFile {
    name = "50-hypervisor-vm-operations.rules";
    text = ''
      /* Hyper-NixOS VM Operations - No Password Required */
      
      // Allow VM management for users in libvirtd group
      polkit.addRule(function(action, subject) {
          if ((action.id == "org.libvirt.unix.manage" ||
               action.id == "org.libvirt.unix.monitor" ||
               action.id == "org.libvirt.unix.read") &&
              subject.isInGroup("libvirtd")) {
              return polkit.Result.YES;
          }
      });
      
      // Allow VM console access
      polkit.addRule(function(action, subject) {
          if (action.id == "org.libvirt.api.domain.open-console" &&
              subject.isInGroup("libvirtd")) {
              return polkit.Result.YES;
          }
      });
      
      // Allow VM snapshot operations
      polkit.addRule(function(action, subject) {
          if ((action.id == "org.libvirt.api.domain.snapshot-create" ||
               action.id == "org.libvirt.api.domain.snapshot-delete" ||
               action.id == "org.libvirt.api.domain.snapshot-revert") &&
              subject.isInGroup("libvirtd")) {
              return polkit.Result.YES;
          }
      });
      
      // Allow storage pool read access
      polkit.addRule(function(action, subject) {
          if (action.id == "org.libvirt.api.storage-pool.read" &&
              subject.isInGroup("libvirtd")) {
              return polkit.Result.YES;
          }
      });
      
      // System operations still require authentication
      polkit.addRule(function(action, subject) {
          if ((action.id.indexOf("org.freedesktop.systemd1.manage") == 0 ||
               action.id.indexOf("org.freedesktop.NetworkManager") == 0 ||
               action.id.indexOf("org.freedesktop.timedate1") == 0) &&
              !subject.isInGroup("wheel")) {
              return polkit.Result.AUTH_ADMIN;
          }
      });
      
      // Hypervisor-specific system operations require auth
      polkit.addRule(function(action, subject) {
          if (action.id.indexOf("org.hypervisor.system") == 0) {
              if (subject.isInGroup("hypervisor-admins") || subject.isInGroup("wheel")) {
                  return polkit.Result.AUTH_ADMIN_KEEP;
              } else {
                  return polkit.Result.NO;
              }
          }
      });
    '';
    destination = "/etc/polkit-1/rules.d/50-hypervisor-vm-operations.rules";
  };
  
  # Additional rules for operators
  operatorRules = pkgs.writeTextFile {
    name = "51-hypervisor-operators.rules";
    text = ''
      /* Hyper-NixOS Operator Privileges */
      
      // Allow storage operations for operators
      polkit.addRule(function(action, subject) {
          if ((action.id == "org.libvirt.api.storage-pool.create" ||
               action.id == "org.libvirt.api.storage-vol.create" ||
               action.id == "org.libvirt.api.storage-vol.delete") &&
              subject.isInGroup("hypervisor-operators")) {
              return polkit.Result.YES;
          }
      });
      
      // Allow network operations for operators
      polkit.addRule(function(action, subject) {
          if ((action.id == "org.libvirt.api.network.create" ||
               action.id == "org.libvirt.api.network.update") &&
              subject.isInGroup("hypervisor-operators")) {
              return polkit.Result.AUTH_ADMIN_KEEP;
          }
      });
    '';
    destination = "/etc/polkit-1/rules.d/51-hypervisor-operators.rules";
  };

in {
  options.hypervisor.security.polkit = {
    enable = mkEnableOption "polkit rules for passwordless VM operations";
    
    enableVMRules = mkOption {
      type = types.bool;
      default = true;
      description = "Enable passwordless VM operations for libvirtd group";
    };
    
    enableOperatorRules = mkOption {
      type = types.bool;
      default = true;
      description = "Enable additional privileges for hypervisor-operators group";
    };
    
    customRules = mkOption {
      type = types.lines;
      default = "";
      description = "Additional custom polkit rules";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install polkit rules
    environment.etc = lib.mkMerge [
      (mkIf cfg.enableVMRules {
        "polkit-1/rules.d/50-hypervisor-vm-operations.rules".source = 
          "${vmOperationsRules}/etc/polkit-1/rules.d/50-hypervisor-vm-operations.rules";
      })
      
      (mkIf cfg.enableOperatorRules {
        "polkit-1/rules.d/51-hypervisor-operators.rules".source = 
          "${operatorRules}/etc/polkit-1/rules.d/51-hypervisor-operators.rules";
      })
      
      (mkIf (cfg.customRules != "") {
        "polkit-1/rules.d/99-hypervisor-custom.rules".text = cfg.customRules;
      })
    ];
    
    # Ensure polkit service is enabled
    security.polkit.enable = true;
    
    # Add polkit debug logging if verbose
    security.polkit.extraConfig = mkIf config.hypervisor.debug.verbose ''
      polkit.addRule(function(action, subject) {
          polkit.log("action=" + action.id + " subject=" + subject.user + " groups=" + subject.groups);
      });
    '';
  };
}