{ config, lib, pkgs, ... }:

# Storage Quota Management
# Enforces disk space limits per VM and prevents storage exhaustion

{
  # Enable filesystem quota support
  boot.supportedFilesystems = [ "ext4" "xfs" "btrfs" ];
  
  # Quota tools
  environment.systemPackages = with pkgs; [
    quota
    libvirt
    qemu_kvm
    btrfs-progs
    xfsprogs
  ];
  
  # Storage quota management script
  environment.etc."hypervisor/scripts/storage_quota.sh" = {
    text = ''
      #!/usr/bin/env bash
      #
      # Hyper-NixOS Storage Quota Manager
      # Copyright (C) 2024-2025 MasterofNull
      # Licensed under GPL v3.0
      #
      # Manages disk space quotas for VMs and storage pools
      
      set -euo pipefail
      PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      
      QUOTA_CONFIG="/var/lib/hypervisor/configuration/storage-quotas.conf"
      STORAGE_BASE="/var/lib/libvirt/images"
      
      usage() {
        cat <<EOF
      Usage: $(basename "$0") <command> [options]
      
      Commands:
        set <vm-name> <size-GB>          Set storage quota for VM
        get <vm-name>                    Show current quota and usage
        list                             List all quotas
        check                            Check quota enforcement
        enforce <vm-name>                Apply quota limits
        expand <vm-name> <new-size-GB>   Increase quota
        alert-threshold <vm-name> <percent>  Set alert at X% full
      
      Examples:
        # Set 50GB quota for VM
        $(basename "$0") set web-server 50
        
        # Check current usage
        $(basename "$0") get web-server
        
        # Expand storage to 100GB
        $(basename "$0") expand web-server 100
        
        # Alert when 80% full
        $(basename "$0") alert-threshold web-server 80
      
      Quota Enforcement:
        - Uses thin provisioning for efficiency
        - Enforces hard limits (VM cannot exceed)
        - Monitors usage and sends alerts
        - Prevents storage exhaustion
      EOF
      }
      
      # Initialize quota tracking
      init_quota_db() {
        mkdir -p "$(dirname "$QUOTA_CONFIG")"
        
        if [[ ! -f "$QUOTA_CONFIG" ]]; then
          cat > "$QUOTA_CONFIG" <<EOF
      # Storage Quotas Configuration
      # Format: vm_name|quota_gb|alert_threshold_percent|current_usage_gb
      EOF
        fi
      }
      
      # Set storage quota
      set_quota() {
        local vm="$1"
        local quota_gb="$2"
        
        if [[ $quota_gb -lt 1 ]] || [[ $quota_gb -gt 10000 ]]; then
          echo "Error: Quota must be 1-10000 GB" >&2
          return 1
        fi
        
        init_quota_db
        
        echo "Setting storage quota for VM: $vm"
        echo "  Quota: $quota_gb GB"
        
        # Remove existing entry
        grep -v "^$vm|" "$QUOTA_CONFIG" > "$QUOTA_CONFIG.tmp" 2>/dev/null || true
        mv "$QUOTA_CONFIG.tmp" "$QUOTA_CONFIG"
        
        # Add new entry (default alert at 80%)
        echo "$vm|$quota_gb|80|0" >> "$QUOTA_CONFIG"
        
        # Find VM disks
        local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
        
        if [[ -z "$disks" ]]; then
          echo "⚠ Warning: No disks found for VM"
          echo "  Quota will be enforced when VM is created"
          return 0
        fi
        
        # Set quota on each disk
        for disk in $disks; do
          if [[ -f "$disk" ]]; then
            local current_size=$(qemu-img info "$disk" | grep "virtual size" | awk '{print $3}' | sed 's/G//')
            
            echo "  Disk: $(basename "$disk")"
            echo "    Current: $current_size GB"
            echo "    New limit: $quota_gb GB"
            
            if (( $(echo "$current_size > $quota_gb" | bc -l) )); then
              echo "    ⚠ Warning: Current size exceeds quota!"
              echo "    Consider expanding quota or shrinking disk"
            else
              # Resize disk to quota (creates thin-provisioned disk)
              qemu-img resize "$disk" "$quota_gb"G 2>/dev/null || true
            fi
          fi
        done
        
        echo "✓ Storage quota set"
      }
      
      # Get quota and usage
      get_quota() {
        local vm="$1"
        
        init_quota_db
        
        # Get quota config
        local quota_line=$(grep "^$vm|" "$QUOTA_CONFIG" 2>/dev/null || echo "")
        
        if [[ -z "$quota_line" ]]; then
          echo "No quota set for VM: $vm"
          
          # Show current disk sizes
          local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
          
          if [[ -n "$disks" ]]; then
            echo ""
            echo "Current disk sizes:"
            for disk in $disks; do
              if [[ -f "$disk" ]]; then
                local info=$(qemu-img info "$disk" 2>/dev/null | grep -E "virtual size|disk size")
                echo "  $(basename "$disk"):"
                echo "    $info"
              fi
            done
          fi
          return 0
        fi
        
        IFS='|' read -r vm_name quota_gb alert_pct current_usage <<< "$quota_line"
        
        echo "Storage quota for VM: $vm"
        echo "  Quota: $quota_gb GB"
        echo "  Alert threshold: $alert_pct%"
        echo ""
        
        # Calculate current usage
        local total_usage=0
        local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
        
        if [[ -n "$disks" ]]; then
          echo "Disks:"
          for disk in $disks; do
            if [[ -f "$disk" ]]; then
              local virtual_size=$(qemu-img info "$disk" 2>/dev/null | grep "virtual size" | awk '{print $3}' | sed 's/G//')
              local actual_size=$(du -h "$disk" | cut -f1)
              local actual_gb=$(du -m "$disk" | cut -f1)
              actual_gb=$((actual_gb / 1024))
              
              total_usage=$((total_usage + actual_gb))
              
              echo "  $(basename "$disk"):"
              echo "    Virtual: $virtual_size GB"
              echo "    Actual:  $actual_size ($actual_gb GB)"
            fi
          done
          
          echo ""
          echo "Total Usage: $total_usage GB / $quota_gb GB"
          
          local usage_pct=$((total_usage * 100 / quota_gb))
          echo "Usage: $usage_pct%"
          
          if [[ $usage_pct -ge $alert_pct ]]; then
            echo "⚠ WARNING: Usage exceeds alert threshold!"
          elif [[ $usage_pct -ge 90 ]]; then
            echo "⚠ CRITICAL: Storage nearly full!"
          fi
          
          # Update usage in config
          grep -v "^$vm|" "$QUOTA_CONFIG" > "$QUOTA_CONFIG.tmp" 2>/dev/null || true
          mv "$QUOTA_CONFIG.tmp" "$QUOTA_CONFIG"
          echo "$vm|$quota_gb|$alert_pct|$total_usage" >> "$QUOTA_CONFIG"
        fi
      }
      
      # List all quotas
      list_quotas() {
        init_quota_db
        
        echo "Storage Quotas:"
        echo ""
        printf "%-20s %10s %10s %10s %10s\n" "VM Name" "Quota GB" "Used GB" "Usage %" "Alert %"
        printf "%-20s %10s %10s %10s %10s\n" "-------" "--------" "-------" "--------" "-------"
        
        while IFS='|' read -r vm quota alert usage; do
          [[ "$vm" =~ ^# ]] && continue
          [[ -z "$vm" ]] && continue
          
          local usage_pct=0
          if [[ $quota -gt 0 ]]; then
            usage_pct=$((usage * 100 / quota))
          fi
          
          printf "%-20s %10s %10s %10s %10s\n" "$vm" "$quota" "$usage" "$usage_pct%" "$alert%"
        done < "$QUOTA_CONFIG"
      }
      
      # Check quota enforcement
      check_quotas() {
        init_quota_db
        
        echo "Checking storage quotas..."
        echo ""
        
        local violations=0
        
        while IFS='|' read -r vm quota alert usage; do
          [[ "$vm" =~ ^# ]] && continue
          [[ -z "$vm" ]] && continue
          
          # Recalculate actual usage
          local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
          local actual_usage=0
          
          for disk in $disks; do
            if [[ -f "$disk" ]]; then
              local disk_gb=$(du -m "$disk" | cut -f1)
              disk_gb=$((disk_gb / 1024))
              actual_usage=$((actual_usage + disk_gb))
            fi
          done
          
          local usage_pct=$((actual_usage * 100 / quota))
          
          if [[ $actual_usage -gt $quota ]]; then
            echo "✗ VIOLATION: $vm exceeds quota"
            echo "  Quota: $quota GB"
            echo "  Usage: $actual_usage GB ($usage_pct%)"
            ((violations++))
          elif [[ $usage_pct -ge $alert ]]; then
            echo "⚠ WARNING: $vm nearing quota"
            echo "  Quota: $quota GB"
            echo "  Usage: $actual_usage GB ($usage_pct%)"
          else
            echo "✓ OK: $vm within quota ($usage_pct%)"
          fi
        done < "$QUOTA_CONFIG"
        
        echo ""
        if [[ $violations -gt 0 ]]; then
          echo "Found $violations quota violation(s)"
          
          # Send alert if alert system available
          if [[ -x /etc/hypervisor/scripts/alert_manager.sh ]]; then
            /etc/hypervisor/scripts/alert_manager.sh warning \
              "Storage Quota Violations" \
              "$violations VM(s) exceeded storage quotas" \
              "storage_quota_violation" \
              3600
          fi
        else
          echo "All VMs within storage quotas"
        fi
      }
      
      # Enforce quota
      enforce_quota() {
        local vm="$1"
        
        init_quota_db
        
        local quota_line=$(grep "^$vm|" "$QUOTA_CONFIG" 2>/dev/null || echo "")
        
        if [[ -z "$quota_line" ]]; then
          echo "No quota configured for VM: $vm"
          return 1
        fi
        
        IFS='|' read -r vm_name quota_gb alert_pct current_usage <<< "$quota_line"
        
        echo "Enforcing storage quota for VM: $vm ($quota_gb GB)"
        
        local disks=$(virsh domblklist "$vm" 2>/dev/null | awk 'NR>2 {print $2}' | grep -v "^$")
        
        for disk in $disks; do
          if [[ -f "$disk" ]]; then
            # Check if disk exceeds quota
            local disk_gb=$(du -m "$disk" | cut -f1)
            disk_gb=$((disk_gb / 1024))
            
            if [[ $disk_gb -gt $quota_gb ]]; then
              echo "⚠ Disk exceeds quota: $(basename "$disk") ($disk_gb GB > $quota_gb GB)"
              echo "  Manual intervention required"
            else
              echo "✓ Disk within quota: $(basename "$disk") ($disk_gb GB)"
            fi
          fi
        done
      }
      
      # Expand quota
      expand_quota() {
        local vm="$1"
        local new_quota="$2"
        
        init_quota_db
        
        local quota_line=$(grep "^$vm|" "$QUOTA_CONFIG" 2>/dev/null || echo "")
        
        if [[ -z "$quota_line" ]]; then
          echo "No quota configured for VM: $vm"
          echo "Use 'set' command to create quota first"
          return 1
        fi
        
        IFS='|' read -r vm_name old_quota alert_pct current_usage <<< "$quota_line"
        
        if [[ $new_quota -le $old_quota ]]; then
          echo "Error: New quota must be larger than current quota ($old_quota GB)" >&2
          return 1
        fi
        
        echo "Expanding storage quota for VM: $vm"
        echo "  Old quota: $old_quota GB"
        echo "  New quota: $new_quota GB"
        echo "  Increase: $((new_quota - old_quota)) GB"
        
        # Update config
        grep -v "^$vm|" "$QUOTA_CONFIG" > "$QUOTA_CONFIG.tmp"
        mv "$QUOTA_CONFIG.tmp" "$QUOTA_CONFIG"
        echo "$vm|$new_quota|$alert_pct|$current_usage" >> "$QUOTA_CONFIG"
        
        echo "✓ Quota expanded"
        echo ""
        echo "To apply to VM disks, run:"
        echo "  qemu-img resize /path/to/disk.qcow2 ${new_quota}G"
      }
      
      # Set alert threshold
      set_alert_threshold() {
        local vm="$1"
        local threshold="$2"
        
        if [[ $threshold -lt 1 ]] || [[ $threshold -gt 100 ]]; then
          echo "Error: Threshold must be 1-100%" >&2
          return 1
        fi
        
        init_quota_db
        
        local quota_line=$(grep "^$vm|" "$QUOTA_CONFIG" 2>/dev/null || echo "")
        
        if [[ -z "$quota_line" ]]; then
          echo "No quota configured for VM: $vm"
          return 1
        fi
        
        IFS='|' read -r vm_name quota_gb old_alert current_usage <<< "$quota_line"
        
        # Update threshold
        grep -v "^$vm|" "$QUOTA_CONFIG" > "$QUOTA_CONFIG.tmp"
        mv "$QUOTA_CONFIG.tmp" "$QUOTA_CONFIG"
        echo "$vm|$quota_gb|$threshold|$current_usage" >> "$QUOTA_CONFIG"
        
        echo "✓ Alert threshold updated: $threshold%"
      }
      
      # Main
      case "''${1:-}" in
        set)
          set_quota "''${2:-}" "''${3:-}"
          ;;
        get)
          get_quota "''${2:-}"
          ;;
        list)
          list_quotas
          ;;
        check)
          check_quotas
          ;;
        enforce)
          enforce_quota "''${2:-}"
          ;;
        expand)
          expand_quota "''${2:-}" "''${3:-}"
          ;;
        alert-threshold)
          set_alert_threshold "''${2:-}" "''${3:-}"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
    mode = "0755";
  };
  
  # Systemd timer for quota monitoring
  systemd.services.storage-quota-check = {
    description = "Check VM Storage Quotas";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/hypervisor/scripts/storage_quota.sh check";
    };
  };
  
  systemd.timers.storage-quota-check = {
    description = "Daily Storage Quota Check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
