{ config, lib, pkgs, ... }:

# VM Creation Limits Module
# Prevents resource exhaustion by limiting number of VMs and their creation rate
# Complements resource-quotas.nix which manages per-VM resource limits

with lib;

let
  cfg = config.hypervisor.vmLimits;

in {
  options.hypervisor.vmLimits = {
    enable = mkEnableOption "VM creation limits";

    global = {
      maxTotalVMs = mkOption {
        type = types.int;
        default = 100;
        description = ''
          Maximum total number of VMs allowed on the system.
          Prevents system resource exhaustion.
        '';
      };

      maxRunningVMs = mkOption {
        type = types.int;
        default = 50;
        description = ''
          Maximum number of VMs that can run concurrently.
          Based on available system resources.
        '';
      };

      maxVMsPerHour = mkOption {
        type = types.int;
        default = 10;
        description = ''
          Rate limit: Maximum VMs that can be created per hour.
          Prevents rapid VM creation attacks.
        '';
      };
    };

    perUser = {
      enable = mkEnableOption "per-user VM limits";

      maxVMsPerUser = mkOption {
        type = types.int;
        default = 20;
        description = ''
          Maximum VMs per user (applies to hypervisor-users group).
          System admins are exempt from this limit.
        '';
      };

      maxRunningVMsPerUser = mkOption {
        type = types.int;
        default = 10;
        description = ''
          Maximum concurrently running VMs per user.
        '';
      };

      userExceptions = mkOption {
        type = types.attrsOf types.int;
        default = {};
        example = { alice = 50; bob = 30; };
        description = ''
          Per-user exceptions to maxVMsPerUser.
          Format: { username = max_vms; }
        '';
      };
    };

    storage = {
      maxDiskPerVM = mkOption {
        type = types.int;
        default = 500;
        description = ''
          Maximum disk size per VM in GB.
          Prevents individual VMs from consuming all storage.
        '';
      };

      maxTotalStorage = mkOption {
        type = types.int;
        default = 5000;
        description = ''
          Maximum total storage for all VMs in GB.
          Reserves space for system and other data.
        '';
      };

      maxSnapshotsPerVM = mkOption {
        type = types.int;
        default = 10;
        description = ''
          Maximum snapshots per VM.
          Prevents snapshot sprawl.
        '';
      };
    };

    enforcement = {
      blockExcessCreation = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If true, prevents VM creation when limits are exceeded.
          If false, only logs warnings.
        '';
      };

      notifyOnApproach = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Notify users when approaching limits (90% threshold).
        '';
      };

      adminOverride = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Allow system admins to override limits with explicit flag.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    # Create limits configuration file
    environment.etc."hypervisor/vm-limits.conf" = {
      text = ''
        # Hyper-NixOS VM Creation Limits
        # Generated from NixOS configuration

        [global]
        max_total_vms=${toString cfg.global.maxTotalVMs}
        max_running_vms=${toString cfg.global.maxRunningVMs}
        max_vms_per_hour=${toString cfg.global.maxVMsPerHour}

        [per_user]
        enable=${if cfg.perUser.enable then "true" else "false"}
        max_vms_per_user=${toString cfg.perUser.maxVMsPerUser}
        max_running_vms_per_user=${toString cfg.perUser.maxRunningVMsPerUser}

        [storage]
        max_disk_per_vm=${toString cfg.storage.maxDiskPerVM}
        max_total_storage=${toString cfg.storage.maxTotalStorage}
        max_snapshots_per_vm=${toString cfg.storage.maxSnapshotsPerVM}

        [enforcement]
        block_excess_creation=${if cfg.enforcement.blockExcessCreation then "true" else "false"}
        notify_on_approach=${if cfg.enforcement.notifyOnApproach then "true" else "false"}
        admin_override=${if cfg.enforcement.adminOverride then "true" else "false"}

        ${optionalString (cfg.perUser.userExceptions != {}) ''
        [user_exceptions]
        ${concatStringsSep "\n" (mapAttrsToList (user: limit: "${user}=${toString limit}") cfg.perUser.userExceptions)}
        ''}
      '';
      mode = "0644";
    };

    # VM Limits Enforcement Script
    environment.systemPackages = [
      (pkgs.writeScriptBin "hv-check-vm-limits" ''
        #!${pkgs.bash}/bin/bash
        #
        # VM Limits Checker
        # Checks if VM creation is allowed based on configured limits
        #
        set -euo pipefail

        LIMITS_CONF="/etc/hypervisor/vm-limits.conf"
        LIMITS_DB="/var/lib/hypervisor/vm-limits.db"
        CREATION_LOG="/var/log/hypervisor/vm-creation.log"

        # Colors for output
        RED='\033[0;31m'
        YELLOW='\033[1;33m'
        GREEN='\033[0;32m'
        NC='\033[0m' # No Color

        # Source configuration
        if [[ -f "$LIMITS_CONF" ]]; then
          source <(grep = "$LIMITS_CONF" | sed 's/ *= */=/g')
        else
          echo "Error: Limits configuration not found: $LIMITS_CONF" >&2
          exit 1
        fi

        # Initialize database
        mkdir -p "$(dirname "$LIMITS_DB")"
        mkdir -p "$(dirname "$CREATION_LOG")"

        # Get current stats
        get_total_vms() {
          virsh list --all --name 2>/dev/null | grep -v '^$' | wc -l
        }

        get_running_vms() {
          virsh list --name 2>/dev/null | grep -v '^$' | wc -l
        }

        get_user_vms() {
          local user="$1"
          virsh -c qemu:///system list --all --name 2>/dev/null | \
            grep -c "^''${user}-" || echo 0
        }

        get_user_running_vms() {
          local user="$1"
          virsh -c qemu:///system list --name 2>/dev/null | \
            grep -c "^''${user}-" || echo 0
        }

        get_total_storage() {
          du -sb /var/lib/libvirt/images 2>/dev/null | \
            awk '{print int($1/1024/1024/1024)}' || echo 0
        }

        get_vms_created_last_hour() {
          if [[ ! -f "$CREATION_LOG" ]]; then
            echo 0
            return
          fi

          local hour_ago=$(date -d '1 hour ago' '+%s')
          grep "^[0-9]" "$CREATION_LOG" 2>/dev/null | \
            awk -v cutoff="$hour_ago" '$1 >= cutoff {count++} END {print count+0}'
        }

        # Log VM creation
        log_creation() {
          local vm_name="$1"
          local user="''${2:-unknown}"
          local timestamp=$(date '+%s')
          echo "$timestamp|$user|$vm_name" >> "$CREATION_LOG"

          # Keep only last 7 days
          local week_ago=$(date -d '7 days ago' '+%s')
          grep "^[0-9]" "$CREATION_LOG" | \
            awk -v cutoff="$week_ago" '$1 >= cutoff' > "$CREATION_LOG.tmp" || true
          mv "$CREATION_LOG.tmp" "$CREATION_LOG" 2>/dev/null || true
        }

        # Check if user is admin
        is_admin() {
          local user="$1"
          groups "$user" 2>/dev/null | grep -q '\b\(wheel\|hypervisor-admins\)\b'
        }

        # Get user-specific limit
        get_user_limit() {
          local user="$1"

          # Check exceptions first
          if grep -q "^\[user_exceptions\]" "$LIMITS_CONF" 2>/dev/null; then
            local limit=$(sed -n '/\[user_exceptions\]/,/\[/p' "$LIMITS_CONF" | \
              grep "^$user=" | cut -d= -f2)
            if [[ -n "$limit" ]]; then
              echo "$limit"
              return
            fi
          fi

          echo "$max_vms_per_user"
        }

        # Main check function
        check_limits() {
          local user="''${1:-$(whoami)}"
          local disk_size="''${2:-0}"  # GB
          local override_flag="''${3:-false}"

          local total_vms=$(get_total_vms)
          local running_vms=$(get_running_vms)
          local total_storage=$(get_total_storage)
          local hourly_creates=$(get_vms_created_last_hour)

          local errors=()
          local warnings=()

          # Check global limits
          if [[ $total_vms -ge $max_total_vms ]]; then
            errors+=("Global VM limit reached: $total_vms/$max_total_vms")
          elif [[ $total_vms -ge $((max_total_vms * 90 / 100)) ]]; then
            warnings+=("Approaching global VM limit: $total_vms/$max_total_vms (90%)")
          fi

          if [[ $running_vms -ge $max_running_vms ]]; then
            errors+=("Global running VM limit reached: $running_vms/$max_running_vms")
          fi

          # Check rate limiting
          if [[ $hourly_creates -ge $max_vms_per_hour ]]; then
            errors+=("Rate limit exceeded: $hourly_creates VMs created in last hour (max: $max_vms_per_hour)")
          fi

          # Check per-user limits (if enabled and user is not admin)
          if [[ "$enable" == "true" ]] && ! is_admin "$user"; then
            local user_limit=$(get_user_limit "$user")
            local user_vms=$(get_user_vms "$user")
            local user_running=$(get_user_running_vms "$user")

            if [[ $user_vms -ge $user_limit ]]; then
              errors+=("User VM limit reached: $user_vms/$user_limit for $user")
            elif [[ $user_vms -ge $((user_limit * 90 / 100)) ]]; then
              warnings+=("Approaching user VM limit: $user_vms/$user_limit (90%)")
            fi

            if [[ $user_running -ge $max_running_vms_per_user ]]; then
              errors+=("User running VM limit reached: $user_running/$max_running_vms_per_user for $user")
            fi
          fi

          # Check storage limits
          if [[ $disk_size -gt $max_disk_per_vm ]]; then
            errors+=("Requested disk size ($disk_size GB) exceeds per-VM limit ($max_disk_per_vm GB)")
          fi

          local projected_storage=$((total_storage + disk_size))
          if [[ $projected_storage -gt $max_total_storage ]]; then
            errors+=("Insufficient storage: would use $projected_storage GB (max: $max_total_storage GB)")
          elif [[ $projected_storage -gt $((max_total_storage * 90 / 100)) ]]; then
            warnings+=("Approaching storage limit: $projected_storage/$max_total_storage GB (90%)")
          fi

          # Display results
          echo "════════════════════════════════════════════════════════════"
          echo "  VM Creation Limits Check"
          echo "════════════════════════════════════════════════════════════"
          echo ""
          echo "Current Status:"
          echo "  Total VMs:       $total_vms / $max_total_vms"
          echo "  Running VMs:     $running_vms / $max_running_vms"
          echo "  Storage Used:    $total_storage GB / $max_total_storage GB"
          echo "  Created/Hour:    $hourly_creates / $max_vms_per_hour"

          if [[ "$enable" == "true" ]] && ! is_admin "$user"; then
            local user_limit=$(get_user_limit "$user")
            local user_vms=$(get_user_vms "$user")
            local user_running=$(get_user_running_vms "$user")
            echo ""
            echo "User Limits ($user):"
            echo "  Total VMs:       $user_vms / $user_limit"
            echo "  Running VMs:     $user_running / $max_running_vms_per_user"
          fi

          # Show warnings
          if [[ ''${#warnings[@]} -gt 0 ]]; then
            echo ""
            echo -e "''${YELLOW}Warnings:''${NC}"
            for warning in "''${warnings[@]}"; do
              echo -e "  ''${YELLOW}⚠''${NC} $warning"
            done
          fi

          # Show errors
          if [[ ''${#errors[@]} -gt 0 ]]; then
            echo ""
            echo -e "''${RED}Errors:''${NC}"
            for error in "''${errors[@]}"; do
              echo -e "  ''${RED}✗''${NC} $error"
            done
            echo ""

            # Check for admin override
            if [[ "$admin_override" == "true" ]] && is_admin "$user" && [[ "$override_flag" == "true" ]]; then
              echo -e "''${YELLOW}Admin override active - limits bypassed''${NC}"
              echo "════════════════════════════════════════════════════════════"
              return 0
            fi

            if [[ "$block_excess_creation" == "true" ]]; then
              echo -e "''${RED}VM creation blocked by limits''${NC}"
              echo ""
              if [[ "$admin_override" == "true" ]]; then
                echo "Admins can override with: --force-override"
              fi
              echo "════════════════════════════════════════════════════════════"
              return 1
            else
              echo -e "''${YELLOW}Warning mode: VM creation allowed but logged''${NC}"
              echo "════════════════════════════════════════════════════════════"
              return 0
            fi
          fi

          echo ""
          echo -e "''${GREEN}✓ All limits satisfied - VM creation allowed''${NC}"
          echo "════════════════════════════════════════════════════════════"
          return 0
        }

        # Command line interface
        case "''${1:-check}" in
          check)
            check_limits "''${2:-$(whoami)}" "''${3:-0}" "''${4:-false}"
            ;;
          log)
            log_creation "$2" "''${3:-$(whoami)}"
            ;;
          status)
            check_limits "$(whoami)" "0" "false"
            ;;
          *)
            echo "Usage: $(basename "$0") {check|log|status}" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  check [user] [disk_gb] [override]  - Check if VM creation allowed" >&2
            echo "  log <vm_name> [user]               - Log VM creation" >&2
            echo "  status                             - Show current status" >&2
            exit 1
            ;;
        esac
      '')
    ];

    # Warning messages for users approaching limits
    environment.etc."hypervisor/docs/vm-limits.md" = {
      text = ''
        # VM Creation Limits

        Hyper-NixOS enforces VM creation limits to prevent resource exhaustion and maintain system stability.

        ## Current Limits

        ### Global Limits
        - Maximum total VMs: ${toString cfg.global.maxTotalVMs}
        - Maximum running VMs: ${toString cfg.global.maxRunningVMs}
        - Creation rate limit: ${toString cfg.global.maxVMsPerHour} VMs per hour

        ### Per-User Limits
        ${if cfg.perUser.enable then ''
        - Maximum VMs per user: ${toString cfg.perUser.maxVMsPerUser}
        - Maximum running VMs per user: ${toString cfg.perUser.maxRunningVMsPerUser}
        - System admins are exempt from per-user limits
        '' else "Per-user limits are disabled"}

        ### Storage Limits
        - Maximum disk per VM: ${toString cfg.storage.maxDiskPerVM} GB
        - Maximum total storage: ${toString cfg.storage.maxTotalStorage} GB
        - Maximum snapshots per VM: ${toString cfg.storage.maxSnapshotsPerVM}

        ## Enforcement
        ${if cfg.enforcement.blockExcessCreation then ''
        - **Strict mode**: VM creation is blocked when limits are exceeded
        '' else ''
        - **Warning mode**: Limits exceeded are logged but creation is allowed
        ''}

        ${if cfg.enforcement.adminOverride then ''
        - System admins can override limits with `--force-override` flag
        '' else ""}

        ## Checking Your Limits

        To check current VM limits and your usage:
        ```bash
        hv-check-vm-limits status
        ```

        ## Requesting Limit Increases

        If you need higher limits:
        1. Contact your system administrator
        2. Provide justification for the increased limits
        3. Admin can adjust limits in `/etc/nixos/configuration.nix`
      '';
      mode = "0644";
    };
  };
}
