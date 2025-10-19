################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: Laptop Hardware Optimizations
# Purpose: Laptop-specific power management, battery optimization, and hardware support
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ config, lib, pkgs, ... }:

{
  options.hypervisor.hardware.laptop = {
    enable = lib.mkEnableOption "laptop-specific optimizations";

    powerManagement = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable aggressive power management for battery life";
      };

      suspendOnLidClose = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Suspend system when laptop lid is closed";
      };

      cpuGovernor = lib.mkOption {
        type = lib.types.enum [ "powersave" "ondemand" "performance" "schedutil" ];
        default = "powersave";
        description = "CPU frequency scaling governor";
      };

      autosuspendDelay = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Seconds of inactivity before automatic suspend";
      };
    };

    battery = {
      optimizationLevel = lib.mkOption {
        type = lib.types.enum [ "maximum-life" "balanced" "performance" ];
        default = "balanced";
        description = "Battery optimization profile";
      };

      chargeThreshold = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Battery charge threshold (0-100) to preserve battery health";
      };

      notifications = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show battery level notifications";
      };
    };

    display = {
      autoBacklight = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically adjust screen brightness based on ambient light";
      };

      dimOnBattery = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Reduce screen brightness when on battery power";
      };

      dimTimeout = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Seconds before dimming screen on inactivity";
      };
    };

    wireless = {
      powerSaving = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable WiFi and Bluetooth power saving modes";
      };

      disableWhenWired = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable WiFi when ethernet cable is connected";
      };
    };

    touchpad = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable and configure touchpad";
      };

      tapToClick = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable tap-to-click on touchpad";
      };

      naturalScrolling = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable natural (reverse) scrolling";
      };

      disableWhileTyping = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Disable touchpad while typing";
      };
    };

    virtualization = {
      vmPowerProfiles = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable power-aware VM scheduling and resource allocation";
      };

      suspendVMsOnBattery = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically suspend running VMs when switching to battery power";
      };
    };
  };

  config = lib.mkIf config.hypervisor.hardware.laptop.enable (let
    cfg = config.hypervisor.hardware.laptop;
  in {
    # Power management with TLP
    services.tlp = lib.mkIf cfg.powerManagement.enable {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = cfg.powerManagement.cpuGovernor;

        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 60;

        # USB autosuspend
        USB_AUTOSUSPEND = 1;
        USB_BLACKLIST_PHONE = 1;

        # SATA aggressive link power management
        SATA_LINKPWR_ON_AC = "max_performance";
        SATA_LINKPWR_ON_BAT = "min_power";

        # PCIe Active State Power Management
        PCIE_ASPM_ON_AC = "performance";
        PCIE_ASPM_ON_BAT = "powersupersave";

        # WiFi power saving
        WIFI_PWR_ON_AC = lib.mkIf (!cfg.wireless.powerSaving) "off";
        WIFI_PWR_ON_BAT = lib.mkIf cfg.wireless.powerSaving "on";

        # Battery care settings
        START_CHARGE_THRESH_BAT0 = lib.mkIf (cfg.battery.chargeThreshold != null)
          (cfg.battery.chargeThreshold - 5);
        STOP_CHARGE_THRESH_BAT0 = lib.mkIf (cfg.battery.chargeThreshold != null)
          cfg.battery.chargeThreshold;
      };
    };

    # Alternative: auto-cpufreq for more advanced CPU management
    services.auto-cpufreq = lib.mkIf (!config.services.tlp.enable && cfg.powerManagement.enable) {
      enable = true;
      settings = {
        battery = {
          governor = cfg.powerManagement.cpuGovernor;
          turbo = "auto";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };

    # Lid switch handling
    services.logind = lib.mkIf cfg.powerManagement.suspendOnLidClose {
      lidSwitch = "suspend";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "suspend";
    };

    # PowerTop for power monitoring and tuning
    powerManagement.powertop.enable = cfg.powerManagement.enable;

    # Thermald for thermal management (Intel)
    services.thermald.enable = true;

    # Laptop mode tools
    powerManagement.enable = true;
    powerManagement.cpuFreqGovernor = lib.mkIf (!cfg.powerManagement.enable) "ondemand";

    # Display backlight management
    programs.light.enable = cfg.display.autoBacklight;

    # Touchpad configuration
    services.libinput = lib.mkIf cfg.touchpad.enable {
      enable = true;
      touchpad = {
        tapping = cfg.touchpad.tapToClick;
        naturalScrolling = cfg.touchpad.naturalScrolling;
        disableWhileTyping = cfg.touchpad.disableWhileTyping;
        accelProfile = "adaptive";
        accelSpeed = "0.5";
      };
    };

    # Battery notification service
    systemd.services.battery-notifier = lib.mkIf cfg.battery.notifications {
      description = "Hyper-NixOS: Battery Level Notifications";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "battery-notifier" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          while true; do
            # Check battery level
            if [ -d /sys/class/power_supply/BAT0 ]; then
              capacity=$(cat /sys/class/power_supply/BAT0/capacity)
              status=$(cat /sys/class/power_supply/BAT0/status)

              if [ "$status" = "Discharging" ]; then
                if [ "$capacity" -le 10 ]; then
                  ${pkgs.libnotify}/bin/notify-send -u critical "Battery Critical" "Battery at $capacity%. Please connect charger."
                elif [ "$capacity" -le 20 ]; then
                  ${pkgs.libnotify}/bin/notify-send -u normal "Battery Low" "Battery at $capacity%. Consider connecting charger."
                fi
              fi
            fi

            sleep 300  # Check every 5 minutes
          done
        ''}";
        Restart = "always";
        RestartSec = "10s";
      };
      wantedBy = [ "multi-user.target" ];
    };

    # VM power management integration
    systemd.services.vm-power-manager = lib.mkIf cfg.virtualization.vmPowerProfiles {
      description = "Hyper-NixOS: VM Power Management";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "vm-power-manager" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          source /etc/hypervisor/scripts/lib/common.sh

          while true; do
            # Detect power state
            if [ -f /sys/class/power_supply/AC/online ]; then
              on_ac=$(cat /sys/class/power_supply/AC/online)

              if [ "$on_ac" = "0" ]; then
                # On battery - reduce VM resources
                log_info "On battery power - applying power-saving VM profile"

                ${lib.optionalString cfg.virtualization.suspendVMsOnBattery ''
                  # Suspend non-critical VMs
                  for vm in $(virsh list --name); do
                    if [ -n "$vm" ]; then
                      log_info "Suspending VM: $vm"
                      virsh suspend "$vm" || true
                    fi
                  done
                ''}
              else
                # On AC - restore normal VM operation
                log_info "On AC power - restoring normal VM profile"

                ${lib.optionalString cfg.virtualization.suspendVMsOnBattery ''
                  # Resume suspended VMs
                  for vm in $(virsh list --state-suspended --name); do
                    if [ -n "$vm" ]; then
                      log_info "Resuming VM: $vm"
                      virsh resume "$vm" || true
                    fi
                  done
                ''}
              fi
            fi

            sleep 30  # Check every 30 seconds
          done
        ''}";
        Restart = "always";
        RestartSec = "10s";
      };
      after = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
    };

    # Required packages
    environment.systemPackages = with pkgs; [
      acpi
      powertop
      brightnessctl
      libnotify
    ] ++ lib.optionals cfg.powerManagement.enable [
      tlp
    ] ++ lib.optionals cfg.display.autoBacklight [
      light
    ];

    # Kernel parameters for laptop optimization
    boot.kernelParams = [
      "pcie_aspm=force"  # Force PCIe power management
      "i915.enable_psr=1"  # Enable Panel Self Refresh (Intel)
    ];

    # Enable laptop-specific kernel modules
    boot.kernelModules = [
      "acpi_call"  # For battery charge thresholds
    ];
  });
}
