{ config, lib, pkgs, ... }:

# Admin User GUI Integration
# Ensures host GUI configuration uses admin/management user's environment settings

let
  cfg = config.hypervisor.gui;
  adminUser = config.hypervisor.management.userName;
in
{
  config = lib.mkIf cfg.enableAtBoot {
    
    # Ensure admin user has all GUI-related groups
    users.users.${adminUser} = {
      # Add GUI-specific groups
      extraGroups = lib.mkAfter [ 
        "video"      # Video device access
        "audio"      # Audio device access
        "input"      # Input device access (touchpad, keyboard)
        "render"     # GPU rendering
        "seat"       # Session management
      ];
    };
    
    # Create admin user's GUI configuration directories
    systemd.tmpfiles.rules = [
      "d /home/${adminUser}/.config 0700 ${adminUser} users - -"
      "d /home/${adminUser}/.config/sway 0700 ${adminUser} users - -"
      "d /home/${adminUser}/.local 0700 ${adminUser} users - -"
      "d /home/${adminUser}/.local/share 0700 ${adminUser} users - -"
      "d /home/${adminUser}/.local/share/applications 0700 ${adminUser} users - -"
    ];
    
    # Link system Sway config to admin user's config
    environment.etc."sway/config.d/hypervisor.conf".text = ''
      # Hypervisor-specific Sway configuration
      # This configuration is loaded for all users, but customized for admin
      
      # Autostart hypervisor dashboard for admin user
      exec if [ "$(whoami)" = "${adminUser}" ]; then \
        /etc/hypervisor/scripts/management_dashboard.sh --autostart; \
      fi
      
      # Keybindings for hypervisor management
      bindsym $mod+h exec alacritty -e /etc/hypervisor/scripts/menu.sh
      bindsym $mod+Shift+h exec alacritty -e sudo /etc/hypervisor/scripts/menu.sh
      
      # VM management shortcuts
      bindsym $mod+v exec virt-manager
      
      # Screenshots
      bindsym Print exec grim -g "$(slurp)" - | wl-copy
      bindsym Shift+Print exec grim - | wl-copy
      
      # Lock screen
      bindsym $mod+l exec swaylock -f -c 000000
    '';
    
    # Create user-specific Sway config template
    environment.etc."skel/.config/sway/config".text = ''
      # User-specific Sway configuration
      # This file is sourced after system configuration
      
      # Include system-wide hypervisor configuration
      include /etc/sway/config.d/*.conf
      
      # User customizations below this line
      # Add your personal keybindings and settings here
    '';
    
    # Ensure admin user's Sway config exists and is owned correctly
    system.activationScripts.admin-gui-config = lib.stringAfter [ "users" ] ''
      # Create admin user Sway config if it doesn't exist
      if [ ! -f /home/${adminUser}/.config/sway/config ]; then
        mkdir -p /home/${adminUser}/.config/sway
        cp /etc/skel/.config/sway/config /home/${adminUser}/.config/sway/config
        chown -R ${adminUser}:users /home/${adminUser}/.config/sway
        chmod 700 /home/${adminUser}/.config/sway
        chmod 600 /home/${adminUser}/.config/sway/config
      fi
      
      # Ensure libinput-gestures config for admin
      if [ ! -f /home/${adminUser}/.config/libinput-gestures.conf ]; then
        mkdir -p /home/${adminUser}/.config
        ln -sf /etc/libinput-gestures.conf /home/${adminUser}/.config/libinput-gestures.conf
        chown -h ${adminUser}:users /home/${adminUser}/.config/libinput-gestures.conf
      fi
      
      # Create desktop shortcuts for admin user
      mkdir -p /home/${adminUser}/Desktop
      chown ${adminUser}:users /home/${adminUser}/Desktop
      
      # Link desktop entries
      for desktop in /etc/xdg/applications/hypervisor-*.desktop; do
        if [ -f "$desktop" ]; then
          basename=$(basename "$desktop")
          ln -sf "$desktop" "/home/${adminUser}/Desktop/$basename"
          chown -h ${adminUser}:users "/home/${adminUser}/Desktop/$basename"
        fi
      done
    '';
    
    # Audio configuration for admin user
    # Link PipeWire/PulseAudio to admin user's session
    services.pipewire = lib.mkIf (config.services ? pipewire) {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
      jack.enable = lib.mkDefault false;
      
      # Ensure proper permissions for admin user
      extraConfig.pipewire."92-low-latency" = {
        context.properties = {
          default.clock.rate = 48000;
          default.clock.quantum = 1024;
          default.clock.min-quantum = 512;
          default.clock.max-quantum = 2048;
        };
      };
    };
    
    # Security: Allow admin user to manage audio
    security.rtkit.enable = lib.mkIf (config.security ? rtkit) (lib.mkDefault true);
    
    # Wayland environment variables for admin session
    environment.sessionVariables = {
      # Ensure Wayland is used
      XDG_SESSION_TYPE = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      
      # Admin-specific paths
      XDG_CONFIG_HOME = lib.mkDefault "/home/${adminUser}/.config";
      XDG_DATA_HOME = lib.mkDefault "/home/${adminUser}/.local/share";
      XDG_CACHE_HOME = lib.mkDefault "/home/${adminUser}/.cache";
    };
    
    # Polkit rules for admin user GUI operations
    security.polkit.extraConfig = ''
      // Allow admin user to manage system settings via GUI
      polkit.addRule(function(action, subject) {
        if (subject.user === "${adminUser}") {
          // Allow power management (reboot, shutdown)
          if (action.id === "org.freedesktop.login1.reboot" ||
              action.id === "org.freedesktop.login1.power-off" ||
              action.id === "org.freedesktop.login1.suspend" ||
              action.id === "org.freedesktop.login1.hibernate") {
            return polkit.Result.YES;
          }
          
          // Allow network management
          if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0) {
            return polkit.Result.YES;
          }
          
          // Allow VM management without password
          if (action.id === "org.libvirt.unix.manage" ||
              action.id === "org.libvirt.unix.monitor") {
            return polkit.Result.YES;
          }
          
          // Allow backlight control
          if (action.id === "org.freedesktop.login1.set-brightness") {
            return polkit.Result.YES;
          }
        }
      });
    '';
    
    # GTK and Qt theme configuration for admin user
    programs.dconf.enable = lib.mkDefault true;
    
    # Ensure XDG user directories are set up for admin
    environment.etc."xdg/user-dirs.defaults".text = ''
      DESKTOP=Desktop
      DOWNLOAD=Downloads
      TEMPLATES=Templates
      PUBLICSHARE=Public
      DOCUMENTS=Documents
      MUSIC=Music
      PICTURES=Pictures
      VIDEOS=Videos
    '';
    
    # Create default application associations for admin user
    environment.etc."xdg/mimeapps.list".text = ''
      [Default Applications]
      text/html=firefox.desktop
      x-scheme-handler/http=firefox.desktop
      x-scheme-handler/https=firefox.desktop
      inode/directory=thunar.desktop
      text/plain=nvim.desktop
    '';
    
    # Notification daemon configuration
    services.dbus.packages = lib.mkIf (config.services ? dbus) [ pkgs.mako ];
    
    # systemd user services for admin GUI session
    systemd.user.services.hypervisor-dashboard = lib.mkIf cfg.enableAtBoot {
      description = "Hypervisor Management Dashboard";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "/etc/hypervisor/scripts/management_dashboard.sh --autostart";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    
  };
}
