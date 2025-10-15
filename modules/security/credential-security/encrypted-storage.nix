# Encrypted Credential Storage Module
# Provides secure encrypted storage for sensitive credentials

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.encryptedStorage;
  
  # Credential vault manager
  credentialVault = pkgs.writeScriptBin "credential-vault" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly VAULT_DIR="/var/lib/hypervisor/credential-vault"
    readonly VAULT_KEY="/run/keys/vault-master.key"
    readonly VAULT_DB="$VAULT_DIR/credentials.db"
    
    # Initialize vault
    init_vault() {
        echo "Initializing credential vault..."
        
        # Create directories
        mkdir -p "$VAULT_DIR" "$(dirname "$VAULT_KEY")"
        chmod 700 "$VAULT_DIR" "$(dirname "$VAULT_KEY")"
        
        # Generate master key if not exists
        if [[ ! -f "$VAULT_KEY" ]]; then
            echo "Generating master key..."
            
            # Use systemd-creds if available
            if command -v systemd-creds >/dev/null 2>&1; then
                dd if=/dev/urandom bs=32 count=1 2>/dev/null | \
                    systemd-creds encrypt --with-key=auto - "$VAULT_KEY"
            else
                # Fallback to raw key with TPM sealing if available
                if [[ -c /dev/tpm0 ]]; then
                    ${pkgs.tpm2-tools}/bin/tpm2_getrandom -o "$VAULT_KEY" 32
                else
                    dd if=/dev/urandom bs=32 count=1 > "$VAULT_KEY"
                fi
            fi
            
            chmod 600 "$VAULT_KEY"
        fi
        
        # Initialize database
        if [[ ! -f "$VAULT_DB" ]]; then
            ${pkgs.sqlite}/bin/sqlite3 "$VAULT_DB" <<'EOF'
    CREATE TABLE credentials (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        encrypted_data BLOB NOT NULL,
        metadata TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        accessed_at TIMESTAMP,
        expires_at TIMESTAMP
    );
    
    CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        credential_id TEXT,
        action TEXT NOT NULL,
        user TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        details TEXT
    );
    
    CREATE INDEX idx_username ON credentials(username);
    CREATE INDEX idx_expires ON credentials(expires_at);
    EOF
            chmod 600 "$VAULT_DB"
        fi
        
        echo "✓ Vault initialized"
    }
    
    # Encrypt data
    encrypt_data() {
        local data="$1"
        local key_file="''${2:-$VAULT_KEY}"
        
        # Use AES-256-GCM with authenticated encryption
        echo -n "$data" | ${pkgs.openssl}/bin/openssl enc \
            -aes-256-gcm \
            -e \
            -pbkdf2 -iter 100000 \
            -pass "file:$key_file" \
            -base64 -A
    }
    
    # Decrypt data
    decrypt_data() {
        local encrypted="$1"
        local key_file="''${2:-$VAULT_KEY}"
        
        echo -n "$encrypted" | ${pkgs.openssl}/bin/openssl enc \
            -aes-256-gcm \
            -d \
            -pbkdf2 -iter 100000 \
            -pass "file:$key_file" \
            -base64 -A
    }
    
    # Store credential
    store_credential() {
        local id="$1"
        local username="$2"
        local password="$3"
        local metadata="''${4:-}"
        local expires="''${5:-}"
        
        # Encrypt password
        local encrypted=$(encrypt_data "$password")
        
        # Store in database
        ${pkgs.sqlite}/bin/sqlite3 "$VAULT_DB" <<EOF
    INSERT OR REPLACE INTO credentials (id, username, encrypted_data, metadata, expires_at)
    VALUES ('$id', '$username', '$encrypted', '$metadata', 
            $([ -n "$expires" ] && echo "'$expires'" || echo "NULL"));
    
    INSERT INTO audit_log (credential_id, action, user)
    VALUES ('$id', 'store', '$(whoami)');
    EOF
        
        echo "✓ Credential stored: $id"
    }
    
    # Retrieve credential
    retrieve_credential() {
        local id="$1"
        
        # Get encrypted data
        local result=$(${pkgs.sqlite}/bin/sqlite3 -separator $'\t' "$VAULT_DB" <<EOF
    SELECT encrypted_data, username, metadata, expires_at
    FROM credentials
    WHERE id = '$id' AND (expires_at IS NULL OR expires_at > datetime('now'));
    EOF
        )
        
        if [[ -z "$result" ]]; then
            echo "ERROR: Credential not found or expired: $id" >&2
            return 1
        fi
        
        # Parse results
        IFS=$'\t' read -r encrypted username metadata expires <<< "$result"
        
        # Decrypt password
        local password=$(decrypt_data "$encrypted")
        
        # Update access time and log
        ${pkgs.sqlite}/bin/sqlite3 "$VAULT_DB" <<EOF
    UPDATE credentials SET accessed_at = CURRENT_TIMESTAMP WHERE id = '$id';
    INSERT INTO audit_log (credential_id, action, user) VALUES ('$id', 'retrieve', '$(whoami)');
    EOF
        
        # Output as JSON
        cat <<EOF
    {
      "id": "$id",
      "username": "$username",
      "password": "$password",
      "metadata": "$metadata",
      "expires": "$expires"
    }
    EOF
    }
    
    # List credentials
    list_credentials() {
        echo "Stored credentials:"
        ${pkgs.sqlite}/bin/sqlite3 -column -header "$VAULT_DB" <<EOF
    SELECT id, username, 
           CASE WHEN expires_at IS NULL THEN 'never' 
                ELSE datetime(expires_at) END as expires,
           datetime(created_at) as created,
           datetime(accessed_at) as last_accessed
    FROM credentials
    WHERE expires_at IS NULL OR expires_at > datetime('now')
    ORDER BY created_at DESC;
    EOF
    }
    
    # Rotate credentials
    rotate_credential() {
        local id="$1"
        local new_password="$2"
        
        # Get existing data
        local result=$(${pkgs.sqlite}/bin/sqlite3 -separator $'\t' "$VAULT_DB" <<EOF
    SELECT username, metadata FROM credentials WHERE id = '$id';
    EOF
        )
        
        if [[ -z "$result" ]]; then
            echo "ERROR: Credential not found: $id" >&2
            return 1
        fi
        
        IFS=$'\t' read -r username metadata <<< "$result"
        
        # Store new version
        store_credential "$id" "$username" "$new_password" "$metadata"
        
        # Log rotation
        ${pkgs.sqlite}/bin/sqlite3 "$VAULT_DB" <<EOF
    INSERT INTO audit_log (credential_id, action, user, details)
    VALUES ('$id', 'rotate', '$(whoami)', 'Password rotated');
    EOF
        
        echo "✓ Credential rotated: $id"
    }
    
    # Cleanup expired
    cleanup_expired() {
        echo "Cleaning up expired credentials..."
        
        # Get expired count
        local count=$(${pkgs.sqlite}/bin/sqlite3 "$VAULT_DB" <<EOF
    SELECT COUNT(*) FROM credentials WHERE expires_at <= datetime('now');
    EOF
        )
        
        if [[ $count -gt 0 ]]; then
            # Log and delete
            ${pkgs.sqlite}/bin/sqlite3 "$VAULT_DB" <<EOF
    INSERT INTO audit_log (credential_id, action, user, details)
    SELECT id, 'expire', 'system', 'Automatic expiration'
    FROM credentials WHERE expires_at <= datetime('now');
    
    DELETE FROM credentials WHERE expires_at <= datetime('now');
    EOF
            echo "✓ Removed $count expired credential(s)"
        else
            echo "No expired credentials found"
        fi
    }
    
    # Main command handling
    case "''${1:-help}" in
        init)
            init_vault
            ;;
        store)
            if [[ $# -lt 4 ]]; then
                echo "Usage: $0 store <id> <username> <password> [metadata] [expires]" >&2
                exit 1
            fi
            store_credential "$2" "$3" "$4" "''${5:-}" "''${6:-}"
            ;;
        get|retrieve)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 get <id>" >&2
                exit 1
            fi
            retrieve_credential "$2"
            ;;
        list)
            list_credentials
            ;;
        rotate)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 rotate <id> <new-password>" >&2
                exit 1
            fi
            rotate_credential "$2" "$3"
            ;;
        cleanup)
            cleanup_expired
            ;;
        audit)
            echo "Recent audit log entries:"
            ${pkgs.sqlite}/bin/sqlite3 -column -header "$VAULT_DB" <<EOF
    SELECT datetime(timestamp) as time, credential_id, action, user, details
    FROM audit_log
    ORDER BY timestamp DESC
    LIMIT 50;
    EOF
            ;;
        *)
            echo "Usage: $0 {init|store|get|list|rotate|cleanup|audit}" >&2
            exit 1
            ;;
    esac
  '';
  
  # Systemd credential helper
  systemdCredentialHelper = pkgs.writeScriptBin "systemd-credential-helper" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Store credential using systemd-creds
    store_systemd_credential() {
        local name="$1"
        local value="$2"
        local output="/etc/credstore/$name"
        
        mkdir -p /etc/credstore
        chmod 700 /etc/credstore
        
        # Encrypt with TPM2 if available
        if [[ -c /dev/tpm0 ]]; then
            echo -n "$value" | systemd-creds encrypt \
                --with-key=tpm2 \
                --tpm2-pcrs=0,7 \
                --name="$name" \
                - "$output"
        else
            # Fallback to host key
            echo -n "$value" | systemd-creds encrypt \
                --with-key=host \
                --name="$name" \
                - "$output"
        fi
        
        chmod 600 "$output"
        echo "✓ Credential stored: $name"
    }
    
    # Retrieve systemd credential
    get_systemd_credential() {
        local name="$1"
        local input="/etc/credstore/$name"
        
        if [[ ! -f "$input" ]]; then
            echo "ERROR: Credential not found: $name" >&2
            return 1
        fi
        
        systemd-creds decrypt --name="$name" "$input"
    }
    
    case "''${1:-help}" in
        store)
            store_systemd_credential "$2" "$3"
            ;;
        get)
            get_systemd_credential "$2"
            ;;
        *)
            echo "Usage: $0 {store|get} <name> [value]" >&2
            exit 1
            ;;
    esac
  '';
  
in
{
  options.hypervisor.security.encryptedStorage = {
    enable = lib.mkEnableOption "Encrypted credential storage";
    
    backend = lib.mkOption {
      type = lib.types.enum [ "vault" "systemd-creds" "both" ];
      default = "both";
      description = "Credential storage backend";
    };
    
    autoRotation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic credential rotation";
      };
      
      interval = lib.mkOption {
        type = lib.types.str;
        default = "monthly";
        description = "Rotation interval";
      };
    };
    
    expiration = {
      defaultTTL = lib.mkOption {
        type = lib.types.int;
        default = 2592000;  # 30 days
        description = "Default credential TTL in seconds";
      };
      
      warnBeforeExpiry = lib.mkOption {
        type = lib.types.int;
        default = 259200;  # 3 days
        description = "Warning time before expiry in seconds";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install credential management tools
    environment.systemPackages = [
      credentialVault
    ] ++ lib.optional (cfg.backend != "vault") [
      systemdCredentialHelper
      pkgs.systemd
    ];
    
    # Create vault directory
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/credential-vault 0700 root root -"
      "d /etc/credstore 0700 root root -"
      "d /run/keys 0700 root root -"
    ];
    
    # Vault initialization service
    systemd.services.credential-vault-init = {
      description = "Initialize credential vault";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${credentialVault}/bin/credential-vault init";
      };
      
      unitConfig = {
        ConditionPathExists = "!/var/lib/hypervisor/credential-vault/credentials.db";
      };
    };
    
    # Automatic cleanup of expired credentials
    systemd.services.credential-cleanup = {
      description = "Clean up expired credentials";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${credentialVault}/bin/credential-vault cleanup";
      };
    };
    
    systemd.timers.credential-cleanup = {
      description = "Daily credential cleanup";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
    
    # Credential rotation timer
    systemd.timers.credential-rotation = lib.mkIf cfg.autoRotation.enable {
      description = "Automatic credential rotation";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = cfg.autoRotation.interval;
        Persistent = true;
      };
    };
    
    # Security hardening for credential storage
    fileSystems."/var/lib/hypervisor/credential-vault" = lib.mkIf (cfg.backend != "systemd-creds") {
      options = [ "nodev" "nosuid" "noexec" ];
    };
  };
}