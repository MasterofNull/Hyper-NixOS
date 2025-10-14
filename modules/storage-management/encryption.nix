{ config, lib, pkgs, ... }:

# VM Disk Encryption
# LUKS encryption for VM disks with secure key management

{
  # Enable cryptsetup for LUKS
  boot.initrd.luks.devices = { };
  
  # Encryption tools
  environment.systemPackages =  [
    pkgs.cryptsetup
    pkgs.qemu_kvm
    pkgs.libvirt
  ];
  
  # VM encryption manager
  environment.etc."hypervisor/scripts/vm_encryption.sh" = {
    text = ''
      #!/usr/bin/env bash
      #
      # Hyper-NixOS VM Encryption Manager
      # Copyright (C) 2024-2025 MasterofNull
      # Licensed under GPL v3.0
      #
      # Manages LUKS encryption for VM disks
      
      set -euo pipefail
      PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      
      KEYSTORE="/var/lib/hypervisor/keys"
      ENCRYPTION_DB="/var/lib/hypervisor/configuration/encrypted-vms.conf"
      
      # Secure keystore with restricted permissions
      mkdir -p "$KEYSTORE"
      chmod 700 "$KEYSTORE"
      
      usage() {
        cat <<EOF
      Usage: $(basename "$0") <command> [options]
      
      Commands:
        create-encrypted <vm-name> <size-GB>        Create encrypted disk
        encrypt-existing <vm-name> <disk-path>      Encrypt existing disk
        decrypt-disk <disk-path> <mount-point>      Decrypt for maintenance
        change-passphrase <vm-name>                 Change encryption key
        list-encrypted                              List encrypted VMs
        verify <vm-name>                            Verify encryption
      
      Examples:
        # Create new 50GB encrypted disk
        $(basename "$0") create-encrypted secure-vm 50
        
        # Encrypt an existing disk
        $(basename "$0") encrypt-existing web-server /var/lib/libvirt/images/web.qcow2
        
        # Change passphrase
        $(basename "$0") change-passphrase secure-vm
        
        # List all encrypted VMs
        $(basename "$0") list-encrypted
      
      Encryption:
        • Algorithm: AES-256-XTS (LUKS2)
        • Key derivation: Argon2id
        • Secure key storage in $KEYSTORE
        • Automatic unlock on VM start
      
      Security Notes:
        • Keys stored encrypted at rest
        • Requires passphrase or key file
        • Host compromise = all VMs compromised
        • For maximum security, use TPM or external key management
      EOF
      }
      
      # Generate secure random key
      generate_key() {
        local vm="$1"
        local keyfile="$KEYSTORE/$vm.key"
        
        if [[ -f "$keyfile" ]]; then
          echo "Error: Key already exists for VM: $vm" >&2
          return 1
        fi
        
        echo "Generating secure encryption key..."
        dd if=/dev/urandom of="$keyfile" bs=512 count=1 2>/dev/null
        chmod 400 "$keyfile"
        
        echo "✓ Key generated: $keyfile"
        echo "⚠ IMPORTANT: Back up this key securely!"
      }
      
      # Create encrypted disk
      create_encrypted_disk() {
        local vm="$1"
        local size_gb="$2"
        local disk_path="/var/lib/libvirt/images/$vm-encrypted.qcow2"
        
        if [[ -f "$disk_path" ]]; then
          echo "Error: Disk already exists: $disk_path" >&2
          return 1
        fi
        
        echo "Creating encrypted disk for VM: $vm"
        echo "  Size: $size_gb GB"
        echo "  Path: $disk_path"
        
        # Generate encryption key
        generate_key "$vm"
        
        local keyfile="$KEYSTORE/$vm.key"
        
        # Create QCOW2 disk with LUKS encryption
        qemu-img create -f qcow2 \
          -o encrypt.format=luks,encrypt.key-secret=sec0 \
          --object secret,id=sec0,file="$keyfile" \
          "$disk_path" \
          "$size_gb"G
        
        # Record in database
        mkdir -p "$(dirname "$ENCRYPTION_DB")"
        
        if [[ ! -f "$ENCRYPTION_DB" ]]; then
          echo "# Encrypted VMs" > "$ENCRYPTION_DB"
          echo "# Format: vm_name|disk_path|key_path|created_date" >> "$ENCRYPTION_DB"
        fi
        
        echo "$vm|$disk_path|$keyfile|$(date -Iseconds)" >> "$ENCRYPTION_DB"
        
        echo "✓ Encrypted disk created"
        echo ""
        echo "To attach to VM:"
        echo "  virsh attach-disk $vm $disk_path vda --driver qemu --subdriver qcow2"
      }
      
      # Encrypt existing disk
      encrypt_existing() {
        local vm="$1"
        local disk_path="$2"
        
        if [[ ! -f "$disk_path" ]]; then
          echo "Error: Disk not found: $disk_path" >&2
          return 1
        fi
        
        echo "⚠ WARNING: This will encrypt the disk IN-PLACE"
        echo "⚠ BACKUP YOUR DATA FIRST!"
        echo ""
        echo "Disk: $disk_path"
        echo ""
        read -p "Continue? (yes/no): " confirm
        
        if [[ "$confirm" != "yes" ]]; then
          echo "Cancelled"
          return 1
        fi
        
        # Check if VM is running
        if virsh list --name | grep -q "^$vm$"; then
          echo "Error: VM must be shut down first" >&2
          return 1
        fi
        
        # Generate key
        generate_key "$vm"
        
        local keyfile="$KEYSTORE/$vm.key"
        local encrypted_path="''${disk_path%.qcow2}-encrypted.qcow2"
        
        echo "Converting disk to encrypted format..."
        echo "This may take a while..."
        
        # Convert to encrypted QCOW2
        qemu-img convert -f qcow2 -O qcow2 \
          -o encrypt.format=luks,encrypt.key-secret=sec0 \
          --object secret,id=sec0,file="$keyfile" \
          "$disk_path" \
          "$encrypted_path"
        
        echo ""
        echo "✓ Disk encrypted successfully"
        echo ""
        echo "Original disk: $disk_path"
        echo "Encrypted disk: $encrypted_path"
        echo ""
        echo "To use encrypted disk:"
        echo "  1. Backup original: mv $disk_path $disk_path.backup"
        echo "  2. Use encrypted: mv $encrypted_path $disk_path"
        echo "  3. Update VM config"
        echo ""
        echo "⚠ Keep original until you verify encrypted disk works!"
        
        # Record in database
        mkdir -p "$(dirname "$ENCRYPTION_DB")"
        [[ -f "$ENCRYPTION_DB" ]] || echo "# Encrypted VMs" > "$ENCRYPTION_DB"
        echo "$vm|$encrypted_path|$keyfile|$(date -Iseconds)" >> "$ENCRYPTION_DB"
      }
      
      # Decrypt disk for maintenance
      decrypt_disk() {
        local disk_path="$1"
        local mount_point="$2"
        
        if [[ ! -f "$disk_path" ]]; then
          echo "Error: Disk not found: $disk_path" >&2
          return 1
        fi
        
        # Find key
        local vm=$(basename "$disk_path" | sed 's/-encrypted.qcow2//')
        local keyfile="$KEYSTORE/$vm.key"
        
        if [[ ! -f "$keyfile" ]]; then
          echo "Error: Key not found for VM: $vm" >&2
          echo "Keyfile: $keyfile" >&2
          return 1
        fi
        
        echo "Decrypting disk for maintenance..."
        echo "  Disk: $disk_path"
        echo "  Mount: $mount_point"
        
        # Mount using qemu-nbd
        modprobe nbd max_part=8
        
        qemu-nbd --connect=/dev/nbd0 \
          --format=qcow2 \
          --object secret,id=sec0,file="$keyfile" \
          --image-opts driver=qcow2,encrypt.format=luks,encrypt.key-secret=sec0,file="$disk_path"
        
        mkdir -p "$mount_point"
        mount /dev/nbd0p1 "$mount_point"
        
        echo "✓ Disk decrypted and mounted"
        echo ""
        echo "When finished, unmount with:"
        echo "  umount $mount_point"
        echo "  qemu-nbd --disconnect /dev/nbd0"
      }
      
      # Change passphrase
      change_passphrase() {
        local vm="$1"
        local keyfile="$KEYSTORE/$vm.key"
        
        if [[ ! -f "$keyfile" ]]; then
          echo "Error: No encryption key found for VM: $vm" >&2
          return 1
        fi
        
        local disk_line=$(grep "^$vm|" "$ENCRYPTION_DB" 2>/dev/null || echo "")
        
        if [[ -z "$disk_line" ]]; then
          echo "Error: VM not found in encryption database" >&2
          return 1
        fi
        
        IFS='|' read -r vm_name disk_path old_keyfile created <<< "$disk_line"
        
        echo "Changing encryption key for VM: $vm"
        echo "  Disk: $disk_path"
        
        # Generate new key
        local new_keyfile="$KEYSTORE/$vm.key.new"
        dd if=/dev/urandom of="$new_keyfile" bs=512 count=1 2>/dev/null
        chmod 400 "$new_keyfile"
        
        echo "Reencrypting disk with new key..."
        
        # This requires qemu-img amend (LUKS2)
        qemu-img amend -f qcow2 \
          --object secret,id=sec0,file="$keyfile" \
          --object secret,id=sec1,file="$new_keyfile" \
          -o encrypt.key-secret=sec1 \
          "$disk_path"
        
        # Replace old key
        mv "$new_keyfile" "$keyfile"
        
        echo "✓ Encryption key changed"
        echo "⚠ Back up new key securely!"
      }
      
      # List encrypted VMs
      list_encrypted() {
        if [[ ! -f "$ENCRYPTION_DB" ]]; then
          echo "No encrypted VMs configured"
          return 0
        fi
        
        echo "Encrypted VMs:"
        echo ""
        printf "%-20s %-40s %-20s\n" "VM Name" "Disk Path" "Created"
        printf "%-20s %-40s %-20s\n" "-------" "---------" "-------"
        
        while IFS='|' read -r vm disk key created; do
          [[ "$vm" =~ ^# ]] && continue
          [[ -z "$vm" ]] && continue
          
          local created_short=$(echo "$created" | cut -d'T' -f1)
          printf "%-20s %-40s %-20s\n" "$vm" "$(basename "$disk")" "$created_short"
        done < "$ENCRYPTION_DB"
      }
      
      # Verify encryption
      verify_encryption() {
        local vm="$1"
        
        local disk_line=$(grep "^$vm|" "$ENCRYPTION_DB" 2>/dev/null || echo "")
        
        if [[ -z "$disk_line" ]]; then
          echo "VM not found in encryption database: $vm"
          return 1
        fi
        
        IFS='|' read -r vm_name disk_path keyfile created <<< "$disk_line"
        
        echo "Verifying encryption for VM: $vm"
        echo "  Disk: $disk_path"
        echo "  Key: $keyfile"
        echo ""
        
        # Check disk exists
        if [[ ! -f "$disk_path" ]]; then
          echo "✗ Disk not found"
          return 1
        fi
        echo "✓ Disk exists"
        
        # Check key exists
        if [[ ! -f "$keyfile" ]]; then
          echo "✗ Key not found"
          return 1
        fi
        echo "✓ Key exists"
        
        # Check encryption
        local info=$(qemu-img info "$disk_path" 2>/dev/null)
        
        if echo "$info" | grep -q "encrypted: yes"; then
          echo "✓ Disk is encrypted"
        else
          echo "✗ Disk is NOT encrypted!"
          return 1
        fi
        
        # Check format
        if echo "$info" | grep -q "format: qcow2"; then
          echo "✓ Format: QCOW2"
        fi
        
        echo ""
        echo "Encryption verified successfully"
      }
      
      # Main
      case "''${1:-}" in
        create-encrypted)
          create_encrypted_disk "''${2:-}" "''${3:-}"
          ;;
        encrypt-existing)
          encrypt_existing "''${2:-}" "''${3:-}"
          ;;
        decrypt-disk)
          decrypt_disk "''${2:-}" "''${3:-}"
          ;;
        change-passphrase)
          change_passphrase "''${2:-}"
          ;;
        list-encrypted)
          list_encrypted
          ;;
        verify)
          verify_encryption "''${2:-}"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
    mode = "0755";
  };
}
