# Split Secret Implementation Module
# Implements Shamir's Secret Sharing for credential distribution

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.splitSecret;
  
  # Secret splitting tool
  secretSplitter = pkgs.writeScriptBin "split-secret" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly SHARES_DIR="/var/lib/hypervisor/secret-shares"
    readonly RECOVERY_DIR="/root/recovery"
    
    # Split secret into shares
    split_secret() {
        local secret_type="''${1:-password}"
        local threshold="''${2:-${toString cfg.threshold}}"
        local shares="''${3:-${toString cfg.shares}}"
        
        echo "═══════════════════════════════════════════════════════════════"
        echo "                    Secret Splitting Utility                     "
        echo "═══════════════════════════════════════════════════════════════"
        echo
        echo "This will split the $secret_type into $shares shares."
        echo "Any $threshold shares can reconstruct the original secret."
        echo
        
        # Create directories
        mkdir -p "$SHARES_DIR" "$RECOVERY_DIR"
        chmod 700 "$SHARES_DIR" "$RECOVERY_DIR"
        
        # Read secret
        local secret=""
        case "$secret_type" in
            password)
                # Read password hash from stdin or prompt
                if [[ -t 0 ]]; then
                    read -s -p "Enter password hash: " secret
                    echo
                else
                    read -r secret
                fi
                ;;
            file)
                # Read file path
                read -p "Enter file path: " filepath
                if [[ ! -f "$filepath" ]]; then
                    echo "ERROR: File not found: $filepath" >&2
                    exit 1
                fi
                secret=$(base64 -w0 < "$filepath")
                ;;
            *)
                echo "ERROR: Unknown secret type: $secret_type" >&2
                exit 1
                ;;
        esac
        
        # Generate shares using ssss
        echo
        echo "Generating shares..."
        local share_output=$(echo -n "$secret" | ${pkgs.ssss}/bin/ssss-split -t "$threshold" -n "$shares" -q)
        
        # Store shares in different locations
        local share_num=1
        while IFS= read -r share; do
            case $share_num in
                1)
                    # Boot partition share
                    if [[ -d /boot ]] && mountpoint -q /boot; then
                        echo "$share" > /boot/.hypervisor-share-$share_num
                        chmod 600 /boot/.hypervisor-share-$share_num
                        echo "✓ Share $share_num stored in boot partition"
                    else
                        echo "$share" > "$SHARES_DIR/share-$share_num"
                        chmod 600 "$SHARES_DIR/share-$share_num"
                        echo "✓ Share $share_num stored locally"
                    fi
                    ;;
                2)
                    # System partition share
                    echo "$share" > "$SHARES_DIR/share-$share_num"
                    chmod 600 "$SHARES_DIR/share-$share_num"
                    echo "✓ Share $share_num stored in system partition"
                    ;;
                3)
                    # QR code for physical storage
                    echo "$share" | ${pkgs.qrencode}/bin/qrencode -o "$RECOVERY_DIR/share-$share_num.png" -s 10
                    chmod 600 "$RECOVERY_DIR/share-$share_num.png"
                    echo "✓ Share $share_num saved as QR code: $RECOVERY_DIR/share-$share_num.png"
                    echo "  Print this QR code and store it securely offline!"
                    ;;
                4)
                    # USB key share (if mounted)
                    local usb_mount=$(findmnt -n -o TARGET -S LABEL=HYPERVISOR-KEY 2>/dev/null || true)
                    if [[ -n "$usb_mount" ]]; then
                        echo "$share" > "$usb_mount/.hypervisor-share-$share_num"
                        chmod 600 "$usb_mount/.hypervisor-share-$share_num"
                        echo "✓ Share $share_num stored on USB key"
                    else
                        echo "$share" > "$RECOVERY_DIR/share-$share_num.txt"
                        chmod 600 "$RECOVERY_DIR/share-$share_num.txt"
                        echo "✓ Share $share_num saved to: $RECOVERY_DIR/share-$share_num.txt"
                        echo "  Copy this to a USB key labeled 'HYPERVISOR-KEY'"
                    fi
                    ;;
                5)
                    # Network share (encrypted)
                    if [[ "${toString cfg.allowNetworkShare}" == "true" ]]; then
                        local encrypted_share=$(echo -n "$share" | \
                            ${pkgs.openssl}/bin/openssl enc -aes-256-cbc -pbkdf2 -base64 -A \
                            -pass pass:"$(hostname)-$(date +%Y%m%d)")
                        echo "$encrypted_share" > "$RECOVERY_DIR/share-$share_num.enc"
                        chmod 600 "$RECOVERY_DIR/share-$share_num.enc"
                        echo "✓ Share $share_num encrypted and saved for network storage"
                    else
                        echo "$share" > "$RECOVERY_DIR/share-$share_num.txt"
                        chmod 600 "$RECOVERY_DIR/share-$share_num.txt"
                        echo "✓ Share $share_num saved to: $RECOVERY_DIR/share-$share_num.txt"
                    fi
                    ;;
                *)
                    # Additional shares
                    echo "$share" > "$RECOVERY_DIR/share-$share_num.txt"
                    chmod 600 "$RECOVERY_DIR/share-$share_num.txt"
                    echo "✓ Share $share_num saved to: $RECOVERY_DIR/share-$share_num.txt"
                    ;;
            esac
            
            ((share_num++))
        done <<< "$share_output"
        
        # Clear secret from memory
        unset secret
        
        echo
        echo "═══════════════════════════════════════════════════════════════"
        echo "Secret successfully split into $shares shares!"
        echo "Required shares for reconstruction: $threshold"
        echo
        echo "Share locations:"
        echo "  1. Boot partition (or $SHARES_DIR)"
        echo "  2. System partition ($SHARES_DIR)"
        echo "  3. QR code for printing ($RECOVERY_DIR)"
        echo "  4. USB key (or $RECOVERY_DIR)"
        echo "  5. Network storage ($RECOVERY_DIR)"
        if [[ $shares -gt 5 ]]; then
            echo "  6+. Additional recovery files ($RECOVERY_DIR)"
        fi
        echo
        echo "IMPORTANT: Store these shares in separate, secure locations!"
        echo "═══════════════════════════════════════════════════════════════"
    }
    
    # Reconstruct secret from shares
    reconstruct_secret() {
        local threshold="''${1:-${toString cfg.threshold}}"
        
        echo "═══════════════════════════════════════════════════════════════"
        echo "                 Secret Reconstruction Utility                   "
        echo "═══════════════════════════════════════════════════════════════"
        echo
        echo "You need at least $threshold shares to reconstruct the secret."
        echo
        
        # Collect shares
        local shares_collected=()
        local share_count=0
        
        # Check automatic sources first
        echo "Searching for shares..."
        
        # Check boot partition
        if [[ -f /boot/.hypervisor-share-1 ]]; then
            shares_collected+=("$(cat /boot/.hypervisor-share-1)")
            echo "✓ Found share in boot partition"
            ((share_count++))
        fi
        
        # Check system partition
        for share_file in "$SHARES_DIR"/share-*; do
            if [[ -f "$share_file" ]]; then
                shares_collected+=("$(cat "$share_file")")
                echo "✓ Found share in system partition"
                ((share_count++))
            fi
        done
        
        # Check USB key
        local usb_mount=$(findmnt -n -o TARGET -S LABEL=HYPERVISOR-KEY 2>/dev/null || true)
        if [[ -n "$usb_mount" ]]; then
            for share_file in "$usb_mount"/.hypervisor-share-*; do
                if [[ -f "$share_file" ]]; then
                    shares_collected+=("$(cat "$share_file")")
                    echo "✓ Found share on USB key"
                    ((share_count++))
                fi
            done
        fi
        
        echo
        echo "Automatic shares found: $share_count"
        
        # Collect additional shares manually if needed
        while [[ $share_count -lt $threshold ]]; do
            echo
            echo "Need $((threshold - share_count)) more share(s)."
            echo "Enter share $((share_count + 1)) (or 'quit' to cancel):"
            read -r share_input
            
            if [[ "$share_input" == "quit" ]]; then
                echo "Reconstruction cancelled."
                exit 0
            fi
            
            # Validate share format
            if [[ "$share_input" =~ ^[0-9]+-[0-9a-f]+$ ]]; then
                shares_collected+=("$share_input")
                ((share_count++))
            else
                echo "ERROR: Invalid share format" >&2
            fi
        done
        
        # Reconstruct secret
        echo
        echo "Reconstructing secret..."
        
        # Create input for ssss-combine
        local shares_input=""
        for share in "''${shares_collected[@]:0:$threshold}"; do
            shares_input+="$share"$'\n'
        done
        
        # Reconstruct
        local secret=$(echo -n "$shares_input" | ${pkgs.ssss}/bin/ssss-combine -t "$threshold" -q)
        
        if [[ -z "$secret" ]]; then
            echo "ERROR: Failed to reconstruct secret" >&2
            echo "The shares may be invalid or corrupted." >&2
            exit 1
        fi
        
        echo "✓ Secret successfully reconstructed!"
        echo
        echo "The reconstructed secret is:"
        echo "════════════════════════════════════════════════"
        echo "$secret"
        echo "════════════════════════════════════════════════"
        echo
        echo "IMPORTANT: This secret is now in your terminal."
        echo "Clear your screen after use: clear && history -c"
    }
    
    # Verify shares without reconstruction
    verify_shares() {
        echo "Verifying available shares..."
        
        local share_locations=()
        
        # Check all locations
        [[ -f /boot/.hypervisor-share-1 ]] && share_locations+=("Boot partition")
        [[ -f "$SHARES_DIR/share-2" ]] && share_locations+=("System partition")
        [[ -f "$RECOVERY_DIR/share-3.png" ]] && share_locations+=("QR code")
        
        local usb_mount=$(findmnt -n -o TARGET -S LABEL=HYPERVISOR-KEY 2>/dev/null || true)
        [[ -n "$usb_mount" ]] && [[ -f "$usb_mount/.hypervisor-share-4" ]] && share_locations+=("USB key")
        
        echo
        echo "Found shares in:"
        printf ' - %s\n' "''${share_locations[@]}"
        echo
        echo "Total shares available: ''${#share_locations[@]}"
        echo "Shares required: ${toString cfg.threshold}"
        
        if [[ ''${#share_locations[@]} -ge ${toString cfg.threshold} ]]; then
            echo "✓ Sufficient shares available for reconstruction"
        else
            echo "✗ Insufficient shares for reconstruction"
            echo "  Need $((${toString cfg.threshold} - ''${#share_locations[@]})) more share(s)"
        fi
    }
    
    # Main command handling
    case "''${1:-help}" in
        split)
            split_secret "''${2:-password}" "''${3:-}" "''${4:-}"
            ;;
        reconstruct|combine)
            reconstruct_secret "''${2:-}"
            ;;
        verify)
            verify_shares
            ;;
        clean)
            echo "Cleaning up shares..."
            read -p "Are you sure? This will delete ALL shares! (yes/no): " confirm
            if [[ "$confirm" == "yes" ]]; then
                rm -f /boot/.hypervisor-share-* 2>/dev/null || true
                rm -f "$SHARES_DIR"/share-* 2>/dev/null || true
                rm -f "$RECOVERY_DIR"/share-* 2>/dev/null || true
                echo "✓ All shares deleted"
            else
                echo "Cancelled"
            fi
            ;;
        *)
            echo "Usage: $0 {split|reconstruct|verify|clean} [args...]"
            echo
            echo "Commands:"
            echo "  split [type] [threshold] [shares]"
            echo "    Split a secret into shares"
            echo "    type: password (default) or file"
            echo
            echo "  reconstruct [threshold]"
            echo "    Reconstruct secret from shares"
            echo
            echo "  verify"
            echo "    Check available shares"
            echo
            echo "  clean"
            echo "    Delete all shares (dangerous!)"
            exit 1
            ;;
    esac
  '';
  
in
{
  options.hypervisor.security.splitSecret = {
    enable = lib.mkEnableOption "Split secret implementation";
    
    threshold = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Number of shares required to reconstruct secret";
    };
    
    shares = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Total number of shares to generate";
    };
    
    allowNetworkShare = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow storing encrypted share for network storage";
    };
    
    autoSplit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically split admin password on creation";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Validate configuration
    assertions = [
      {
        assertion = cfg.threshold <= cfg.shares;
        message = "Threshold must not exceed total shares";
      }
      {
        assertion = cfg.threshold >= 2;
        message = "Threshold must be at least 2 for security";
      }
    ];
    
    # Install secret sharing tools
    environment.systemPackages = [
      secretSplitter
      pkgs.ssss  # Shamir's Secret Sharing Scheme
      pkgs.qrencode  # For QR code generation
    ];
    
    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/secret-shares 0700 root root -"
      "d /root/recovery 0700 root root -"
    ];
    
    # Integration with first boot
    systemd.services.split-admin-secret = lib.mkIf cfg.autoSplit {
      description = "Split admin credentials into shares";
      after = [ "hypervisor-first-boot.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StandardInput = "file:/run/admin-password-hash";
        ExecStart = "${secretSplitter}/bin/split-secret split password";
        ExecStartPost = "${pkgs.coreutils}/bin/shred -zu /run/admin-password-hash";
      };
      
      unitConfig = {
        ConditionPathExists = "/run/admin-password-hash";
      };
    };
  };
}