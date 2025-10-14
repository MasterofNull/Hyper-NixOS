{ config, lib, pkgs, ... }:

# Core Hypervisor Options Definition
# Only defines core system options that are used across multiple modules

{
  options.hypervisor = {
    # Top-level enable option
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Hyper-NixOS virtualization platform";
    };

    # Management Configuration
    management = {
      userName = lib.mkOption {
        type = lib.types.strMatching "^[a-z_][a-z0-9_-]*$";
        default = "hypervisor";
        description = "Username for the management user account (must follow Unix naming conventions)";
      };
    };

    # Boot Services Configuration
    menu = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the hypervisor menu at boot";
      };
    };

    firstBootWelcome = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the first boot welcome screen";
      };
    };

    firstBootWizard = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the first boot setup wizard";
      };
    };

    # GUI Configuration
    gui = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GUI desktop environment at boot";
      };
    };
  };
}