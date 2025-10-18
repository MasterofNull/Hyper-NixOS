# Hyper-NixOS Update Checker Module
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Monthly NixOS update checker and notification system
# Only admins can perform system upgrades

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.updateChecker;

  updateCheckerScript = pkgs.writeShellScript "nixos-update-checker" ''
    #!/usr/bin/env bash
    set -euo pipefail

    LOG_DIR="/var/log/hypervisor"
    LOG_FILE="$LOG_DIR/update-checker.log"
    NOTIFY_FILE="/var/lib/hypervisor/update-available"
    MOTD_FILE="/etc/motd.d/updates-available"

    mkdir -p "$LOG_DIR" /var/lib/hypervisor /etc/motd.d

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }

    log "=== NixOS Update Check Started ==="

    # Get current NixOS version
    CURRENT_VERSION=$(nixos-version --json | ${pkgs.jq}/bin/jq -r '.nixosVersion' || echo "unknown")
    CURRENT_REVISION=$(nixos-version --json | ${pkgs.jq}/bin/jq -r '.nixpkgsRevision' || echo "unknown")

    log "Current NixOS version: $CURRENT_VERSION"
    log "Current nixpkgs revision: $CURRENT_REVISION"

    # Check flake inputs for available updates
    cd /etc/hypervisor || exit 1

    # Update flake lock to see what's available (doesn't change system)
    log "Checking for available updates..."

    if ! ${pkgs.nix}/bin/nix flake update --commit-lock-file 2>&1 | tee -a "$LOG_FILE"; then
      log "WARNING: Failed to check for updates"
      exit 0
    fi

    # Compare lock file changes
    if ${pkgs.git}/bin/git diff --quiet HEAD flake.lock 2>/dev/null; then
      log "No updates available - system is up to date"
      rm -f "$NOTIFY_FILE" "$MOTD_FILE"
      exit 0
    fi

    # Updates are available
    log "Updates available!"

    # Get details of what changed
    CHANGES=$(${pkgs.git}/bin/git diff HEAD flake.lock | grep -E '^\+.*"rev"|^\-.*"rev"' || echo "")

    # Create notification file with update details
    cat > "$NOTIFY_FILE" <<EOF
NixOS updates are available!

Current version: $CURRENT_VERSION
Current revision: $CURRENT_REVISION

To review changes:
  cd /etc/hypervisor && git diff HEAD flake.lock

To test the upgrade (recommended):
  sudo nixos-rebuild test --flake /etc/hypervisor

To apply the upgrade:
  sudo nixos-rebuild switch --flake /etc/hypervisor

Changes detected:
$CHANGES

Last checked: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    # Create MOTD banner for users
    cat > "$MOTD_FILE" <<EOF

╔══════════════════════════════════════════════════════════╗
║                  ⚠ UPDATES AVAILABLE ⚠                  ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  NixOS updates are available for this system.           ║
║  Last checked: $(date '+%Y-%m-%d')                              ║
║                                                          ║
║  Only administrators can perform system upgrades.       ║
║                                                          ║
║  To review: cat /var/lib/hypervisor/update-available    ║
║  To upgrade: sudo hv system-upgrade                      ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

EOF

    chmod 644 "$NOTIFY_FILE" "$MOTD_FILE"
    log "Update notification created at: $NOTIFY_FILE"

    # Send notification to admins (if notification system is configured)
    if command -v wall >/dev/null 2>&1; then
      echo "NixOS updates available! Run: cat /var/lib/hypervisor/update-available" | wall 2>/dev/null || true
    fi

    log "=== Update Check Complete ==="
  '';

  upgradeTestScript = pkgs.writeShellScript "nixos-upgrade-test" ''
    #!/usr/bin/env bash
    set -euo pipefail

    LOG_DIR="/var/log/hypervisor"
    LOG_FILE="$LOG_DIR/upgrade-test.log"
    RESULT_FILE="/var/lib/hypervisor/upgrade-test-result"

    mkdir -p "$LOG_DIR" /var/lib/hypervisor

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }

    log "=== NixOS Upgrade Test Started ==="

    # Ensure we have the latest flake lock
    if [[ ! -f /etc/hypervisor/flake.lock ]]; then
      log "ERROR: No flake.lock found. Run update checker first."
      exit 1
    fi

    # Test the upgrade (doesn't persist across reboots)
    log "Testing upgrade configuration..."

    if nixos-rebuild test --flake /etc/hypervisor 2>&1 | tee -a "$LOG_FILE"; then
      log "✓ Upgrade test PASSED"
      log "The new configuration is active but will revert on reboot."

      cat > "$RESULT_FILE" <<EOF
Upgrade Test: PASSED
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')

The upgrade test completed successfully.
The new configuration is currently active but will revert on reboot.

To make the upgrade permanent:
  sudo nixos-rebuild switch --flake /etc/hypervisor

To revert immediately:
  sudo nixos-rebuild switch --rollback
EOF
      exit 0
    else
      EXIT_CODE=$?
      log "✗ Upgrade test FAILED (exit code: $EXIT_CODE)"
      log "See log for errors: $LOG_FILE"

      # Try to extract error information
      ERRORS=$(tail -n 50 "$LOG_FILE" | grep -i "error\|failed\|warning" || echo "See full log for details")

      cat > "$RESULT_FILE" <<EOF
Upgrade Test: FAILED
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Exit Code: $EXIT_CODE

The upgrade test failed. Your current system is unchanged.

Recent errors:
$ERRORS

Full log: $LOG_FILE

Common fixes:
1. Configuration conflicts: Review /etc/nixos/configuration.nix for deprecated options
2. Hardware changes: Run 'sudo nixos-generate-config' to update hardware detection
3. Flake issues: Run 'cd /etc/hypervisor && nix flake update' to refresh inputs
4. Build failures: Check available disk space with 'df -h'

For help: https://github.com/MasterofNull/Hyper-NixOS/issues
EOF
      exit $EXIT_CODE
    fi
  '';

in {
  options.hypervisor.updateChecker = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable monthly NixOS update checker.
        Checks for available NixOS updates and notifies administrators.
      '';
    };

    schedule = mkOption {
      type = types.str;
      default = "monthly";
      example = "weekly";
      description = ''
        How often to check for updates.
        Accepts systemd calendar format (e.g., "monthly", "weekly", "Mon *-*-* 02:00:00").
      '';
    };

    notifyAdmins = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Show update notification in MOTD for all users.
        Admins can view details and perform upgrades.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Update checker systemd service
    systemd.services.nixos-update-checker = {
      description = "NixOS Update Checker";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${updateCheckerScript}";
        User = "root";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/log/hypervisor" "/var/lib/hypervisor" "/etc/hypervisor" "/etc/motd.d" ];
        NoNewPrivileges = true;
      };
    };

    # Monthly timer for update checks
    systemd.timers.nixos-update-checker = {
      description = "Monthly NixOS Update Check";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;  # Run on boot if missed
        RandomizedDelaySec = "1h";  # Spread load across the hour
      };
    };

    # Helper command for manual upgrade testing
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "hv-check-updates" ''
        if [[ $EUID -ne 0 ]]; then
          echo "This command must be run as root"
          exit 1
        fi
        systemctl start nixos-update-checker.service
        journalctl -u nixos-update-checker.service -n 50 --no-pager
      '')

      (pkgs.writeShellScriptBin "hv-upgrade-test" ''
        if [[ $EUID -ne 0 ]]; then
          echo "This command must be run as root"
          exit 1
        fi
        ${upgradeTestScript}
        cat /var/lib/hypervisor/upgrade-test-result
      '')

      (pkgs.writeShellScriptBin "hv-system-upgrade" ''
        if [[ $EUID -ne 0 ]]; then
          echo "ERROR: This command must be run as root (sudo)"
          exit 1
        fi

        echo "==================================="
        echo " Hyper-NixOS System Upgrade"
        echo "==================================="
        echo ""

        # Check if updates were tested
        if [[ ! -f /var/lib/hypervisor/upgrade-test-result ]]; then
          echo "WARNING: Upgrade has not been tested yet"
          echo ""
          read -p "Run test first? [Y/n] " -n 1 -r
          echo ""
          if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            ${upgradeTestScript}
            cat /var/lib/hypervisor/upgrade-test-result
            echo ""
            read -p "Test passed. Continue with permanent upgrade? [y/N] " -n 1 -r
            echo ""
            [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
          fi
        else
          # Show previous test result
          cat /var/lib/hypervisor/upgrade-test-result
          echo ""

          # Check if test passed
          if ! grep -q "PASSED" /var/lib/hypervisor/upgrade-test-result; then
            echo "ERROR: Previous upgrade test FAILED"
            echo "Fix the errors before proceeding with permanent upgrade"
            exit 1
          fi

          read -p "Apply permanent upgrade? [y/N] " -n 1 -r
          echo ""
          [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
        fi

        echo ""
        echo "Applying permanent upgrade..."
        nixos-rebuild switch --flake /etc/hypervisor

        echo ""
        echo "✓ Upgrade complete!"
        echo ""
        echo "The new configuration is now active and will persist across reboots."
        echo "If you encounter issues, you can rollback with:"
        echo "  sudo nixos-rebuild switch --rollback"
      '')
    ];

    # Ensure log directory exists
    system.activationScripts.hypervisorUpdateChecker = ''
      mkdir -p /var/log/hypervisor /var/lib/hypervisor /etc/motd.d
      chmod 755 /var/log/hypervisor /var/lib/hypervisor
    '';

    # Add to hv CLI help
    environment.etc."hypervisor/commands/update-commands.txt".text = ''
      Update Management Commands:

        hv-check-updates    Check for available NixOS updates (admin only)
        hv-upgrade-test     Test upgrade without persisting changes (admin only)
        hv-system-upgrade   Apply permanent system upgrade (admin only)

      Update workflow:
        1. Automatic check runs monthly (or run 'sudo hv-check-updates')
        2. Test the upgrade: sudo hv-upgrade-test
        3. Review results and verify system works
        4. Apply permanent: sudo hv-system-upgrade
    '';
  };
}
