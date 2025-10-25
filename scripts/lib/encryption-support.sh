#!/usr/bin/env bash
# Encryption Support Library for Hyper-NixOS
# Handles detection and preservation of LUKS/dm-crypt configurations

# Detect if the system is using encryption
detect_encryption() {
  local encrypted=false
  local encryption_type=""
  local encrypted_devices=()
  
  # Method 1: Check for LUKS devices via dmsetup
  if command -v dmsetup >/dev/null 2>&1; then
    if dmsetup ls --target crypt 2>/dev/null | grep -q .; then
      encrypted=true
      encryption_type="dm-crypt/LUKS"
      
      # Get encrypted device names
      while IFS= read -r line; do
        local dev_name=$(echo "$line" | awk '{print $1}')
        encrypted_devices+=("$dev_name")
      done < <(dmsetup ls --target crypt 2>/dev/null)
    fi
  fi
  
  # Method 2: Check for LUKS headers on block devices
  if command -v cryptsetup >/dev/null 2>&1 && [[ "$encrypted" == "false" ]]; then
    for dev in /dev/sd* /dev/nvme* /dev/vd* /dev/mapper/*; do
      [[ -b "$dev" ]] || continue
      if cryptsetup isLuks "$dev" 2>/dev/null; then
        encrypted=true
        encryption_type="LUKS"
        encrypted_devices+=("$(basename "$dev")")
      fi
    done
  fi
  
  # Method 3: Check /etc/crypttab
  if [[ -f /etc/crypttab ]] && grep -v "^#" /etc/crypttab | grep -q .; then
    encrypted=true
    [[ -z "$encryption_type" ]] && encryption_type="crypttab"
    
    # Parse crypttab for devices
    while IFS= read -r line; do
      [[ "$line" =~ ^# ]] && continue
      [[ -z "$line" ]] && continue
      local dev_name=$(echo "$line" | awk '{print $1}')
      encrypted_devices+=("$dev_name")
    done < <(grep -v "^#" /etc/crypttab)
  fi
  
  # Method 4: Check current mounts for /dev/mapper
  if mount | grep -q "/dev/mapper/"; then
    if [[ "$encrypted" == "false" ]]; then
      encrypted=true
      encryption_type="device-mapper"
    fi
    
    # Get mounted encrypted devices
    while IFS= read -r dev; do
      encrypted_devices+=("$(basename "$dev")")
    done < <(mount | grep "/dev/mapper/" | awk '{print $1}')
  fi
  
  # Output results as JSON-like format
  cat <<EOF
ENCRYPTED=$encrypted
ENCRYPTION_TYPE=$encryption_type
ENCRYPTED_DEVICES=(${encrypted_devices[@]})
EOF
}

# Extract LUKS configuration from hardware-configuration.nix
extract_luks_config() {
  local hw_config="$1"
  
  if [[ ! -f "$hw_config" ]]; then
    echo ""
    return 1
  fi
  
  # Extract the entire boot.initrd.luks.devices section
  awk '
    /boot\.initrd\.luks\.devices/ && /=/ && /{/ {
      in_luks=1
      brace_count=1
      print
      next
    }
    in_luks {
      print
      # Count braces to find the end of the section
      open_count = gsub(/{/, "{", $0)
      close_count = gsub(/}/, "}", $0)
      brace_count += open_count - close_count
      if (brace_count <= 0) {
        in_luks=0
      }
    }
  ' "$hw_config"
}

# Extract all boot.initrd settings (not just LUKS)
extract_initrd_config() {
  local hw_config="$1"
  
  if [[ ! -f "$hw_config" ]]; then
    echo ""
    return 1
  fi
  
  # Extract boot.initrd.* settings
  awk '
    /boot\.initrd/ && !in_initrd {
      in_initrd=1
      line_buffer=$0
      if ($0 ~ /;$/) {
        print line_buffer
        in_initrd=0
        next
      }
      brace_count=0
      brace_count += gsub(/{/, "{", $0)
      brace_count -= gsub(/}/, "}", $0)
      if (brace_count == 0 && $0 ~ /;$/) {
        print line_buffer
        in_initrd=0
      }
      next
    }
    in_initrd {
      line_buffer = line_buffer "\n" $0
      open_count = gsub(/{/, "{", $0)
      close_count = gsub(/}/, "}", $0)
      brace_count += open_count - close_count
      if (brace_count <= 0 && $0 ~ /};?$/) {
        print line_buffer
        in_initrd=0
      }
    }
  ' "$hw_config"
}

# Validate that a hardware config has required encryption settings
validate_encryption_config() {
  local hw_config="$1"
  local required_encrypted_device="$2"  # Optional: specific device to check
  
  if [[ ! -f "$hw_config" ]]; then
    echo "ERROR: Hardware config not found: $hw_config" >&2
    return 1
  fi
  
  # Check for LUKS devices section
  if ! grep -q "boot\.initrd\.luks\.devices" "$hw_config" 2>/dev/null; then
    echo "WARNING: No LUKS devices configured in $hw_config" >&2
    return 1
  fi
  
  # If specific device required, check for it
  if [[ -n "$required_encrypted_device" ]]; then
    if ! grep -q "device.*$required_encrypted_device" "$hw_config" 2>/dev/null; then
      echo "ERROR: Required encrypted device $required_encrypted_device not found in config" >&2
      return 1
    fi
  fi
  
  # Check for availableKernelModules (required for LUKS)
  if ! grep -q "boot\.initrd\.availableKernelModules" "$hw_config" 2>/dev/null; then
    echo "WARNING: No boot.initrd.availableKernelModules defined" >&2
  fi
  
  # Check for required LUKS kernel modules
  local has_dm_mod=false
  local has_dm_crypt=false
  
  if grep -q '"dm_mod"' "$hw_config" 2>/dev/null; then
    has_dm_mod=true
  fi
  
  if grep -q '"dm_crypt"' "$hw_config" 2>/dev/null; then
    has_dm_crypt=true
  fi
  
  if [[ "$has_dm_mod" == "false" ]] || [[ "$has_dm_crypt" == "false" ]]; then
    echo "WARNING: Missing required LUKS kernel modules (dm_mod, dm_crypt)" >&2
  fi
  
  return 0
}

# Merge LUKS configuration into a hardware config that's missing it
merge_luks_config() {
  local target_config="$1"
  local luks_config="$2"
  
  if [[ ! -f "$target_config" ]]; then
    echo "ERROR: Target config not found: $target_config" >&2
    return 1
  fi
  
  if [[ -z "$luks_config" ]]; then
    echo "ERROR: No LUKS configuration provided" >&2
    return 1
  fi
  
  # Check if LUKS config already exists
  if grep -q "boot\.initrd\.luks\.devices" "$target_config" 2>/dev/null; then
    echo "INFO: Target config already has LUKS configuration, skipping merge" >&2
    return 0
  fi
  
  # Create temporary file for the merge
  local tmp_config=$(mktemp)
  
  # Insert LUKS config before the closing brace of the module
  awk -v luks="$luks_config" '
    /^}$/ && !inserted {
      # Add LUKS configuration before final closing brace
      print ""
      print "  # LUKS encryption configuration (preserved from original)"
      print luks
      print ""
      inserted=1
    }
    {print}
  ' "$target_config" > "$tmp_config"
  
  # Validate the result
  if [[ ! -s "$tmp_config" ]]; then
    echo "ERROR: Merge resulted in empty file" >&2
    rm -f "$tmp_config"
    return 1
  fi
  
  # Replace original with merged version
  mv "$tmp_config" "$target_config"
  echo "INFO: Successfully merged LUKS configuration" >&2
  return 0
}

# Display encryption information
display_encryption_info() {
  local hw_config="${1:-/etc/nixos/hardware-configuration.nix}"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Encryption Configuration Status"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # Detect current system encryption
  eval "$(detect_encryption)"
  
  if [[ "$ENCRYPTED" == "true" ]]; then
    echo "✓ System Encryption: ENABLED"
    echo "  Type: $ENCRYPTION_TYPE"
    echo "  Devices:"
    for dev in "${ENCRYPTED_DEVICES[@]}"; do
      echo "    - $dev"
    done
  else
    echo "ℹ System Encryption: NOT DETECTED"
  fi
  
  echo
  
  # Check hardware config
  if [[ -f "$hw_config" ]]; then
    echo "Hardware Configuration: $hw_config"
    
    if grep -q "boot\.initrd\.luks\.devices" "$hw_config" 2>/dev/null; then
      echo "✓ LUKS Configuration: PRESENT"
      
      # Extract and display configured devices
      echo "  Configured devices:"
      grep -A1 "boot\.initrd\.luks\.devices" "$hw_config" | \
        grep "device =" | \
        sed 's/.*device = "\([^"]*\)".*/\1/' | \
        while IFS= read -r dev; do
          echo "    - $dev"
        done
      
      # Check for keyfiles
      if grep -q "keyFile" "$hw_config" 2>/dev/null; then
        echo "  Key files: CONFIGURED"
      fi
      
      # Check for required kernel modules
      if grep -q '"dm_mod"' "$hw_config" && grep -q '"dm_crypt"' "$hw_config" 2>/dev/null; then
        echo "✓ Kernel modules: PRESENT (dm_mod, dm_crypt)"
      else
        echo "⚠ Kernel modules: MISSING (dm_mod, dm_crypt)"
      fi
    else
      echo "ℹ LUKS Configuration: NOT FOUND"
      
      if [[ "$ENCRYPTED" == "true" ]]; then
        echo
        echo "⚠ WARNING: System appears encrypted but config is missing LUKS settings!"
        echo "  This may prevent the system from booting."
      fi
    fi
  else
    echo "⚠ Hardware Configuration: NOT FOUND"
  fi
  
  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Export functions
export -f detect_encryption
export -f extract_luks_config
export -f extract_initrd_config
export -f validate_encryption_config
export -f merge_luks_config
export -f display_encryption_info
