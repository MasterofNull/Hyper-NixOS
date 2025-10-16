#!/usr/bin/env bash
#
# hv-migrate - Migrate VMs from various virtualization platforms to Hyper-NixOS
#

set -euo pipefail

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Script metadata
SCRIPT_NAME="$(basename "$0")"
REQUIRES_SUDO=false
OPERATION_TYPE="migration"

# Default values
SOURCE_HOST=""
SOURCE_USER="root"
SOURCE_PORT=""
SOURCE_PLATFORM=""
VM_ID=""
TARGET_STORAGE="local"
CONVERT_CONFIG=true
MIGRATE_NETWORK=true
MIGRATE_SNAPSHOTS=false
DRY_RUN=false
AUTH_METHOD="password"
AUTH_PASSWORD=""
API_TOKEN=""

# Supported platforms
SUPPORTED_PLATFORMS=(
    "enterprise-virt"   # Generic enterprise virtualization platform
    "libvirt"          # libvirt/KVM systems
    "vmware"           # VMware vSphere/ESXi
    "openstack"        # OpenStack
    "ovirt"            # oVirt/RHV
    "xen"              # Xen/XenServer
    "hyperv"           # Microsoft Hyper-V
)

# Default ports for different platforms
declare -A DEFAULT_PORTS=(
    ["enterprise-virt"]="8006"
    ["libvirt"]="16509"
    ["vmware"]="443"
    ["openstack"]="5000"
    ["ovirt"]="443"
    ["xen"]="443"
    ["hyperv"]="5985"
)

# Help function
show_help() {
    cat << EOF
hv-migrate - Migrate VMs from various virtualization platforms to Hyper-NixOS

SYNOPSIS:
    $SCRIPT_NAME [OPTIONS] --source <host> --platform <platform> --vm <id>

DESCRIPTION:
    Migrate virtual machines from different virtualization platforms to Hyper-NixOS.
    Supports configuration conversion, disk migration, and network mapping.

SUPPORTED PLATFORMS:
    enterprise-virt   - Enterprise virtualization platforms (REST API based)
    libvirt          - libvirt/KVM/QEMU systems
    vmware           - VMware vSphere/ESXi
    openstack        - OpenStack Nova
    ovirt            - oVirt/Red Hat Virtualization
    xen              - Xen/XenServer/Citrix Hypervisor
    hyperv           - Microsoft Hyper-V

OPTIONS:
    -s, --source <host>       Source host address
    -p, --platform <platform> Source platform type
    -u, --user <user>         Source platform user (default: root)
    -P, --port <port>         Source platform port (auto-detected if not specified)
    -v, --vm <id>             VM ID/name to migrate
    --password <pass>         Authentication password
    --api-token <token>       API token for authentication (if supported)
    
    Migration Options:
    --target-storage <name>   Target storage pool (default: $TARGET_STORAGE)
    --no-convert             Don't convert configuration
    --no-network             Don't migrate network settings
    --with-snapshots         Include snapshots in migration
    
    Mapping Options:
    --network-map <map>       Network mapping (e.g., "src1:dst1,src2:dst2")
    --storage-map <map>       Storage mapping
    --cpu-map <map>          CPU type mapping
    
    Advanced:
    --dry-run                Show what would be done without doing it
    --format <format>        Force specific disk format (qcow2, raw, vmdk)
    --compression            Compress during transfer
    
    -h, --help               Show this help message

EXAMPLES:
    # Migrate from enterprise virtualization platform
    $SCRIPT_NAME --source virt.example.com --platform enterprise-virt --vm 100

    # Migrate from VMware with network mapping
    $SCRIPT_NAME --source vcenter.local --platform vmware --vm "web-server" \\
        --network-map "VM Network:vmbr0,Storage Network:vmbr1"

    # Migrate from libvirt/KVM
    $SCRIPT_NAME --source kvm-host.local --platform libvirt --vm domain1 \\
        --with-snapshots

    # Migrate from OpenStack
    $SCRIPT_NAME --source openstack.local --platform openstack --vm instance-001 \\
        --api-token "gAAAAABg..."

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                SOURCE_HOST="$2"
                shift 2
                ;;
            -p|--platform)
                SOURCE_PLATFORM="$2"
                shift 2
                ;;
            -u|--user)
                SOURCE_USER="$2"
                shift 2
                ;;
            -P|--port)
                SOURCE_PORT="$2"
                shift 2
                ;;
            -v|--vm)
                VM_ID="$2"
                shift 2
                ;;
            --password)
                AUTH_PASSWORD="$2"
                AUTH_METHOD="password"
                shift 2
                ;;
            --api-token)
                API_TOKEN="$2"
                AUTH_METHOD="token"
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
            --format)
                DISK_FORMAT="$2"
                shift 2
                ;;
            --compression)
                USE_COMPRESSION=true
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
    [[ -z "$SOURCE_HOST" ]] && die "Source host is required"
    [[ -z "$SOURCE_PLATFORM" ]] && die "Platform type is required"
    [[ -z "$VM_ID" ]] && die "VM ID is required"
    
    # Validate platform
    local valid_platform=false
    for platform in "${SUPPORTED_PLATFORMS[@]}"; do
        if [[ "$SOURCE_PLATFORM" == "$platform" ]]; then
            valid_platform=true
            break
        fi
    done
    [[ "$valid_platform" == "false" ]] && die "Unsupported platform: $SOURCE_PLATFORM"
    
    # Set default port if not specified
    if [[ -z "$SOURCE_PORT" ]]; then
        SOURCE_PORT="${DEFAULT_PORTS[$SOURCE_PLATFORM]}"
    fi
    
    # Get authentication if needed
    if [[ "$AUTH_METHOD" == "password" ]] && [[ -z "$AUTH_PASSWORD" ]]; then
        read -s -p "Password for $SOURCE_USER@$SOURCE_HOST: " AUTH_PASSWORD
        echo
    fi
}

# Platform-specific API functions
call_platform_api() {
    local platform="$1"
    local method="$2"
    local endpoint="$3"
    shift 3
    
    case "$platform" in
        enterprise-virt)
            call_enterprise_virt_api "$method" "$endpoint" "$@"
            ;;
        libvirt)
            call_libvirt_api "$method" "$endpoint" "$@"
            ;;
        vmware)
            call_vmware_api "$method" "$endpoint" "$@"
            ;;
        openstack)
            call_openstack_api "$method" "$endpoint" "$@"
            ;;
        *)
            die "API not implemented for platform: $platform"
            ;;
    esac
}

# Enterprise virtualization platform API
call_enterprise_virt_api() {
    local method="$1"
    local endpoint="$2"
    shift 2
    
    local url="https://${SOURCE_HOST}:${SOURCE_PORT}/api2/json${endpoint}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would call: $method $url"
        return 0
    fi
    
    # Get auth ticket if needed
    if [[ -z "${SESSION_TICKET:-}" ]]; then
        get_enterprise_virt_session
    fi
    
    curl -s -k -X "$method" \
        -H "Cookie: AuthSession=${SESSION_TICKET}" \
        -H "Content-Type: application/json" \
        "$@" \
        "$url"
}

# Get session for enterprise virtualization platform
get_enterprise_virt_session() {
    log_info "Authenticating with $SOURCE_PLATFORM..."
    
    local response
    response=$(curl -s -k -X POST \
        -d "username=${SOURCE_USER}&password=${AUTH_PASSWORD}" \
        "https://${SOURCE_HOST}:${SOURCE_PORT}/api2/json/access/ticket")
    
    SESSION_TICKET=$(echo "$response" | jq -r '.data.ticket // empty')
    
    if [[ -z "$SESSION_TICKET" ]]; then
        die "Failed to authenticate with $SOURCE_PLATFORM"
    fi
    
    log_success "Authentication successful"
}

# libvirt API wrapper
call_libvirt_api() {
    local method="$1"
    local endpoint="$2"
    
    # For libvirt, we use virsh commands over SSH
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute virsh command for: $endpoint"
        return 0
    fi
    
    case "$endpoint" in
        "/domains")
            ssh "${SOURCE_USER}@${SOURCE_HOST}" "virsh list --all --name"
            ;;
        "/domains/$VM_ID")
            ssh "${SOURCE_USER}@${SOURCE_HOST}" "virsh dumpxml $VM_ID"
            ;;
        *)
            log_warn "libvirt endpoint not implemented: $endpoint"
            ;;
    esac
}

# VMware API wrapper
call_vmware_api() {
    local method="$1"
    local endpoint="$2"
    shift 2
    
    local url="https://${SOURCE_HOST}:${SOURCE_PORT}/api${endpoint}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would call VMware API: $method $url"
        return 0
    fi
    
    # VMware uses session-based auth
    if [[ -z "${VMWARE_SESSION:-}" ]]; then
        get_vmware_session
    fi
    
    curl -s -k -X "$method" \
        -H "vmware-api-session-id: ${VMWARE_SESSION}" \
        -H "Content-Type: application/json" \
        "$@" \
        "$url"
}

# Get VMware session
get_vmware_session() {
    log_info "Authenticating with VMware vSphere..."
    
    local response
    response=$(curl -s -k -X POST \
        -u "${SOURCE_USER}:${AUTH_PASSWORD}" \
        "https://${SOURCE_HOST}:${SOURCE_PORT}/api/session")
    
    VMWARE_SESSION=$(echo "$response" | tr -d '"')
    
    if [[ -z "$VMWARE_SESSION" ]]; then
        die "Failed to authenticate with VMware"
    fi
    
    log_success "VMware authentication successful"
}

# OpenStack API wrapper
call_openstack_api() {
    local method="$1"
    local endpoint="$2"
    shift 2
    
    # OpenStack uses Keystone tokens
    if [[ -z "${OS_TOKEN:-}" ]]; then
        get_openstack_token
    fi
    
    curl -s -X "$method" \
        -H "X-Auth-Token: ${OS_TOKEN}" \
        -H "Content-Type: application/json" \
        "$@" \
        "http://${SOURCE_HOST}:${SOURCE_PORT}${endpoint}"
}

# Get VM configuration from source platform
get_vm_config() {
    local vmid="$1"
    
    log_info "Fetching VM configuration for $vmid from $SOURCE_PLATFORM..."
    
    case "$SOURCE_PLATFORM" in
        enterprise-virt)
            # Find VM location
            local resources
            resources=$(call_platform_api "$SOURCE_PLATFORM" GET "/cluster/resources?type=vm")
            local node
            node=$(echo "$resources" | jq -r ".data[] | select(.name == \"$vmid\" or .vmid == $vmid) | .node // empty" | head -1)
            
            if [[ -z "$node" ]]; then
                die "VM $vmid not found"
            fi
            
            # Get VM config
            local config
            config=$(call_platform_api "$SOURCE_PLATFORM" GET "/nodes/$node/vms/$vmid/config")
            echo "$config" | jq '.data'
            ;;
            
        libvirt)
            # Get domain XML
            call_libvirt_api GET "/domains/$vmid"
            ;;
            
        vmware)
            # Get VM details
            local vm_list
            vm_list=$(call_platform_api "$SOURCE_PLATFORM" GET "/vcenter/vm")
            local vm_id
            vm_id=$(echo "$vm_list" | jq -r ".[] | select(.name == \"$vmid\") | .vm // empty" | head -1)
            
            if [[ -z "$vm_id" ]]; then
                die "VM $vmid not found in VMware"
            fi
            
            call_platform_api "$SOURCE_PLATFORM" GET "/vcenter/vm/$vm_id"
            ;;
            
        *)
            die "Configuration retrieval not implemented for platform: $SOURCE_PLATFORM"
            ;;
    esac
}

# Convert VM configuration to Hyper-NixOS format
convert_vm_config() {
    local source_config="$1"
    local vm_name="imported-${VM_ID}"
    
    log_info "Converting VM configuration from $SOURCE_PLATFORM format..."
    
    case "$SOURCE_PLATFORM" in
        enterprise-virt)
            convert_enterprise_virt_config "$source_config" "$vm_name"
            ;;
        libvirt)
            convert_libvirt_config "$source_config" "$vm_name"
            ;;
        vmware)
            convert_vmware_config "$source_config" "$vm_name"
            ;;
        *)
            log_warn "Configuration conversion not implemented for $SOURCE_PLATFORM"
            log_info "Manual configuration will be required"
            ;;
    esac
}

# Convert enterprise virtualization platform config
convert_enterprise_virt_config() {
    local config="$1"
    local vm_name="$2"
    
    # Extract settings
    local memory cores sockets cpu
    memory=$(echo "$config" | jq -r '.memory // 2048')
    cores=$(echo "$config" | jq -r '.cores // 1')
    sockets=$(echo "$config" | jq -r '.sockets // 1')
    cpu=$(echo "$config" | jq -r '.cpu // "host"')
    
    # Generate Hyper-NixOS config
    cat > "/tmp/hv-import-${VM_ID}.nix" << EOF
# Imported from $SOURCE_PLATFORM - VM: ${VM_ID}
# Import date: $(date)
# Source platform: Enterprise Virtualization Platform
{
  name = "${vm_name}";
  memory = ${memory};
  cores = ${cores};
  sockets = ${sockets};
  
  cpu = {
    type = "${cpu}";
  };
  
  boot = "order=scsi0;ide2;net0";
  
EOF
    
    # Convert disks
    echo "  # Disks" >> "/tmp/hv-import-${VM_ID}.nix"
    echo "  scsi = {" >> "/tmp/hv-import-${VM_ID}.nix"
    
    # Process SCSI disks
    for i in {0..7}; do
        local disk
        disk=$(echo "$config" | jq -r ".scsi${i} // empty")
        if [[ -n "$disk" ]]; then
            echo "    scsi${i} = {" >> "/tmp/hv-import-${VM_ID}.nix"
            echo "      size = \"32G\";  # Update with actual size" >> "/tmp/hv-import-${VM_ID}.nix"
            echo "      format = \"qcow2\";" >> "/tmp/hv-import-${VM_ID}.nix"
            echo "    };" >> "/tmp/hv-import-${VM_ID}.nix"
        fi
    done
    
    echo "  };" >> "/tmp/hv-import-${VM_ID}.nix"
    
    # Convert network
    if [[ "$MIGRATE_NETWORK" == "true" ]]; then
        echo "" >> "/tmp/hv-import-${VM_ID}.nix"
        echo "  # Network interfaces" >> "/tmp/hv-import-${VM_ID}.nix"
        echo "  net = {" >> "/tmp/hv-import-${VM_ID}.nix"
        
        for i in {0..7}; do
            local net
            net=$(echo "$config" | jq -r ".net${i} // empty")
            if [[ -n "$net" ]]; then
                echo "    net${i} = {" >> "/tmp/hv-import-${VM_ID}.nix"
                echo "      model = \"virtio\";" >> "/tmp/hv-import-${VM_ID}.nix"
                echo "      bridge = \"vmbr0\";" >> "/tmp/hv-import-${VM_ID}.nix"
                echo "    };" >> "/tmp/hv-import-${VM_ID}.nix"
            fi
        done
        
        echo "  };" >> "/tmp/hv-import-${VM_ID}.nix"
    fi
    
    echo "}" >> "/tmp/hv-import-${VM_ID}.nix"
    
    log_success "Configuration converted to: /tmp/hv-import-${VM_ID}.nix"
}

# Convert libvirt XML to Hyper-NixOS format
convert_libvirt_config() {
    local xml_config="$1"
    local vm_name="$2"
    
    # Parse XML using xmlstarlet or similar
    # This is a simplified example
    log_info "Converting libvirt XML configuration..."
    
    # Extract basic values from XML
    local memory_kb memory_mb cores
    memory_kb=$(echo "$xml_config" | grep -oP '<memory[^>]*>\K[0-9]+' | head -1 || echo "2097152")
    memory_mb=$((memory_kb / 1024))
    cores=$(echo "$xml_config" | grep -oP '<vcpu[^>]*>\K[0-9]+' | head -1 || echo "2")
    
    cat > "/tmp/hv-import-${VM_ID}.nix" << EOF
# Imported from libvirt - Domain: ${VM_ID}
# Import date: $(date)
{
  name = "${vm_name}";
  memory = ${memory_mb};
  cores = ${cores};
  sockets = 1;
  
  cpu = {
    type = "host";
  };
  
  # Note: Disk and network configuration needs manual adjustment
}
EOF
    
    log_success "Basic configuration converted. Manual adjustment required for disks and networking."
}

# Migrate VM disks
migrate_disks() {
    local vmid="$1"
    
    log_info "Migrating VM disks..."
    
    # Create target directory
    local target_dir="/var/lib/hypervisor/vms/${VM_ID}"
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$target_dir"
    fi
    
    case "$SOURCE_PLATFORM" in
        enterprise-virt|libvirt)
            # For platforms with SSH access
            log_info "Disk migration requires SSH access to source host"
            log_info "Please use one of these methods:"
            echo -e "1. SCP: scp root@${SOURCE_HOST}:/path/to/disk.img $target_dir/"
            echo -e "2. rsync: rsync -avz --progress root@${SOURCE_HOST}:/path/to/disk.img $target_dir/"
            echo -e "3. dd over SSH: ssh root@${SOURCE_HOST} 'dd if=/path/to/disk.img' | dd of=$target_dir/disk.img"
            ;;
            
        vmware)
            log_info "For VMware, export VM as OVF/OVA and extract disk images"
            echo "1. Export VM from vSphere/ESXi as OVF"
            echo "2. Extract VMDK files from OVF package"
            echo "3. Convert VMDK to qcow2: qemu-img convert -O qcow2 disk.vmdk $target_dir/disk.qcow2"
            ;;
            
        *)
            log_warn "Disk migration instructions not available for $SOURCE_PLATFORM"
            ;;
    esac
}

# Create VM in Hyper-NixOS
create_vm_in_hypervisor() {
    local vmid="$1"
    local config_file="/tmp/hv-import-${vmid}.nix"
    
    log_info "Creating VM in Hyper-NixOS..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create VM with configuration:"
        cat "$config_file"
        return
    fi
    
    # Copy configuration to hypervisor config directory
    local hv_config="/etc/hypervisor/vms/imported-${vmid}.nix"
    cp "$config_file" "$hv_config"
    
    log_info "VM configuration saved to: $hv_config"
    log_info "To activate, add to your configuration.nix:"
    echo "  hypervisor.vms.imported-${vmid} = import $hv_config;"
}

# Main migration function
migrate_vm() {
    local vmid="$1"
    
    log_info "Starting migration of VM $vmid from $SOURCE_PLATFORM to Hyper-NixOS"
    
    # Get VM configuration
    local config
    config=$(get_vm_config "$vmid")
    
    # Convert configuration
    if [[ "$CONVERT_CONFIG" == "true" ]]; then
        convert_vm_config "$config"
    fi
    
    # Migrate disks
    migrate_disks "$vmid"
    
    # Migrate snapshots if requested
    if [[ "$MIGRATE_SNAPSHOTS" == "true" ]]; then
        log_info "Snapshot migration must be done manually for most platforms"
    fi
    
    # Create VM in Hyper-NixOS
    create_vm_in_hypervisor "$vmid"
    
    log_success "Migration preparation completed!"
    log_info "Next steps:"
    echo "1. Migrate disk images to the target location"
    echo "2. Update your configuration.nix to include the VM"
    echo "3. Adjust the imported configuration as needed"
    echo "4. Run 'nixos-rebuild switch' to apply changes"
    echo "5. Start the VM with 'virsh start imported-${vmid}'"
}

# Main function
main() {
    parse_args "$@"
    
    # Perform migration
    migrate_vm "$VM_ID"
}

# Run main function
main "$@"