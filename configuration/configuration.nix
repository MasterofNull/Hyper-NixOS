{ config, pkgs, lib, ... }:

let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  # Enable menu at boot by default - this is the primary interface
  enableMenuAtBoot = lib.attrByPath ["hypervisor" "menu" "enableAtBoot"] true config;
  # First-boot welcome screen - lightweight orientation (one-time, auto-dismiss)
  enableWelcomeAtBoot = lib.attrByPath ["hypervisor" "firstBootWelcome" "enableAtBoot"] true config;
  # First-boot wizard disabled - users run "Install VMs" from main menu instead
  enableWizardAtBoot = lib.attrByPath ["hypervisor" "firstBootWizard" "enableAtBoot"] false config;
  # Detect if GUI is available in base system (for menu/dashboard to know)
  baseSystemHasGui = config.services.xserver.enable or false;
  # Check if user has explicit hypervisor GUI preference
  # If not set, we respect base system configuration (don't override)
  hasHypervisorGuiPreference = lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config;
  hypervisorGuiRequested = lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config;
  # Only override if user has explicit preference, otherwise respect base system
  enableGuiAtBoot = if hasHypervisorGuiPreference then hypervisorGuiRequested else baseSystemHasGui;
  # Compatibility flags for NixOS versions (24.05 vs 24.11+)
  hasNewDM = lib.hasAttrByPath ["services" "displayManager"] config;
  hasOldDM = lib.hasAttrByPath ["services" "xserver" "displayManager"] config;
  hasNewDesk = lib.hasAttrByPath ["services" "desktopManager" "gnome"] config;
  hasOldDesk = lib.hasAttrByPath ["services" "xserver" "desktopManager" "gnome"] config;
in {
  system.stateVersion = "24.05"; # set at initial install; do not change blindly
  imports = [
    ./hardware-configuration.nix
    ./hardware-input.nix
    ../scripts/vfio-boot.nix
    ./security.nix
    ./security-production.nix  # Production security model (default)
    ./monitoring.nix
    ./backup.nix
    ./automation.nix  # Automated health checks, backups, updates, monitoring
    ./alerting.nix    # Alert system (email, webhooks)
    ./web-dashboard.nix  # Web dashboard (optional, localhost only by default)
  ]
  ++ lib.optional (builtins.pathExists ./enterprise-features.nix) ./enterprise-features.nix
  ++ lib.optional (builtins.pathExists ./performance.nix) ./performance.nix
  ++ lib.optional (builtins.pathExists ./cache-optimization.nix) ./cache-optimization.nix  # Always load for faster downloads
  # Load local, host-specific overrides from /var/lib to avoid mutating the flake input
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/performance.nix) /var/lib/hypervisor/configuration/performance.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/perf-local.nix) /var/lib/hypervisor/configuration/perf-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/security-local.nix) /var/lib/hypervisor/configuration/security-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/security-strict.nix) /var/lib/hypervisor/configuration/security-strict.nix  # Optional: Maximum security
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/users-local.nix) /var/lib/hypervisor/configuration/users-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/system-local.nix) /var/lib/hypervisor/configuration/system-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/management-local.nix) /var/lib/hypervisor/configuration/management-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/swap-local.nix) /var/lib/hypervisor/configuration/swap-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/gui-local.nix) /var/lib/hypervisor/configuration/gui-local.nix
  ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/cache-optimization.nix) /var/lib/hypervisor/configuration/cache-optimization.nix;

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

  # Boot Behavior Configuration:
  # - First boot: Setup wizard runs (if enabled), then VM selector
  # - Subsequent boots: VM boot selector (if VMs exist) or main menu
  # - VM selector shows: VMs list + "More Options" → main menu
  # - Main menu has: "← Back to VM Boot Selector" option
  # - Default: VM-first boot flow (enableMenuAtBoot = true)
  # - GUI available via menu: "More Options" → "GNOME Desktop"
  
  # Autologin configuration for appliance/kiosk mode
  # SECURITY NOTE: For production/multi-user systems, disable autologin!
  # See docs/SECURITY_MODEL.md for secure configurations
  # 
  # Console auto-login: Only if menu/wizard enabled AND (no GUI preference OR GUI explicitly disabled)
  # This respects base system GUI configuration - we don't force console login if user wants GUI
  # Recommended: Create hypervisor-operator user without sudo access
  # See: /var/lib/hypervisor/configuration/security-kiosk.nix
  consoleAutoLoginEnabled = (enableMenuAtBoot || enableWizardAtBoot) && (!hasHypervisorGuiPreference || !enableGuiAtBoot);
  services.getty.autologinUser = lib.mkIf consoleAutoLoginEnabled mgmtUser;
  
  # Create a default 'hypervisor' user only when used as the management user
  # Note: During bootstrap, the script will automatically detect existing users
  # and add them to users-local.nix with wheel group membership for sudo access
  users.users = lib.mkIf (mgmtUser == "hypervisor") {
    hypervisor = {
      isNormalUser = true;
      extraGroups = [ "wheel" "kvm" "libvirtd" "video" "input" ];
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
    "d /var/lib/hypervisor/logs 0750 ${mgmtUser} ${mgmtUser} - -"
  ];

  # Log rotation for hypervisor logs
  services.logrotate = {
    enable = true;
    settings = {
      "/var/lib/hypervisor/logs/*.log" = {
        frequency = "daily";
        rotate = 7;
        compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip";
        compressext = ".gz";
        missingok = true;
        notifempty = true;
        sharedscripts = true;
        postrotate = ''
          systemctl reload hypervisor-menu.service 2>/dev/null || true
        '';
      };
      "/var/log/hypervisor/*.log" = {
        frequency = "daily";
        rotate = 7;
        compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip";
        compressext = ".gz";
        missingok = true;
        notifempty = true;
      };
    };
  };

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
      
      # SECURITY: Restart menu on exit to prevent shell escape
      # If menu crashes or user exits, it restarts instead of dropping to shell
      # This prevents physical access from gaining shell on autologin user
      Restart = "always";
      RestartSec = "2";
    };
  };

  # First-boot welcome screen (lightweight, one-time orientation)
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
      User = "root";
      WorkingDirectory = "/etc/hypervisor";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      StateDirectory = "hypervisor";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor/logs"
        "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/logs/first_boot.log"
      ];
      ReadWritePaths = [ "/var/lib/hypervisor/logs" "/var/lib/hypervisor/.first_boot_welcome_shown" ];
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      Environment = [ "DIALOG=whiptail" "TERM=linux" "HOME=/root" "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin" ];
    };
    unitConfig = {
      ConditionPathExists = "!/var/lib/hypervisor/.first_boot_welcome_shown";
    };
  };

  # First-boot wizard (DISABLED - replaced by "Install VMs" menu option)
  # Kept for reference but not enabled by default
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
        "${pkgs.coreutils}/bin/mkdir -p /etc/hypervisor/src/configuration"
      ];
      ReadWritePaths = [ "/etc/hypervisor/src/configuration" "/var/lib/hypervisor/logs" ];
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
  
  # IMPORTANT SECURITY MODEL:
  # - Autologin is enabled for seamless console menu (appliance-like experience)
  # - BUT passwordless sudo is RESTRICTED to specific VM management commands only
  # - System administration tasks REQUIRE password authentication
  # - This balances convenience (VM management) with security (system protection)
  
  # Require password for wheel group by default (secure by default)
  security.sudo.wheelNeedsPassword = true;
  
  # Granular sudo rules: passwordless ONLY for specific VM management operations
  security.sudo.extraRules = [
    {
      # VM Management - passwordless for convenience
      users = [ mgmtUser ];
      commands = [
        # Libvirt/virsh VM operations (read-only and VM control)
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
        # VM creation/definition (uses generated XML, not user input)
        { command = "${pkgs.libvirt}/bin/virsh define"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh undefine"; options = [ "NOPASSWD" ]; }
        # Snapshot operations
        { command = "${pkgs.libvirt}/bin/virsh snapshot-create-as"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-revert"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-delete"; options = [ "NOPASSWD" ]; }
        # Network operations (read-only)
        { command = "${pkgs.libvirt}/bin/virsh net-list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-info"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-dhcp-leases"; options = [ "NOPASSWD" ]; }
      ];
    }
    {
      # System administration - REQUIRES PASSWORD for security
      # These are intentionally NOT in the NOPASSWD list:
      # - nixos-rebuild (system changes)
      # - systemctl (service management) 
      # - any commands that modify /etc, /var, or system state
      # - network configuration changes
      # - user/permission changes
      # - package installation
      users = [ mgmtUser ];
      commands = [
        { command = "ALL"; }  # Allowed but requires password
      ];
    }
  ];
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

  # GUI management environment (Wayland GNOME)
  # Default: GNOME installed but NOT auto-started (available via menu)
  # To auto-start GUI at boot: Create /var/lib/hypervisor/configuration/gui-local.nix with hypervisor.gui.enableAtBoot = true
  # Using mkDefault so base system config is preserved (if user wants GNOME available)
  # But we don't force it to start on boot
  services.xserver.enable = lib.mkDefault (baseSystemHasGui || enableGuiAtBoot);
  # Display Manager (GDM) - prefer legacy xserver paths for compatibility
  # CRITICAL: Only enable display manager if GUI boot is explicitly requested
  # This prevents auto-starting GUI even if base system has GNOME installed
  services.xserver.displayManager.gdm.enable = lib.mkDefault (enableGuiAtBoot && hasOldDM);
  services.xserver.displayManager.gdm.wayland = lib.mkDefault (enableGuiAtBoot && hasOldDM);
  # Auto-login only if GUI boot is explicitly requested
  services.xserver.displayManager.autoLogin = lib.mkIf (enableGuiAtBoot && hasOldDM) {
    enable = lib.mkDefault true;
    user = mgmtUser;
  };
  # Desktop Manager (GNOME) - support both old and new option paths
  # Use mkDefault to respect base system configuration
  services.xserver.desktopManager.gnome.enable = lib.mkDefault (enableGuiAtBoot && hasOldDesk);
  programs.xwayland.enable = lib.mkDefault enableGuiAtBoot;
  # Desktop files - ALWAYS present so they work if user manually accesses GNOME
  # Even if GUI boot is disabled, these allow easy menu access from GNOME session
  environment.etc."xdg/autostart/hypervisor-dashboard.desktop" = lib.mkIf enableGuiAtBoot {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Dashboard
      Exec=/etc/hypervisor/scripts/management_dashboard.sh --autostart
      X-GNOME-Autostart-enabled=true
    '';
  };
  
  # Application launcher icons - always available
  environment.etc."xdg/applications/hypervisor-menu.desktop" = {
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
  };
  environment.etc."xdg/applications/hypervisor-dashboard.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Dashboard
      Comment=GUI dashboard for VM and task management
      Exec=/etc/hypervisor/scripts/management_dashboard.sh
      Icon=computer
      Categories=System;Utility;
    '';
  };
  environment.etc."xdg/applications/hypervisor-installer.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Hypervisor Setup Wizard
      Comment=Run first-boot setup and configuration wizard
      Exec=gnome-terminal -- /etc/hypervisor/scripts/setup_wizard.sh
      Icon=system-software-install
      Terminal=false
      Categories=System;Settings;
    '';
  };
  environment.etc."xdg/applications/hypervisor-networking.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Network Foundation Setup
      Comment=Configure foundational networking (bridges, interfaces)
      Exec=gnome-terminal -- sudo /etc/hypervisor/scripts/foundational_networking_setup.sh
      Icon=network-wired
      Terminal=false
      Categories=System;Settings;Network;
    '';
  };
  
  # Create desktop shortcuts for quick access
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
  mode = "0755";
  };
}
