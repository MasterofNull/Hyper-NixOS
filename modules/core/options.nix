{ config, lib, pkgs, ... }:

# Core Hypervisor Options Definition
# Defines the base hypervisor configuration options

{
  options.hypervisor = {
    # Management options
    management = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = "hypervisor";
        description = "Username for the management user account";
      };
    };

    # Menu options
    menu = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the hypervisor menu at boot";
      };
    };

    # First boot welcome options
    firstBootWelcome = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the first boot welcome screen";
      };
    };

    # First boot wizard options
    firstBootWizard = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the first boot setup wizard";
      };
    };

    # GUI options
    gui = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GUI desktop environment at boot";
      };
    };
  };
}