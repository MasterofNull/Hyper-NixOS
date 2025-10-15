# Hardware Authentication Module
# Support for FIDO2/U2F, TPM2, and Smart Cards

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.hardwareAuth;
  
  # FIDO2 enrollment tool
  fido2Enroller = pkgs.writeScriptBin "enroll-fido2" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly FIDO2_DIR="/etc/hypervisor/fido2"
    readonly USER="''${1:-$USER}"
    
    echo "FIDO2/U2F Security Key Enrollment"
    echo "================================"
    echo
    echo "Enrolling key for user: $USER"
    echo
    
    # Check for FIDO2 devices
    echo "Checking for security keys..."
    DEVICES=$(${pkgs.libfido2}/bin/fido2-token -L 2>/dev/null || true)
    
    if [[ -z "$DEVICES" ]]; then
        echo "ERROR: No FIDO2/U2F devices found!" >&2
        echo "Please insert your security key and try again." >&2
        exit 1
    fi
    
    echo "Found devices:"
    echo "$DEVICES"
    echo
    
    # Create directory
    mkdir -p "$FIDO2_DIR"
    chmod 700 "$FIDO2_DIR"
    
    # Generate challenge
    echo "Generating credential..."
    CRED_FILE="$FIDO2_DIR/$USER.cred"
    
    # Create resident credential
    echo "Please touch your security key when it blinks..."
    
    if ${pkgs.libfido2}/bin/fido2-cred -M -r \
        -k "$CRED_FILE" \
        2>/dev/null; then
        echo "✓ Credential created successfully"
        chmod 600 "$CRED_FILE"
        
        # Extract public key for PAM
        ${pkgs.libfido2}/bin/fido2-cred -V -o "$CRED_FILE" > "$FIDO2_DIR/$USER.pub"
        chmod 644 "$FIDO2_DIR/$USER.pub"
        
        echo
        echo "Enrollment complete!"
        echo "Credential stored in: $CRED_FILE"
        echo
        echo "Testing authentication..."
        echo "Please touch your security key again..."
        
        # Test authentication
        CHALLENGE=$(echo -n "test-$(date +%s)" | base64 -w0)
        if echo "$CHALLENGE" | ${pkgs.libfido2}/bin/fido2-assert \
            -G -h - \
            -s "ssh:hypervisor" \
            2>/dev/null; then
            echo "✓ Authentication test successful"
        else
            echo "✗ Authentication test failed" >&2
            exit 1
        fi
    else
        echo "✗ Failed to create credential" >&2
        exit 1
    fi
    
    # Configure PAM if root
    if [[ $EUID -eq 0 ]]; then
        echo
        echo "Configuring PAM for FIDO2 authentication..."
        
        # Create PAM configuration
        cat > /etc/pam.d/hypervisor-fido2 <<'EOF'
    # FIDO2 authentication for Hypervisor
    auth required pam_u2f.so authfile=$FIDO2_DIR/authorized_keys cue
    EOF
        
        # Add user to authorized_keys format
        echo "$USER:$(cat "$FIDO2_DIR/$USER.pub")" >> "$FIDO2_DIR/authorized_keys"
        chmod 644 "$FIDO2_DIR/authorized_keys"
        
        echo "✓ PAM configuration updated"
    fi
    
    echo
    echo "Setup complete! FIDO2 authentication is now enabled for $USER"
  '';
  
  # TPM2 enrollment tool
  tpm2Enroller = pkgs.writeScriptBin "enroll-tpm2" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "TPM2 Enrollment"
    echo "==============="
    echo
    
    # Check for TPM2
    if [[ ! -c /dev/tpm0 ]] && [[ ! -c /dev/tpmrm0 ]]; then
        echo "ERROR: No TPM2 device found!" >&2
        exit 1
    fi
    
    # Check TPM2 tools
    if ! command -v tpm2_createprimary >/dev/null; then
        echo "ERROR: tpm2-tools not installed!" >&2
        exit 1
    fi
    
    readonly TPM2_DIR="/etc/hypervisor/tpm2"
    readonly USER="''${1:-$USER}"
    
    mkdir -p "$TPM2_DIR"
    chmod 700 "$TPM2_DIR"
    
    echo "Creating TPM2 key hierarchy..."
    
    # Create primary key
    ${pkgs.tpm2-tools}/bin/tpm2_createprimary \
        -C e \
        -g sha256 \
        -G rsa \
        -c "$TPM2_DIR/primary.ctx" \
        -a "restricted|decrypt|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"
    
    # Create user key
    ${pkgs.tpm2-tools}/bin/tpm2_create \
        -C "$TPM2_DIR/primary.ctx" \
        -g sha256 \
        -G rsa \
        -u "$TPM2_DIR/$USER.pub" \
        -r "$TPM2_DIR/$USER.priv" \
        -a "sign|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"
    
    # Load key
    ${pkgs.tpm2-tools}/bin/tpm2_load \
        -C "$TPM2_DIR/primary.ctx" \
        -u "$TPM2_DIR/$USER.pub" \
        -r "$TPM2_DIR/$USER.priv" \
        -c "$TPM2_DIR/$USER.ctx"
    
    # Make persistent
    HANDLE="0x8100$(printf '%04x' $RANDOM)"
    ${pkgs.tpm2-tools}/bin/tpm2_evictcontrol \
        -C o \
        -c "$TPM2_DIR/$USER.ctx" \
        -p "$HANDLE"
    
    echo "$HANDLE" > "$TPM2_DIR/$USER.handle"
    chmod 600 "$TPM2_DIR/$USER.handle"
    
    echo "✓ TPM2 key created and made persistent"
    echo "  Handle: $HANDLE"
    echo
    
    # Test signing
    echo "Testing TPM2 signature..."
    echo "test" | ${pkgs.tpm2-tools}/bin/tpm2_sign \
        -c "$HANDLE" \
        -g sha256 \
        -o "$TPM2_DIR/test.sig"
    
    if [[ -f "$TPM2_DIR/test.sig" ]]; then
        echo "✓ TPM2 signature test successful"
        rm -f "$TPM2_DIR/test.sig"
    else
        echo "✗ TPM2 signature test failed" >&2
        exit 1
    fi
    
    echo
    echo "TPM2 enrollment complete for user: $USER"
  '';
  
  # Multi-factor setup wizard
  mfaSetupWizard = pkgs.writeScriptBin "setup-mfa" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "          Multi-Factor Authentication Setup Wizard              "
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "This wizard will help you set up hardware-based MFA."
    echo
    
    # Detect available methods
    METHODS=()
    
    # Check FIDO2
    if ${pkgs.libfido2}/bin/fido2-token -L 2>/dev/null | grep -q "^"; then
        METHODS+=("fido2")
        echo "✓ FIDO2/U2F security key detected"
    fi
    
    # Check TPM2
    if [[ -c /dev/tpm0 ]] || [[ -c /dev/tpmrm0 ]]; then
        METHODS+=("tpm2")
        echo "✓ TPM2 chip detected"
    fi
    
    # Check smart cards
    if command -v pkcs11-tool >/dev/null && pkcs11-tool -L 2>/dev/null | grep -q "Slot"; then
        METHODS+=("smartcard")
        echo "✓ Smart card reader detected"
    fi
    
    if [[ ''${#METHODS[@]} -eq 0 ]]; then
        echo
        echo "✗ No hardware authentication devices detected!"
        echo
        echo "Supported devices:"
        echo "  - FIDO2/U2F security keys (YubiKey, Solo, etc.)"
        echo "  - TPM2 chips (built into many laptops)"
        echo "  - Smart cards with PKCS#11 support"
        exit 1
    fi
    
    echo
    echo "Available authentication methods:"
    for i in "''${!METHODS[@]}"; do
        echo "  $((i+1))) ''${METHODS[$i]}"
    done
    
    echo
    read -p "Select method [1-''${#METHODS[@]}]: " choice
    
    if [[ $choice -lt 1 ]] || [[ $choice -gt ''${#METHODS[@]} ]]; then
        echo "Invalid choice!" >&2
        exit 1
    fi
    
    METHOD="''${METHODS[$((choice-1))]}"
    
    echo
    echo "Setting up $METHOD authentication..."
    echo
    
    case "$METHOD" in
        fido2)
            ${fido2Enroller}/bin/enroll-fido2 "$USER"
            ;;
        tpm2)
            ${tpm2Enroller}/bin/enroll-tpm2 "$USER"
            ;;
        smartcard)
            echo "Smart card setup not yet implemented"
            exit 1
            ;;
    esac
    
    # Configure sudo to require MFA
    if [[ $EUID -eq 0 ]]; then
        echo
        echo "Configuring sudo for MFA..."
        
        cat > /etc/sudoers.d/99-hypervisor-mfa <<EOF
    # Require MFA for sudo
    Defaults timestamp_timeout=0
    Defaults env_keep += "SSH_AUTH_SOCK"
    
    # MFA required for admin users
    %wheel ALL=(ALL:ALL) ALL
    EOF
        
        chmod 440 /etc/sudoers.d/99-hypervisor-mfa
        
        echo "✓ Sudo configured for MFA"
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "              MFA Setup Complete!                               "
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "Next steps:"
    echo "1. Test your authentication method"
    echo "2. Enroll a backup method (recommended)"
    echo "3. Store recovery codes securely"
  '';
  
in
{
  options.hypervisor.security.hardwareAuth = {
    enable = lib.mkEnableOption "Hardware authentication support";
    
    fido2 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable FIDO2/U2F authentication";
      };
      
      required = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require FIDO2 for authentication";
      };
    };
    
    tpm2 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable TPM2 authentication";
      };
      
      pcrBanks = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ 0 1 2 3 7 ];
        description = "PCR banks to use for sealing";
      };
    };
    
    smartcard = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable smart card authentication";
      };
      
      pkcs11Module = lib.mkOption {
        type = lib.types.str;
        default = "${pkgs.opensc}/lib/opensc-pkcs11.so";
        description = "PKCS#11 module path";
      };
    };
    
    backupCodes = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Generate backup codes for recovery";
      };
      
      count = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Number of backup codes to generate";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install hardware authentication packages
    environment.systemPackages = [
      mfaSetupWizard
    ] ++ lib.optionals cfg.fido2.enable [
      fido2Enroller
      pkgs.libfido2
      pkgs.pam_u2f
    ] ++ lib.optionals cfg.tpm2.enable [
      tpm2Enroller
      pkgs.tpm2-tools
      pkgs.tpm2-tss
    ] ++ lib.optionals cfg.smartcard.enable [
      pkgs.opensc
      pkgs.pcsc-lite
      pkgs.ccid
    ];
    
    # Enable smart card daemon if needed
    services.pcscd.enable = lib.mkIf cfg.smartcard.enable true;
    
    # PAM configuration for FIDO2
    security.pam.services = lib.mkIf cfg.fido2.enable {
      sudo = {
        u2fAuth = cfg.fido2.required;
      };
      
      login = {
        u2fAuth = cfg.fido2.required;
      };
    };
    
    # TPM2 resource manager
    systemd.services.tpm2-abrmd = lib.mkIf cfg.tpm2.enable {
      description = "TPM2 Access Broker and Resource Manager";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.tpm2-abrmd}/bin/tpm2-abrmd";
        Restart = "always";
      };
    };
    
    # Create MFA directories
    systemd.tmpfiles.rules = [
      "d /etc/hypervisor/fido2 0700 root root -"
      "d /etc/hypervisor/tpm2 0700 root root -"
      "d /etc/hypervisor/backup-codes 0700 root root -"
    ];
  };
}