{ config, lib, pkgs, ... }:

# Hypervisor Configuration Options
# Defines all hypervisor-related configuration options to avoid circular dependencies

{
  options.hypervisor = {
    management = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = "hypervisor";
        description = "Management user name for hypervisor operations";
      };
    };

    menu = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable hypervisor menu at boot";
      };
    };

    firstBootWelcome = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable first boot welcome screen";
      };
    };

    firstBootWizard = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable first boot setup wizard";
      };
    };

    gui = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GUI desktop environment at boot";
      };
    };

    security = {
      profile = lib.mkOption {
        type = lib.types.enum [ "headless" "management" ];
        default = "headless";
        description = ''
          Security operational profile:
          - headless: Zero-trust VM operations (polkit-based, no sudo)
          - management: System administration (sudo with expanded privileges)
        '';
      };
    };
  };
}