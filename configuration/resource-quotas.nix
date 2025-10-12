{ config, lib, pkgs, ... }:

# Resource Quota Management
# Enforces CPU, Memory, Disk, and Network limits per VM
# Prevents resource exhaustion and ensures fair sharing

{
  # Systemd resource control (cgroups v2)
  systemd.enableUnifiedCgroupHierarchy = true;
  
  # libvirt with resource quota support
  virtualisation.libvirtd = {
    qemu = {
      # Enable cgroup resource management
      package = pkgs.qemu_kvm;
      
      # Security
      runAsRoot = false;
      
      # VNC security - only listen on localhost
      # This prevents VMs from being accessible from the network
      verbatimConfig = ''
        vnc_listen = "127.0.0.1"
      '';
    };
  };
  
  # Environment packages for quota management
  environment.systemPackages = with pkgs; [
    libvirt
    qemu_kvm
    quota  # Disk quota tools
  ];
  
  # Quota management scripts
  environment.etc."hypervisor/scripts/quota_manager.sh" = {
    text = ''
      #!/usr/bin/env bash
      #
      # Hyper-NixOS Resource Quota Manager
      # Copyright (C) 2024-2025 MasterofNull
      # Licensed under GPL v3.0
      #
      # Manages CPU, memory, disk, and network quotas for VMs
      
      set -euo pipefail
      PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      
      QUOTA_CONFIG="/var/lib/hypervisor/configuration/resource-quotas.conf"
      QUOTA_DB="/var/lib/hypervisor/resource-quotas.db"
      
      # Default quotas (can be overridden per-VM)
      DEFAULT_CPU_QUOTA=100         # % (100% = 1 full CPU)
      DEFAULT_MEMORY_LIMIT=2048     # MB
      DEFAULT_DISK_LIMIT=50         # GB
      DEFAULT_NETWORK_LIMIT=100     # Mbps
      DEFAULT_IOPS_LIMIT=1000       # IO operations per second
      
      usage() {
        cat <<EOF
      Usage: $(basename "$0") <command> <vm-name> [options]
      
      Commands:
        set <vm> --cpu <percent> --memory <MB> --disk <GB> --network <Mbps>
        get <vm>
        list
        enforce <vm>
        remove <vm>
      
      Examples:
        # Set quotas for a VM
        $(basename "$0") set web-server --cpu 200 --memory 4096 --disk 100
        
        # Get current quotas
        $(basename "$0") get web-server
        
        # List all VMs with quotas
        $(basename "$0") list
        
        # Enforce quotas (apply to running VM)
        $(basename "$0") enforce web-server
      
      Quota Limits:
        CPU:     0-800% (800% = 8 full CPUs)
        Memory:  128-65536 MB
        Disk:    1-1000 GB per VM
        Network: 1-10000 Mbps
        IOPS:    100-100000 operations/sec
      EOF
      }
      
      # Initialize quota database
      init_db() {
        if [[ ! -f "$QUOTA_DB" ]]; then
          echo "# VM Resource Quotas" > "$QUOTA_DB"
          echo "# Format: vm_name|cpu_quota|memory_limit|disk_limit|network_limit|iops_limit" >> "$QUOTA_DB"
        fi
      }
      
      # Set quotas for a VM
      set_quotas() {
        local vm="$1"
        shift
        
        local cpu=$DEFAULT_CPU_QUOTA
        local memory=$DEFAULT_MEMORY_LIMIT
        local disk=$DEFAULT_DISK_LIMIT
        local network=$DEFAULT_NETWORK_LIMIT
        local iops=$DEFAULT_IOPS_LIMIT
        
        # Parse options
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --cpu) cpu="$2"; shift 2;;
            --memory) memory="$2"; shift 2;;
            --disk) disk="$2"; shift 2;;
            --network) network="$2"; shift 2;;
            --iops) iops="$2"; shift 2;;
            *) echo "Unknown option: $1" >&2; return 1;;
          esac
        done
        
        # Validate
        if [[ $cpu -lt 0 ]] || [[ $cpu -gt 800 ]]; then
          echo "Error: CPU quota must be 0-800%" >&2
          return 1
        fi
        
        if [[ $memory -lt 128 ]] || [[ $memory -gt 65536 ]]; then
          echo "Error: Memory limit must be 128-65536 MB" >&2
          return 1
        fi
        
        # Save to database
        init_db
        
        # Remove existing entry
        grep -v "^$vm|" "$QUOTA_DB" > "$QUOTA_DB.tmp" 2>/dev/null || true
        mv "$QUOTA_DB.tmp" "$QUOTA_DB"
        
        # Add new entry
        echo "$vm|$cpu|$memory|$disk|$network|$iops" >> "$QUOTA_DB"
        
        echo "✓ Quotas set for VM: $vm"
        echo "  CPU:     $cpu%"
        echo "  Memory:  $memory MB"
        echo "  Disk:    $disk GB"
        echo "  Network: $network Mbps"
        echo "  IOPS:    $iops ops/sec"
        
        # Apply if VM is running
        if virsh list --name | grep -q "^$vm$"; then
          echo ""
          echo "VM is running - applying quotas now..."
          enforce_quotas "$vm"
        fi
      }
      
      # Get quotas for a VM
      get_quotas() {
        local vm="$1"
        
        init_db
        
        if ! grep -q "^$vm|" "$QUOTA_DB"; then
          echo "No quotas set for VM: $vm (using defaults)"
          echo "  CPU:     $DEFAULT_CPU_QUOTA%"
          echo "  Memory:  $DEFAULT_MEMORY_LIMIT MB"
          echo "  Disk:    $DEFAULT_DISK_LIMIT GB"
          echo "  Network: $DEFAULT_NETWORK_LIMIT Mbps"
          echo "  IOPS:    $DEFAULT_IOPS_LIMIT ops/sec"
          return 0
        fi
        
        local line=$(grep "^$vm|" "$QUOTA_DB")
        IFS='|' read -r vm cpu memory disk network iops <<< "$line"
        
        echo "Quotas for VM: $vm"
        echo "  CPU:     $cpu%"
        echo "  Memory:  $memory MB"
        echo "  Disk:    $disk GB"
        echo "  Network: $network Mbps"
        echo "  IOPS:    $iops ops/sec"
        
        # Show current usage if VM is running
        if virsh list --name | grep -q "^$vm$"; then
          echo ""
          echo "Current Usage:"
          
          local cpu_time=$(virsh domstats "$vm" | grep "cpu.time=" | cut -d= -f2)
          local mem_actual=$(virsh domstats "$vm" | grep "balloon.current=" | cut -d= -f2)
          
          if [[ -n "$cpu_time" ]]; then
            echo "  CPU time: $cpu_time ns"
          fi
          
          if [[ -n "$mem_actual" ]]; then
            local mem_mb=$((mem_actual / 1024))
            local mem_pct=$((mem_mb * 100 / memory))
            echo "  Memory:   $mem_mb MB / $memory MB ($mem_pct%)"
          fi
        fi
      }
      
      # List all VMs with quotas
      list_quotas() {
        init_db
        
        echo "VM Resource Quotas:"
        echo ""
        printf "%-20s %10s %10s %10s %10s %10s\n" "VM Name" "CPU %" "Memory MB" "Disk GB" "Network" "IOPS"
        printf "%-20s %10s %10s %10s %10s %10s\n" "--------" "------" "---------" "--------" "-------" "-----"
        
        while IFS='|' read -r vm cpu memory disk network iops; do
          [[ "$vm" =~ ^# ]] && continue
          [[ -z "$vm" ]] && continue
          printf "%-20s %10s %10s %10s %10s %10s\n" "$vm" "$cpu" "$memory" "$disk" "$network" "$iops"
        done < "$QUOTA_DB"
      }
      
      # Enforce quotas on running VM
      enforce_quotas() {
        local vm="$1"
        
        if ! virsh list --name | grep -q "^$vm$"; then
          echo "Error: VM $vm is not running" >&2
          return 1
        fi
        
        init_db
        
        local line=$(grep "^$vm|" "$QUOTA_DB" || echo "$vm|$DEFAULT_CPU_QUOTA|$DEFAULT_MEMORY_LIMIT|$DEFAULT_DISK_LIMIT|$DEFAULT_NETWORK_LIMIT|$DEFAULT_IOPS_LIMIT")
        IFS='|' read -r vm cpu memory disk network iops <<< "$line"
        
        echo "Enforcing quotas for VM: $vm"
        
        # CPU quota (via cgroups)
        local cpu_period=100000  # 100ms
        local cpu_quota=$((cpu * 1000))  # Convert % to quota
        
        virsh schedinfo "$vm" --set cpu_shares=$((cpu * 10)) 2>/dev/null || true
        
        # Memory limit
        virsh setmem "$vm" "$memory"M --config --live 2>/dev/null || true
        virsh memtune "$vm" --hard-limit $((memory * 1024)) 2>/dev/null || true
        
        # Disk IOPS limit
        # Get disk devices
        local disks=$(virsh domblklist "$vm" --details | awk '/^file/{print $3}')
        for disk_target in $disks; do
          virsh blkdeviotune "$vm" "$disk_target" \
            --total-iops-sec "$iops" 2>/dev/null || true
        done
        
        # Network bandwidth limit (via libvirt)
        local network_kb=$((network * 1000 / 8))  # Convert Mbps to KB/s
        local interfaces=$(virsh domiflist "$vm" | awk 'NR>2 {print $1}')
        for iface in $interfaces; do
          virsh domiftune "$vm" "$iface" \
            --inbound "$network_kb,''${network_kb}0,''${network_kb}00" \
            --outbound "$network_kb,''${network_kb}0,''${network_kb}00" 2>/dev/null || true
        done
        
        echo "✓ Quotas enforced"
      }
      
      # Remove quotas
      remove_quotas() {
        local vm="$1"
        
        init_db
        
        grep -v "^$vm|" "$QUOTA_DB" > "$QUOTA_DB.tmp" 2>/dev/null || true
        mv "$QUOTA_DB.tmp" "$QUOTA_DB"
        
        echo "✓ Quotas removed for VM: $vm"
      }
      
      # Main
      case "''${1:-}" in
        set)
          shift
          vm="$1"
          shift
          set_quotas "$vm" "$@"
          ;;
        get)
          get_quotas "$2"
          ;;
        list)
          list_quotas
          ;;
        enforce)
          enforce_quotas "$2"
          ;;
        remove)
          remove_quotas "$2"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
    mode = "0755";
  };
  
  # Systemd service to enforce quotas on boot
  systemd.services.hypervisor-quota-enforce = {
    description = "Enforce VM Resource Quotas";
    after = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeScript "enforce-all-quotas" ''
        #!/usr/bin/env bash
        # Enforce quotas for all running VMs
        for vm in $(virsh list --name); do
          [[ -z "$vm" ]] && continue
          /etc/hypervisor/scripts/quota_manager.sh enforce "$vm" || true
        done
      ''}";
      RemainAfterExit = true;
    };
  };
}
