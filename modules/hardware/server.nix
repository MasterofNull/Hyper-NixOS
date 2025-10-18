################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: Server Hardware Optimizations
# Purpose: Server-specific HA, RAID, remote management, and enterprise features
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.hardware.server;
in {
  options.hypervisor.hardware.server = {
    enable = mkEnableOption "server-specific optimizations";

    headless = mkOption {
      type = types.bool;
      default = true;
      description = "Headless server mode (no GUI, optimized for remote management)";
    };

    raid = {
      enable = mkEnableOption "RAID support and management";

      type = mkOption {
        type = types.nullOr (types.enum [ "mdadm" "zfs" "btrfs" ]);
        default = "mdadm";
        description = "RAID implementation to use";
      };

      monitoring = mkOption {
        type = types.bool;
        default = true;
        description = "Enable RAID health monitoring and alerts";
      };

      autoRepair = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically repair degraded RAID arrays";
      };

      scrubSchedule = mkOption {
        type = types.str;
        default = "monthly";
        description = "Schedule for RAID scrubbing (systemd timer format)";
      };
    };

    highAvailability = {
      enable = mkEnableOption "high availability clustering";

      clusterName = mkOption {
        type = types.str;
        default = "hyper-nixos-cluster";
        description = "Name of the HA cluster";
      };

      nodes = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "node1.example.com" "node2.example.com" ];
        description = "List of cluster node hostnames or IPs";
      };

      fencing = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable STONITH fencing for split-brain protection";
        };

        method = mkOption {
          type = types.enum [ "ipmi" "apc" "ssh" "manual" ];
          default = "ipmi";
          description = "Fencing method for node isolation";
        };
      };

      virtualIPManager = mkOption {
        type = types.bool;
        default = true;
        description = "Enable floating IP management for service migration";
      };
    };

    remoteManagement = {
      enable = mkEnableOption "remote management integration";

      ipmi = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable IPMI/BMC integration";
        };

        monitorSensors = mkOption {
          type = types.bool;
          default = true;
          description = "Monitor hardware sensors via IPMI";
        };

        solEnabled = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Serial Over LAN console access";
        };
      };

      kvm = {
        enable = mkEnableOption "remote KVM console access";

        port = mkOption {
          type = types.port;
          default = 5900;
          description = "VNC port for remote console";
        };
      };

      webConsole = mkOption {
        type = types.bool;
        default = true;
        description = "Enable web-based management console";
      };
    };

    storage = {
      enterprise = {
        enable = mkEnableOption "enterprise storage backend support";

        backends = mkOption {
          type = types.listOf (types.enum [ "ceph" "glusterfs" "nfs" "iscsi" "fc" ]);
          default = [];
          description = "Enabled enterprise storage backends";
        };

        ceph = {
          monitors = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "mon1:6789" "mon2:6789" "mon3:6789" ];
            description = "Ceph monitor addresses";
          };

          pools = mkOption {
            type = types.listOf types.str;
            default = [ "vms" "images" ];
            description = "Ceph pools for VM storage";
          };
        };

        glusterfs = {
          volumes = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "gv0" "vm-storage" ];
            description = "GlusterFS volumes to mount";
          };

          servers = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "GlusterFS server addresses";
          };
        };
      };

      multipath = {
        enable = mkEnableOption "multipath I/O for redundant storage paths";

        policy = mkOption {
          type = types.enum [ "round-robin" "failover" "multibus" "service-time" ];
          default = "service-time";
          description = "Multipath load balancing policy";
        };
      };

      thinProvisioning = mkOption {
        type = types.bool;
        default = true;
        description = "Enable thin provisioning for efficient storage allocation";
      };
    };

    networking = {
      bonding = {
        enable = mkEnableOption "network interface bonding";

        mode = mkOption {
          type = types.enum [ "active-backup" "balance-rr" "balance-xor" "broadcast" "802.3ad" "balance-tlb" "balance-alb" ];
          default = "802.3ad";
          description = "Network bonding mode (LACP recommended)";
        };

        interfaces = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "enp1s0" "enp2s0" ];
          description = "Physical interfaces to bond";
        };
      };

      jumboFrames = mkOption {
        type = types.bool;
        default = false;
        description = "Enable jumbo frames (MTU 9000) for storage networks";
      };

      sriovVirtualization = mkEnableOption "SR-IOV network virtualization for high-performance VMs";
    };

    performance = {
      cpuGovernor = mkOption {
        type = types.enum [ "performance" "ondemand" "conservative" ];
        default = "performance";
        description = "CPU frequency governor for servers";
      };

      numaOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable NUMA-aware VM placement and memory allocation";
      };

      hugepages = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable transparent huge pages for VM memory";
        };

        size = mkOption {
          type = types.enum [ "2M" "1G" ];
          default = "2M";
          description = "Huge page size";
        };

        count = mkOption {
          type = types.int;
          default = 1024;
          description = "Number of huge pages to allocate";
        };
      };

      ioScheduler = mkOption {
        type = types.enum [ "none" "mq-deadline" "kyber" ];
        default = "none";
        description = "I/O scheduler (none for NVMe, mq-deadline for SAS/SATA)";
      };
    };

    monitoring = {
      enhanced = mkOption {
        type = types.bool;
        default = true;
        description = "Enable enhanced server monitoring (IPMI, RAID, cluster health)";
      };

      exporters = mkOption {
        type = types.listOf (types.enum [ "node" "ipmi" "mdadm" "smartctl" "libvirt" ]);
        default = [ "node" "ipmi" "mdadm" "smartctl" "libvirt" ];
        description = "Prometheus exporters to enable";
      };

      alerting = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable alerting for critical server events";
        };

        channels = mkOption {
          type = types.listOf (types.enum [ "email" "slack" "pagerduty" "webhook" ]);
          default = [ "email" ];
          description = "Alert notification channels";
        };
      };
    };

    backup = {
      enterprise = mkOption {
        type = types.bool;
        default = false;
        description = "Enable enterprise backup integration (Veeam, Bacula, etc.)";
      };

      replication = {
        enable = mkEnableOption "VM replication to remote site";

        remoteHost = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Remote replication target host";
        };

        schedule = mkOption {
          type = types.str;
          default = "hourly";
          description = "Replication schedule";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Headless mode - disable GUI
    services.xserver.enable = mkIf cfg.headless false;

    # Server performance tuning
    powerManagement.cpuFreqGovernor = cfg.performance.cpuGovernor;

    # RAID support
    boot.swraid = mkIf (cfg.raid.enable && cfg.raid.type == "mdadm") {
      enable = true;
      mdadmConf = ''
        MAILADDR root
        PROGRAM /run/current-system/sw/bin/mdadm-notify
      '';
    };

    # ZFS support
    boot.supportedFilesystems = mkIf cfg.raid.enable (
      optional (cfg.raid.type == "zfs") "zfs" ++
      optional (cfg.raid.type == "btrfs") "btrfs"
    );

    # RAID monitoring
    services.mdmonitor = mkIf (cfg.raid.enable && cfg.raid.monitoring && cfg.raid.type == "mdadm") {
      enable = true;
    };

    # RAID scrubbing service
    systemd.services.raid-scrub = mkIf (cfg.raid.enable && cfg.raid.type == "mdadm") {
      description = "Hyper-NixOS: RAID Array Scrubbing";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "raid-scrub" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          for array in /dev/md*; do
            if [ -b "$array" ]; then
              echo "Scrubbing $array..."
              echo "check" > "/sys/block/$(basename "$array")/md/sync_action"
            fi
          done
        ''}";
      };
    };

    systemd.timers.raid-scrub = mkIf (cfg.raid.enable && cfg.raid.type == "mdadm") {
      description = "Hyper-NixOS: Monthly RAID Scrub";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.raid.scrubSchedule;
        Persistent = true;
      };
    };

    # High availability clustering with Pacemaker
    services.pacemaker = mkIf cfg.highAvailability.enable {
      enable = true;
    };

    services.corosync = mkIf cfg.highAvailability.enable {
      enable = true;
      clusterName = cfg.highAvailability.clusterName;
    };

    # IPMI tools and monitoring
    hardware.enableRedistributableFirmware = mkIf cfg.remoteManagement.ipmi.enable true;

    environment.systemPackages = with pkgs; [
      # Basic server tools
      htop
      iotop
      iftop
      tcpdump
      ethtool

      # RAID management
    ] ++ optionals (cfg.raid.enable && cfg.raid.type == "mdadm") [
      mdadm
    ] ++ optionals (cfg.raid.enable && cfg.raid.type == "zfs") [
      zfs
    ] ++ optionals cfg.remoteManagement.ipmi.enable [
      ipmitool
      freeipmi
    ] ++ optionals cfg.highAvailability.enable [
      pacemaker
      corosync
      pcs
    ] ++ optionals (elem "ceph" cfg.storage.enterprise.backends) [
      ceph
    ] ++ optionals (elem "glusterfs" cfg.storage.enterprise.backends) [
      glusterfs
    ] ++ optionals cfg.storage.multipath.enable [
      multipath-tools
    ];

    # IPMI sensor monitoring
    systemd.services.ipmi-sensors = mkIf (cfg.remoteManagement.ipmi.enable && cfg.remoteManagement.ipmi.monitorSensors) {
      description = "Hyper-NixOS: IPMI Sensor Monitoring";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "ipmi-sensors" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          # Check if IPMI is available
          if ! ${pkgs.ipmitool}/bin/ipmitool sdr list &>/dev/null; then
            echo "IPMI not available on this system"
            exit 0
          fi

          # Log sensor data
          ${pkgs.ipmitool}/bin/ipmitool sdr list full | tee /var/log/hypervisor/ipmi-sensors.log

          # Check for critical sensors
          if ${pkgs.ipmitool}/bin/ipmitool sdr list | grep -i "critical"; then
            echo "CRITICAL: Hardware sensors in critical state!" | systemd-cat -t hypervisor -p err
          fi
        ''}";
      };
    };

    systemd.timers.ipmi-sensors = mkIf (cfg.remoteManagement.ipmi.enable && cfg.remoteManagement.ipmi.monitorSensors) {
      description = "Hyper-NixOS: IPMI Sensor Check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";  # Every 15 minutes
        Persistent = true;
      };
    };

    # Multipath configuration
    services.multipath = mkIf cfg.storage.multipath.enable {
      enable = true;
      defaults = ''
        user_friendly_names yes
        path_grouping_policy ${cfg.storage.multipath.policy}
        failback immediate
        no_path_retry 5
      '';
    };

    # Ceph client configuration
    environment.etc."ceph/ceph.conf" = mkIf (elem "ceph" cfg.storage.enterprise.backends) {
      text = ''
        [global]
        mon_host = ${concatStringsSep "," cfg.storage.enterprise.ceph.monitors}
        auth_cluster_required = cephx
        auth_service_required = cephx
        auth_client_required = cephx
      '';
    };

    # GlusterFS client
    fileSystems = mkIf (elem "glusterfs" cfg.storage.enterprise.backends)
      (listToAttrs (map (volume: nameValuePair "/mnt/gluster/${volume}" {
        device = "${head cfg.storage.enterprise.glusterfs.servers}:/${volume}";
        fsType = "glusterfs";
        options = [ "defaults" "_netdev" "backup-volfile-servers=${concatStringsSep ":" (tail cfg.storage.enterprise.glusterfs.servers)}" ];
      }) cfg.storage.enterprise.glusterfs.volumes));

    # Network bonding
    networking.bonds = mkIf (cfg.networking.bonding.enable && cfg.networking.bonding.interfaces != []) {
      bond0 = {
        interfaces = cfg.networking.bonding.interfaces;
        driverOptions = {
          mode = cfg.networking.bonding.mode;
          miimon = "100";
          lacp_rate = mkIf (cfg.networking.bonding.mode == "802.3ad") "fast";
        };
      };
    };

    # Jumbo frames
    networking.interfaces = mkIf cfg.networking.jumboFrames
      (listToAttrs (map (iface: nameValuePair iface { mtu = 9000; })
        (if cfg.networking.bonding.enable then [ "bond0" ] else [])));

    # Huge pages
    boot.kernelParams = mkIf cfg.performance.hugepages.enable [
      "hugepagesz=${cfg.performance.hugepages.size}"
      "hugepages=${toString cfg.performance.hugepages.count}"
      "default_hugepagesz=${cfg.performance.hugepages.size}"
    ] ++ optional cfg.networking.jumboFrames "mtu=9000";

    # Kernel modules for server features
    boot.kernelModules = [
      "bonding"
      "ipmi_devintf"
      "ipmi_si"
    ] ++ optionals cfg.storage.multipath.enable [
      "dm-multipath"
    ];

    # Server-optimized kernel parameters
    boot.kernel.sysctl = {
      # Network performance
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.ipv4.tcp_rmem" = "4096 87380 67108864";
      "net.ipv4.tcp_wmem" = "4096 65536 67108864";
      "net.core.netdev_max_backlog" = 300000;
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.ipv4.tcp_mtu_probing" = 1;

      # VM density optimization
      "vm.swappiness" = 1;
      "vm.overcommit_memory" = 1;
      "vm.overcommit_ratio" = 100;

      # File system
      "fs.file-max" = 2097152;
      "fs.aio-max-nr" = 1048576;
    } // optionalAttrs cfg.performance.numaOptimization {
      "kernel.numa_balancing" = 1;
    };

    # Prometheus exporters
    services.prometheus.exporters = {
      node = mkIf (cfg.monitoring.enhanced && elem "node" cfg.monitoring.exporters) {
        enable = true;
        enabledCollectors = [ "systemd" "processes" "interrupts" ];
      };

      ipmi = mkIf (cfg.monitoring.enhanced && elem "ipmi" cfg.monitoring.exporters && cfg.remoteManagement.ipmi.enable) {
        enable = true;
      };

      smartctl = mkIf (cfg.monitoring.enhanced && elem "smartctl" cfg.monitoring.exporters) {
        enable = true;
      };
    };

    # VM replication service
    systemd.services.vm-replication = mkIf (cfg.backup.replication.enable && cfg.backup.replication.remoteHost != null) {
      description = "Hyper-NixOS: VM Replication Service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "vm-replication" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          source /etc/hypervisor/scripts/lib/common.sh

          REMOTE_HOST="${cfg.backup.replication.remoteHost}"

          log_info "Starting VM replication to $REMOTE_HOST"

          # Replicate each running VM
          for vm in $(virsh list --name); do
            if [ -n "$vm" ]; then
              log_info "Replicating VM: $vm"

              # Create snapshot for consistent backup
              virsh snapshot-create-as "$vm" "replication-$(date +%Y%m%d-%H%M%S)" \
                --disk-only --atomic --quiesce || true

              # Sync VM disk images
              rsync -avz --progress \
                /var/lib/libvirt/images/"$vm"*.qcow2 \
                "$REMOTE_HOST":/var/lib/libvirt/images/ || log_error "Failed to replicate $vm"

              # Clean up snapshot
              virsh snapshot-delete "$vm" --current --metadata || true
            fi
          done

          log_info "VM replication completed"
        ''}";
      };
    };

    systemd.timers.vm-replication = mkIf (cfg.backup.replication.enable && cfg.backup.replication.remoteHost != null) {
      description = "Hyper-NixOS: VM Replication Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.replication.schedule;
        Persistent = true;
      };
    };

    # Server optimization activation message
    system.activationScripts.serverOptimizations = ''
      echo "Hyper-NixOS: Server optimizations enabled"
      ${optionalString cfg.headless "echo '  - Headless mode active'"}
      ${optionalString cfg.raid.enable "echo '  - RAID support: ${cfg.raid.type}'"}
      ${optionalString cfg.highAvailability.enable "echo '  - HA clustering: ${cfg.highAvailability.clusterName}'"}
      ${optionalString cfg.remoteManagement.ipmi.enable "echo '  - IPMI remote management enabled'"}
      ${optionalString (cfg.storage.enterprise.backends != []) "echo '  - Enterprise storage: ${concatStringsSep ", " cfg.storage.enterprise.backends}'"}
    '';
  };
}
