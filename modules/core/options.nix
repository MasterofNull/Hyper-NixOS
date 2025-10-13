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

    # Security options
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
      strictFirewall = lib.mkEnableOption "Enable default-deny nftables for hypervisor";
      migrationTcp = lib.mkEnableOption "Allow libvirt TCP migration ports (16514, 49152-49216)";
      sshStrictMode = lib.mkEnableOption "Enable strictest SSH configuration";
    };

    # Monitoring options
    monitoring = {
      enablePrometheus = lib.mkEnableOption "Enable Prometheus monitoring stack";
      enableGrafana = lib.mkEnableOption "Enable Grafana dashboards";
      enableAlertmanager = lib.mkEnableOption "Enable Alertmanager for notifications";
      prometheusPort = lib.mkOption {
        type = lib.types.port;
        default = 9090;
        description = "Port for Prometheus server";
      };
      grafanaPort = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port for Grafana server";
      };
    };

    # Backup options
    backup = {
      enable = lib.mkEnableOption "Enable automated VM backup system";
      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Backup schedule (daily, weekly, or custom systemd calendar format)";
      };
      retention = lib.mkOption {
        type = lib.types.attrsOf lib.types.int;
        default = {
          daily = 7;
          weekly = 4;
          monthly = 3;
        };
        description = "Backup retention policy";
      };
      destination = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/hypervisor/backups";
        description = "Backup destination directory";
      };
      encrypt = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Encrypt backups using GPG";
      };
      compression = lib.mkOption {
        type = lib.types.enum [ "none" "gzip" "bzip2" "xz" "zstd" ];
        default = "zstd";
        description = "Compression algorithm for backups";
      };
    };

    # Performance options
    performance = {
      enableHugepages = lib.mkEnableOption "Enable hugepages (can improve performance, reduces memory flexibility)";
      disableSMT = lib.mkEnableOption "Disable SMT/Hyper-Threading (mitigates side-channels; can reduce throughput)";
    };
  };
}