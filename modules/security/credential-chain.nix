# Credential Chain Security Module
# Implements secure credential migration with tamper detection

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.credentialChain;
  
  # Script to verify credential integrity
  credentialVerifier = pkgs.writeScriptBin "verify-credentials" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly HASH_FILE="/var/lib/hypervisor/.credential-hash"
    readonly TAMPER_FLAG="/var/lib/hypervisor/.tamper-detected"
    readonly SECURITY_LOG="/var/log/hypervisor/security.log"
    
    # Function to compute system hash
    compute_system_hash() {
        local shadow_hash=$(sha512sum /etc/shadow 2>/dev/null | cut -d' ' -f1 || echo "no-shadow")
        local passwd_hash=$(sha512sum /etc/passwd | cut -d' ' -f1)
        local machine_id=$(cat /etc/machine-id)
        
        echo -n "''${shadow_hash}:''${passwd_hash}:''${machine_id}" | sha512sum | cut -d' ' -f1
    }
    
    # Check if credentials have been tampered with
    check_integrity() {
        if [[ ! -f "''$HASH_FILE" ]]; then
            echo "No credential hash found - first boot allowed"
            return 0
        fi
        
        local stored_hash=$(cat "''$HASH_FILE")
        local current_hash=$(compute_system_hash)
        
        if [[ "$stored_hash" != "$current_hash" ]]; then
            echo "SECURITY ALERT: Credential tampering detected!"
            
            # Create tamper flag
            mkdir -p "$(dirname "''$TAMPER_FLAG")"
            cat > "''$TAMPER_FLAG" <<EOF
    Tamper detected at: $(date -Iseconds)
    Expected hash: ''$stored_hash
    Current hash: ''$current_hash
    EOF
            
            # Log security event
            mkdir -p "$(dirname "''$SECURITY_LOG")"
            echo "[$(date -Iseconds)] SECURITY: Credential tamper detected" >> "''$SECURITY_LOG"
            
            return 1
        fi
        
        echo "Credential integrity verified"
        return 0
    }
    
    # Main
    case "''${1:-check}" in
        check)
            check_integrity
            ;;
        update)
            # Only allow update in specific conditions
            if [[ -f "''$TAMPER_FLAG" ]]; then
                echo "ERROR: Cannot update hash - tamper flag is set"
                exit 1
            fi
            
            echo "Updating credential hash..."
            compute_system_hash > "''$HASH_FILE"
            chmod 600 "''$HASH_FILE"
            echo "Hash updated"
            ;;
        *)
            echo "Usage: $0 {check|update}"
            exit 1
            ;;
    esac
  '';
  
  # Script to import host credentials
  credentialImporter = pkgs.writeScriptBin "import-host-credentials" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly CRED_FILE="/tmp/hyper-nixos-creds.enc"
    readonly HASH_FILE="/var/lib/hypervisor/.credential-hash"
    readonly IMPORT_LOG="/var/log/hypervisor/credential-import.log"
    
    # Colors
    readonly GREEN='\033[0;32m'
    readonly RED='\033[0;31m'
    readonly YELLOW='\033[1;33m'
    readonly NC='\033[0m'
    
    import_credentials() {
        if [[ ! -f "''$CRED_FILE" ]]; then
            echo "No credential package found"
            return 1
        fi
        
        echo -e "''${YELLOW}Importing host credentials...''${NC}"
        
        # Decode the package
        local package=$(base64 -d "''$CRED_FILE")
        
        # Extract user information
        local username=$(echo "$package" | ${pkgs.jq}/bin/jq -r '.credentials.username')
        local password_hash=$(echo "$package" | ${pkgs.jq}/bin/jq -r '.credentials.password_hash')
        local groups=$(echo "$package" | ${pkgs.jq}/bin/jq -r '.credentials.groups')
        local migrated_from=$(echo "$package" | ${pkgs.jq}/bin/jq -r '.credentials.migrated_from')
        
        # Verify integrity
        local stored_hash=$(echo "$package" | ${pkgs.jq}/bin/jq -r '.integrity.hash')
        local salt=$(echo "$package" | ${pkgs.jq}/bin/jq -r '.integrity.salt')
        
        # Recompute hash to verify
        local cred_data=$(echo "$package" | ${pkgs.jq}/bin/jq -c '.credentials')
        local computed_hash=$(echo -n "''${cred_data}''${salt}" | sha512sum | cut -d' ' -f1)
        
        if [[ "$stored_hash" != "$computed_hash" ]]; then
            echo -e "''${RED}ERROR: Credential package integrity check failed!''${NC}"
            return 1
        fi
        
        echo -e "''${GREEN}✓ Credential integrity verified''${NC}"
        
        # Create user configuration
        cat > /etc/nixos/modules/users-migrated.nix <<EOF
    # Automatically generated from host system migration
    # Migrated from: ''$migrated_from
    # Migration date: $(date -Iseconds)
    
    { config, lib, pkgs, ... }:
    
    {
      users.users.''$username = {
        isNormalUser = true;
        description = "Migrated from ''$migrated_from";
        hashedPassword = "''$password_hash";
        extraGroups = [ ''$(echo "''$groups" | sed 's/ /", "/g' | sed 's/^/"/; s/$/"/') ];
      };
      
      # Mark that we have migrated credentials
      environment.etc."hypervisor/migrated-from".text = "''$migrated_from";
    }
    EOF
        
        # Create initial credential hash
        mkdir -p "$(dirname "''$HASH_FILE")"
        ${credentialVerifier}/bin/verify-credentials update
        
        # Log the import
        mkdir -p "$(dirname "''$IMPORT_LOG")"
        echo "[''$(date -Iseconds)] Imported credentials for ''$username from ''$migrated_from" >> "''$IMPORT_LOG"
        
        # Secure cleanup
        shred -u "''$CRED_FILE" 2>/dev/null || rm -f "''$CRED_FILE"
        
        echo -e "''${GREEN}✓ Credentials imported successfully''${NC}"
        echo "  User: ''$username"
        echo "  Groups: ''$groups"
        echo "  Source: ''$migrated_from"
        
        return 0
    }
    
    # Main
    if [[ ''$EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
    
    import_credentials
  '';
in
{
  options.hypervisor.security.credentialChain = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable credential chain security with tamper detection";
    };
    
    enforceIntegrity = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enforce credential integrity checks";
    };
    
    triggerOnTamper = lib.mkOption {
      type = lib.types.enum [ "lock" "alert" "both" ];
      default = "both";
      description = "Action to take when tampering is detected";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install verification scripts
    environment.systemPackages = [ 
      credentialVerifier 
      credentialImporter 
    ];
    
    # Systemd service to check credential integrity
    systemd.services.credential-integrity-check = {
      description = "Verify credential chain integrity";
      after = [ "sysinit.target" ];
      before = [ "hypervisor-first-boot.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${credentialVerifier}/bin/verify-credentials check";
        ExecStartPost = pkgs.writeShellScript "check-tamper" ''
          if [[ -f /var/lib/hypervisor/.tamper-detected ]]; then
            case "${cfg.triggerOnTamper}" in
              lock|both)
                # Lock the system
                touch /var/lib/hypervisor/.security-lockdown
                # Disable first-boot
                touch /var/lib/hypervisor/.first-boot-complete
                ;;
            esac
            
            case "${cfg.triggerOnTamper}" in
              alert|both)
                # Send security alert
                logger -p security.crit "SECURITY: Credential tampering detected - system locked"
                # In production, this could send email/SMS alerts
                ;;
            esac
          fi
        '';
      };
    };
    
    # Import service that runs before first-boot
    systemd.services.import-host-credentials = {
      description = "Import host system credentials if available";
      after = [ "sysinit.target" ];
      before = [ "hypervisor-first-boot.service" ];
      wantedBy = [ "multi-user.target" ];
      
      unitConfig = {
        ConditionPathExists = "/tmp/hyper-nixos-creds.enc";
      };
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${credentialImporter}/bin/import-host-credentials";
      };
    };
    
    # Security monitoring
    services.auditd.enable = true;
    security.audit.enable = true;
    security.audit.rules = lib.mkAfter [
      # Monitor credential files
      "-w /etc/shadow -p wa -k credential_changes"
      "-w /etc/passwd -p wa -k credential_changes"
      "-w /var/lib/hypervisor/.credential-hash -p wa -k credential_integrity"
      "-w /var/lib/hypervisor/.tamper-detected -p wa -k security_alert"
    ];
  };
}