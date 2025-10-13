{ config, lib, pkgs, ... }:

# Core Hypervisor Options Definition
# ═══════════════════════════════════════════════════════════════
# CENTRALIZED OPTIONS ARCHITECTURE
# All hypervisor.* options are defined here for consistency
# Individual modules should NOT define their own options
# ═══════════════════════════════════════════════════════════════

{
  options.hypervisor = {
    # ═══════════════════════════════════════════════════════════════
    # Management Configuration
    # ═══════════════════════════════════════════════════════════════
    management = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = "hypervisor";
        description = "Username for the management user account";
        # Validate username follows Unix conventions
        check = name: builtins.match "^[a-z_][a-z0-9_-]*$" name != null;
      };
    };

    # ═══════════════════════════════════════════════════════════════
    # Boot Services Configuration
    # ═══════════════════════════════════════════════════════════════
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

    # ═══════════════════════════════════════════════════════════════
    # GUI Configuration
    # ═══════════════════════════════════════════════════════════════
    gui = {
      enableAtBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GUI desktop environment at boot";
      };
    };

    # ═══════════════════════════════════════════════════════════════
    # Web Dashboard Configuration
    # ═══════════════════════════════════════════════════════════════
    web = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the web dashboard";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the web dashboard";
      };
    };

    # ═══════════════════════════════════════════════════════════════
    # Security Configuration
    # ═══════════════════════════════════════════════════════════════
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

    # ═══════════════════════════════════════════════════════════════
    # Virtualization Configuration
    # ═══════════════════════════════════════════════════════════════
    vfio = {
      enable = lib.mkEnableOption "Enable VFIO/IOMMU for PCI passthrough";
      pcieIds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "10de:1b80" "10de:10f0" ];
        description = "List of PCI vendor:device IDs to bind to vfio-pci";
      };
    };

    performance = {
      enableHugepages = lib.mkEnableOption "Enable hugepages (can improve performance, reduces memory flexibility)";
      disableSMT = lib.mkEnableOption "Disable SMT/Hyper-Threading (mitigates side-channels; can reduce throughput)";
    };

    # ═══════════════════════════════════════════════════════════════
    # Monitoring Configuration
    # ═══════════════════════════════════════════════════════════════
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

    # ═══════════════════════════════════════════════════════════════
    # Automation Configuration
    # ═══════════════════════════════════════════════════════════════
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
  };
}