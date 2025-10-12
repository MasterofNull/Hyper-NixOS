{ config, pkgs, lib, ... }:

# Hyper-NixOS Main Configuration
# This is the top-level configuration file that imports all modules

let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  enableMenuAtBoot = lib.attrByPath ["hypervisor" "menu" "enableAtBoot"] true config;
  enableWelcomeAtBoot = lib.attrByPath ["hypervisor" "firstBootWelcome" "enableAtBoot"] true config;
  enableWizardAtBoot = lib.attrByPath ["hypervisor" "firstBootWizard" "enableAtBoot"] false config;
  
  # Boot Architecture: Headless console menu by default, GUI only on explicit request
  # This hypervisor is designed to boot to a TUI menu for VM management (minimal resources).
  # GUI desktop environment is opt-in via hypervisor.gui.enableAtBoot = true
  hasHypervisorGuiPreference = lib.hasAttrByPath ["hypervisor" "gui" "enableAtBoot"] config;
  hypervisorGuiRequested = lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config;
  enableGuiAtBoot = if hasHypervisorGuiPreference then hypervisorGuiRequested else false;
  
  # Enable console autologin only when not booting to a GUI Desktop
  consoleAutoLoginEnabled = (enableMenuAtBoot || enableWizardAtBoot) && (!enableGuiAtBoot);
in {
  # ═══════════════════════════════════════════════════════════════
  # System Version
  # ═══════════════════════════════════════════════════════════════
  system.stateVersion = "24.05";
  
  # ═══════════════════════════════════════════════════════════════
  # Module Imports - Organized by Topic
  # ═══════════════════════════════════════════════════════════════
  imports = [
    # ─────────────────────────────────────────────────────────────
    # Core System Configuration
    # ─────────────────────────────────────────────────────────────
    ./core/hardware-configuration.nix
    ./core/boot.nix
    ./core/system.nix
    ./core/packages.nix
    ./core/directories.nix
    ./core/logrotate.nix
    ./core/cache-optimization.nix
    
    # ─────────────────────────────────────────────────────────────
    # Security Configuration
    # ─────────────────────────────────────────────────────────────
    ./security/base.nix
    ./security/production.nix
    ./security/profiles.nix
    ./security/kernel-hardening.nix
    ./security/firewall.nix
    ./security/ssh.nix
    
    # ─────────────────────────────────────────────────────────────
    # Virtualization Configuration
    # ─────────────────────────────────────────────────────────────
    ./virtualization/libvirt.nix
    ../scripts/vfio-boot.nix
    
    # ─────────────────────────────────────────────────────────────
    # Monitoring Configuration
    # ─────────────────────────────────────────────────────────────
    ./monitoring/prometheus.nix
    ./monitoring/alerting.nix
    ./monitoring/logging.nix
    
    # ─────────────────────────────────────────────────────────────
    # Automation Services
    # ─────────────────────────────────────────────────────────────
    ./automation/services.nix
    ./automation/backup.nix
    
    # ─────────────────────────────────────────────────────────────
    # GUI Configuration (optional)
    # ─────────────────────────────────────────────────────────────
    ./gui/desktop.nix
    ./gui/input.nix
    
    # ─────────────────────────────────────────────────────────────
    # Web Dashboard
    # ─────────────────────────────────────────────────────────────
    ./web/dashboard.nix
    
  # ─────────────────────────────────────────────────────────────
  # Optional Modules (conditionally loaded)
  # ─────────────────────────────────────────────────────────────
  ] ++ lib.optional (builtins.pathExists ./enterprise/features.nix) 
      ./enterprise/features.nix
    ++ lib.optional (builtins.pathExists ./virtualization/performance.nix) 
      ./virtualization/performance.nix
  
  # ─────────────────────────────────────────────────────────────
  # Local Override Configuration Files
  # These allow per-host customization without modifying the base
  # ─────────────────────────────────────────────────────────────
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/performance.nix) 
      /var/lib/hypervisor/configuration/performance.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/perf-local.nix) 
      /var/lib/hypervisor/configuration/perf-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/security-local.nix) 
      /var/lib/hypervisor/configuration/security-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/users-local.nix) 
      /var/lib/hypervisor/configuration/users-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/system-local.nix) 
      /var/lib/hypervisor/configuration/system-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/management-local.nix) 
      /var/lib/hypervisor/configuration/management-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/swap-local.nix) 
      /var/lib/hypervisor/configuration/swap-local.nix
    ++ lib.optional (builtins.pathExists /var/lib/hypervisor/configuration/gui-local.nix) 
      /var/lib/hypervisor/configuration/gui-local.nix
    
    # Note: security/strict.nix is loaded from /var/lib/hypervisor/configuration/security-strict.nix
    ++ lib.optional (builtins.pathExists ./security/strict.nix) 
      ./security/strict.nix;
  
  # ═══════════════════════════════════════════════════════════════
  # Systemd Services - Hypervisor Menu
  # ═══════════════════════════════════════════════════════════════
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
      
      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = false;
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
  
  # ═══════════════════════════════════════════════════════════════
  # Systemd Services - First Boot Welcome
  # ═══════════════════════════════════════════════════════════════
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
      
      ReadWritePaths = [ 
        "/var/lib/hypervisor/logs" 
        "/var/lib/hypervisor/.first_boot_welcome_shown" 
      ];
      
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      
      Environment = [ 
        "DIALOG=whiptail" 
        "TERM=linux" 
        "HOME=/root" 
        "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin" 
      ];
    };
    
    unitConfig.ConditionPathExists = "!/var/lib/hypervisor/.first_boot_welcome_shown";
  };
  
  # ═══════════════════════════════════════════════════════════════
  # Systemd Services - First Boot Wizard
  # ═══════════════════════════════════════════════════════════════
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
      
      ReadWritePaths = [ 
        "/etc/hypervisor/src/configuration" 
        "/var/lib/hypervisor/logs" 
      ];
      
      StandardInput = "tty";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      
      Environment = [ 
        "DIALOG=whiptail" 
        "TERM=linux" 
        "HOME=/root" 
        "PATH=/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin" 
      ];
    };
    
    unitConfig.ConditionPathExists = "!/var/lib/hypervisor/.first_boot_done";
  };
}
