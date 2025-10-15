#!/usr/bin/env bash
#
# hv-bootstrap - Bootstrap NixOS VMs with auto-install ISO
# Enterprise VM deployment and provisioning
#

set -euo pipefail

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Script metadata
SCRIPT_NAME="$(basename "$0")"
REQUIRES_SUDO=false
OPERATION_TYPE="vm_bootstrap"

# Default values
DEFAULT_NODE="localhost"
DEFAULT_MEMORY="2048"
DEFAULT_CORES="2"
DEFAULT_DISK="20G"
AUTO_INSTALL=false
FLAKE_REF=""
VM_NAME=""
NODE=""
ISO_PATH=""
CLOUD_INIT=false

# Help function
show_help() {
    cat << EOF
hv-bootstrap - Bootstrap NixOS VMs with automated installation

SYNOPSIS:
    $SCRIPT_NAME [OPTIONS] <vm-name>

DESCRIPTION:
    Bootstrap a new NixOS VM with optional auto-installation ISO generation.
    Can deploy from flakes or traditional NixOS configurations.

OPTIONS:
    -f, --flake <ref>         Flake reference (e.g., .#myvm, github:user/repo#vm)
    -n, --node <node>         Target hypervisor node (default: $DEFAULT_NODE)
    -a, --auto-install        Generate and use auto-install ISO
    -i, --iso <path>          Use specific ISO image
    -c, --cloud-init          Enable cloud-init support
    
    VM Options:
    -m, --memory <MB>         Memory size in MB (default: $DEFAULT_MEMORY)
    -C, --cores <num>         Number of CPU cores (default: $DEFAULT_CORES)
    -d, --disk <size>         Disk size (default: $DEFAULT_DISK)
    -b, --bridge <name>       Network bridge (default: vmbr0)
    
    Advanced:
    --uefi                    Use UEFI boot instead of BIOS
    --tpm                     Add TPM device
    --gpu-passthrough <id>    Pass through GPU with PCI ID
    --dry-run                 Show what would be done without doing it
    
    -h, --help               Show this help message

EXAMPLES:
    # Bootstrap VM from flake with auto-install
    $SCRIPT_NAME --flake .#webserver --auto-install webserver
    
    # Bootstrap with specific ISO
    $SCRIPT_NAME --iso /path/to/nixos.iso --memory 4096 myvm
    
    # Bootstrap with cloud-init
    $SCRIPT_NAME --flake .#cloudvm --cloud-init --cores 4 cloudvm

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--flake)
                FLAKE_REF="$2"
                shift 2
                ;;
            -n|--node)
                NODE="$2"
                shift 2
                ;;
            -a|--auto-install)
                AUTO_INSTALL=true
                shift
                ;;
            -i|--iso)
                ISO_PATH="$2"
                shift 2
                ;;
            -c|--cloud-init)
                CLOUD_INIT=true
                shift
                ;;
            -m|--memory)
                MEMORY="$2"
                shift 2
                ;;
            -C|--cores)
                CORES="$2"
                shift 2
                ;;
            -d|--disk)
                DISK_SIZE="$2"
                shift 2
                ;;
            -b|--bridge)
                BRIDGE="$2"
                shift 2
                ;;
            --uefi)
                USE_UEFI=true
                shift
                ;;
            --tpm)
                USE_TPM=true
                shift
                ;;
            --gpu-passthrough)
                GPU_PCI_ID="$2"
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
            -*)
                die "Unknown option: $1"
                ;;
            *)
                if [[ -z "$VM_NAME" ]]; then
                    VM_NAME="$1"
                else
                    die "Multiple VM names specified"
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    [[ -z "$VM_NAME" ]] && die "VM name is required"
    
    # Set defaults
    : "${NODE:=$DEFAULT_NODE}"
    : "${MEMORY:=$DEFAULT_MEMORY}"
    : "${CORES:=$DEFAULT_CORES}"
    : "${DISK_SIZE:=$DEFAULT_DISK}"
    : "${BRIDGE:=vmbr0}"
    : "${USE_UEFI:=false}"
    : "${USE_TPM:=false}"
    : "${DRY_RUN:=false}"
}

# Generate auto-install ISO
generate_auto_install_iso() {
    local vm_name="$1"
    local flake_ref="$2"
    local iso_path="/tmp/${vm_name}-install.iso"
    
    log_info "Generating auto-install ISO for $vm_name..."
    
    # Create temporary directory for ISO generation
    local work_dir
    work_dir=$(mktemp -d)
    trap "rm -rf '$work_dir'" EXIT
    
    # Generate installer configuration
    cat > "$work_dir/installer.nix" << EOF
{ config, pkgs, lib, ... }:
{
  imports = [
    # Include the installer profile
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];
  
  # Auto-install script
  systemd.services.auto-install = {
    description = "Auto-install NixOS";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    
    script = ''
      set -euo pipefail
      
      echo "Starting auto-installation..."
      
      # Wait for disk to be available
      while [[ ! -e /dev/vda && ! -e /dev/sda ]]; do
        echo "Waiting for disk..."
        sleep 1
      done
      
      # Determine disk device
      if [[ -e /dev/vda ]]; then
        DISK=/dev/vda
      else
        DISK=/dev/sda
      fi
      
      echo "Using disk: \$DISK"
      
      # Partition disk
      parted --script \$DISK -- \\
        mklabel gpt \\
        mkpart ESP fat32 1MB 512MB \\
        set 1 esp on \\
        mkpart primary 512MB 100%
      
      # Format partitions
      mkfs.fat -F 32 -n ESP \$DISK"1"
      mkfs.ext4 -L nixos \$DISK"2"
      
      # Mount partitions
      mount /dev/disk/by-label/nixos /mnt
      mkdir -p /mnt/boot
      mount /dev/disk/by-label/ESP /mnt/boot
      
      # Generate hardware configuration
      nixos-generate-config --root /mnt
      
      # Install from flake if specified
      ${if flake_ref != "" then ''
        echo "Installing from flake: ${flake_ref}"
        nixos-install --flake "${flake_ref}" --no-root-passwd
      '' else ''
        echo "Installing default configuration"
        nixos-install --no-root-passwd
      ''}
      
      echo "Installation complete! Rebooting..."
      reboot
    '';
  };
  
  # Enable SSH for debugging
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  
  # Set root password for debugging (remove in production)
  users.users.root.initialPassword = "nixos";
  
  # Ensure network is available
  networking.useDHCP = lib.mkDefault true;
  networking.useNetworkd = true;
  systemd.network.wait-online.enable = true;
}
EOF
    
    # Build the ISO
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build ISO with:"
        echo "nix build -f '$work_dir/installer.nix' config.system.build.isoImage"
    else
        log_info "Building ISO (this may take a while)..."
        local result
        result=$(nix build -f "$work_dir/installer.nix" config.system.build.isoImage --no-link --print-out-paths)
        
        # Copy ISO to final location
        cp "$result/iso/"*.iso "$iso_path"
        log_success "Auto-install ISO created: $iso_path"
    fi
    
    echo "$iso_path"
}

# Generate cloud-init ISO
generate_cloud_init_iso() {
    local vm_name="$1"
    local user_data="$2"
    local meta_data="$3"
    local iso_path="/tmp/${vm_name}-cloud-init.iso"
    
    log_info "Generating cloud-init ISO..."
    
    local work_dir
    work_dir=$(mktemp -d)
    trap "rm -rf '$work_dir'" EXIT
    
    # Create meta-data
    cat > "$work_dir/meta-data" << EOF
instance-id: ${vm_name}
local-hostname: ${vm_name}
${meta_data}
EOF
    
    # Create user-data
    if [[ -n "$user_data" ]]; then
        cp "$user_data" "$work_dir/user-data"
    else
        cat > "$work_dir/user-data" << 'EOF'
#cloud-config
users:
  - name: nixos
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: []

packages:
  - qemu-guest-agent
  - htop
  - vim

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
EOF
    fi
    
    # Generate ISO
    if command -v genisoimage >/dev/null 2>&1; then
        genisoimage -output "$iso_path" -volid cidata -joliet -rock \
            "$work_dir/user-data" "$work_dir/meta-data"
    elif command -v mkisofs >/dev/null 2>&1; then
        mkisofs -output "$iso_path" -volid cidata -joliet -rock \
            "$work_dir/user-data" "$work_dir/meta-data"
    else
        die "Neither genisoimage nor mkisofs found. Install genisoimage package."
    fi
    
    log_success "Cloud-init ISO created: $iso_path"
    echo "$iso_path"
}

# Create VM definition
create_vm_definition() {
    local vm_name="$1"
    
    cat << EOF
{
  # Basic VM settings
  name = "${vm_name}";
  memory = ${MEMORY};
  cores = ${CORES};
  sockets = 1;
  
  # CPU configuration
  cpu = {
    type = "host";
  };
  
  # Boot settings
  bios = "${USE_UEFI:+ovmf}${USE_UEFI:-seabios}";
  boot = "order=scsi0;ide2;net0";
  
  # Disks
  scsi = {
    scsi0 = {
      size = "${DISK_SIZE}";
      format = "qcow2";
      cache = "writeback";
      discard = true;
      ssd = true;
    };
  };
  
  # Network
  net = {
    net0 = {
      model = "virtio";
      bridge = "${BRIDGE}";
      firewall = true;
    };
  };
  
  # CD-ROM for installation
  ide = {
    ide2 = {
      media = "cdrom";
      file = "${ISO_PATH:-none}";
    };
  };
  
  # Features
  agent = true;
  tablet = true;
  
  ${USE_TPM:+# TPM device
  tpmstate0 = {
    file = "local:tpm";
    version = "v2.0";
  };}
  
  ${GPU_PCI_ID:+# GPU passthrough
  hostpci = {
    hostpci0 = {
      host = "${GPU_PCI_ID}";
      pcie = true;
      x-vga = true;
    };
  };}
}
EOF
}

# Create the VM
create_vm() {
    local vm_name="$1"
    local definition="$2"
    
    log_info "Creating VM '$vm_name' on node '$NODE'..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create VM with definition:"
        echo "$definition"
        return
    fi
    
    # Save VM definition
    local vm_config="/etc/hypervisor/vms/${vm_name}.nix"
    mkdir -p "$(dirname "$vm_config")"
    echo "$definition" > "$vm_config"
    
    # Apply VM configuration
    # This would integrate with Hyper-NixOS VM management
    log_info "Applying VM configuration..."
    
    # For now, create using qemu-img and virsh as a placeholder
    # In real implementation, this would use Hyper-NixOS VM creation API
    
    local disk_path="/var/lib/hypervisor/vms/${vm_name}/disk0.qcow2"
    mkdir -p "$(dirname "$disk_path")"
    
    # Create disk
    qemu-img create -f qcow2 "$disk_path" "$DISK_SIZE"
    
    # Generate libvirt XML (simplified)
    local xml_path="/tmp/${vm_name}.xml"
    cat > "$xml_path" << EOF
<domain type='kvm'>
  <name>${vm_name}</name>
  <memory unit='MiB'>${MEMORY}</memory>
  <vcpu placement='static'>${CORES}</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    ${USE_UEFI:+<loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.fd</loader>}
  </os>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='writeback' discard='unmap'/>
      <source file='${disk_path}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    ${ISO_PATH:+<disk type='file' device='cdrom'>
      <source file='${ISO_PATH}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>}
    <interface type='bridge'>
      <source bridge='${BRIDGE}'/>
      <model type='virtio'/>
    </interface>
    <console type='pty'/>
    <channel type='unix'>
      <source mode='bind'/>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
  </devices>
</domain>
EOF
    
    # Define and start VM
    virsh define "$xml_path"
    virsh start "$vm_name"
    
    log_success "VM '$vm_name' created and started"
}

# Main function
main() {
    parse_args "$@"
    
    # Generate or validate ISO
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        ISO_PATH=$(generate_auto_install_iso "$VM_NAME" "$FLAKE_REF")
    elif [[ "$CLOUD_INIT" == "true" ]]; then
        # For cloud-init, we need the base OS ISO plus cloud-init ISO
        if [[ -z "$ISO_PATH" ]]; then
            die "Base OS ISO required for cloud-init deployment (use --iso)"
        fi
        CLOUD_INIT_ISO=$(generate_cloud_init_iso "$VM_NAME" "" "")
        log_info "Cloud-init ISO: $CLOUD_INIT_ISO"
    elif [[ -z "$ISO_PATH" ]]; then
        die "Either --auto-install, --cloud-init, or --iso must be specified"
    fi
    
    # Validate ISO exists
    if [[ ! -f "$ISO_PATH" ]] && [[ "$DRY_RUN" != "true" ]]; then
        die "ISO not found: $ISO_PATH"
    fi
    
    # Create VM definition
    local vm_def
    vm_def=$(create_vm_definition "$VM_NAME")
    
    # Create the VM
    create_vm "$VM_NAME" "$vm_def"
    
    if [[ "$AUTO_INSTALL" == "true" ]]; then
        log_info "Auto-installation will begin shortly..."
        log_info "Monitor progress with: virsh console $VM_NAME"
        log_info "Installation typically takes 10-20 minutes"
    fi
    
    log_success "VM bootstrap completed successfully!"
}

# Run main function
main "$@"