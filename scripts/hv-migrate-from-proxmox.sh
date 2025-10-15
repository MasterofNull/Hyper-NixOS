#!/usr/bin/env bash
#
# hv-migrate-from-proxmox - Migrate VMs from Proxmox to Hyper-NixOS
#

set -euo pipefail

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Script metadata
SCRIPT_NAME="$(basename "$0")"
REQUIRES_SUDO=false
OPERATION_TYPE="migration"

# Default values
PROXMOX_HOST=""
PROXMOX_USER="root@pam"
PROXMOX_PORT="8006"
VM_ID=""
TARGET_STORAGE="local"
CONVERT_CONFIG=true
MIGRATE_NETWORK=true
MIGRATE_SNAPSHOTS=false
DRY_RUN=false
PROXMOX_PASSWORD=""
USE_API_TOKEN=false
API_TOKEN=""

# Help function
show_help() {
    cat << EOF
hv-migrate-from-proxmox - Migrate VMs from Proxmox to Hyper-NixOS

SYNOPSIS:
    $SCRIPT_NAME [OPTIONS] --source <proxmox-host> --vm <vmid>

DESCRIPTION:
    Migrate virtual machines from a Proxmox VE server to Hyper-NixOS.
    Supports configuration conversion, disk migration, and network mapping.

OPTIONS:
    -s, --source <host>       Proxmox host address
    -u, --user <user>         Proxmox user (default: $PROXMOX_USER)
    -P, --port <port>         Proxmox port (default: $PROXMOX_PORT)
    -v, --vm <vmid>           VM ID to migrate
    -p, --password <pass>     Proxmox password (or use PROXMOX_PASSWORD env)
    --api-token <token>       Use API token instead of password
    
    Migration Options:
    --target-storage <name>   Target storage pool (default: $TARGET_STORAGE)
    --no-convert             Don't convert configuration
    --no-network             Don't migrate network settings
    --with-snapshots         Include snapshots in migration
    
    Advanced:
    --network-map <map>       Network mapping (e.g., "vmbr0:vmbr0,vmbr1:vmbr2")
    --storage-map <map>       Storage mapping (e.g., "local:local,ceph:nfs")
    --cpu-map <map>          CPU type mapping
    --dry-run                Show what would be done without doing it
    
    -h, --help               Show this help message

EXAMPLES:
    # Basic migration
    $SCRIPT_NAME --source proxmox.example.com --vm 100 --password mypass
    
    # Migration with network mapping
    $SCRIPT_NAME --source 192.168.1.10 --vm 101 \\
        --network-map "vmbr0:vmbr0,vmbr1:bridge1" \\
        --with-snapshots
    
    # Using API token
    $SCRIPT_NAME --source proxmox.local --vm 102 \\
        --api-token "user@pve!tokenid=12345678-1234-1234-1234-123456789012"

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                PROXMOX_HOST="$2"
                shift 2
                ;;
            -u|--user)
                PROXMOX_USER="$2"
                shift 2
                ;;
            -P|--port)
                PROXMOX_PORT="$2"
                shift 2
                ;;
            -v|--vm)
                VM_ID="$2"
                shift 2
                ;;
            -p|--password)
                PROXMOX_PASSWORD="$2"
                shift 2
                ;;
            --api-token)
                API_TOKEN="$2"
                USE_API_TOKEN=true
                shift 2
                ;;
            --target-storage)
                TARGET_STORAGE="$2"
                shift 2
                ;;
            --no-convert)
                CONVERT_CONFIG=false
                shift
                ;;
            --no-network)
                MIGRATE_NETWORK=false
                shift
                ;;
            --with-snapshots)
                MIGRATE_SNAPSHOTS=true
                shift
                ;;
            --network-map)
                NETWORK_MAP="$2"
                shift 2
                ;;
            --storage-map)
                STORAGE_MAP="$2"
                shift 2
                ;;
            --cpu-map)
                CPU_MAP="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
    
    # Validate required arguments
    [[ -z "$PROXMOX_HOST" ]] && die "Proxmox host is required"
    [[ -z "$VM_ID" ]] && die "VM ID is required"
    
    # Get password if not provided
    if [[ -z "$PROXMOX_PASSWORD" ]] && [[ "$USE_API_TOKEN" != "true" ]]; then
        if [[ -n "${PROXMOX_PASSWORD:-}" ]]; then
            PROXMOX_PASSWORD="$PROXMOX_PASSWORD"
        else
            read -s -p "Proxmox password: " PROXMOX_PASSWORD
            echo
        fi
    fi
}

# Proxmox API functions
proxmox_api() {
    local method="$1"
    local endpoint="$2"
    shift 2
    
    local url="https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json${endpoint}"
    local auth_header=""
    
    if [[ "$USE_API_TOKEN" == "true" ]]; then
        auth_header="Authorization: PVEAPIToken=${API_TOKEN}"
    else
        # Get auth ticket if not exists
        if [[ -z "${PROXMOX_TICKET:-}" ]]; then
            get_auth_ticket
        fi
        auth_header="Cookie: PVEAuthCookie=${PROXMOX_TICKET}"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would call: $method $url"
        return 0
    fi
    
    curl -s -k -X "$method" \
        -H "$auth_header" \
        -H "Content-Type: application/json" \
        "$@" \
        "$url"
}

# Get authentication ticket
get_auth_ticket() {
    log_info "Authenticating with Proxmox..."
    
    local response
    response=$(curl -s -k -X POST \
        -d "username=${PROXMOX_USER}&password=${PROXMOX_PASSWORD}" \
        "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/access/ticket")
    
    PROXMOX_TICKET=$(echo "$response" | jq -r '.data.ticket')
    CSRF_TOKEN=$(echo "$response" | jq -r '.data.CSRFPreventionToken')
    
    if [[ -z "$PROXMOX_TICKET" ]] || [[ "$PROXMOX_TICKET" == "null" ]]; then
        die "Failed to authenticate with Proxmox"
    fi
    
    log_success "Authentication successful"
}

# Get VM configuration from Proxmox
get_vm_config() {
    local vmid="$1"
    
    log_info "Fetching VM configuration for VMID $vmid..."
    
    # Get node where VM is located
    local nodes_response
    nodes_response=$(proxmox_api GET "/cluster/resources?type=vm")
    
    local node
    node=$(echo "$nodes_response" | jq -r ".data[] | select(.vmid == $vmid) | .node")
    
    if [[ -z "$node" ]]; then
        die "VM $vmid not found on any node"
    fi
    
    log_info "VM found on node: $node"
    
    # Get VM config
    local config_response
    config_response=$(proxmox_api GET "/nodes/$node/qemu/$vmid/config")
    
    echo "$config_response" | jq '.data'
}

# Convert Proxmox config to Hyper-NixOS format
convert_vm_config() {
    local proxmox_config="$1"
    local vm_name="vm-${VM_ID}"
    
    log_info "Converting VM configuration..."
    
    # Extract basic settings
    local memory cores sockets cpu
    memory=$(echo "$proxmox_config" | jq -r '.memory // 2048')
    cores=$(echo "$proxmox_config" | jq -r '.cores // 1')
    sockets=$(echo "$proxmox_config" | jq -r '.sockets // 1')
    cpu=$(echo "$proxmox_config" | jq -r '.cpu // "host"')
    
    # Convert CPU type
    case "$cpu" in
        "host"|"kvm64"|"qemu64")
            cpu="host"
            ;;
        *)
            # Keep specific CPU model
            ;;
    esac
    
    # Start building Hyper-NixOS config
    cat > "/tmp/hv-vm-${VM_ID}.nix" << EOF
# Migrated from Proxmox - VM ID: ${VM_ID}
# Migration date: $(date)
{
  name = "${vm_name}";
  memory = ${memory};
  cores = ${cores};
  sockets = ${sockets};
  
  cpu = {
    type = "${cpu}";
  };
  
EOF
    
    # Convert boot order
    local boot_order
    boot_order=$(echo "$proxmox_config" | jq -r '.boot // "cdn"')
    echo "  boot = \"order=scsi0;ide2;net0\";" >> "/tmp/hv-vm-${VM_ID}.nix"
    
    # Convert BIOS settings
    local bios
    bios=$(echo "$proxmox_config" | jq -r '.bios // "seabios"')
    if [[ "$bios" == "ovmf" ]]; then
        echo "  bios = \"ovmf\";" >> "/tmp/hv-vm-${VM_ID}.nix"
    fi
    
    # Convert display settings
    local vga
    vga=$(echo "$proxmox_config" | jq -r '.vga // "std"')
    echo "  vga = \"${vga}\";" >> "/tmp/hv-vm-${VM_ID}.nix"
    
    # Convert agent setting
    local agent
    agent=$(echo "$proxmox_config" | jq -r '.agent // "0"')
    if [[ "$agent" == "1" ]]; then
        echo "  agent = true;" >> "/tmp/hv-vm-${VM_ID}.nix"
    fi
    
    # Convert disks
    echo "" >> "/tmp/hv-vm-${VM_ID}.nix"
    echo "  # Disks" >> "/tmp/hv-vm-${VM_ID}.nix"
    
    # Process SCSI disks
    echo "  scsi = {" >> "/tmp/hv-vm-${VM_ID}.nix"
    for i in {0..7}; do
        local disk
        disk=$(echo "$proxmox_config" | jq -r ".scsi${i} // empty")
        if [[ -n "$disk" ]]; then
            convert_disk_config "scsi${i}" "$disk" >> "/tmp/hv-vm-${VM_ID}.nix"
        fi
    done
    echo "  };" >> "/tmp/hv-vm-${VM_ID}.nix"
    
    # Process IDE disks (usually CD-ROM)
    echo "" >> "/tmp/hv-vm-${VM_ID}.nix"
    echo "  ide = {" >> "/tmp/hv-vm-${VM_ID}.nix"
    for i in {0..3}; do
        local disk
        disk=$(echo "$proxmox_config" | jq -r ".ide${i} // empty")
        if [[ -n "$disk" ]]; then
            if [[ "$disk" =~ media=cdrom ]]; then
                echo "    ide${i} = { media = \"cdrom\"; };" >> "/tmp/hv-vm-${VM_ID}.nix"
            fi
        fi
    done
    echo "  };" >> "/tmp/hv-vm-${VM_ID}.nix"
    
    # Convert network interfaces
    if [[ "$MIGRATE_NETWORK" == "true" ]]; then
        echo "" >> "/tmp/hv-vm-${VM_ID}.nix"
        echo "  # Network interfaces" >> "/tmp/hv-vm-${VM_ID}.nix"
        echo "  net = {" >> "/tmp/hv-vm-${VM_ID}.nix"
        
        for i in {0..7}; do
            local net
            net=$(echo "$proxmox_config" | jq -r ".net${i} // empty")
            if [[ -n "$net" ]]; then
                convert_network_config "net${i}" "$net" >> "/tmp/hv-vm-${VM_ID}.nix"
            fi
        done
        
        echo "  };" >> "/tmp/hv-vm-${VM_ID}.nix"
    fi
    
    # Close configuration
    echo "}" >> "/tmp/hv-vm-${VM_ID}.nix"
    
    log_success "Configuration converted to: /tmp/hv-vm-${VM_ID}.nix"
}

# Convert disk configuration
convert_disk_config() {
    local disk_name="$1"
    local disk_config="$2"
    
    # Parse disk string (format: storage:size,options)
    local storage size
    if [[ "$disk_config" =~ ^([^:]+):([^,]+) ]]; then
        storage="${BASH_REMATCH[1]}"
        size="${BASH_REMATCH[2]}"
        
        # Map storage if needed
        if [[ -n "${STORAGE_MAP:-}" ]]; then
            # Apply storage mapping
            for map in ${STORAGE_MAP//,/ }; do
                local src="${map%:*}"
                local dst="${map#*:}"
                if [[ "$storage" == "$src" ]]; then
                    storage="$dst"
                    break
                fi
            done
        fi
        
        echo "    ${disk_name} = {"
        echo "      size = \"${size}\";"
        echo "      format = \"qcow2\";"
        
        # Parse additional options
        if [[ "$disk_config" =~ cache=([^,]+) ]]; then
            echo "      cache = \"${BASH_REMATCH[1]}\";"
        fi
        if [[ "$disk_config" =~ discard=on ]]; then
            echo "      discard = true;"
        fi
        if [[ "$disk_config" =~ ssd=1 ]]; then
            echo "      ssd = true;"
        fi
        
        echo "    };"
    fi
}

# Convert network configuration
convert_network_config() {
    local net_name="$1"
    local net_config="$2"
    
    # Parse network string (format: model=XX,bridge=XX,options)
    local model bridge
    if [[ "$net_config" =~ model=([^,]+) ]]; then
        model="${BASH_REMATCH[1]}"
    fi
    if [[ "$net_config" =~ bridge=([^,]+) ]]; then
        bridge="${BASH_REMATCH[1]}"
        
        # Apply network mapping if provided
        if [[ -n "${NETWORK_MAP:-}" ]]; then
            for map in ${NETWORK_MAP//,/ }; do
                local src="${map%:*}"
                local dst="${map#*:}"
                if [[ "$bridge" == "$src" ]]; then
                    bridge="$dst"
                    break
                fi
            done
        fi
    fi
    
    echo "    ${net_name} = {"
    echo "      model = \"${model:-virtio}\";"
    echo "      bridge = \"${bridge:-vmbr0}\";"
    
    if [[ "$net_config" =~ firewall=1 ]]; then
        echo "      firewall = true;"
    fi
    if [[ "$net_config" =~ tag=([0-9]+) ]]; then
        echo "      tag = ${BASH_REMATCH[1]};"
    fi
    if [[ "$net_config" =~ rate=([0-9]+) ]]; then
        echo "      rate = ${BASH_REMATCH[1]};"
    fi
    
    echo "    };"
}

# Migrate VM disks
migrate_disks() {
    local vmid="$1"
    local node="$2"
    
    log_info "Migrating VM disks..."
    
    # Get VM config to find disks
    local config_response
    config_response=$(proxmox_api GET "/nodes/$node/qemu/$vmid/config")
    local config
    config=$(echo "$config_response" | jq '.data')
    
    # Find all disk devices
    local disks=()
    for key in $(echo "$config" | jq -r 'keys[]'); do
        if [[ "$key" =~ ^(scsi|virtio|ide|sata)[0-9]+$ ]]; then
            local value
            value=$(echo "$config" | jq -r ".\"$key\"")
            if [[ ! "$value" =~ media=cdrom ]] && [[ "$value" =~ ^[^:]+: ]]; then
                disks+=("$key:$value")
            fi
        fi
    done
    
    # Create target directory
    local target_dir="/var/lib/hypervisor/vms/vm-${vmid}"
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$target_dir"
    fi
    
    # Migrate each disk
    for disk_entry in "${disks[@]}"; do
        local disk_name="${disk_entry%%:*}"
        local disk_path="${disk_entry#*:}"
        
        # Extract storage and volume from path
        if [[ "$disk_path" =~ ^([^:]+):(.+)$ ]]; then
            local storage="${BASH_REMATCH[1]}"
            local volume="${BASH_REMATCH[2]}"
            
            log_info "Migrating disk $disk_name ($volume)..."
            
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would migrate disk $disk_name to $target_dir/${disk_name}.qcow2"
                continue
            fi
            
            # Export disk from Proxmox
            local export_url="https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/nodes/$node/qemu/$vmid/migrate"
            
            # For now, we'll use qemu-img to convert and copy
            # In production, this would use the Proxmox export API
            log_warn "Note: Direct disk migration requires SSH access to Proxmox host"
            log_info "Please manually copy the disk using:"
            echo "  ssh root@${PROXMOX_HOST} 'qemu-img convert -O qcow2 /path/to/$volume $target_dir/${disk_name}.qcow2'"
        fi
    done
}

# Migrate snapshots
migrate_snapshots() {
    local vmid="$1"
    local node="$2"
    
    if [[ "$MIGRATE_SNAPSHOTS" != "true" ]]; then
        return
    fi
    
    log_info "Migrating VM snapshots..."
    
    # Get snapshot list
    local snap_response
    snap_response=$(proxmox_api GET "/nodes/$node/qemu/$vmid/snapshot")
    local snapshots
    snapshots=$(echo "$snap_response" | jq -r '.data[] | select(.name != "current") | .name')
    
    if [[ -z "$snapshots" ]]; then
        log_info "No snapshots to migrate"
        return
    fi
    
    # Create snapshot directory
    local snap_dir="/var/lib/hypervisor/vms/vm-${vmid}/snapshots"
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$snap_dir"
    fi
    
    # Migrate each snapshot
    while IFS= read -r snapshot; do
        log_info "Migrating snapshot: $snapshot"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would migrate snapshot $snapshot"
            continue
        fi
        
        # Get snapshot config
        local snap_config
        snap_config=$(proxmox_api GET "/nodes/$node/qemu/$vmid/snapshot/$snapshot/config")
        
        # Save snapshot metadata
        echo "$snap_config" | jq '.data' > "$snap_dir/${snapshot}.json"
        
        # Note: Actual snapshot data migration would require more complex handling
        log_warn "Note: Full snapshot data migration requires additional implementation"
    done <<< "$snapshots"
}

# Create VM in Hyper-NixOS
create_vm_in_hypervisor() {
    local vmid="$1"
    local config_file="/tmp/hv-vm-${vmid}.nix"
    
    log_info "Creating VM in Hyper-NixOS..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create VM with configuration:"
        cat "$config_file"
        return
    fi
    
    # Copy configuration to hypervisor config directory
    local hv_config="/etc/hypervisor/vms/vm-${vmid}.nix"
    cp "$config_file" "$hv_config"
    
    # Import VM configuration
    # This would integrate with Hyper-NixOS VM management
    log_info "VM configuration saved to: $hv_config"
    log_info "To activate, add to your configuration.nix:"
    echo "  hypervisor.vms.vm-${vmid} = import $hv_config;"
}

# Main migration function
migrate_vm() {
    local vmid="$1"
    
    log_info "Starting migration of VM $vmid from Proxmox to Hyper-NixOS"
    
    # Get VM configuration
    local config
    config=$(get_vm_config "$vmid")
    
    # Get node information
    local nodes_response
    nodes_response=$(proxmox_api GET "/cluster/resources?type=vm")
    local node
    node=$(echo "$nodes_response" | jq -r ".data[] | select(.vmid == $vmid) | .node")
    
    # Convert configuration
    if [[ "$CONVERT_CONFIG" == "true" ]]; then
        convert_vm_config "$config"
    fi
    
    # Migrate disks
    migrate_disks "$vmid" "$node"
    
    # Migrate snapshots
    migrate_snapshots "$vmid" "$node"
    
    # Create VM in Hyper-NixOS
    create_vm_in_hypervisor "$vmid"
    
    log_success "Migration completed!"
    log_info "Next steps:"
    echo "1. Copy disk images to the target location"
    echo "2. Update your configuration.nix to include the VM"
    echo "3. Run 'nixos-rebuild switch' to apply changes"
    echo "4. Start the VM with 'virsh start vm-${vmid}'"
}

# Main function
main() {
    parse_args "$@"
    
    # Perform migration
    migrate_vm "$VM_ID"
}

# Run main function
main "$@"