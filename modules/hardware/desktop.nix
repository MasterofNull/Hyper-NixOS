################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: Desktop Hardware Optimizations
# Purpose: Desktop-specific performance tuning, GPU passthrough, and multi-monitor support
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.hardware.desktop;
in {
  options.hypervisor.hardware.desktop = {
    enable = mkEnableOption "desktop-specific optimizations";

    performance = {
      cpuGovernor = mkOption {
        type = types.enum [ "performance" "ondemand" "schedutil" ];
        default = "performance";
        description = "CPU frequency scaling governor for desktop";
      };

      enableTurbo = mkOption {
        type = types.bool;
        default = true;
        description = "Enable CPU turbo boost";
      };

      ioScheduler = mkOption {
        type = types.enum [ "mq-deadline" "kyber" "bfq" "none" ];
        default = "mq-deadline";
        description = "I/O scheduler for best desktop performance";
      };
    };

    gpu = {
      passthrough = {
        enable = mkEnableOption "GPU passthrough support for VMs";

        primaryGPU = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "10de:1b80";
          description = "PCI ID of primary GPU for host (vendor:device)";
        };

        passthroughGPUs = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "10de:1c03" "10de:10f1" ];
          description = "PCI IDs of GPUs to pass through to VMs";
        };

        isolateGPUs = mkOption {
          type = types.bool;
          default = true;
          description = "Isolate passthrough GPUs from host at boot";
        };

        enableIOMMU = mkOption {
          type = types.bool;
          default = true;
          description = "Enable IOMMU for PCIe device isolation";
        };
      };

      multiGPU = {
        enable = mkEnableOption "multi-GPU configuration support";

        renderOffload = mkOption {
          type = types.bool;
          default = false;
          description = "Enable PRIME render offload for hybrid graphics";
        };
      };

      optimization = mkOption {
        type = types.enum [ "nvidia" "amd" "intel" "auto" ];
        default = "auto";
        description = "GPU vendor-specific optimizations";
      };
    };

    display = {
      multiMonitor = {
        enable = mkEnableOption "multi-monitor optimizations";

        arrangement = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "DP-1 --right-of HDMI-1";
          description = "Monitor arrangement for xrandr";
        };

        enableFreeSync = mkOption {
          type = types.bool;
          default = false;
          description = "Enable AMD FreeSync support";
        };

        enableGSync = mkOption {
          type = types.bool;
          default = false;
          description = "Enable NVIDIA G-SYNC support";
        };
      };

      highRefreshRate = {
        enable = mkEnableOption "high refresh rate monitor support";

        defaultRefreshRate = mkOption {
          type = types.int;
          default = 144;
          description = "Default refresh rate for high refresh rate monitors";
        };
      };
    };

    gaming = {
      enable = mkEnableOption "gaming VM optimizations";

      lookingGlass = {
        enable = mkEnableOption "Looking Glass for low-latency GPU passthrough";

        shmSize = mkOption {
          type = types.int;
          default = 256;
          description = "Shared memory size in MB for Looking Glass";
        };
      };

      screamAudio = mkEnableOption "Scream for low-latency audio passthrough";

      optimizeLatency = mkOption {
        type = types.bool;
        default = true;
        description = "Apply CPU pinning and latency optimizations for gaming VMs";
      };
    };

    storage = {
      nvmeOptimization = mkEnableOption "NVMe storage optimizations";

      enableTrim = mkOption {
        type = types.bool;
        default = true;
        description = "Enable periodic TRIM for SSDs";
      };

      diskScheduler = mkOption {
        type = types.enum [ "none" "mq-deadline" "kyber" ];
        default = "none";
        description = "I/O scheduler for NVMe drives";
      };
    };

    audio = {
      lowLatency = mkEnableOption "low-latency audio configuration";

      pipeWire = mkOption {
        type = types.bool;
        default = true;
        description = "Use PipeWire for audio (better for desktop)";
      };

      sampleRate = mkOption {
        type = types.int;
        default = 48000;
        description = "Audio sample rate";
      };
    };
  };

  config = mkIf cfg.enable {
    # Performance tuning
    powerManagement.cpuFreqGovernor = cfg.performance.cpuGovernor;

    # CPU turbo boost and other kernel parameters
    boot.kernelParams = [
      (mkIf cfg.performance.enableTurbo "intel_pstate=active")
      (mkIf cfg.performance.enableTurbo "amd_pstate=active")
    ] ++ optionals cfg.gpu.passthrough.enableIOMMU [
      "intel_iommu=on"
      "amd_iommu=on"
      "iommu=pt"
    ] ++ optionals (cfg.gpu.passthrough.enable && cfg.gpu.passthrough.isolateGPUs) [
      "video=efifb:off"
      "video=vesafb:off"
    ] ++ optionals cfg.gaming.enable [
      "hugepagesz=1G"
      "hugepages=16"
      "default_hugepagesz=1G"
    ];

    # VFIO GPU passthrough configuration
    boot.initrd.kernelModules = mkIf cfg.gpu.passthrough.enable [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
      "vfio_virqfd"
    ];

    boot.kernelModules = [
      "kvm-intel"
      "kvm-amd"
    ] ++ optionals cfg.gpu.passthrough.enable [
      "vfio-pci"
    ];

    # GPU isolation via VFIO
    boot.extraModprobeConfig = mkIf (cfg.gpu.passthrough.enable && cfg.gpu.passthrough.passthroughGPUs != []) ''
      # Isolate GPUs for passthrough
      ${concatMapStringsSep "\n" (gpu: "options vfio-pci ids=${gpu}") cfg.gpu.passthrough.passthroughGPUs}

      # Prevent host drivers from claiming passthrough GPUs
      softdep drm pre: vfio-pci
      softdep nouveau pre: vfio-pci
      softdep amdgpu pre: vfio-pci
      softdep i915 pre: vfio-pci
    '';

    # GPU-specific optimizations
    hardware.nvidia = mkIf (cfg.gpu.optimization == "nvidia" || cfg.gpu.optimization == "auto") {
      modesetting.enable = true;
      powerManagement.enable = false;  # Desktop doesn't need power saving
      open = false;  # Use proprietary driver for best performance
      nvidiaSettings = true;
    };

    # Graphics support (NixOS 24.05 uses hardware.opengl)
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;  # For 32-bit games/applications
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
      ] ++ optionals (cfg.gpu.optimization == "nvidia" || cfg.gpu.optimization == "auto") [
        nvidia-vaapi-driver
      ] ++ optionals (cfg.gpu.optimization == "amd" || cfg.gpu.optimization == "auto") [
        amdvlk
        rocm-opencl-icd
      ];
    };

    # Multi-monitor setup
    services.xserver.xrandrHeads = mkIf (cfg.display.multiMonitor.enable && cfg.display.multiMonitor.arrangement != null) [
      cfg.display.multiMonitor.arrangement
    ];

    # Gaming-related tmpfiles rules
    systemd.tmpfiles.rules =
      (optionals cfg.gaming.lookingGlass.enable [
        "f /dev/shm/looking-glass 0660 ${config.hypervisor.users.operator} kvm -"
      ])
      ++
      (optionals cfg.gaming.enable [
        "w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise"
      ]);

    environment.etc."looking-glass-client.ini" = mkIf cfg.gaming.lookingGlass.enable {
      text = ''
        [app]
        shmFile=/dev/shm/looking-glass

        [input]
        rawMouse=yes
        mouseRedraw=yes

        [spice]
        enable=yes
        audio=yes
      '';
    };

    # NVMe optimizations
    services.fstrim.enable = mkIf cfg.storage.enableTrim true;

    # I/O scheduler configuration
    services.udev.extraRules = mkIf cfg.storage.nvmeOptimization ''
      # NVMe-specific optimizations
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="${cfg.storage.diskScheduler}"
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/iosched/low_latency}="1"
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="1024"
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="512"
    '';

    # Audio configuration
    services.pipewire = mkIf cfg.audio.pipeWire {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      config.pipewire = mkIf cfg.audio.lowLatency {
        "context.properties" = {
          "default.clock.rate" = cfg.audio.sampleRate;
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 256;
        };
      };
    };

    # Scream audio for VMs
    systemd.services.scream-audio = mkIf cfg.gaming.screamAudio {
      description = "Hyper-NixOS: Scream Audio Receiver for Gaming VMs";
      after = [ "network.target" "pipewire.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.scream}/bin/scream-ivshmem-pulse";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    # VM CPU pinning helper for gaming
    environment.etc."hypervisor/gaming-vm-template.xml" = mkIf cfg.gaming.optimizeLatency {
      text = ''
        <!-- Gaming VM CPU Pinning Template -->
        <!-- Apply with: virsh edit <vm-name> -->
        <domain type='kvm'>
          <cputune>
            <!-- Pin vCPUs to physical cores (adjust based on your CPU) -->
            <vcpupin vcpu='0' cpuset='2'/>
            <vcpupin vcpu='1' cpuset='3'/>
            <vcpupin vcpu='2' cpuset='4'/>
            <vcpupin vcpu='3' cpuset='5'/>
            <!-- Pin emulator threads away from vCPU cores -->
            <emulatorpin cpuset='0-1'/>
            <!-- I/O thread pinning -->
            <iothreadpin iothread='1' cpuset='0-1'/>
          </cputune>

          <cpu mode='host-passthrough' check='none' migratable='on'>
            <topology sockets='1' dies='1' cores='4' threads='1'/>
            <cache mode='passthrough'/>
            <feature policy='require' name='topoext'/>
          </cpu>

          <clock offset='localtime'>
            <timer name='rtc' tickpolicy='catchup'/>
            <timer name='pit' tickpolicy='delay'/>
            <timer name='hpet' present='no'/>
            <timer name='hypervclock' present='yes'/>
          </clock>
        </domain>
      '';
    };

    # Desktop-specific packages
    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
      lm_sensors
      hwinfo
    ] ++ optionals cfg.gpu.passthrough.enable [
      looking-glass-client
    ] ++ optionals cfg.gaming.screamAudio [
      scream
    ] ++ optionals cfg.display.multiMonitor.enable [
      xorg.xrandr
      arandr
    ];

    # Desktop-optimized kernel parameters
    boot.kernel.sysctl = {
      # VM performance tuning
      "vm.swappiness" = 10;  # Prefer RAM over swap
      "vm.vfs_cache_pressure" = 50;  # Keep directory cache
      "vm.dirty_ratio" = 10;
      "vm.dirty_background_ratio" = 5;

      # Network performance
      "net.core.netdev_max_backlog" = 16384;
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_mtu_probing" = 1;
    } // optionalAttrs cfg.gaming.enable {
      # Gaming-specific optimizations
      "kernel.sched_latency_ns" = 4000000;
      "kernel.sched_min_granularity_ns" = 500000;
      "kernel.sched_wakeup_granularity_ns" = 50000;
      "kernel.sched_migration_cost_ns" = 250000;
    };

    # Information message
    system.activationScripts.desktopOptimizations = mkIf cfg.enable ''
      echo "Hyper-NixOS: Desktop optimizations enabled"
      ${optionalString cfg.gpu.passthrough.enable ''
        echo "  - GPU passthrough configured for: ${concatStringsSep ", " cfg.gpu.passthrough.passthroughGPUs}"
        echo "  - IOMMU: ${if cfg.gpu.passthrough.enableIOMMU then "enabled" else "disabled"}"
      ''}
      ${optionalString cfg.gaming.enable ''
        echo "  - Gaming VM optimizations active"
        echo "  - Looking Glass: ${if cfg.gaming.lookingGlass.enable then "enabled" else "disabled"}"
      ''}
    '';
  };
}
