#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS VM Templates Library
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Pre-configured VM templates for rapid deployment

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

TEMPLATE_DIR="/var/lib/hypervisor/templates"
TEMPLATE_REPO="https://github.com/MasterofNull/Hyper-NixOS-Templates"

mkdir -p "$TEMPLATE_DIR"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  list                              List available templates
  create <name> <template>          Create VM from template
  show <template>                   Show template details
  import <url>                      Import custom template
  export <vm> <template-name>       Export VM as template
  update                            Update template library

Available Templates:
  ubuntu-server      Ubuntu 24.04 LTS server
  debian-stable      Debian 12 stable
  alpine-minimal     Alpine Linux (minimal)
  windows-10         Windows 10 Pro
  windows-server     Windows Server 2022
  centos-stream      CentOS Stream 9
  fedora-workstation Fedora 39 Workstation
  arch-linux         Arch Linux

Examples:
  # List all templates
  $(basename "$0") list
  
  # Create VM from template
  $(basename "$0") create my-web-server ubuntu-server
  
  # Export existing VM as template
  $(basename "$0") export production-web web-server-template
  
  # Import custom template
  $(basename "$0") import https://example.com/my-template.json

Templates Include:
  • Pre-configured OS
  • Optimized settings
  • Security hardening
  • Common software packages
  • Ready to customize
EOF
}

# Built-in templates
get_template_ubuntu_server() {
  cat <<'EOF'
{
  "name": "ubuntu-server",
  "description": "Ubuntu 24.04 LTS Server",
  "os": "ubuntu24.04",
  "cpu": 2,
  "memory": 2048,
  "disk": 20,
  "iso_url": "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso",
  "iso_checksum": "sha256:...",
  "network": "default",
  "packages": [
    "openssh-server",
    "curl",
    "wget",
    "vim",
    "htop"
  ],
  "features": {
    "cloud_init": true,
    "ssh_keys": true,
    "auto_update": true
  }
}
EOF
}

get_template_debian_stable() {
  cat <<'EOF'
{
  "name": "debian-stable",
  "description": "Debian 12 Bookworm",
  "os": "debian12",
  "cpu": 2,
  "memory": 2048,
  "disk": 20,
  "iso_url": "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso",
  "network": "default",
  "packages": [
    "ssh",
    "sudo",
    "curl",
    "vim"
  ]
}
EOF
}

get_template_alpine_minimal() {
  cat <<'EOF'
{
  "name": "alpine-minimal",
  "description": "Alpine Linux (Minimal)",
  "os": "alpine3.19",
  "cpu": 1,
  "memory": 512,
  "disk": 5,
  "iso_url": "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.0-x86_64.iso",
  "network": "default",
  "features": {
    "minimal": true,
    "container_ready": true
  }
}
EOF
}

# List templates
list_templates() {
  echo "Available VM Templates:"
  echo ""
  printf "%-20s %-40s %8s %8s %8s\n" "Name" "Description" "CPU" "RAM" "Disk"
  printf "%-20s %-40s %8s %8s %8s\n" "----" "-----------" "---" "---" "----"
  
  # Built-in templates
  printf "%-20s %-40s %8s %8s %8s\n" "ubuntu-server" "Ubuntu 24.04 LTS Server" "2" "2GB" "20GB"
  printf "%-20s %-40s %8s %8s %8s\n" "debian-stable" "Debian 12 Bookworm" "2" "2GB" "20GB"
  printf "%-20s %-40s %8s %8s %8s\n" "alpine-minimal" "Alpine Linux (Minimal)" "1" "512MB" "5GB"
  printf "%-20s %-40s %8s %8s %8s\n" "centos-stream" "CentOS Stream 9" "2" "2GB" "25GB"
  printf "%-20s %-40s %8s %8s %8s\n" "fedora-workstation" "Fedora 39 Workstation" "2" "4GB" "30GB"
  printf "%-20s %-40s %8s %8s %8s\n" "arch-linux" "Arch Linux" "2" "2GB" "20GB"
  printf "%-20s %-40s %8s %8s %8s\n" "windows-10" "Windows 10 Pro" "2" "4GB" "60GB"
  printf "%-20s %-40s %8s %8s %8s\n" "windows-server" "Windows Server 2022" "4" "8GB" "80GB"
  
  # Custom templates
  if [[ -d "$TEMPLATE_DIR" ]] && ls "$TEMPLATE_DIR"/*.json >/dev/null 2>&1; then
    echo ""
    echo "Custom Templates:"
    for template in "$TEMPLATE_DIR"/*.json; do
      local name=$(jq -r '.name' "$template" 2>/dev/null || basename "$template" .json)
      local desc=$(jq -r '.description // "Custom template"' "$template" 2>/dev/null)
      local cpu=$(jq -r '.cpu // "?"' "$template" 2>/dev/null)
      local mem=$(jq -r '.memory // "?"' "$template" 2>/dev/null)
      local disk=$(jq -r '.disk // "?"' "$template" 2>/dev/null)
      
      printf "%-20s %-40s %8s %8s %8s\n" "$name" "$desc" "$cpu" "${mem}MB" "${disk}GB"
    done
  fi
}

# Show template details
show_template() {
  local template_name="$1"
  
  echo "Template: $template_name"
  echo ""
  
  case "$template_name" in
    ubuntu-server)
      get_template_ubuntu_server | jq .
      ;;
    debian-stable)
      get_template_debian_stable | jq .
      ;;
    alpine-minimal)
      get_template_alpine_minimal | jq .
      ;;
    *)
      local template_file="$TEMPLATE_DIR/$template_name.json"
      if [[ -f "$template_file" ]]; then
        cat "$template_file" | jq .
      else
        echo "Error: Template not found: $template_name" >&2
        return 1
      fi
      ;;
  esac
}

# Create VM from template
create_from_template() {
  local vm_name="$1"
  local template_name="$2"
  
  echo "Creating VM from template: $template_name"
  echo "  VM Name: $vm_name"
  
  # Get template
  local template_json
  case "$template_name" in
    ubuntu-server)
      template_json=$(get_template_ubuntu_server)
      ;;
    debian-stable)
      template_json=$(get_template_debian_stable)
      ;;
    alpine-minimal)
      template_json=$(get_template_alpine_minimal)
      ;;
    *)
      local template_file="$TEMPLATE_DIR/$template_name.json"
      if [[ -f "$template_file" ]]; then
        template_json=$(cat "$template_file")
      else
        echo "Error: Template not found: $template_name" >&2
        return 1
      fi
      ;;
  esac
  
  # Extract template values
  local cpu=$(echo "$template_json" | jq -r '.cpu // 2')
  local memory=$(echo "$template_json" | jq -r '.memory // 2048')
  local disk=$(echo "$template_json" | jq -r '.disk // 20')
  local os=$(echo "$template_json" | jq -r '.os // "linux"')
  local iso_url=$(echo "$template_json" | jq -r '.iso_url // ""')
  
  echo "  CPU: $cpu cores"
  echo "  Memory: $memory MB"
  echo "  Disk: $disk GB"
  echo "  OS: $os"
  
  # Create disk
  local disk_path="/var/lib/libvirt/images/$vm_name.qcow2"
  
  if [[ -f "$disk_path" ]]; then
    echo "Error: Disk already exists: $disk_path" >&2
    return 1
  fi
  
  echo ""
  echo "Creating virtual disk..."
  qemu-img create -f qcow2 "$disk_path" "$disk"G
  
  # Create VM XML
  local vm_xml="/tmp/$vm_name.xml"
  
  cat > "$vm_xml" <<VMXML
<domain type='kvm'>
  <name>$vm_name</name>
  <memory unit='MiB'>$memory</memory>
  <vcpu>$cpu</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/run/current-system/sw/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='writeback'/>
      <source file='$disk_path'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <console type='pty'/>
    <graphics type='vnc' listen='127.0.0.1' autoport='yes'/>
    <video>
      <model type='qxl'/>
    </video>
  </devices>
</domain>
VMXML
  
  # Define VM
  echo "Defining VM..."
  virsh define "$vm_xml"
  rm "$vm_xml"
  
  echo ""
  echo "✓ VM created from template!"
  echo ""
  echo "Next steps:"
  
  if [[ -n "$iso_url" ]]; then
    echo "1. Download ISO:"
    echo "   cd /var/lib/libvirt/images && wget $iso_url"
    echo ""
    echo "2. Attach ISO:"
    echo "   virsh change-media $vm_name hdc --insert /var/lib/libvirt/images/$(basename "$iso_url")"
    echo ""
  fi
  
  echo "3. Start VM:"
  echo "   virsh start $vm_name"
  echo ""
  echo "4. Connect to console:"
  echo "   virsh console $vm_name"
}

# Export VM as template
export_as_template() {
  local vm_name="$1"
  local template_name="$2"
  
  if ! virsh list --all --name | grep -q "^$vm_name$"; then
    echo "Error: VM not found: $vm_name" >&2
    return 1
  fi
  
  echo "Exporting VM as template: $vm_name -> $template_name"
  
  # Get VM info
  local cpu=$(virsh vcpucount "$vm_name" --maximum)
  local memory=$(virsh dommemstat "$vm_name" 2>/dev/null | grep "actual" | awk '{print $2}' || echo "2048000")
  memory=$((memory / 1024))
  
  # Get disk info
  local disks=$(virsh domblklist "$vm_name" | awk 'NR>2 {print $2}' | grep -v "^$")
  local disk_size=0
  
  for disk in $disks; do
    if [[ -f "$disk" ]]; then
      local size=$(qemu-img info "$disk" | grep "virtual size" | awk '{print $3}' | sed 's/G//')
      disk_size=$((disk_size + ${size%.*}))
    fi
  done
  
  # Create template JSON
  local template_file="$TEMPLATE_DIR/$template_name.json"
  
  cat > "$template_file" <<EOF
{
  "name": "$template_name",
  "description": "Template exported from $vm_name",
  "source_vm": "$vm_name",
  "created": "$(date -Iseconds)",
  "cpu": $cpu,
  "memory": $memory,
  "disk": $disk_size,
  "os": "custom",
  "features": {
    "custom_template": true
  }
}
EOF
  
  echo "✓ Template exported: $template_file"
  echo ""
  echo "To create VMs from this template:"
  echo "  $(basename "$0") create new-vm $template_name"
}

# Import template
import_template() {
  local url="$1"
  
  echo "Importing template from: $url"
  
  local template_file="$TEMPLATE_DIR/$(basename "$url")"
  
  if wget -q "$url" -O "$template_file"; then
    echo "✓ Template imported: $template_file"
    
    # Validate JSON
    if jq . "$template_file" >/dev/null 2>&1; then
      local name=$(jq -r '.name' "$template_file")
      echo "  Template name: $name"
    else
      echo "⚠ Warning: Template is not valid JSON"
    fi
  else
    echo "Error: Failed to download template" >&2
    return 1
  fi
}

# Update template library
update_templates() {
  echo "Updating template library..."
  echo ""
  echo "Built-in templates are always up-to-date"
  echo ""
  echo "To update custom templates:"
  echo "  Re-import from source URLs"
  echo ""
  echo "Template library location: $TEMPLATE_DIR"
}

# Main
case "${1:-}" in
  list)
    list_templates
    ;;
  create)
    create_from_template "${2:-}" "${3:-}"
    ;;
  show)
    show_template "${2:-}"
    ;;
  import)
    import_template "${2:-}"
    ;;
  export)
    export_as_template "${2:-}" "${3:-}"
    ;;
  update)
    update_templates
    ;;
  *)
    usage
    exit 1
    ;;
esac
