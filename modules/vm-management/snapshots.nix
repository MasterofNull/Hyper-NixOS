{ config, lib, pkgs, ... }:

# Snapshot Lifecycle Management
# Automates snapshot creation, retention, and cleanup

{
  environment.systemPackages =  [
    pkgs.libvirt
    pkgs.qemu_kvm
  ];
  
  # Snapshot management script
  environment.etc."hypervisor/scripts/snapshot_manager.sh" = {
    text = ''
      #!/usr/bin/env bash
      #
      # Hyper-NixOS Snapshot Lifecycle Manager
      # Copyright (C) 2024-2025 MasterofNull
      # Licensed under GPL v3.0
      #
      # Manages VM snapshots with automatic lifecycle policies
      
      set -euo pipefail
      PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      
      SNAPSHOT_CONFIG="/var/lib/hypervisor/configuration/snapshot-policies.conf"
      SNAPSHOT_LOG="/var/lib/hypervisor/logs/snapshots.log"
      
      mkdir -p "$(dirname "$SNAPSHOT_LOG")" 2>/dev/null || true
      
      log() {
        echo "[$(date -Iseconds)] $*" | tee -a "$SNAPSHOT_LOG"
      }
      
      usage() {
        cat <<EOF
      Usage: $(basename "$0") <command> [options]
      
      Commands:
        create <vm> [description]           Create snapshot
        list <vm>                           List snapshots
        restore <vm> <snapshot-name>        Restore snapshot
        delete <vm> <snapshot-name>         Delete snapshot
        set-policy <vm> <policy>            Set retention policy
        apply-policy <vm>                   Apply retention policy
        auto-snapshot <vm>                  Create automatic snapshot
        cleanup <vm>                        Remove old snapshots
      
      Retention Policies:
        hourly:N    Keep N hourly snapshots
        daily:N     Keep N daily snapshots
        weekly:N    Keep N weekly snapshots
        monthly:N   Keep N monthly snapshots
        manual      Keep all (manual cleanup only)
      
      Examples:
        # Create manual snapshot
        $(basename "$0") create web-server "Before upgrade"
        
        # Set retention policy (keep 7 daily, 4 weekly)
        $(basename "$0") set-policy web-server "daily:7,weekly:4"
        
        # Create automatic snapshot (uses policy)
        $(basename "$0") auto-snapshot web-server
        
        # List all snapshots
        $(basename "$0") list web-server
        
        # Restore specific snapshot
        $(basename "$0") restore web-server snapshot-20250112-1200
        
        # Clean up old snapshots per policy
        $(basename "$0") cleanup web-server
      
      Snapshot Types:
        Internal:  Stored within VM disk (fast, live snapshot)
        External:  Separate file (slower, more reliable)
        
      Default: Internal snapshots for speed and simplicity
      EOF
      }
      
      # Initialize policy database
      init_policy_db() {
        mkdir -p "$(dirname "$SNAPSHOT_CONFIG")"
        
        if [[ ! -f "$SNAPSHOT_CONFIG" ]]; then
          cat > "$SNAPSHOT_CONFIG" <<EOF
      # Snapshot Retention Policies
      # Format: vm_name|policy
      # Policy examples:
      #   hourly:24,daily:7,weekly:4
      #   daily:30
      #   manual
      EOF
        fi
      }
      
      # Create snapshot
      create_snapshot() {
        local vm="$1"
        local description="''${2:-Snapshot created at $(date)}"
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local snapshot_name="snapshot-$timestamp"
        
        if ! virsh list --all --name | grep -q "^$vm$"; then
          echo "Error: VM $vm not found" >&2
          return 1
        fi
        
        log "Creating snapshot for VM: $vm"
        log "  Name: $snapshot_name"
        log "  Description: $description"
        
        # Create internal snapshot
        virsh snapshot-create-as "$vm" \
          "$snapshot_name" \
          "$description" \
          --atomic
        
        log "✓ Snapshot created successfully"
        
        echo "Snapshot created: $snapshot_name"
        
        # Apply retention policy if configured
        apply_retention_policy "$vm"
      }
      
      # List snapshots
      list_snapshots() {
        local vm="$1"
        
        if ! virsh list --all --name | grep -q "^$vm$"; then
          echo "Error: VM $vm not found" >&2
          return 1
        fi
        
        echo "Snapshots for VM: $vm"
        echo ""
        
        virsh snapshot-list "$vm" --tree
        
        echo ""
        echo "Detailed information:"
        echo ""
        
        local snapshots=$(virsh snapshot-list "$vm" --name)
        
        for snapshot in $snapshots; do
          echo "Snapshot: $snapshot"
          virsh snapshot-info "$vm" "$snapshot" | grep -E "Name:|State:|Creation Time:" | sed 's/^/  /'
          echo ""
        done
      }
      
      # Restore snapshot
      restore_snapshot() {
        local vm="$1"
        local snapshot="$2"
        
        if ! virsh list --all --name | grep -q "^$vm$"; then
          echo "Error: VM $vm not found" >&2
          return 1
        fi
        
        if ! virsh snapshot-list "$vm" --name | grep -q "^$snapshot$"; then
          echo "Error: Snapshot $snapshot not found" >&2
          return 1
        fi
        
        log "Restoring snapshot for VM: $vm"
        log "  Snapshot: $snapshot"
        
        # Check if VM is running
        if virsh list --name | grep -q "^$vm$"; then
          echo "VM is running - shutting down for restore..."
          virsh shutdown "$vm"
          
          # Wait for shutdown (max 60 seconds)
          local timeout=60
          while [[ $timeout -gt 0 ]] && virsh list --name | grep -q "^$vm$"; do
            sleep 1
            ((timeout--))
          done
          
          if virsh list --name | grep -q "^$vm$"; then
            echo "Forcing shutdown..."
            virsh destroy "$vm"
          fi
        fi
        
        # Restore snapshot
        virsh snapshot-revert "$vm" "$snapshot"
        
        log "✓ Snapshot restored successfully"
        
        echo "✓ Snapshot restored: $snapshot"
        echo ""
        echo "VM is in shutdown state. Start with:"
        echo "  virsh start $vm"
      }
      
      # Delete snapshot
      delete_snapshot() {
        local vm="$1"
        local snapshot="$2"
        
        if ! virsh snapshot-list "$vm" --name | grep -q "^$snapshot$"; then
          echo "Error: Snapshot $snapshot not found" >&2
          return 1
        fi
        
        log "Deleting snapshot: $vm / $snapshot"
        
        virsh snapshot-delete "$vm" "$snapshot" --metadata
        
        log "✓ Snapshot deleted"
        
        echo "✓ Snapshot deleted: $snapshot"
      }
      
      # Set retention policy
      set_retention_policy() {
        local vm="$1"
        local policy="$2"
        
        init_policy_db
        
        # Validate policy format
        if [[ ! "$policy" =~ ^(manual|hourly:[0-9]+|daily:[0-9]+|weekly:[0-9]+|monthly:[0-9]+)(,(hourly:[0-9]+|daily:[0-9]+|weekly:[0-9]+|monthly:[0-9]+))*$ ]]; then
          echo "Error: Invalid policy format" >&2
          echo "Examples: hourly:24, daily:7, hourly:24,daily:7,weekly:4" >&2
          return 1
        fi
        
        log "Setting retention policy for VM: $vm"
        log "  Policy: $policy"
        
        # Remove existing policy
        grep -v "^$vm|" "$SNAPSHOT_CONFIG" > "$SNAPSHOT_CONFIG.tmp" 2>/dev/null || true
        mv "$SNAPSHOT_CONFIG.tmp" "$SNAPSHOT_CONFIG"
        
        # Add new policy
        echo "$vm|$policy" >> "$SNAPSHOT_CONFIG"
        
        echo "✓ Retention policy set: $policy"
      }
      
      # Apply retention policy
      apply_retention_policy() {
        local vm="$1"
        
        init_policy_db
        
        local policy_line=$(grep "^$vm|" "$SNAPSHOT_CONFIG" 2>/dev/null || echo "")
        
        if [[ -z "$policy_line" ]]; then
          log "No retention policy set for VM: $vm"
          return 0
        fi
        
        IFS='|' read -r vm_name policy <<< "$policy_line"
        
        if [[ "$policy" == "manual" ]]; then
          log "Manual retention policy - no automatic cleanup"
          return 0
        fi
        
        log "Applying retention policy for VM: $vm"
        log "  Policy: $policy"
        
        # Parse policy (e.g., "hourly:24,daily:7")
        IFS=',' read -ra policy_parts <<< "$policy"
        
        local snapshots=$(virsh snapshot-list "$vm" --name)
        local now=$(date +%s)
        
        for part in "''${policy_parts[@]}"; do
          IFS=':' read -r interval keep <<< "$part"
          
          case "$interval" in
            hourly)
              local cutoff=$((now - 3600 * keep))
              ;;
            daily)
              local cutoff=$((now - 86400 * keep))
              ;;
            weekly)
              local cutoff=$((now - 604800 * keep))
              ;;
            monthly)
              local cutoff=$((now - 2592000 * keep))
              ;;
            *)
              continue
              ;;
          esac
          
          # Find and delete old snapshots
          for snapshot in $snapshots; do
            # Extract timestamp from snapshot name
            if [[ "$snapshot" =~ snapshot-([0-9]{8})-([0-9]{6}) ]]; then
              local snap_date="''${BASH_REMATCH[1]}"
              local snap_time="''${BASH_REMATCH[2]}"
              local snap_timestamp=$(date -d "''${snap_date:0:4}-''${snap_date:4:2}-''${snap_date:6:2} ''${snap_time:0:2}:''${snap_time:2:2}:''${snap_time:4:2}" +%s 2>/dev/null || echo "$now")
              
              if [[ $snap_timestamp -lt $cutoff ]]; then
                log "  Deleting old snapshot: $snapshot (older than $keep $interval)"
                virsh snapshot-delete "$vm" "$snapshot" --metadata 2>/dev/null || true
              fi
            fi
          done
        done
        
        log "✓ Retention policy applied"
      }
      
      # Create automatic snapshot
      auto_snapshot() {
        local vm="$1"
        
        create_snapshot "$vm" "Automatic snapshot"
      }
      
      # Cleanup old snapshots
      cleanup_snapshots() {
        local vm="$1"
        
        apply_retention_policy "$vm"
      }
      
      # Main
      case "''${1:-}" in
        create)
          create_snapshot "''${2:-}" "''${3:-}"
          ;;
        list)
          list_snapshots "''${2:-}"
          ;;
        restore)
          restore_snapshot "''${2:-}" "''${3:-}"
          ;;
        delete)
          delete_snapshot "''${2:-}" "''${3:-}"
          ;;
        set-policy)
          set_retention_policy "''${2:-}" "''${3:-}"
          ;;
        apply-policy)
          apply_retention_policy "''${2:-}"
          ;;
        auto-snapshot)
          auto_snapshot "''${2:-}"
          ;;
        cleanup)
          cleanup_snapshots "''${2:-}"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
    mode = "0755";
  };
  
  # Automatic snapshot service
  systemd.services.auto-snapshot = {
    description = "Automatic VM Snapshots";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeScript "auto-snapshot-all" ''
        #!/usr/bin/env bash
        # Create automatic snapshots for all configured VMs
        
        SNAPSHOT_CONFIG="/var/lib/hypervisor/configuration/snapshot-policies.conf"
        
        if [[ ! -f "$SNAPSHOT_CONFIG" ]]; then
          exit 0
        fi
        
        while IFS='|' read -r vm policy; do
          [[ "$vm" =~ ^# ]] && continue
          [[ -z "$vm" ]] && continue
          [[ "$policy" == "manual" ]] && continue
          
          echo "Creating automatic snapshot for: $vm"
          /etc/hypervisor/scripts/snapshot_manager.sh auto-snapshot "$vm" || true
        done < "$SNAPSHOT_CONFIG"
      '';
    };
  };
  
  # Daily automatic snapshots
  systemd.timers.auto-snapshot = {
    description = "Daily Automatic VM Snapshots";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
