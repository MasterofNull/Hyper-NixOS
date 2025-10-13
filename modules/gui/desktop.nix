{ config, lib, pkgs, ... }:

# Desktop Environment Configuration
# GUI and display manager settings

let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  enableGuiAtBoot = 
    if lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config 
    then lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config 
    else false;
  hasOldDM = lib.hasAttrByPath ["services" "xserver" "displayManager"] config;
in {
  # X Server configuration (only when GUI enabled)
  services.xserver.enable = lib.mkDefault enableGuiAtBoot;
  
  # Auto-login configuration
  services.xserver.displayManager.autoLogin = lib.mkIf (enableGuiAtBoot && hasOldDM) {
    enable = lib.mkDefault true;
    user = mgmtUser;
  };
  
  # Wayland-first: enable Xwayland only if GUI is enabled for compatibility
  programs.xwayland.enable = lib.mkDefault enableGuiAtBoot;
  
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
