{ config, pkgs, lib, ... }:
let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  enableMenuAtBoot = lib.attrByPath ["hypervisor" "menu" "enableAtBoot"] true config;
  enableWelcomeAtBoot = lib.attrByPath ["hypervisor" "firstBootWelcome" "enableAtBoot"] true config;
  enableWizardAtBoot = lib.attrByPath ["hypervisor" "firstBootWizard" "enableAtBoot"] false config;
  # Boot Architecture: Headless console menu by default, GUI only on explicit request
  # This hypervisor is designed to boot to a TUI menu for VM management (minimal resources).
  # GUI desktop environment is opt-in via hypervisor.gui.enableAtBoot = true
  # 
  # IMPORTANT: Do NOT read config.services.xserver.enable here - it creates circular dependency
  # and violates the "headless by default" architecture by trying to preserve previous GUI state.
  hasHypervisorGuiPreference = lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config;
  hypervisorGuiRequested = lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config;
  enableGuiAtBoot = if hasHypervisorGuiPreference then hypervisorGuiRequested else false;
  hasNewDM = lib.hasAttrByPath ["services" "displayManager"] config;
  hasOldDM = lib.hasAttrByPath ["services" "xserver" "displayManager"] config;
  # Enable console autologin only when not booting to a GUI Desktop
  consoleAutoLoginEnabled = (enableMenuAtBoot || enableWizardAtBoot) && (!enableGuiAtBoot);
in {
  system.stateVersion = "24.05";
  imports = [
    ./hardware-configuration.nix ./hardware-input.nix ../scripts/vfio-boot.nix
    ./security.nix ./security-production.nix ./security-profiles.nix
    ./monitoring.nix ./backup.nix ./automation.nix ./alerting.nix ./web-dashboard.nix
  ] ++ lib.optional (builtins.pathExists ./enterprise-features.nix) ./enterprise-features.nix
    ++ lib.optional (builtins.pathExists ./performance.nix) ./performance.nix
    ++ lib.optional (builtins.pathExists ./cache-optimization.nix) ./cache-optimization.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/performance.nix) /var/lib/hypervisor/configuration/performance.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/perf-local.nix) /var/lib/hypervisor/configuration/perf-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/security-local.nix) /var/lib/hypervisor/configuration/security-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/security-strict.nix) /var/lib/hypervisor/configuration/security-strict.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/users-local.nix) /var/lib/hypervisor/configuration/users-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/system-local.nix) /var/lib/hypervisor/configuration/system-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/management-local.nix) /var/lib/hypervisor/configuration/management-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/swap-local.nix) /var/lib/hypervisor/configuration/swap-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/gui-local.nix) /var/lib/hypervisor/configuration/gui-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/cache-optimization.nix) /var/lib/hypervisor/configuration/cache-optimization.nix;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = lib.mkDefault "hypervisor";
  time.timeZone = lib.mkDefault "UTC";
  # Prefer latest stable kernel; allow override to hardened
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  # Security-conscious users can set boot.kernelPackages = pkgs.linuxPackages_hardened; in local overlays
  # Note: Security hardening (auditd, sysctl) is configured in security-production.nix
  environment.systemPackages = with pkgs; [
    qemu_full OVMF jq python3 python3Packages.jsonschema curl newt dialog nano
    libvirt virt-manager pciutils ripgrep yad
    looking-glass-client gnupg swtpm openssh xorriso nfs-utils
  ];
  environment.etc."hypervisor/vm_profiles".source = ../vm_profiles;
  environment.etc."hypervisor/isos".source = ../isos;
  environment.etc."hypervisor/scripts".source = ../scripts;
  environment.etc."hypervisor/config.json".source = ../configuration/config.json;
  environment.etc."hypervisor/docs".source = ../docs;
  environment.etc."hypervisor/vm_profile.schema.json".source = ../configuration/vm_profile.schema.json;
  environment.etc."libvirt/hooks/qemu".source = ../scripts/libvirt_hooks/qemu;
  # Note: User management, autologin, sudo rules, and directory ownership
  # are configured in security-profiles.nix based on active profile
  services.logrotate = {
    enable = true;
    settings = {
      "/var/lib/hypervisor/logs/*.log" = {
        frequency = "daily"; rotate = 7; compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip"; compressext = ".gz";
        missingok = true; notifempty = true; sharedscripts = true;
        postrotate = "systemctl reload hypervisor-menu.service 2>/dev/null || true";
      };
      "/var/log/hypervisor/*.log" = {
        frequency = "daily"; rotate = lib.mkDefault 7; compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip"; compressext = ".gz";
        missingok = true; notifempty = true;
      };
    };
  };
  # Note: libvirtd security configuration is in security-production.nix
  virtualisation.libvirtd.enable = true;
  systemd.services.hypervisor-menu = {
    description = "Boot-time Hypervisor VM Menu";
    wantedBy = lib.optional (enableMenuAtBoot && !enableGuiAtBoot) "multi-user.target";
    after = [ "network-online.target" "libvirtd.service" ];
    wants = [ "network-online.target" "libvirtd.service" ];
    # Avoid racing the Display Manager for VT1
    conflicts = [ "getty@tty1.service" "display-manager.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/menu.sh";
      WorkingDirectory = "/etc/hypervisor";
      User = "${mgmtUser}";
      SupplementaryGroups = [ "kvm" "libvirtd" "video" ];
      Restart = "always"; RestartSec = 2;
      StateDirectory = "hypervisor"; LogsDirectory = "";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor/logs"
        "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/logs/menu.log"
      ];
      StandardInput = "tty"; StandardOutput = "tty";
      TTYPath = "/dev/tty1"; TTYReset = true; TTYVHangup = true;
      Environment = [
        "SDL_VIDEODRIVER=kmsdrm" "SDL_AUDIODRIVER=alsa" "DIALOG=whiptail"
        "TERM=linux" "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      ];
      NoNewPrivileges = true; PrivateTmp = true; ProtectSystem = "strict";
      ProtectHome = true; PrivateDevices = false;
      DeviceAllow = [ "/dev/kvm rw" "/dev/dri/* rw" ];
      LockPersonality = true; MemoryDenyWriteExecute = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      SystemCallFilter = [ "@system-service" "@pkey" "@chown" ];
      ProtectKernelTunables = true; ProtectKernelModules = true;
      ProtectControlGroups = true; RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = ""; AmbientCapabilities = "";
    };
  };
  systemd.services.hypervisor-first-boot-welcome = {
    description = "First-boot Welcome Screen";
    wantedBy = lib.optional enableWelcomeAtBoot "multi-user.target";
    after = [ "network-online.target" "systemd-tmpfiles-setup.service" ];
    before = [ "hypervisor-menu.service" ];
    wants = [ "network-online.target" ];
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/first_boot_welcome.sh";
      User = "root"; WorkingDirectory = "/etc/hypervisor";
      NoNewPrivileges = true; PrivateTmp = true; ProtectSystem = "strict"; ProtectHome = true;
      StateDirectory = "hypervisor";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor/logs"
        "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/logs/first_boot.log"
      ];
      ReadWritePaths = [ "/var/lib/hypervisor/logs" "/var/lib/hypervisor/.first_boot_welcome_shown" ];
      StandardInput = "tty"; StandardOutput = "tty";
      TTYPath = "/dev/tty1"; TTYReset = true; TTYVHangup = true;
      Environment = [ "DIALOG=whiptail" "TERM=linux" "HOME=/root" "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin" ];
    };
    unitConfig.ConditionPathExists = "!/var/lib/hypervisor/.first_boot_welcome_shown";
  };
  systemd.services.hypervisor-first-boot = {
    description = "First-boot Setup Wizard (Disabled)";
    wantedBy = lib.optional enableWizardAtBoot "multi-user.target";
    after = [ "network-online.target" "systemd-tmpfiles-setup.service" ];
    before = [ "hypervisor-menu.service" ];
    wants = [ "network-online.target" ];
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'if [ ! -f /var/lib/hypervisor/.first_boot_done ]; then ${pkgs.bash}/bin/bash /etc/hypervisor/scripts/setup_wizard.sh || true; ${pkgs.coreutils}/bin/touch /var/lib/hypervisor/.first_boot_done; fi'";
      User = "root"; WorkingDirectory = "/etc/hypervisor";
      NoNewPrivileges = true; PrivateTmp = true; ProtectSystem = "strict"; ProtectHome = true;
      StateDirectory = "hypervisor"; LogsDirectory = "";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor/logs"
        "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/logs/first_boot.log"
        "${pkgs.coreutils}/bin/mkdir -p /etc/hypervisor/src/configuration"
      ];
      ReadWritePaths = [ "/etc/hypervisor/src/configuration" "/var/lib/hypervisor/logs" ];
      StandardInput = "tty"; StandardOutput = "tty";
      TTYPath = "/dev/tty1"; TTYReset = true; TTYVHangup = true;
      Environment = [ "DIALOG=whiptail" "TERM=linux" "HOME=/root" "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin" ];
    };
    unitConfig.ConditionPathExists = "!/var/lib/hypervisor/.first_boot_done";
  };
  # Note: Firewall, SSH, and sudo configuration are in security-production.nix
  security.sudo.enable = true;
  security.apparmor.enable = true;
  security.apparmor.policies."qemu-system-x86_64".profile = builtins.readFile ../configuration/apparmor/qemu-system-x86_64;
  boot.kernelParams = [ "apparmor=1" "security=apparmor" ];
  services.printing.enable = false;
  hardware.pulseaudio.enable = false;
  sound.enable = false;
  hardware.opengl.enable = true;
  services.xserver.enable = lib.mkDefault enableGuiAtBoot;
  # Do not force any specific display manager; respect the system's previous generation
  services.xserver.displayManager.autoLogin = lib.mkIf (enableGuiAtBoot && hasOldDM) {
    enable = lib.mkDefault true; user = mgmtUser;
  };
  # Wayland-first: enable Xwayland only if GUI is enabled for compatibility
  programs.xwayland.enable = lib.mkDefault enableGuiAtBoot;
  environment.etc."xdg/autostart/hypervisor-dashboard.desktop" = lib.mkIf enableGuiAtBoot {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Dashboard
      Exec=/etc/hypervisor/scripts/management_dashboard.sh --autostart
    '';
  };
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
