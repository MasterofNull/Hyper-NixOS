# Hyper-NixOS Hibernation & Authentication Module
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Intelligent hibernation/resume authentication management
# Prevents user lockouts on systems without passwords
# Context-aware: headless VMs vs desktop environments

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.hibernation;

  # Detect if system has a desktop environment
  hasDesktop = config.services.xserver.enable || config.programs.wayland.enable;

  # Detect if any users have passwords set
  usersWithPasswords = lib.filter (user:
    user.hashedPassword != null && user.hashedPassword != "" &&
    user.hashedPassword != "!" && user.hashedPassword != "*"
  ) (attrValues config.users.users);

  hasAnyPasswords = length usersWithPasswords > 0;

  # Intelligent swap detection script
  swapDetectionScript = pkgs.writeShellScript "detect-swap" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Find swap devices/files
    SWAP_DEVICES=$(swapon --show=NAME --noheadings 2>/dev/null || true)

    if [[ -z "$SWAP_DEVICES" ]]; then
      echo "none"
      exit 0
    fi

    # Get largest swap device for hibernation
    LARGEST_SWAP=$(swapon --show=NAME,SIZE --bytes --noheadings 2>/dev/null | \
                   sort -k2 -rn | head -n1 | awk '{print $1}' || true)

    if [[ -z "$LARGEST_SWAP" ]]; then
      echo "none"
    else
      echo "$LARGEST_SWAP"
    fi
  '';

  # Hibernation capability detection
  hibernationCheckScript = pkgs.writeShellScript "check-hibernation" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if system has enough swap for hibernation
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_SWAP_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')

    # Need swap >= RAM for hibernation
    if [[ $TOTAL_SWAP_KB -ge $TOTAL_RAM_KB ]]; then
      echo "supported"
    elif [[ $TOTAL_SWAP_KB -gt 0 ]]; then
      echo "insufficient"  # Has swap but not enough
    else
      echo "none"  # No swap at all
    fi
  '';

in {
  options.hypervisor.hibernation = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable intelligent hibernation support.
        Automatically configures based on available swap and user context.
      '';
    };

    autoDetectSwap = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Automatically detect and configure swap for hibernation.
        When enabled, finds largest swap device and sets resume device.
      '';
    };

    requirePassword = mkOption {
      type = types.enum [ "auto" "always" "never" "desktop-only" ];
      default = "auto";
      description = ''
        When to require password on resume from hibernation/suspend.

        - auto: Require password only if users have passwords set
        - always: Always require password (may lock out users!)
        - never: Never require password (security risk!)
        - desktop-only: Require password only on desktop systems
      '';
    };

    allowHeadlessResume = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow headless systems (VMs, servers) to resume without password.
        Prevents lockouts on systems without passwords configured.
      '';
    };

    suspendToRamEnabled = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable suspend-to-RAM (sleep mode).
        Supported on laptops, desktops, some SBCs.
      '';
    };

    preventUserLockout = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Actively prevent user lockouts after resume.

        If enabled and no users have passwords:
        - Disables lock screen on resume
        - Auto-login for single-user systems
        - Warns but allows resume without password
      '';
    };
  };

  config = mkIf cfg.enable {
    # Intelligent swap detection and configuration
    boot.resumeDevice = mkIf cfg.autoDetectSwap (
      let
        swapDeviceDetection = pkgs.runCommand "detect-resume-device" {} ''
          RESUME_DEV=$(${swapDetectionScript})
          echo -n "$RESUME_DEV" > $out
        '';
        detectedSwap = builtins.readFile swapDeviceDetection;
      in
        mkIf (detectedSwap != "none") detectedSwap
    );

    # Hibernation kernel parameters
    boot.kernelParams = mkIf cfg.autoDetectSwap [
      # Resume timeout - give system time to wake up
      "resume_offset=0"
    ];

    # Power management configuration
    powerManagement = {
      enable = true;

      # Hibernation support
      powerDownCommands = ''
        # Log hibernation event
        echo "[$(date)] System entering hibernation" >> /var/log/hypervisor/power.log

        # Sync filesystems
        ${pkgs.coreutils}/bin/sync

        # Flush caches
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
      '';

      powerUpCommands = ''
        # Log resume event
        echo "[$(date)] System resumed from hibernation" >> /var/log/hypervisor/power.log

        # Restore services
        ${pkgs.systemd}/bin/systemctl restart libvirtd.service 2>/dev/null || true
      '';
    };

    # Context-aware authentication on resume
    security.pam.services = let
      # Determine if we should require password
      shouldRequirePassword =
        if cfg.requirePassword == "always" then true
        else if cfg.requirePassword == "never" then false
        else if cfg.requirePassword == "desktop-only" then hasDesktop
        else hasAnyPasswords;  # auto mode

      # PAM configuration for resume
      resumeAuth = {
        unixAuth = shouldRequirePassword;
        allowNullPassword = !shouldRequirePassword;

        # If preventing lockouts and no passwords, allow without auth
        text = mkIf (cfg.preventUserLockout && !hasAnyPasswords) ''
          # Allow resume without password if no users have passwords
          # This prevents lockouts on headless systems
          auth sufficient pam_permit.so
        '';
      };

    in {
      # Suspend/hibernate resume authentication
      systemd-user.text = mkIf (!shouldRequirePassword) ''
        # Headless/passwordless resume - no authentication required
        auth sufficient pam_permit.so
      '';

      # Lock screen on resume (only if passwords exist)
      swaylock = mkIf (hasDesktop && shouldRequirePassword) {
        unixAuth = true;
      };

      # Display manager resume
      lightdm = mkIf (hasDesktop && shouldRequirePassword) {
        unixAuth = true;
      };

      gdm = mkIf (hasDesktop && shouldRequirePassword) {
        unixAuth = true;
      };
    };

    # Auto-login for single passwordless user (prevents lockout)
    services.getty.autologinUser = mkIf (
      cfg.preventUserLockout &&
      !hasDesktop &&
      !hasAnyPasswords &&
      length (attrValues config.users.users) == 2  # root + 1 user
    ) (
      # Find the non-root user
      head (filter (u: u != "root") (attrNames config.users.users))
    );

    # Systemd sleep configuration
    systemd.sleep.extraConfig = ''
      # Suspend configuration
      AllowSuspend=${if cfg.suspendToRamEnabled then "yes" else "no"}
      AllowHibernation=yes
      AllowSuspendThenHibernate=yes
      AllowHybridSleep=yes

      # Hibernate after 30 minutes of suspension (laptops)
      HibernateDelaySec=30min
    '';

    # Warnings for admins
    warnings =
      optional (cfg.requirePassword == "never" && hasAnyPasswords) ''
        Hibernation password requirement is disabled but users have passwords set.
        This may be a security risk. Consider setting requirePassword = "auto".
      ''
      ++
      optional (!cfg.preventUserLockout && !hasAnyPasswords) ''
        User lockout prevention is disabled and no users have passwords.
        Users may be locked out after resume. Enable preventUserLockout.
      '';

    # Informational messages on first boot
    environment.etc."hypervisor/hibernation-status".text = ''
      Hyper-NixOS Hibernation Configuration
      =====================================

      Desktop Environment: ${if hasDesktop then "Yes" else "No (headless)"}
      Users with Passwords: ${toString (length usersWithPasswords)}
      Password Required on Resume: ${if shouldRequirePassword then "Yes" else "No"}

      Suspend-to-RAM: ${if cfg.suspendToRamEnabled then "Enabled" else "Disabled"}
      Hibernation: ${if cfg.enable then "Enabled" else "Disabled"}
      Auto Swap Detection: ${if cfg.autoDetectSwap then "Enabled" else "Disabled"}

      Lockout Prevention: ${if cfg.preventUserLockout then "Enabled" else "Disabled"}

      ${if !hasAnyPasswords then ''
      ⚠ WARNING: No users have passwords set!

      To prevent lockouts:
      1. Set passwords: sudo passwd <username>
      2. Or keep preventUserLockout = true (current setting)

      Headless systems without passwords will auto-resume without prompts.
      '' else ''
      ✓ Users have passwords - authentication will work on resume.
      ''}

      To check hibernation support:
        cat /sys/power/state

      To hibernate manually:
        sudo systemctl hibernate

      To suspend:
        sudo systemctl suspend
    '';

    # Create log directory
    system.activationScripts.hibernationSetup = ''
      mkdir -p /var/log/hypervisor
      chmod 755 /var/log/hypervisor

      # Check hibernation capability
      HIBERNATION_STATUS=$(${hibernationCheckScript})
      echo "Hibernation support: $HIBERNATION_STATUS" >> /var/log/hypervisor/power.log

      if [[ "$HIBERNATION_STATUS" == "insufficient" ]]; then
        echo "WARNING: Swap size insufficient for hibernation" >> /var/log/hypervisor/power.log
        echo "Need swap >= $(grep MemTotal /proc/meminfo | awk '{print $2}') KB" >> /var/log/hypervisor/power.log
      elif [[ "$HIBERNATION_STATUS" == "none" ]]; then
        echo "WARNING: No swap configured - hibernation disabled" >> /var/log/hypervisor/power.log
      fi
    '';

    # Helper commands
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "hv-hibernation-status" ''
        echo "=== Hyper-NixOS Hibernation Status ==="
        echo ""
        cat /etc/hypervisor/hibernation-status
        echo ""
        echo "=== Current Power State ==="
        cat /sys/power/state
        echo ""
        echo "=== Swap Devices ==="
        swapon --show
        echo ""
        echo "=== Resume Device ==="
        cat /sys/power/resume_offset 2>/dev/null || echo "Not configured"
      '')

      (pkgs.writeShellScriptBin "hv-test-suspend" ''
        if [[ $EUID -ne 0 ]]; then
          echo "This command must be run as root"
          exit 1
        fi

        echo "Testing suspend-to-RAM..."
        echo "System will suspend for 10 seconds"
        sleep 3
        rtcwake -m mem -s 10
      '')
    ];
  };
}
