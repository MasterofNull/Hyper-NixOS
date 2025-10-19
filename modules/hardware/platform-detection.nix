# Hyper-NixOS Platform-Specific Hardware Detection
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Intelligent detection of platform-specific hardware:
# - Laptops: Touchpad, backlight, keyboard, battery, etc.
# - Desktops: Multi-monitor, keyboard RGB, gaming peripherals
# - Servers: IPMI, BMC, hardware sensors
# - SBCs: GPIO, hardware PWM, specific board features

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.platform;

  # Detect if system is a laptop
  isLaptop = builtins.pathExists "/sys/class/power_supply/BAT0" ||
             builtins.pathExists "/sys/class/power_supply/BAT1" ||
             builtins.pathExists "/proc/acpi/battery";

  # Detect if system has a touchpad
  hasTouchpad = builtins.pathExists "/dev/input/by-path" &&
                (builtins.readDir "/dev/input/by-path") != {};

  # Detect backlight support
  hasBacklight = builtins.pathExists "/sys/class/backlight";

  # Detect battery
  hasBattery = isLaptop;

  # Detect multiple monitors (best effort)
  monitorDetectionScript = pkgs.writeShellScript "detect-monitors" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Count connected displays
    DISPLAY_COUNT=0

    # Try various methods
    if command -v xrandr >/dev/null 2>&1 && [[ -n "''${DISPLAY:-}" ]]; then
      DISPLAY_COUNT=$(xrandr --query | grep " connected" | wc -l)
    elif [[ -d /sys/class/drm ]]; then
      DISPLAY_COUNT=$(find /sys/class/drm -name "card*-*" -type d | grep -v "HDMI-A-0" | wc -l)
    fi

    echo "$DISPLAY_COUNT"
  '';

  # Detect RGB keyboard support (gaming peripherals)
  hasRGBKeyboard = builtins.any (p: p) [
    (builtins.pathExists "/sys/class/leds" &&
     builtins.any (d: lib.hasInfix "rgb" (lib.toLower d))
       (builtins.attrNames (builtins.readDir "/sys/class/leds")))
  ];

  # Detect NVIDIA GPU
  hasNvidiaGPU =
    if builtins.pathExists "/proc/bus/pci/devices" then
      builtins.any (line: lib.hasInfix "NVIDIA" line || lib.hasInfix "nvidia" line)
        (lib.splitString "\n" (builtins.readFile "/proc/bus/pci/devices"))
    else false;

  # Detect AMD GPU
  hasAMDGPU =
    if builtins.pathExists "/proc/bus/pci/devices" then
      builtins.any (line: lib.hasInfix "amdgpu" (lib.toLower line))
        (lib.splitString "\n" (builtins.readFile "/proc/bus/pci/devices"))
    else false;

  # Detect Intel integrated graphics
  hasIntelGPU =
    if builtins.pathExists "/proc/bus/pci/devices" then
      builtins.any (line: lib.hasInfix "Intel" line)
        (lib.splitString "\n" (builtins.readFile "/proc/bus/pci/devices"))
    else false;

  # Detect if system is headless (no GPU)
  isHeadless = !(hasNvidiaGPU || hasAMDGPU || hasIntelGPU);

  # Detect Bluetooth
  hasBluetooth = builtins.pathExists "/sys/class/bluetooth";

  # Detect WiFi
  hasWifi = builtins.pathExists "/sys/class/net" &&
            builtins.any (iface:
              builtins.pathExists "/sys/class/net/${iface}/wireless"
            ) (builtins.attrNames (builtins.readDir "/sys/class/net"));

  # Detect webcam
  hasWebcam = builtins.pathExists "/dev/video0";

  # Detect audio devices
  hasAudio = builtins.pathExists "/dev/snd";

in {
  options.hypervisor.platform = {
    enableAutoDetection = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable automatic platform-specific hardware detection.
        Configures touchpads, backlights, keyboards, monitors, etc.
      '';
    };

    forceType = mkOption {
      type = types.nullOr (types.enum [ "laptop" "desktop" "server" "sbc" ]);
      default = null;
      description = ''
        Force platform type instead of auto-detection.
        Useful for edge cases where detection fails.
      '';
    };
  };

  config = mkIf cfg.enableAutoDetection {
    # Determine platform type
    hypervisor.hardware.laptop.enable = mkDefault (cfg.forceType == "laptop" || (isLaptop && cfg.forceType == null));
    hypervisor.hardware.desktop.enable = mkDefault (cfg.forceType == "desktop" || (!isLaptop && !isHeadless && cfg.forceType == null));
    hypervisor.hardware.server.enable = mkDefault (cfg.forceType == "server" || (isHeadless && cfg.forceType == null));

    # Laptop-specific services
    services.libinput = mkIf (isLaptop && hasTouchpad) {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        accelProfile = "adaptive";
        disableWhileTyping = true;
        middleEmulation = true;
        scrollMethod = "twofinger";
      };
    };

    services.illum.enable = mkIf (isLaptop && hasBacklight) true;
    services.upower.enable = mkIf (isLaptop && hasBattery) true;
    services.tlp.enable = mkIf (isLaptop && hasBattery && !config.services.auto-cpufreq.enable) (mkDefault true);

    # Desktop-specific services
    services.xserver.xrandrHeads = mkIf (!isLaptop && !isHeadless && config.services.xserver.enable) [];
    services.autorandr.enable = mkIf (!isLaptop && !isHeadless) (mkDefault config.services.xserver.enable);

    # Graphics drivers
    hardware = {
      # NVIDIA
      nvidia = mkIf hasNvidiaGPU {
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        modesetting.enable = true;
        powerManagement.enable = isLaptop;  # Power management for laptops
        open = false;  # Use proprietary driver for better compatibility
      };

      # Graphics (OpenGL/Vulkan support) - NixOS 25.05 uses hardware.opengl
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
        extraPackages = with pkgs;
          (optionals hasIntelGPU [
            intel-media-driver
            vaapiIntel
            vaapiVdpau
            libvdpau-va-gl
          ])
          ++
          (optionals hasAMDGPU [
            rocm-opencl-icd
            rocm-opencl-runtime
          ]);
      };

      # Bluetooth
      bluetooth = mkIf hasBluetooth {
        enable = true;
        powerOnBoot = !isLaptop;  # Don't auto-enable on laptops to save power
      };

      # PulseAudio/PipeWire for audio
      pulseaudio.enable = mkDefault (hasAudio && !config.services.pipewire.enable);
    };

    # Networking
    networking.wireless.enable = mkDefault (hasWifi && !config.networking.networkmanager.enable);
    networking.networkmanager.enable = mkDefault (hasWifi || !isHeadless);
    networking.networkmanager.wifi.powersave = mkIf isLaptop true;

    # Webcam support
    boot.kernelModules = mkIf hasWebcam [ "uvcvideo" ];

    # Platform detection logging
    system.activationScripts.platformDetection = ''
      LOG_FILE="/var/log/hypervisor/platform-detection.log"
      mkdir -p "$(dirname "$LOG_FILE")"

      {
        echo "=== Platform Hardware Detection ==="
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Platform Type: ${if isLaptop then "Laptop" else if isHeadless then "Server/Headless" else "Desktop"}"
        echo ""
        echo "Detected Hardware:"
        ${if hasTouchpad then "echo '  ✓ Touchpad'" else "echo '  ✗ Touchpad'"}
        ${if hasBacklight then "echo '  ✓ Backlight'" else "echo '  ✗ Backlight'"}
        ${if hasBattery then "echo '  ✓ Battery'" else "echo '  ✗ Battery'"}
        ${if hasBluetooth then "echo '  ✓ Bluetooth'" else "echo '  ✗ Bluetooth'"}
        ${if hasWifi then "echo '  ✓ WiFi'" else "echo '  ✗ WiFi'"}
        ${if hasWebcam then "echo '  ✓ Webcam'" else "echo '  ✗ Webcam'"}
        ${if hasAudio then "echo '  ✓ Audio'" else "echo '  ✗ Audio'"}
        echo ""
        echo "Graphics:"
        ${if hasNvidiaGPU then "echo '  ✓ NVIDIA GPU'" else ""}
        ${if hasAMDGPU then "echo '  ✓ AMD GPU'" else ""}
        ${if hasIntelGPU then "echo '  ✓ Intel GPU'" else ""}
        ${if isHeadless then "echo '  ! Headless (no GPU detected)'" else ""}
        echo ""
        echo "Auto-Enabled Modules:"
        ${if isLaptop then "echo '  → hypervisor.hardware.laptop'" else ""}
        ${if !isLaptop && !isHeadless then "echo '  → hypervisor.hardware.desktop'" else ""}
        ${if isHeadless then "echo '  → hypervisor.hardware.server'" else ""}
        echo ""
        echo "=========================================="
      } > "$LOG_FILE"

      chmod 644 "$LOG_FILE"
    '';

    # Export platform info
    environment.etc."hypervisor/platform-info.json".text = builtins.toJSON {
      platform_type = if isLaptop then "laptop" else if isHeadless then "server" else "desktop";
      touchpad = hasTouchpad;
      backlight = hasBacklight;
      battery = hasBattery;
      bluetooth = hasBluetooth;
      wifi = hasWifi;
      webcam = hasWebcam;
      audio = hasAudio;
      gpu_nvidia = hasNvidiaGPU;
      gpu_amd = hasAMDGPU;
      gpu_intel = hasIntelGPU;
      headless = isHeadless;
    };

    # Helper command
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "hv-platform-info" ''
        echo "=== Detected Platform Information ==="
        cat /etc/hypervisor/platform-info.json | ${pkgs.jq}/bin/jq .
        echo ""
        echo "=== Detection Log ==="
        cat /var/log/hypervisor/platform-detection.log 2>/dev/null || echo "Log not available yet"
      '')
    ];

    # Warnings
    warnings =
      optional (isLaptop && !hasBattery) ''
        System detected as laptop but no battery found.
        This might be a desktop or the battery is not properly connected.
      ''
      ++
      optional (hasNvidiaGPU && config.services.xserver.videoDrivers == []) ''
        NVIDIA GPU detected but no video drivers configured.
        Add "nvidia" to services.xserver.videoDrivers for optimal performance.
      '';
  };
}
