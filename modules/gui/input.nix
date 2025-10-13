{ config, lib, pkgs, ... }:

{
  # Comprehensive touchpad and keyboard support for hypervisor management
  # This module provides multitouch, gestures, backlighting, and hotkey support
  # ONLY enabled when X server is enabled (GUI mode)

  # Touchpad support with libinput (modern, multitouch-aware driver)
  # Only enable when xserver is enabled to avoid forcing GUI mode
  services.xserver.libinput = lib.mkIf config.services.xserver.enable {
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

  # Keyboard configuration (only when X server is enabled)
  services.xserver.xkb = lib.mkIf config.services.xserver.enable {
    layout = lib.mkDefault "us";
    variant = lib.mkDefault "";
    options = lib.mkDefault "terminate:ctrl_alt_bksp";  # Ctrl+Alt+Backspace to restart X

    # Enable support for additional keyboard layouts and variants
    # Users can switch layouts with: setxkbmap <layout>
    extraLayouts = {};
  };

  # Console keyboard configuration
  # Only use X keyboard settings in console when X server is enabled
  console.useXkbConfig = lib.mkIf config.services.xserver.enable true;

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
    xorg.xinput
    
    # Keyboard layout switching and configuration
    xorg.xkbcomp
    xorg.setxkbmap
    
    # ACPI event monitoring and debugging
    acpi
    acpid
    
    # Additional useful tools
    xdotool           # Simulate keyboard/mouse events
    wmctrl            # Window management from command line
    evtest            # Event device testing
    
    # Multitouch gesture support (optional, for GNOME/Wayland)
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

  # XDG autostart for libinput-gestures (if using GNOME with touchpad gestures)
  environment.etc."xdg/autostart/libinput-gestures.desktop" = lib.mkIf config.services.xserver.enable {
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
  environment.etc."libinput-gestures.conf" = lib.mkIf config.services.xserver.enable {
    text = ''
      # Multitouch gestures configuration
      # Swipe gestures
      gesture swipe up 3 _internal ws_up
      gesture swipe down 3 _internal ws_down
      gesture swipe left 3 xdotool key alt+Right
      gesture swipe right 3 xdotool key alt+Left
      gesture swipe left 4 xdotool key ctrl+alt+Right
      gesture swipe right 4 xdotool key ctrl+alt+Left
      
      # Pinch gestures
      gesture pinch in 2 xdotool key ctrl+minus
      gesture pinch out 2 xdotool key ctrl+plus
      
      # Configuration
      device all
    '';
  };

  # extraLayouts moved into the xkb block above to avoid duplicate attribute definitions

  # Enable NumLock on boot (console and X11)
  # Uncomment if desired:
  # services.xserver.displayManager.sessionCommands = ''
  #   ${pkgs.numlockx}/bin/numlockx on
  # '';
  
  # System-wide keyboard rate and delay
  # services.xserver.autoRepeatDelay = 250;
  # services.xserver.autoRepeatInterval = 30;
}
