{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.hardware.arm;

  # Detect ARM platform from system info
  detectArmPlatform = pkgs.writeShellScript "detect-arm-platform" ''
    if [ ! -f /proc/cpuinfo ]; then
      echo "unknown"
      exit 0
    fi

    # Check for Raspberry Pi 5
    if grep -qi "Raspberry Pi 5" /proc/cpuinfo; then
      echo "rpi5"
    # Check for Raspberry Pi 4
    elif grep -qi "Raspberry Pi 4" /proc/cpuinfo; then
      echo "rpi4"
    # Check for Raspberry Pi 3
    elif grep -qi "Raspberry Pi 3" /proc/cpuinfo; then
      echo "rpi3"
    # Check for RockPro64
    elif grep -qi "rockchip" /proc/cpuinfo && grep -qi "rk3399" /proc/cpuinfo; then
      echo "rockpro64"
    # Check for Rock64
    elif grep -qi "rockchip" /proc/cpuinfo && grep -qi "rk3328" /proc/cpuinfo; then
      echo "rock64"
    # Check for Pine64
    elif grep -qi "allwinner" /proc/cpuinfo && grep -qi "sun50i" /proc/cpuinfo; then
      echo "pine64"
    # Check for PineBook Pro
    elif grep -qi "rockchip" /proc/cpuinfo && grep -qi "rk3399" /proc/cpuinfo && [ -e /sys/class/power_supply/BAT0 ]; then
      echo "pinebook-pro"
    # Check for ODROID-N2/N2+
    elif grep -qi "odroid-n2" /proc/cpuinfo || grep -qi "meson-g12b" /proc/cpuinfo; then
      echo "odroid-n2"
    # Check for ODROID-C4
    elif grep -qi "odroid-c4" /proc/cpuinfo || grep -qi "meson-sm1" /proc/cpuinfo; then
      echo "odroid-c4"
    # Check for ODROID-XU4
    elif grep -qi "odroid-xu4" /proc/cpuinfo || grep -qi "exynos5422" /proc/cpuinfo; then
      echo "odroid-xu4"
    # Generic ODROID
    elif grep -qi "odroid" /proc/cpuinfo; then
      echo "odroid-generic"
    # Check for Orange Pi 5
    elif grep -qi "orange.*pi.*5" /proc/cpuinfo || grep -qi "rk3588" /proc/cpuinfo; then
      echo "orangepi-5"
    # Check for Orange Pi Zero
    elif grep -qi "orange.*pi.*zero" /proc/cpuinfo; then
      echo "orangepi-zero"
    # Generic Orange Pi
    elif grep -qi "orange.*pi" /proc/cpuinfo; then
      echo "orangepi-generic"
    # Check for NanoPi R4S/R5S
    elif grep -qi "nanopi.*r[45]s" /proc/cpuinfo; then
      echo "nanopi-r4s"
    # Check for Jetson Nano
    elif grep -qi "jetson.*nano" /proc/cpuinfo || grep -qi "tegra210" /proc/cpuinfo; then
      echo "jetson-nano"
    # Check for Jetson Xavier
    elif grep -qi "jetson.*xavier" /proc/cpuinfo || grep -qi "tegra194" /proc/cpuinfo; then
      echo "jetson-xavier"
    # Check for Banana Pi
    elif grep -qi "banana.*pi" /proc/cpuinfo; then
      echo "bananapi"
    # Generic ARM64
    elif uname -m | grep -qi "aarch64"; then
      echo "generic-arm64"
    # ARM32
    elif uname -m | grep -qi "armv7"; then
      echo "generic-arm32"
    else
      echo "unknown"
    fi
  '';

in {
  options.hypervisor.hardware.arm = {
    enable = mkEnableOption "ARM-specific hardware configuration";

    platform = mkOption {
      type = types.enum [
        "rpi3"
        "rpi4"
        "rpi5"
        "rockpro64"
        "rock64"
        "pine64"
        "pinebook-pro"
        "odroid-n2"
        "odroid-c4"
        "odroid-xu4"
        "odroid-generic"
        "orangepi-5"
        "orangepi-zero"
        "orangepi-generic"
        "nanopi-r4s"
        "jetson-nano"
        "jetson-xavier"
        "bananapi"
        "generic-arm64"
        "generic-arm32"
        "unknown"
      ];
      default = "generic-arm64";
      description = "Specific ARM platform for optimized configuration";
    };

    autoDetect = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically detect ARM platform";
    };

    virtualization = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable ARM virtualization support (KVM)";
      };

      nestedVirtualization = mkOption {
        type = types.bool;
        default = false;
        description = "Enable nested virtualization (may not be supported on all platforms)";
      };
    };

    optimizations = {
      enableCpuGovernor = mkOption {
        type = types.bool;
        default = true;
        description = "Enable performance CPU governor for better VM performance";
      };

      enableZram = mkOption {
        type = types.bool;
        default = true;
        description = "Enable zram for compressed RAM (helpful on memory-constrained ARM boards)";
      };

      memoryProfile = mkOption {
        type = types.enum [ "minimal" "standard" "performance" ];
        default = "standard";
        description = ''
          Memory optimization profile:
          - minimal: For 2GB RAM or less (aggressive swap, zram, reduced caching)
          - standard: For 4GB RAM (balanced approach)
          - performance: For 8GB+ RAM (maximize caching, minimal swap)
        '';
      };

      sdCardOptimization = mkOption {
        type = types.bool;
        default = false;
        description = "Enable SD card wear reduction (reduces writes, enables noatime)";
      };
    };

    thermal = {
      enable = mkEnableOption "thermal management and monitoring";

      maxTemperature = mkOption {
        type = types.int;
        default = 80;
        description = "Maximum CPU temperature in Celsius before throttling";
      };

      fanControl = {
        enable = mkEnableOption "automatic fan control based on temperature";

        lowSpeed = mkOption {
          type = types.int;
          default = 40;
          description = "Temperature (°C) to start fan at low speed";
        };

        mediumSpeed = mkOption {
          type = types.int;
          default = 60;
          description = "Temperature (°C) to increase to medium speed";
        };

        highSpeed = mkOption {
          type = types.int;
          default = 70;
          description = "Temperature (°C) to increase to high speed";
        };
      };

      throttleVMsOnHeat = mkOption {
        type = types.bool;
        default = true;
        description = "Reduce VM resource allocation when CPU temperature is high";
      };
    };
  };

  config = mkIf cfg.enable {
    # ARM-specific kernel modules for virtualization
    boot.kernelModules = [
      "kvm"
      "vhost"
      "vhost-net"
      "vhost-vsock"
    ] ++ optionals (cfg.virtualization.nestedVirtualization) [
      "kvm-arm"
    ];

    # ARM virtualization kernel parameters
    boot.kernelParams = [
      "kvm-arm.mode=protected"
    ] ++ optionals (cfg.optimizations.enableCpuGovernor) [
      "cpufreq.default_governor=performance"
    ];

    # Platform-specific bootloader configuration
    boot.loader = {
      # Disable GRUB on ARM (not typically used)
      grub.enable = mkDefault false;

      # Enable generic extlinux bootloader (common for ARM)
      generic-extlinux-compatible.enable = mkDefault true;

      # Raspberry Pi specific bootloader
      raspberryPi = mkIf (elem cfg.platform ["rpi3" "rpi4" "rpi5"]) {
        enable = true;
        version = if cfg.platform == "rpi5" then 5
                  else if cfg.platform == "rpi4" then 4
                  else 3;
      };
    };

    # ARM-optimized packages for virtualization
    environment.systemPackages = with pkgs; [
      # QEMU with ARM support
      qemu_kvm

      # Libvirt for ARM
      libvirt

      # Virtualization tools
      virt-manager
      virt-viewer

      # ARM-specific utilities
    ] ++ optionals (cfg.platform == "rpi4" || cfg.platform == "rpi5") [
      libraspberrypi
      raspberrypi-eeprom
    ];

    # Virtualization configuration for ARM
    virtualisation = mkIf cfg.virtualization.enable {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = false;
          swtpm.enable = true;
          ovmf = {
            enable = true;
            packages = [ pkgs.OVMF.fd ];
          };
        };
      };
    };

    # CPU governor optimization
    powerManagement.cpuFreqGovernor = mkIf cfg.optimizations.enableCpuGovernor "performance";

    # Zram for memory compression (helpful on low-RAM ARM boards)
    zramSwap = mkIf cfg.optimizations.enableZram {
      enable = true;
      algorithm = "zstd";
      memoryPercent = if cfg.optimizations.memoryProfile == "minimal" then 100
                      else if cfg.optimizations.memoryProfile == "standard" then 50
                      else 25;
    };

    # Memory profile-specific kernel parameters
    boot.kernel.sysctl = {
      # Minimal profile (2GB or less)
      "vm.swappiness" = if cfg.optimizations.memoryProfile == "minimal" then 60
                       else if cfg.optimizations.memoryProfile == "standard" then 30
                       else 10;
      "vm.vfs_cache_pressure" = if cfg.optimizations.memoryProfile == "minimal" then 150
                                else if cfg.optimizations.memoryProfile == "standard" then 100
                                else 50;
      "vm.dirty_ratio" = if cfg.optimizations.memoryProfile == "minimal" then 5
                        else if cfg.optimizations.memoryProfile == "standard" then 10
                        else 20;
      "vm.dirty_background_ratio" = if cfg.optimizations.memoryProfile == "minimal" then 3
                                    else if cfg.optimizations.memoryProfile == "standard" then 5
                                    else 10;
    };

    # SD card wear reduction
    fileSystems = mkIf cfg.optimizations.sdCardOptimization {
      "/".options = [ "noatime" "nodiratime" ];
      "/boot".options = mkIf (config.fileSystems ? "/boot") [ "noatime" ];
    };

    # Thermal management service
    systemd.services.arm-thermal-monitor = mkIf cfg.thermal.enable {
      description = "Hyper-NixOS: ARM Thermal Monitoring and Management";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        ExecStart = "${pkgs.writeShellScript "arm-thermal-monitor" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          TEMP_ZONES=(/sys/class/thermal/thermal_zone*/temp)
          MAX_TEMP=${toString cfg.thermal.maxTemperature}
          LOW_TEMP=${toString cfg.thermal.fanControl.lowSpeed}
          MED_TEMP=${toString cfg.thermal.fanControl.mediumSpeed}
          HIGH_TEMP=${toString cfg.thermal.fanControl.highSpeed}

          # Find fan control (if available)
          FAN_CONTROL=""
          if [ -e /sys/class/hwmon/hwmon0/pwm1 ]; then
            FAN_CONTROL="/sys/class/hwmon/hwmon0/pwm1"
          elif [ -e /sys/class/thermal/cooling_device0/cur_state ]; then
            FAN_CONTROL="/sys/class/thermal/cooling_device0/cur_state"
          fi

          log() {
            echo "$1" | ${pkgs.systemd}/bin/systemd-cat -t arm-thermal -p "$2"
          }

          get_max_temp() {
            local max_temp=0
            for zone in "''${TEMP_ZONES[@]}"; do
              if [ -f "$zone" ]; then
                local temp=$(cat "$zone")
                temp=$((temp / 1000))  # Convert millidegrees to degrees
                if [ "$temp" -gt "$max_temp" ]; then
                  max_temp=$temp
                fi
              fi
            done
            echo "$max_temp"
          }

          set_fan_speed() {
            local speed=$1  # 0-255
            if [ -n "$FAN_CONTROL" ] && [ -w "$FAN_CONTROL" ]; then
              echo "$speed" > "$FAN_CONTROL" 2>/dev/null || true
            fi
          }

          throttle_vms() {
            local action=$1  # "throttle" or "restore"

            if [ "$action" = "throttle" ]; then
              log "High temperature detected - throttling VMs" "warning"

              # Reduce CPU allocation for running VMs
              for vm in $(virsh list --name 2>/dev/null || true); do
                if [ -n "$vm" ]; then
                  # Set CPU quota to 50%
                  virsh schedinfo "$vm" --set cpu_shares=512 2>/dev/null || true
                  log "Throttled VM: $vm" "info"
                fi
              done
            else
              log "Temperature normalized - restoring VM performance" "info"

              # Restore normal CPU allocation
              for vm in $(virsh list --name 2>/dev/null || true); do
                if [ -n "$vm" ]; then
                  virsh schedinfo "$vm" --set cpu_shares=1024 2>/dev/null || true
                  log "Restored VM: $vm" "info"
                fi
              done
            fi
          }

          # State tracking
          VM_THROTTLED=false

          while true; do
            current_temp=$(get_max_temp)

            # Fan control
            ${optionalString cfg.thermal.fanControl.enable ''
              if [ "$current_temp" -ge "$HIGH_TEMP" ]; then
                set_fan_speed 255  # Full speed
              elif [ "$current_temp" -ge "$MED_TEMP" ]; then
                set_fan_speed 180  # Medium speed
              elif [ "$current_temp" -ge "$LOW_TEMP" ]; then
                set_fan_speed 100  # Low speed
              else
                set_fan_speed 0    # Off
              fi
            ''}

            # VM throttling on high temperature
            ${optionalString cfg.thermal.throttleVMsOnHeat ''
              if [ "$current_temp" -ge "$MAX_TEMP" ] && [ "$VM_THROTTLED" = "false" ]; then
                throttle_vms "throttle"
                VM_THROTTLED=true
              elif [ "$current_temp" -lt "$((MAX_TEMP - 10))" ] && [ "$VM_THROTTLED" = "true" ]; then
                throttle_vms "restore"
                VM_THROTTLED=false
              fi
            ''}

            # Critical temperature warning
            if [ "$current_temp" -ge "$MAX_TEMP" ]; then
              log "CRITICAL: CPU temperature at ''${current_temp}°C (max: ''${MAX_TEMP}°C)" "err"
            fi

            sleep 5  # Check every 5 seconds
          done
        ''}";
      };
    };

    # Platform-specific hardware enablement
    hardware = {
      # Enable Raspberry Pi hardware
      raspberry-pi = mkIf (elem cfg.platform ["rpi3" "rpi4" "rpi5"]) {
        apply-overlays-dtmerge.enable = true;
      };

      # Enable device tree overlays for ARM
      deviceTree = {
        enable = true;
      };

      # Enable firmware for ARM devices
      enableRedistributableFirmware = true;
    };

    # Auto-detection on system activation
    system.activationScripts.detectArmPlatform = mkIf cfg.autoDetect ''
      detected=$(${detectArmPlatform})
      echo "Detected ARM platform: $detected"

      # Store detection result
      mkdir -p /etc/hypervisor
      echo "$detected" > /etc/hypervisor/arm-platform
    '';

    # Set hypervisor system info
    hypervisor.system.architecture = "arm";
    hypervisor.system.platform = cfg.platform;
  };
}
