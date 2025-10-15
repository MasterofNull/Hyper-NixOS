# First Boot Security Guide

## Quick Start: Immediate Security Improvements

### 1. Move Credential File Out of /tmp

Instead of `/tmp/hyper-nixos-creds.enc`, use a secure location:

```bash
# In installer script, change:
CRED_FILE="/run/install/hyper-nixos-creds.enc"  # RAM-only location

# Create secure directory
mkdir -p /run/install
chmod 700 /run/install
mount -t tmpfs -o size=10M,mode=700 tmpfs /run/install
```

### 2. Use systemd Credentials (Recommended)

For NixOS 23.11+, use systemd's built-in credential encryption:

```nix
# In your first-boot service
systemd.services.hypervisor-first-boot = {
  serviceConfig = {
    # Credentials are automatically encrypted at rest
    LoadCredential = [
      "admin-password:/run/install/admin.cred"
    ];
  };
  
  script = ''
    # Access decrypted credential in service
    ADMIN_HASH=$(cat "$CREDENTIALS_DIRECTORY/admin-password")
  '';
};
```

### 3. Minimal Secure Password Function

Add this to your first-boot script:

```bash
secure_password_prompt() {
    local user="$1"
    local password=""
    local password_confirm=""
    
    while true; do
        # Disable echo
        read -s -p "Enter password for $user: " password
        echo
        read -s -p "Confirm password: " password_confirm
        echo
        
        # Basic validation
        if [[ "$password" != "$password_confirm" ]]; then
            echo "Passwords don't match!" >&2
            continue
        fi
        
        if [[ ${#password} -lt 12 ]]; then
            echo "Password must be at least 12 characters!" >&2
            continue
        fi
        
        # Check for common passwords
        if [[ "$password" =~ (password|admin|user|123456) ]]; then
            echo "Password too common!" >&2
            continue
        fi
        
        break
    done
    
    # Generate hash with high rounds
    echo -n "$password" | mkpasswd -m sha-512 -R 100000
}
```

### 4. Console-Only First Boot

Prevent SSH during first boot:

```nix
systemd.services.hypervisor-first-boot = {
  serviceConfig = {
    # ... existing config ...
    
    # Add environment check
    Environment = "FIRST_BOOT_SECURE=1";
  };
  
  preStart = ''
    # Refuse to run over SSH
    if [[ -n "''${SSH_CONNECTION:-}" ]]; then
      echo "First boot must be run from console, not SSH!" >&2
      exit 1
    fi
  '';
};
```

### 5. Time-Limited First Boot

Only allow first boot within 1 hour of installation:

```bash
# In first-boot script
check_time_window() {
    local install_time=$(stat -c %Y /etc/machine-id 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local elapsed=$((current_time - install_time))
    
    # 3600 seconds = 1 hour
    if [[ $elapsed -gt 3600 ]]; then
        echo "First boot time window expired!" >&2
        echo "Manual setup required - contact administrator" >&2
        exit 1
    fi
}
```

## Complete Example Integration

Here's how to integrate these improvements into your existing first-boot.nix:

```nix
{ config, lib, pkgs, ... }:
let
  # Secure first boot script with improvements
  secureFirstBootScript = pkgs.writeScriptBin "first-boot-wizard" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Security checks
    if [[ $EUID -ne 0 ]]; then
        echo "Must run as root!" >&2
        exit 1
    fi
    
    if [[ -n "''${SSH_CONNECTION:-}" ]]; then
        echo "Must run from console, not SSH!" >&2
        exit 1
    fi
    
    # Time window check (1 hour from install)
    INSTALL_TIME=$(stat -c %Y /etc/machine-id 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    if [[ $((CURRENT_TIME - INSTALL_TIME)) -gt 3600 ]]; then
        echo "First boot window expired!" >&2
        exit 1
    fi
    
    # Secure password function
    secure_password() {
        local user="$1"
        local pass=""
        local confirm=""
        
        while true; do
            read -s -p "Password for $user: " pass
            echo
            read -s -p "Confirm: " confirm
            echo
            
            [[ "$pass" != "$confirm" ]] && echo "Mismatch!" && continue
            [[ ''${#pass} -lt 12 ]] && echo "Too short!" && continue
            [[ "$pass" =~ (password|admin|123) ]] && echo "Too common!" && continue
            
            break
        done
        
        echo -n "$pass" | ${pkgs.mkpasswd}/bin/mkpasswd -m sha-512 -R 100000
    }
    
    # Create admin securely
    echo "Creating admin user..."
    HASH=$(secure_password "admin")
    
    # Write config to secure location (not /tmp!)
    cat > /run/admin-config.nix <<EOF
    { config, lib, pkgs, ... }:
    {
      users.users.admin = {
        isNormalUser = true;
        extraGroups = [ "wheel" "libvirtd" "kvm" ];
        hashedPassword = "$HASH";
      };
    }
    EOF
    
    # Move to final location
    mv /run/admin-config.nix /etc/nixos/admin-config.nix
    chmod 600 /etc/nixos/admin-config.nix
    
    # ... rest of setup ...
  '';
in
{
  # ... your existing configuration ...
  
  # Use the secure script
  environment.systemPackages = [ secureFirstBootScript ];
}
```

## Additional Recommendations

### For High Security Environments

1. **Use Hardware Security Module (HSM)**:
   ```nix
   # Require FIDO2 key for admin
   security.pam.u2f = {
     enable = true;
     control = "required";
   };
   ```

2. **Enable Secure Boot**:
   ```nix
   boot.loader.systemd-boot.enable = true;
   boot.loader.efi.canTouchEfiVariables = true;
   boot.initrd.systemd.enable = true;  # For TPM2 support
   ```

3. **Use TPM2 for Credential Sealing**:
   ```bash
   # Seal password to TPM2 PCRs
   echo -n "$PASSWORD_HASH" | systemd-creds encrypt \
     --tpm2-device=auto --tpm2-pcrs=0,7 \
     - /etc/credstore/admin.cred
   ```

### For Standard Deployments

The minimal improvements above provide good security:
- ✅ No credentials in world-readable locations
- ✅ Strong password requirements
- ✅ Console-only first boot
- ✅ Time-limited setup window
- ✅ High-cost password hashing

## Testing Your Implementation

```bash
# Test password validation
echo "weak" | secure_password_prompt "test" # Should fail
echo "StrongP@ssw0rd123!" | secure_password_prompt "test" # Should succeed

# Test SSH rejection
SSH_CONNECTION="test" ./first-boot-wizard # Should fail

# Test time window
touch -t 202501010000 /etc/machine-id # Set old timestamp
./first-boot-wizard # Should fail due to expired window
```

Remember: Security is about layers. Even implementing just the basic improvements significantly enhances your first boot security.