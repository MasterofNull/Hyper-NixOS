{ config, lib, pkgs, ... }:

{
  # Comprehensive touchpad and keyboard support for hypervisor management
  # This module provides multitouch, gestures, backlighting, and hotkey support
  # Works with Wayland/Sway (NO X11)

  # Touchpad support with libinput (modern, multitouch-aware driver)
  # Only enable when Sway is enabled (GUI mode)
  services.libinput = lib.mkIf config.programs.sway.enable {
    enable = true;
    
    # Touchpad-specific settings
    touchpad = {
      # Enable tap-to-click
      tapping = true;
      
      # Enable two-finger tap for right-click
      tappingButtonMap = "lrm";
      
      # Natural scrolling (reversed direction, like macOS/mobile)
      naturalScrolling = false;  # set to true for natural scrolling
      
      # Enable horizontal and vertical scrolling
      scrollMethod = "twofinger";
      
      # Disable touchpad while typing to prevent accidental touches
      disableWhileTyping = true;
      
      # Click method (areas = traditional button areas, clickfinger = tap anywhere)
      clickMethod = "clickfinger";
      
      # Acceleration profile (adaptive = default, flat = no acceleration)
      accelProfile = "adaptive";
      
      # Pointer speed adjustment (-1.0 to 1.0, 0 is default)
      accelSpeed = "0";
      
      # Middle button emulation (click both buttons simultaneously)
      middleEmulation = true;
      
      # Drag lock (continue dragging after lifting finger briefly)
      # dragLock = false;
    };
    
    # Mouse settings
    mouse = {
      accelProfile = "adaptive";
      accelSpeed = "0";
      middleEmulation = true;
      naturalScrolling = false;
    };
  };

  # Keyboard configuration for Wayland
  services.xkb = lib.mkIf config.programs.sway.enable {
    layout = lib.mkDefault "us";
    variant = lib.mkDefault "";
  };

  # Console keyboard configuration
  # Only use XKB settings in console when Sway is enabled
  console.useXkbConfig = lib.mkIf config.programs.sway.enable true;

  # ACPI events handling (lid, power button, keyboard hotkeys)
  services.acpid = {
    enable = true;
    
    # Custom ACPI event handlers
    handlers = {
      # Brightness keys support
      brightnessDown = {
        event = "video/brightnessdown.*";
        action = ''
          ${pkgs.brightnessctl}/bin/brightnessctl set 5%-
        '';
      };
      
      brightnessUp = {
        event = "video/brightnessup.*";
        action = ''
          ${pkgs.brightnessctl}/bin/brightnessctl set +5%
        '';
      };
      
      # Keyboard backlight keys
      kbdBacklightDown = {
        event = "video/kbd_backlight_down.*";
        action = ''
          ${pkgs.brightnessctl}/bin/brightnessctl --device='*::kbd_backlight' set 5%-
        '';
      };
      
      kbdBacklightUp = {
        event = "video/kbd_backlight_up.*";
        action = ''
          ${pkgs.brightnessctl}/bin/brightnessctl --device='*::kbd_backlight' set +5%
        '';
      };
      
      kbdBacklightToggle = {
        event = "video/kbd_backlight_toggle.*";
        action = ''
          current=$(${pkgs.brightnessctl}/bin/brightnessctl --device='*::kbd_backlight' get)
          if [ "$current" -eq 0 ]; then
            ${pkgs.brightnessctl}/bin/brightnessctl --device='*::kbd_backlight' set 100%
          else
            ${pkgs.brightnessctl}/bin/brightnessctl --device='*::kbd_backlight' set 0
          fi
        '';
      };
    };
  };

  # Install essential input device tools
  environment.systemPackages = with pkgs; [
    # Brightness control utility (works with screen and keyboard backlight)
    brightnessctl
    
    # Input device configuration and debugging tools
    libinput
    evtest            # Event device testing
    
    # ACPI event monitoring and debugging
    acpi
    acpid
    
    # Wayland-specific tools
    wl-clipboard      # Wayland clipboard utilities
    wtype             # Simulate keyboard/mouse events (Wayland equivalent of xdotool)
    ydotool           # Universal input automation (works with Wayland)
    
    # Multitouch gesture support for Wayland
    libinput-gestures
  ];

  # Udev rules for input devices (ensure proper permissions)
  services.udev.extraRules = ''
    # Allow users in 'input' group to access input devices
    KERNEL=="event*", SUBSYSTEM=="input", GROUP="input", MODE="0660"
    
    # Allow users in 'video' group to control backlight
    SUBSYSTEM=="backlight", ACTION=="add", \
      RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", \
      RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    
    SUBSYSTEM=="leds", ACTION=="add", KERNEL=="*::kbd_backlight", \
      RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness", \
      RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
  '';

  # Ensure input group exists for device access
  users.groups.input = {};

  # XDG autostart for libinput-gestures (Wayland/Sway with touchpad gestures)
  environment.etc."xdg/autostart/libinput-gestures.desktop" = lib.mkIf config.programs.sway.enable {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Libinput Gestures
      Comment=Multitouch gesture recognizer
      Exec=${pkgs.libinput-gestures}/bin/libinput-gestures
      NoDisplay=true
    '';
  };

  # Default libinput-gestures configuration (user can override in ~/.config)
  environment.etc."libinput-gestures.conf" = lib.mkIf config.programs.sway.enable {
    text = ''
      # Multitouch gestures configuration for Sway/Wayland
      # Swipe gestures for workspace navigation
      gesture swipe up 3 swaymsg workspace prev
      gesture swipe down 3 swaymsg workspace next
      gesture swipe left 4 swaymsg workspace next
      gesture swipe right 4 swaymsg workspace prev
      
      # Pinch gestures (using wtype for Wayland)
      gesture pinch in 2 wtype -M ctrl -P minus -m ctrl
      gesture pinch out 2 wtype -M ctrl -P equal -m ctrl
      
      # Configuration
      device all
    '';
  };

  # Wayland input configuration (Sway handles keyboard repeat rate in its config)
}
