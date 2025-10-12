#!/usr/bin/env bash
#
# Hyper-NixOS VM Cloning Tool
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Fast VM duplication with COW and linked clones

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> <source-vm> <new-vm> [options]

Commands:
  full <source> <new>              Full clone (independent copy)
  linked <source> <new>            Linked clone (COW, shares base)
  template <source>                Prepare VM as template

Options:
  --start                          Start clone after creation
  --network <name>                 Attach to network
  --customize                      Run customization (change hostname, etc.)

Examples:
  # Full clone (independent copy)
  $(basename "$0") full web-server web-server-02
  
  # Linked clone (fast, shares base disk)
  $(basename "$0") linked template-ubuntu dev-vm-01 --start
  
  # Prepare template for cloning
  $(basename "$0") template golden-image

Clone Types:

  FULL CLONE:
    • Complete independent copy
    • Uses more disk space
    • Slower to create
    • Safe for production
    • Can modify freely
  
  LINKED CLONE:
    • References base disk (COW)
    • Fast creation (seconds)
    • Minimal disk usage
    • Perfect for testing
    • Requires base disk intact

Use Cases:
  • Rapid development environments
  • Testing before production
  • Scale-out workloads
  • Training environments
  • Disposable sandboxes
EOF
}

# Full clone
full_clone() {
  local source_vm="$1"
  local new_vm="$2"
  local start="${3:-false}"
  
  if ! virsh list --all --name | grep -q "^$source_vm$"; then
    echo "Error: Source VM not found: $source_vm" >&2
    return 1
  fi
  
  if virsh list --all --name | grep -q "^$new_vm$"; then
    echo "Error: VM already exists: $new_vm" >&2
    return 1
  fi
  
  echo "Creating full clone: $source_vm → $new_vm"
  echo ""
  
  # Check if source is running
  if virsh list --name | grep -q "^$source_vm$"; then
    echo "⚠ Warning: Source VM is running"
    echo "For best results, shut down source VM first"
    echo ""
    read -p "Continue anyway? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
      echo "Cancelled"
      return 1
    fi
  fi
  
  echo "Cloning VM (this may take a few minutes)..."
  
  # Use virt-clone for full clone
  virt-clone \
    --original "$source_vm" \
    --name "$new_vm" \
    --auto-clone
  
  echo ""
  echo "✓ Full clone created successfully!"
  echo ""
  echo "Clone details:"
  virsh dominfo "$new_vm" | grep -E "Name:|UUID:|CPU|Memory"
  
  # Customize clone
  customize_clone "$new_vm"
  
  if [[ "$start" == "true" ]]; then
    echo ""
    echo "Starting clone..."
    virsh start "$new_vm"
    echo "✓ Clone started"
  fi
  
  echo ""
  echo "Clone ready: $new_vm"
}

# Linked clone (COW)
linked_clone() {
  local source_vm="$1"
  local new_vm="$2"
  local start="${3:-false}"
  
  if ! virsh list --all --name | grep -q "^$source_vm$"; then
    echo "Error: Source VM not found: $source_vm" >&2
    return 1
  fi
  
  if virsh list --all --name | grep -q "^$new_vm$"; then
    echo "Error: VM already exists: $new_vm" >&2
    return 1
  fi
  
  echo "Creating linked clone: $source_vm → $new_vm"
  echo ""
  
  # Get source disk
  local source_disks=$(virsh domblklist "$source_vm" | awk 'NR>2 {print $2}' | grep -v "^$")
  local source_disk=$(echo "$source_disks" | head -1)
  
  if [[ -z "$source_disk" ]]; then
    echo "Error: No disk found for source VM" >&2
    return 1
  fi
  
  echo "Source disk: $source_disk"
  
  # Create backing file (COW)
  local new_disk="/var/lib/libvirt/images/$new_vm.qcow2"
  
  echo "Creating linked disk (COW)..."
  qemu-img create -f qcow2 \
    -F qcow2 \
    -b "$source_disk" \
    "$new_disk"
  
  echo "✓ Linked disk created (minimal space)"
  
  # Get source VM XML
  local source_xml=$(virsh dumpxml "$source_vm")
  
  # Create new VM XML
  local new_xml=$(mktemp)
  
  echo "$source_xml" | \
    sed "s|<name>$source_vm</name>|<name>$new_vm</name>|" | \
    sed "s|<uuid>.*</uuid>||" | \
    sed "s|$source_disk|$new_disk|g" \
    > "$new_xml"
  
  # Define new VM
  echo "Defining new VM..."
  virsh define "$new_xml"
  rm "$new_xml"
  
  echo "✓ Linked clone created!"
  echo ""
  echo "⚠ Important: Linked clone depends on source disk"
  echo "  Do NOT delete or modify: $source_disk"
  echo "  If source is deleted, clone will break"
  
  # Customize
  customize_clone "$new_vm"
  
  if [[ "$start" == "true" ]]; then
    echo ""
    echo "Starting clone..."
    virsh start "$new_vm"
    echo "✓ Clone started"
  fi
  
  echo ""
  echo "Clone ready: $new_vm"
  echo ""
  echo "Disk usage:"
  echo "  Source: $(du -h "$source_disk" | cut -f1)"
  echo "  Clone:  $(du -h "$new_disk" | cut -f1) (will grow as modified)"
}

# Customize clone
customize_clone() {
  local vm="$1"
  
  echo ""
  echo "Customizing clone..."
  
  # Generate new MAC addresses
  local interfaces=$(virsh domiflist "$vm" --inactive | awk 'NR>2 {print $5}')
  
  for old_mac in $interfaces; do
    # Generate new MAC
    local new_mac="52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"
    
    # Update MAC in VM config
    virsh detach-interface "$vm" network --mac "$old_mac" --config 2>/dev/null || true
    
    # Re-attach with new MAC
    local network=$(virsh domiflist "$vm" --inactive | awk 'NR>2 {print $3}' | head -1)
    
    cat > /tmp/new-interface.xml <<EOF
<interface type='network'>
  <source network='${network:-default}'/>
  <mac address='$new_mac'/>
  <model type='virtio'/>
</interface>
EOF
    
    virsh attach-device "$vm" /tmp/new-interface.xml --config 2>/dev/null || true
    rm /tmp/new-interface.xml
  done
  
  echo "  ✓ New MAC addresses generated"
  echo "  ✓ Network configuration updated"
  echo ""
  echo "⚠ Additional customization needed:"
  echo "  • Change hostname inside VM"
  echo "  • Update static IP if configured"
  echo "  • Regenerate SSH host keys"
  echo "  • Update license keys if needed"
}

# Prepare template
prepare_template() {
  local vm="$1"
  
  if ! virsh list --all --name | grep -q "^$vm$"; then
    echo "Error: VM not found: $vm" >&2
    return 1
  fi
  
  echo "Preparing VM as template: $vm"
  echo ""
  
  # Check if running
  if virsh list --name | grep -q "^$vm$"; then
    echo "⚠ VM is running"
    echo ""
    echo "For best results, follow these steps inside VM first:"
    echo ""
    echo "Linux:"
    echo "  1. Clean system:"
    echo "       sudo apt clean  # or yum clean all"
    echo "       sudo rm -rf /tmp/*"
    echo "       sudo rm -rf /var/tmp/*"
    echo ""
    echo "  2. Remove unique identifiers:"
    echo "       sudo rm -f /etc/machine-id"
    echo "       sudo rm -f /var/lib/dbus/machine-id"
    echo "       sudo rm -f /etc/ssh/ssh_host_*"
    echo ""
    echo "  3. Clear history:"
    echo "       history -c"
    echo "       rm ~/.bash_history"
    echo ""
    echo "  4. Shutdown:"
    echo "       sudo shutdown -h now"
    echo ""
    echo "Windows:"
    echo "  1. Run Sysprep:"
    echo "       C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown"
    echo ""
    
    read -p "Has template preparation been completed? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
      echo "Please complete preparation steps, then run this command again"
      return 1
    fi
    
    echo "Shutting down VM..."
    virsh shutdown "$vm"
    
    # Wait for shutdown
    local timeout=60
    while [[ $timeout -gt 0 ]] && virsh list --name | grep -q "^$vm$"; do
      sleep 1
      ((timeout--))
    done
  fi
  
  echo ""
  echo "✓ Template preparation complete"
  echo ""
  echo "Template is ready for cloning:"
  echo "  Full clone:   $(basename "$0") full $vm new-vm-name"
  echo "  Linked clone: $(basename "$0") linked $vm new-vm-name"
  echo ""
  echo "Best practices:"
  echo "  • Keep template shut down"
  echo "  • Don't modify template after cloning"
  echo "  • Document template contents"
  echo "  • Tag template in VM name (e.g., 'template-ubuntu')"
}

# Main
case "${1:-}" in
  full)
    full_clone "${2:-}" "${3:-}" "${4:-false}"
    ;;
  linked)
    linked_clone "${2:-}" "${3:-}" "${4:-false}"
    ;;
  template)
    prepare_template "${2:-}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
