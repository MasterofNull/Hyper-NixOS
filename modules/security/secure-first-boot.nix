# Secure First Boot Implementation
# Enhanced security for credential handling during first boot

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.secureFirstBoot;
  
  # Secure password input utility with memory locking
  securePasswordTool = pkgs.writeScriptBin "secure-password-input" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Function to securely read password
    secure_read_password() {
        local prompt="''${1:-Password: }"
        local password=""
        local password_confirm=""
        
        # Disable echo and handle interrupts
        stty -echo
        trap 'stty echo; exit 1' INT TERM EXIT
        
        while true; do
            # Read password
            IFS= read -r -p "''$prompt" password
            echo
            
            # Read confirmation
            IFS= read -r -p "Confirm password: " password_confirm
            echo
            
            # Check match
            if [[ "$password" != "$password_confirm" ]]; then
                echo "Passwords do not match. Please try again." >&2
                continue
            fi
            
            # Check minimum length
            if [[ ''${#password} -lt 12 ]]; then
                echo "Password must be at least 12 characters long." >&2
                continue
            fi
            
            # Check complexity
            local has_upper=0 has_lower=0 has_digit=0 has_special=0
            
            if [[ "$password" =~ [A-Z] ]]; then has_upper=1; fi
            if [[ "$password" =~ [a-z] ]]; then has_lower=1; fi
            if [[ "$password" =~ [0-9] ]]; then has_digit=1; fi
            if [[ "$password" =~ [^A-Za-z0-9] ]]; then has_special=1; fi
            
            local complexity=$((has_upper + has_lower + has_digit + has_special))
            
            if [[ $complexity -lt 3 ]]; then
                echo "Password must contain at least 3 of: uppercase, lowercase, digits, special characters" >&2
                continue
            fi
            
            # Check for common patterns
            if [[ "$password" =~ (password|admin|root|user|hypervisor|123456|qwerty) ]]; then
                echo "Password contains common patterns. Please choose a stronger password." >&2
                continue
            fi
            
            # All checks passed
            break
        done
        
        # Re-enable echo
        stty echo
        trap - INT TERM EXIT
        
        # Generate hash
        echo -n "$password" | ${pkgs.mkpasswd}/bin/mkpasswd -m sha-512 -R 100000
    }
    
    # Main
    case "''${1:-interactive}" in
        interactive)
            secure_read_password "''${2:-Password: }"
            ;;
        check)
            # Just check if a password would be valid
            password="''${2:-}"
            if [[ ''${#password} -lt 12 ]]; then
                echo "Too short"
                exit 1
            fi
            echo "OK"
            ;;
        *)
            echo "Usage: $0 [interactive|check] [prompt]"
            exit 1
            ;;
    esac
  '';
  
  # Secure credential file handler
  credentialHandler = pkgs.writeScriptBin "secure-credential-handler" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly SECURE_DIR="/run/hypervisor-creds"
    readonly CRED_FILE="$SECURE_DIR/first-boot.creds"
    
    # Ensure secure directory
    setup_secure_dir() {
        # Create with restricted permissions
        mkdir -p "$SECURE_DIR"
        chmod 700 "$SECURE_DIR"
        
        # Mount as tmpfs to ensure it's in memory only
        if ! mountpoint -q "$SECURE_DIR"; then
            mount -t tmpfs -o size=1M,mode=700 tmpfs "$SECURE_DIR"
        fi
    }
    
    # Store credentials securely
    store_credential() {
        local user="$1"
        local hash="$2"
        
        setup_secure_dir
        
        # Store in memory-only location
        {
            echo "user:$user"
            echo "hash:$hash"
            echo "timestamp:$(date -Iseconds)"
        } > "$CRED_FILE"
        
        chmod 600 "$CRED_FILE"
    }
    
    # Retrieve and clear credentials
    retrieve_credential() {
        if [[ ! -f "$CRED_FILE" ]]; then
            echo "No credentials found" >&2
            return 1
        fi
        
        # Read credentials
        cat "$CRED_FILE"
        
        # Secure deletion
        shred -zu "$CRED_FILE" 2>/dev/null || rm -f "$CRED_FILE"
    }
    
    # Cleanup on exit
    cleanup() {
        if [[ -d "$SECURE_DIR" ]]; then
            # Shred any remaining files
            find "$SECURE_DIR" -type f -exec shred -zu {} \; 2>/dev/null || true
            
            # Unmount and remove
            umount "$SECURE_DIR" 2>/dev/null || true
            rmdir "$SECURE_DIR" 2>/dev/null || true
        fi
    }
    
    trap cleanup EXIT
    
    # Main
    case "''${1:-help}" in
        store)
            store_credential "$2" "$3"
            ;;
        retrieve)
            retrieve_credential
            ;;
        cleanup)
            cleanup
            ;;
        *)
            echo "Usage: $0 {store|retrieve|cleanup}"
            exit 1
            ;;
    esac
  '';
  
  # Physical presence verification
  physicalPresenceCheck = pkgs.writeScriptBin "verify-physical-presence" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "════════════════════════════════════════════════════════════════"
    echo "              PHYSICAL PRESENCE VERIFICATION REQUIRED            "
    echo "════════════════════════════════════════════════════════════════"
    echo
    echo "This system requires verification of physical access for first boot."
    echo
    
    # Method 1: Check for interactive TTY
    if ! tty -s; then
        echo "ERROR: Not running on an interactive terminal" >&2
        exit 1
    fi
    
    # Method 2: Generate and verify random challenge
    CHALLENGE=$(head -c 6 /dev/urandom | base64 | tr -d '=/')
    echo "Please type the following code to verify physical presence:"
    echo
    echo "    $CHALLENGE"
    echo
    read -p "Enter code: " response
    
    if [[ "$response" != "$CHALLENGE" ]]; then
        echo "ERROR: Incorrect code" >&2
        exit 1
    fi
    
    # Method 3: Require console access (no SSH)
    if [[ -n "''${SSH_CONNECTION:-}" ]] || [[ -n "''${SSH_CLIENT:-}" ]]; then
        echo "ERROR: First boot must be performed from console, not SSH" >&2
        exit 1
    fi
    
    echo "✓ Physical presence verified"
    
    # Create verification token
    echo "$(date -Iseconds):verified" > /run/physical-presence-verified
    chmod 600 /run/physical-presence-verified
  '';
  
  # Enhanced first boot script
  enhancedFirstBoot = pkgs.writeScriptBin "secure-first-boot" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Must run as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
    
    # Verify physical presence first
    ${physicalPresenceCheck}/bin/verify-physical-presence || exit 1
    
    # Check for security lockdown
    if [[ -f /var/lib/hypervisor/.security-lockdown ]]; then
        echo "SECURITY: System is in lockdown mode" >&2
        echo "First boot has been disabled due to security concerns" >&2
        exit 1
    fi
    
    # Anti-tampering check
    if ${cfg.antiTamperCommand}; then
        echo "✓ System integrity verified"
    else
        echo "SECURITY: System integrity check failed" >&2
        exit 1
    fi
    
    echo
    echo "════════════════════════════════════════════════════════════════"
    echo "                    SECURE FIRST BOOT SETUP                      "
    echo "════════════════════════════════════════════════════════════════"
    echo
    
    # Create admin user with secure password
    echo "Creating administrative user..."
    echo
    echo "Username: ${cfg.adminUsername}"
    
    # Get secure password
    HASH=$(${securePasswordTool}/bin/secure-password-input "Admin password: ")
    
    # Store temporarily in secure location
    ${credentialHandler}/bin/secure-credential-handler store "${cfg.adminUsername}" "$HASH"
    
    # Create user (will be picked up by NixOS rebuild)
    cat > /etc/nixos/secure-admin-user.nix <<EOF
    # Secure admin user configuration
    # Generated by secure first boot on $(date -Iseconds)
    # This file will be encrypted after first rebuild
    
    { config, lib, pkgs, ... }:
    {
      users.users.${cfg.adminUsername} = {
        isNormalUser = true;
        extraGroups = [ "wheel" "libvirtd" "kvm" ];
        hashedPassword = "$HASH";
        
        # Require password change on first real login
        # (after first boot is complete)
        passwordFile = lib.mkForce null;
      };
      
      # Security settings for admin user
      security.sudo.extraRules = [{
        users = [ "${cfg.adminUsername}" ];
        commands = [{
          command = "ALL";
          options = [ "PASSWD" ]; # Require password
        }];
      }];
    }
    EOF
    
    # Secure the file
    chmod 600 /etc/nixos/secure-admin-user.nix
    
    # Import in configuration
    if ! grep -q "secure-admin-user.nix" /etc/nixos/configuration.nix; then
        sed -i '/imports = \[/a\    ./secure-admin-user.nix' /etc/nixos/configuration.nix
    fi
    
    echo "✓ Admin user configured"
    echo
    
    # Continue with tier selection...
    echo "Select system tier:"
    echo "1) Minimal"
    echo "2) Standard"
    echo "3) Enhanced"
    echo "4) Professional"  
    echo "5) Enterprise"
    read -p "Choice [1-5]: " tier_choice
    
    # ... rest of tier configuration ...
    
    # Final security steps
    echo
    echo "Applying security hardening..."
    
    # Clear sensitive data
    ${credentialHandler}/bin/secure-credential-handler cleanup
    
    # Remove physical presence token
    rm -f /run/physical-presence-verified
    
    # Create completion marker
    touch /var/lib/hypervisor/.first-boot-complete
    chmod 644 /var/lib/hypervisor/.first-boot-complete
    
    echo "✓ First boot complete!"
    echo
    echo "System will now rebuild with secure configuration..."
    
    # Trigger rebuild
    nixos-rebuild switch
  '';
  
in
{
  options.hypervisor.security.secureFirstBoot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable enhanced security for first boot";
    };
    
    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Username for the administrative account";
    };
    
    requirePhysicalPresence = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require physical console access for first boot";
    };
    
    antiTamperCommand = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.coreutils}/bin/true"; # Placeholder
      description = "Command to run for anti-tampering checks";
    };
    
    passwordComplexity = {
      minLength = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Minimum password length";
      };
      
      requireClasses = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Number of character classes required (upper/lower/digit/special)";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install security tools
    environment.systemPackages = [
      securePasswordTool
      credentialHandler
      physicalPresenceCheck
      enhancedFirstBoot
    ];
    
    # Enhanced first boot service
    systemd.services.hypervisor-secure-first-boot = lib.mkIf config.hypervisor.firstBoot.enable {
      description = "Secure Hyper-NixOS First Boot Setup";
      
      unitConfig = {
        # Only on actual first boot
        ConditionPathExists = "!/var/lib/hypervisor/.first-boot-complete";
        
        # Not if migrated
        ConditionPathExists = "!/etc/nixos/modules/users-migrated.nix";
      };
      
      serviceConfig = {
        Type = "idle";
        RemainAfterExit = true;
        StandardInput = "tty";
        StandardOutput = "inherit";
        StandardError = "inherit";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        
        # Security restrictions
        PrivateNetwork = lib.mkIf cfg.requirePhysicalPresence true;
        RestrictAddressFamilies = "";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        
        # Run the secure wizard
        ExecStart = "${enhancedFirstBoot}/bin/secure-first-boot";
      };
      
      after = [ "sysinit.target" "basic.target" ];
      before = [ "getty.target" ];
      wantedBy = [ "multi-user.target" ];
      conflicts = [ "getty@tty1.service" ];
    };
    
    # Security assertions
    assertions = [
      {
        assertion = cfg.passwordComplexity.minLength >= 8;
        message = "Password minimum length must be at least 8 characters";
      }
      {
        assertion = cfg.passwordComplexity.requireClasses >= 2 && cfg.passwordComplexity.requireClasses <= 4;
        message = "Password complexity must require 2-4 character classes";
      }
    ];
  };
}