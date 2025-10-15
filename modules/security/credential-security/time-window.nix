# Time Window Enforcement Module
# Restricts sensitive operations to specific time windows

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.timeWindow;
  
  # Time window checker
  timeWindowChecker = pkgs.writeScriptBin "check-time-window" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Check if within allowed time window
    check_installation_window() {
        local window_type="''${1:-installation}"
        local max_seconds=0
        
        case "$window_type" in
            installation)
                max_seconds=${toString cfg.installationWindow}
                ;;
            first-boot)
                max_seconds=${toString cfg.firstBootWindow}
                ;;
            recovery)
                max_seconds=${toString cfg.recoveryWindow}
                ;;
            *)
                echo "Unknown window type: $window_type" >&2
                exit 1
                ;;
        esac
        
        # Get system installation time
        local install_time=0
        if [[ -f /etc/machine-id ]]; then
            install_time=$(stat -c %Y /etc/machine-id 2>/dev/null || echo 0)
        fi
        
        # Fallback to other indicators
        if [[ $install_time -eq 0 ]] && [[ -f /var/log/installer/install.log ]]; then
            install_time=$(stat -c %Y /var/log/installer/install.log 2>/dev/null || echo 0)
        fi
        
        if [[ $install_time -eq 0 ]]; then
            echo "WARNING: Cannot determine installation time" >&2
            # Fail-safe: allow if we can't determine time
            return 0
        fi
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - install_time))
        
        echo "Installation time: $(date -d @$install_time)"
        echo "Current time: $(date -d @$current_time)"
        echo "Elapsed: $((elapsed / 60)) minutes ($elapsed seconds)"
        echo "Maximum allowed: $((max_seconds / 60)) minutes ($max_seconds seconds)"
        
        if [[ $elapsed -gt $max_seconds ]]; then
            echo
            echo "ERROR: Time window has expired!"
            echo "This operation must be performed within $((max_seconds / 60)) minutes of installation."
            return 1
        else
            local remaining=$((max_seconds - elapsed))
            echo
            echo "Time remaining: $((remaining / 60)) minutes ($remaining seconds)"
            return 0
        fi
    }
    
    # Check business hours restriction
    check_business_hours() {
        local current_hour=$(date +%H)
        local current_day=$(date +%u)  # 1=Monday, 7=Sunday
        
        # Check if weekend
        if [[ $current_day -eq 6 ]] || [[ $current_day -eq 7 ]]; then
            if [[ "${toString cfg.allowWeekends}" != "true" ]]; then
                echo "ERROR: Operation not allowed on weekends" >&2
                return 1
            fi
        fi
        
        # Check hour restrictions
        if [[ $current_hour -lt ${toString cfg.businessHoursStart} ]] || \
           [[ $current_hour -ge ${toString cfg.businessHoursEnd} ]]; then
            echo "ERROR: Operation only allowed between ${toString cfg.businessHoursStart}:00 and ${toString cfg.businessHoursEnd}:00" >&2
            return 1
        fi
        
        echo "Business hours check: OK"
        return 0
    }
    
    # Check maintenance window
    check_maintenance_window() {
        local current_time=$(date +%s)
        local maint_file="/var/lib/hypervisor/.maintenance-window"
        
        if [[ ! -f "$maint_file" ]]; then
            echo "No maintenance window defined"
            return 1
        fi
        
        local maint_start=$(grep "^start=" "$maint_file" | cut -d= -f2)
        local maint_end=$(grep "^end=" "$maint_file" | cut -d= -f2)
        
        if [[ $current_time -ge $maint_start ]] && [[ $current_time -le $maint_end ]]; then
            echo "Within maintenance window"
            return 0
        else
            echo "Outside maintenance window"
            echo "Window: $(date -d @$maint_start) to $(date -d @$maint_end)"
            return 1
        fi
    }
    
    # Main execution
    case "''${1:-check}" in
        check)
            window_type="''${2:-first-boot}"
            if check_installation_window "$window_type"; then
                echo "✓ Time window check passed"
                exit 0
            else
                exit 1
            fi
            ;;
        business-hours)
            if check_business_hours; then
                exit 0
            else
                exit 1
            fi
            ;;
        maintenance)
            if check_maintenance_window; then
                exit 0
            else
                exit 1
            fi
            ;;
        set-maintenance)
            # Set maintenance window
            duration="''${2:-3600}"  # Default 1 hour
            start=$(date +%s)
            end=$((start + duration))
            
            mkdir -p /var/lib/hypervisor
            cat > /var/lib/hypervisor/.maintenance-window <<EOF
    start=$start
    end=$end
    created=$(date -Iseconds)
    duration=$duration
    EOF
            echo "Maintenance window set:"
            echo "  Start: $(date -d @$start)"
            echo "  End: $(date -d @$end)"
            echo "  Duration: $((duration / 60)) minutes"
            ;;
        *)
            echo "Usage: $0 [check|business-hours|maintenance|set-maintenance] [args...]"
            exit 1
            ;;
    esac
  '';
  
  # Grace period extension tool
  gracePeriodExtender = pkgs.writeScriptBin "extend-time-window" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # This requires physical presence and admin authentication
    echo "Time Window Extension Request"
    echo "============================="
    echo
    echo "This will extend the time window for sensitive operations."
    echo "Requires: Physical console access + Admin authentication"
    echo
    
    # Verify physical presence
    if ! ${pkgs.verify-physical-presence}/bin/verify-physical-presence; then
        echo "ERROR: Physical presence verification failed" >&2
        exit 1
    fi
    
    # Require admin authentication
    echo "Admin authentication required:"
    if ! sudo -k && sudo true; then
        echo "ERROR: Authentication failed" >&2
        exit 1
    fi
    
    # Create extension token
    local extension_time=${toString cfg.extensionDuration}
    local token_file="/var/lib/hypervisor/.time-extension-token"
    
    cat > "$token_file" <<EOF
    created=$(date +%s)
    expires=$(($(date +%s) + extension_time))
    authorized_by=$SUDO_USER
    reason="$*"
    EOF
    
    chmod 600 "$token_file"
    
    echo "✓ Time window extended by $((extension_time / 60)) minutes"
    echo "  Authorized by: $SUDO_USER"
    echo "  Reason: $*"
  '';
  
in
{
  options.hypervisor.security.timeWindow = {
    enable = lib.mkEnableOption "Time window enforcement";
    
    installationWindow = lib.mkOption {
      type = lib.types.int;
      default = 3600;  # 1 hour
      description = "Time window for installation operations (seconds)";
    };
    
    firstBootWindow = lib.mkOption {
      type = lib.types.int;
      default = 3600;  # 1 hour
      description = "Time window for first boot operations (seconds)";
    };
    
    recoveryWindow = lib.mkOption {
      type = lib.types.int;
      default = 7200;  # 2 hours
      description = "Time window for recovery operations (seconds)";
    };
    
    businessHoursStart = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = "Start of business hours (24-hour format)";
    };
    
    businessHoursEnd = lib.mkOption {
      type = lib.types.int;
      default = 18;
      description = "End of business hours (24-hour format)";
    };
    
    allowWeekends = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow sensitive operations on weekends";
    };
    
    extensionDuration = lib.mkOption {
      type = lib.types.int;
      default = 1800;  # 30 minutes
      description = "Duration of time window extensions (seconds)";
    };
    
    enforceBusinessHours = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enforce business hours for operations";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install time window tools
    environment.systemPackages = [
      timeWindowChecker
      gracePeriodExtender
    ];
    
    # Add time window check to first boot
    systemd.services.hypervisor-first-boot = lib.mkIf config.hypervisor.firstBoot.enable {
      serviceConfig = {
        ExecStartPre = [
          "${timeWindowChecker}/bin/check-time-window check first-boot"
        ] ++ lib.optional cfg.enforceBusinessHours
          "${timeWindowChecker}/bin/check-time-window business-hours";
      };
    };
    
    # Time window state directory
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor 0755 root root -"
    ];
    
    # Audit time-sensitive operations - only if audit is available
    security.audit = lib.mkIf (config.security ? audit) {
      rules = lib.mkAfter [
        # Log time window checks
        "-w /var/lib/hypervisor/.time-extension-token -p wa -k time_extension"
        "-w /var/lib/hypervisor/.maintenance-window -p wa -k maintenance_window"
      ];
    };
  };
}