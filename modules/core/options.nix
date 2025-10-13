{ config, lib, pkgs, ... }:

# Core Hypervisor Options
# Defines all the hypervisor.* options used throughout the system

{
  options.hypervisor = {
    # Management user configuration
    management = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = "hypervisor";
        description = "Username for the hypervisor management user";
      };
    };

    # Boot-time menu configuration
    menu = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the hypervisor menu at boot time";
      };
    };

    # First boot welcome screen
    firstBootWelcome = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the first boot welcome screen";
      };
    };

    # First boot setup wizard
    firstBootWizard = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the first boot setup wizard";
      };
    };

    # GUI configuration
    gui = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GUI desktop environment at boot";
      };
    };

    # Security configuration
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

      strictFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable default-deny nftables for hypervisor";
      };

      migrationTcp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow libvirt TCP migration ports (16514, 49152-49216)";
      };

      sshStrictMode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable strictest SSH configuration";
      };
    };
  };
}