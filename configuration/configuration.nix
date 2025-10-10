{ config, pkgs, lib, ... }:

let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  enableMenuAtBoot = lib.attrByPath ["hypervisor" "menu" "enableAtBoot"] false config;
  enableWizardAtBoot = lib.attrByPath ["hypervisor" "firstBootWizard" "enableAtBoot"] false config;
  enableGuiAtBoot = lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] true config;
in {
  system.stateVersion = "24.05"; # set at initial install; do not change blindly
  imports = [
    ./hardware-configuration.nix
    ../scripts/vfio-boot.nix
    ./security.nix
  ]
  ++ lib.optional (builtins.pathExists ./performance.nix) ./performance.nix
  # Load local, host-specific overrides from /var/lib to avoid mutating the flake input
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/performance.nix) /var/lib/hypervisor/configuration/performance.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/perf-local.nix) /var/lib/hypervisor/configuration/perf-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/security-local.nix) /var/lib/hypervisor/configuration/security-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/users-local.nix) /var/lib/hypervisor/configuration/users-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/system-local.nix) /var/lib/hypervisor/configuration/system-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/management-local.nix) /var/lib/hypervisor/configuration/management-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/swap-local.nix) /var/lib/hypervisor/configuration/swap-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/gui-local.nix) /var/lib/hypervisor/configuration/gui-local.nix;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use mkDefault so host-imported settings from system-local.nix win
  networking.hostName = lib.mkDefault "hypervisor";
  time.timeZone = lib.mkDefault "UTC";

  # Hardened kernel and auditing
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

  # Minimal packages
  environment.systemPackages = with pkgs; [
    qemu_full
    OVMF
    jq
    python3
    python3Packages.jsonschema
    curl
    newt  # provides `whiptail`
    dialog
    nano
    libvirt
    virt-manager
    gnome.zenity
    gnome.gnome-terminal
    pciutils
    looking-glass-client
    gnupg
    swtpm
    openssh
    xorriso
    nfs-utils
    openssh
  ];

  # Provide menu and profiles from this repository at runtime
  # Python TUI not exposed; primary UI is shell menu for reduced surface
  environment.etc."hypervisor/vm_profiles".source = ../vm_profiles;
  environment.etc."hypervisor/isos".source = ../isos;
  environment.etc."hypervisor/scripts".source = ../scripts;
  environment.etc."hypervisor/config.json".source = ../configuration/config.json;
  environment.etc."hypervisor/docs".source = ../docs;
  environment.etc."hypervisor/vm_profile.schema.json".source = ../configuration/vm_profile.schema.json;
  # Install libvirt hook for per-VM slice limits
  environment.etc."libvirt/hooks/qemu".source = ../scripts/libvirt_hooks/qemu;

  # Create a default 'hypervisor' user only when used as the management user
  users.users = lib.mkIf (mgmtUser == "hypervisor") {
    hypervisor = {
      isNormalUser = true;
      extraGroups = [ "wheel" "kvm" "libvirtd" "video" ];
      createHome = false;
    };
  };

  # Create state dirs for OVMF vars, disks, XML, profiles, ISOs
  systemd.tmpfiles.rules = [
    "d /var/lib/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/isos 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/disks 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/xml 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/vm_profiles 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/gnupg 0700 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/backups 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/log/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
  ];

  # Enable libvirt for virsh/XML workflows
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.runAsRoot = false;
  virtualisation.libvirtd.extraConfig = ''
    security_driver = "apparmor"
    dynamic_ownership = 1
    clear_emulator_capabilities = 1
    seccomp_sandbox = 1
    namespaces = [ "mount", "uts", "ipc", "pid", "net" ]
  '';

  # Start the VM selection menu at boot on the console
  systemd.services.hypervisor-menu = {
    description = "Boot-time Hypervisor VM Menu";
    wantedBy = lib.optional enableMenuAtBoot "multi-user.target";
    after = [ "network-online.target" "libvirtd.service" ];
    wants = [ "network-online.target" "libvirtd.service" ];
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/menu.sh";
      WorkingDirectory = "/etc/hypervisor";
      User = "${mgmtUser}";
      SupplementaryGroups = [ "kvm" "libvirtd" "video" ];
      Restart = "always";
      RestartSec = 2;
      StateDirectory = "hypervisor";
      LogsDirectory = "";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor/logs"
        "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/logs/menu.log"
      ];
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      Environment = [
        "SDL_VIDEODRIVER=kmsdrm"
        "SDL_AUDIODRIVER=alsa"
        "DIALOG=whiptail"
        "TERM=linux"
        "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      ];

      # Hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = false; # allow /dev/kvm
      DeviceAllow = [ "/dev/kvm rw" "/dev/dri/* rw" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      SystemCallFilter = [ "@system-service" "@pkey" "@chown" ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
    };
  };

  # First-boot wizard (runs once, then marks completion)
  systemd.services.hypervisor-first-boot = {
    description = "First-boot Setup Wizard";
    wantedBy = lib.optional enableWizardAtBoot "multi-user.target";
    after = [ "network-online.target" "systemd-tmpfiles-setup.service" ];
    before = [ "hypervisor-menu.service" ];
    wants = [ "network-online.target" ];
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'if [ ! -f /var/lib/hypervisor/.first_boot_done ]; then ${pkgs.bash}/bin/bash /etc/hypervisor/scripts/setup_wizard.sh || true; ${pkgs.coreutils}/bin/touch /var/lib/hypervisor/.first_boot_done; fi'";
      User = "root";
      WorkingDirectory = "/etc/hypervisor";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      StateDirectory = "hypervisor";
      LogsDirectory = "";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor/logs"
        "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/logs/first_boot.log"
        "${pkgs.coreutils}/bin/mkdir -p /etc/hypervisor/configuration"
      ];
      ReadWritePaths = [ "/etc/hypervisor/configuration" "/var/lib/hypervisor/logs" ];
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      Environment = [ "DIALOG=whiptail" "TERM=linux" "HOME=/root" "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin" ];
    };
    unitConfig = {
      ConditionPathExists = "!/var/lib/hypervisor/.first_boot_done";
    };
  };

  # Security hardening
  networking.firewall.enable = true;
  security.sudo.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      KbdInteractiveAuthentication = false;
    };
  };
  security.apparmor.enable = true;
  security.apparmor.policies = {
    "qemu-system-x86_64".profile = builtins.readFile ../configuration/apparmor/qemu-system-x86_64;
  };
  boot.kernelParams = [ "apparmor=1" "security=apparmor" ];

  # Avoid starting unnecessary daemons
  services.printing.enable = false;
  hardware.pulseaudio.enable = false;
  sound.enable = false;
  hardware.opengl.enable = true;

  # GUI management environment (Wayland GNOME) - enabled by default for initial setup
  # Can be disabled by setting hypervisor.gui.enableAtBoot = false in management-local.nix
  services.xserver.enable = lib.mkIf enableGuiAtBoot true;
  services.displayManager.gdm.enable = lib.mkIf enableGuiAtBoot true;
  services.displayManager.gdm.wayland = lib.mkIf enableGuiAtBoot true;
  services.displayManager.autoLogin = lib.mkIf enableGuiAtBoot {
    enable = true;
    user = mgmtUser;
  };
  services.desktopManager.gnome.enable = lib.mkIf enableGuiAtBoot true;
  programs.xwayland.enable = lib.mkIf enableGuiAtBoot true;
  environment.etc."xdg/autostart/hypervisor-dashboard.desktop" = lib.mkIf enableGuiAtBoot {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Dashboard
      Exec=/etc/hypervisor/scripts/management_dashboard.sh --autostart
      X-GNOME-Autostart-enabled=true
    '';
  };
  environment.etc."xdg/applications/hypervisor-dashboard.desktop" = lib.mkIf enableGuiAtBoot {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Dashboard
      Comment=Manage VMs and hypervisor tasks
      Exec=/etc/hypervisor/scripts/management_dashboard.sh
      Icon=computer
      Categories=System;Utility;
    '';
  };
  environment.etc."xdg/applications/hypervisor-installer.desktop" = lib.mkIf enableGuiAtBoot {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Installer
      Comment=Run first-boot setup/installer
      Exec=/etc/hypervisor/scripts/setup_wizard.sh
      Icon=system-software-install
      Categories=System;Utility;
    '';
  };
}
