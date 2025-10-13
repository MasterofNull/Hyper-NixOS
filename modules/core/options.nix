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
        # Validate username follows Unix conventions
        check = name: builtins.match "^[a-z_][a-z0-9_-]*$" name != null;
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

    # Web dashboard options
    web = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the web dashboard";
      };
    };
  };
}