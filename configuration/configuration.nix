{ config, pkgs, lib, ... }:
let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  enableMenuAtBoot = lib.attrByPath ["hypervisor" "menu" "enableAtBoot"] true config;
  enableWelcomeAtBoot = lib.attrByPath ["hypervisor" "firstBootWelcome" "enableAtBoot"] true config;
  enableWizardAtBoot = lib.attrByPath ["hypervisor" "firstBootWizard" "enableAtBoot"] false config;
  baseSystemHasGui = config.services.xserver.enable or false;
  hasHypervisorGuiPreference = lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config;
  hypervisorGuiRequested = lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config;
  enableGuiAtBoot = if hasHypervisorGuiPreference then hypervisorGuiRequested else baseSystemHasGui;
  hasNewDM = lib.hasAttrByPath ["services" "displayManager"] config;
  hasOldDM = lib.hasAttrByPath ["services" "xserver" "displayManager"] config;
  hasNewDesk = lib.hasAttrByPath ["services" "desktopManager" "gnome"] config;
  hasOldDesk = lib.hasAttrByPath ["services" "xserver" "desktopManager" "gnome"] config;
  # Enable console autologin only when not booting to a GUI Desktop
  consoleAutoLoginEnabled = (enableMenuAtBoot || enableWizardAtBoot) && (!enableGuiAtBoot);
in {
  system.stateVersion = "24.05";
  imports = [
    ./hardware-configuration.nix ./hardware-input.nix ../scripts/vfio-boot.nix
    ./security.nix ./security-production.nix ./monitoring.nix ./backup.nix
    ./automation.nix ./alerting.nix ./web-dashboard.nix
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
  boot.kernelPackages = pkgs.linuxPackages_hardened;
  security.auditd.enable = true;
  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 0;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "kernel.kexec_load_disabled" = 1;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
  };
  environment.systemPackages = with pkgs; [
    qemu_full OVMF jq python3 python3Packages.jsonschema curl newt dialog nano
    libvirt virt-manager gnome.zenity gnome.gnome-terminal pciutils
    looking-glass-client gnupg swtpm openssh xorriso nfs-utils
  ];
  environment.etc."hypervisor/vm_profiles".source = ../vm_profiles;
  environment.etc."hypervisor/isos".source = ../isos;
  environment.etc."hypervisor/scripts".source = ../scripts;
  environment.etc."hypervisor/config.json".source = ../configuration/config.json;
  environment.etc."hypervisor/docs".source = ../docs;
  environment.etc."hypervisor/vm_profile.schema.json".source = ../configuration/vm_profile.schema.json;
  environment.etc."libvirt/hooks/qemu".source = ../scripts/libvirt_hooks/qemu;
  services.getty.autologinUser = lib.mkIf consoleAutoLoginEnabled mgmtUser;
  users.users = lib.mkIf (mgmtUser == "hypervisor") {
    hypervisor = {
      isNormalUser = true;
      extraGroups = [ "wheel" "kvm" "libvirtd" "video" "input" ];
      createHome = false;
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/isos 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/disks 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/xml 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/vm_profiles 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/gnupg 0700 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/backups 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/log/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/logs 0750 ${mgmtUser} ${mgmtUser} - -"
  ];
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
        frequency = "daily"; rotate = 7; compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip"; compressext = ".gz";
        missingok = true; notifempty = true;
      };
    };
  };
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.runAsRoot = false;
  virtualisation.libvirtd.extraConfig = ''
    security_driver = "apparmor"
    dynamic_ownership = 1
    clear_emulator_capabilities = 1
    seccomp_sandbox = 1
    namespaces = [ "mount", "uts", "ipc", "pid", "net" ]
  '';
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
  networking.firewall.enable = true;
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;
  security.sudo.extraRules = [
    {
      users = [ mgmtUser ];
      commands = [
        { command = "${pkgs.libvirt}/bin/virsh list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh start"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh shutdown"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh reboot"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh destroy"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh suspend"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh resume"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh dominfo"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh domstate"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh domuuid"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh domifaddr"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh console"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh define"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh undefine"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-create-as"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-revert"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-delete"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-info"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-dhcp-leases"; options = [ "NOPASSWD" ]; }
      ];
    }
    { users = [ mgmtUser ]; commands = [ { command = "ALL"; } ]; }
  ];
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; PermitRootLogin = "no";
      X11Forwarding = false; KbdInteractiveAuthentication = false;
    };
  };
  security.apparmor.enable = true;
  security.apparmor.policies."qemu-system-x86_64".profile = builtins.readFile ../configuration/apparmor/qemu-system-x86_64;
  boot.kernelParams = [ "apparmor=1" "security=apparmor" ];
  services.printing.enable = false;
  hardware.pulseaudio.enable = false;
  sound.enable = false;
  hardware.opengl.enable = true;
  services.xserver.enable = lib.mkDefault (baseSystemHasGui || enableGuiAtBoot);
  services.xserver.displayManager.gdm.enable = lib.mkDefault (enableGuiAtBoot && hasOldDM);
  services.xserver.displayManager.gdm.wayland = lib.mkDefault (enableGuiAtBoot && hasOldDM);
  services.xserver.displayManager.autoLogin = lib.mkIf (enableGuiAtBoot && hasOldDM) {
    enable = lib.mkDefault true; user = mgmtUser;
  };
  services.xserver.desktopManager.gnome.enable = lib.mkDefault (enableGuiAtBoot && hasOldDesk);
  programs.xwayland.enable = lib.mkDefault enableGuiAtBoot;
  environment.etc."xdg/autostart/hypervisor-dashboard.desktop" = lib.mkIf enableGuiAtBoot {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Dashboard
      Exec=/etc/hypervisor/scripts/management_dashboard.sh --autostart
      X-GNOME-Autostart-enabled=true
    '';
  };
  environment.etc."xdg/applications/hypervisor-menu.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Hypervisor Console Menu
    Comment=Main hypervisor management menu
    Exec=gnome-terminal -- /etc/hypervisor/scripts/menu.sh
    Icon=utilities-terminal
    Terminal=false
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
    Exec=gnome-terminal -- /etc/hypervisor/scripts/setup_wizard.sh
    Icon=system-software-install
    Terminal=false
    Categories=System;Settings;
  '';
  environment.etc."xdg/applications/hypervisor-networking.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Network Foundation Setup
    Comment=Configure foundational networking (bridges, interfaces)
    Exec=gnome-terminal -- sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
    Icon=network-wired
    Terminal=false
    Categories=System;Settings;Network;
  '';
  environment.etc."skel/Desktop/Hypervisor-Menu.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Console Menu
      Comment=Main hypervisor management menu
      Exec=gnome-terminal -- /etc/hypervisor/scripts/menu.sh
      Icon=utilities-terminal
      Terminal=false
      Categories=System;Utility;
    '';
    mode = "0755";
  };
}
