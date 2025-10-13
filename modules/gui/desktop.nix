{ config, lib, pkgs, ... }:

# Desktop Environment Configuration
# Pure Wayland/Sway GUI (NO X11 - security risk)

let
  # Access config values safely within the config section
  mgmtUser = config.hypervisor.management.userName;
  enableGuiAtBoot = config.hypervisor.gui.enableAtBoot or false;
in {
  # Sway window manager (pure Wayland, no X11)
  programs.sway = lib.mkIf enableGuiAtBoot {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      wl-clipboard
      mako # notification daemon
      alacritty # terminal
      wofi # launcher
      waybar # status bar
    ];
  };
  
  # greetd display manager for Wayland autologin
  services.greetd = lib.mkIf enableGuiAtBoot {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
      initial_session = {
        command = "sway";
        user = mgmtUser;
      };
    };
  };
  
  # XWayland: DISABLED - this is a locked-down Wayland-only system
  # Never enable X11/XWayland on production hypervisors (security risk)
  programs.xwayland.enable = lib.mkForce false;
  
  # XDG Desktop entries for hypervisor tools
  environment.etc."xdg/applications/hypervisor-menu.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Hypervisor Console Menu
    Comment=Main hypervisor management menu
    Exec=/etc/hypervisor/scripts/menu.sh
    Icon=utilities-terminal
    Terminal=true
    Categories=System;Utility;
  '';
  
  environment.etc."xdg/applications/hypervisor-dashboard.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Hypervisor Dashboard
    Comment=GUI dashboard for VM and task management
    Exec=/etc/hypervisor/scripts/management_dashboard.sh
    Icon=computer
    Categories=System;Utility;
  '';
  
  environment.etc."xdg/applications/hypervisor-installer.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Hypervisor Setup Wizard
    Comment=Run first-boot setup and configuration wizard
    Exec=/etc/hypervisor/scripts/setup_wizard.sh
    Icon=system-software-install
    Terminal=true
    Categories=System;Settings;
  '';
  
  environment.etc."xdg/applications/hypervisor-networking.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Network Foundation Setup
    Comment=Configure foundational networking (bridges, interfaces)
    Exec=sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
    Icon=network-wired
    Terminal=true
    Categories=System;Settings;Network;
  '';
  
  # Auto-start dashboard when GUI boots
  environment.etc."xdg/autostart/hypervisor-dashboard.desktop" = lib.mkIf enableGuiAtBoot {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Dashboard
      Exec=/etc/hypervisor/scripts/management_dashboard.sh --autostart
    '';
  };
  
  # Desktop shortcut
  environment.etc."skel/Desktop/Hypervisor-Menu.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Console Menu
      Comment=Main hypervisor management menu
      Exec=/etc/hypervisor/scripts/menu.sh
      Icon=utilities-terminal
      Terminal=true
      Categories=System;Utility;
    '';
    mode = "0755";
  };
}
