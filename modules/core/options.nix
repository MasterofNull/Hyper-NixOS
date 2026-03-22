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

    # Default VM configuration
    defaults = {
      vcpus = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Default number of vCPUs for new VMs";
      };
      memory = lib.mkOption {
        type = lib.types.int;
        default = 2048;
        description = "Default memory in MB for new VMs";
      };
      diskSize = lib.mkOption {
        type = lib.types.str;
        default = "20G";
        description = "Default disk size for new VMs";
      };
      networkBridge = lib.mkOption {
        type = lib.types.str;
        default = "virbr0";
        description = "Default network bridge for new VMs";
      };
    };

    # Compatibility metadata used by older hardware-detection modules.
    # Keep this narrow so existing writers can evaluate without forcing a
    # larger namespace migration during unrelated fixes.
    system = {
      architecture = lib.mkOption {
        type = lib.types.str;
        default = "unknown";
        description = "Detected or selected system architecture metadata.";
      };

      platform = lib.mkOption {
        type = lib.types.str;
        default = "generic";
        description = "Detected or selected platform metadata.";
      };
    };
  };
}
