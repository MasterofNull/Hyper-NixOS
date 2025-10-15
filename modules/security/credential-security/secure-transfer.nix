# Secure Credential Transfer Module
# Provides TPM2 and software encryption for credential protection

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.credentialTransfer;
  
  # TPM2-based credential sealing
  tpm2Sealer = pkgs.writeScriptBin "tpm2-seal-credentials" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly INPUT_FILE="''${1:-}"
    readonly OUTPUT_FILE="''${2:-''${INPUT_FILE}.sealed}"
    
    if [[ -z "$INPUT_FILE" ]]; then
        echo "Usage: $0 <input-file> [output-file]" >&2
        exit 1
    fi
    
    # Check for TPM2 device
    if [[ ! -c /dev/tpm0 ]] && [[ ! -c /dev/tpmrm0 ]]; then
        echo "No TPM2 device found, falling back to software encryption" >&2
        exec ${softwareSealer}/bin/software-seal-credentials "$@"
    fi
    
    echo "Sealing credentials with TPM2..."
    
    # Create primary key
    ${pkgs.tpm2-tools}/bin/tpm2_createprimary -C o -c primary.ctx \
        -g sha256 -G rsa -a "restricted|decrypt|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"
    
    # Create PCR policy (boot measurements)
    ${pkgs.tpm2-tools}/bin/tpm2_startauthsession -S session.ctx
    ${pkgs.tpm2-tools}/bin/tpm2_policypcr -S session.ctx -l sha256:0,1,2,3,7 -L policy.digest
    ${pkgs.tpm2-tools}/bin/tpm2_flushcontext session.ctx
    
    # Create sealing object
    ${pkgs.tpm2-tools}/bin/tpm2_create -C primary.ctx -u seal.pub -r seal.priv \
        -L policy.digest -i "$INPUT_FILE" -a "fixedtpm|fixedparent"
    
    # Load sealing object
    ${pkgs.tpm2-tools}/bin/tpm2_load -C primary.ctx -u seal.pub -r seal.priv -c seal.ctx
    
    # Make persistent
    ${pkgs.tpm2-tools}/bin/tpm2_evictcontrol -C o -c seal.ctx -p 0x81000001
    
    # Save public portions for unsealing
    ${pkgs.tpm2-tools}/bin/tpm2_readpublic -c 0x81000001 -o "$OUTPUT_FILE.pub"
    
    # Clean up temporary files
    rm -f primary.ctx seal.pub seal.priv seal.ctx policy.digest
    
    # Secure delete original
    ${pkgs.coreutils}/bin/shred -vzu "$INPUT_FILE"
    
    echo "✓ Credentials sealed to TPM2 PCRs 0,1,2,3,7"
    echo "  Output: $OUTPUT_FILE"
    echo "  Public: $OUTPUT_FILE.pub"
  '';
  
  # Software-based encryption fallback
  softwareSealer = pkgs.writeScriptBin "software-seal-credentials" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly INPUT_FILE="''${1:-}"
    readonly OUTPUT_FILE="''${2:-''${INPUT_FILE}.enc}"
    
    if [[ -z "$INPUT_FILE" ]]; then
        echo "Usage: $0 <input-file> [output-file]" >&2
        exit 1
    fi
    
    echo "Sealing credentials with software encryption..."
    
    # Generate ephemeral key from hardware RNG
    readonly KEY_FILE="/run/hypervisor-creds/ephemeral.key"
    mkdir -p "$(dirname "$KEY_FILE")"
    chmod 700 "$(dirname "$KEY_FILE")"
    
    # Mount as tmpfs if not already
    if ! mountpoint -q "$(dirname "$KEY_FILE")"; then
        mount -t tmpfs -o size=1M,mode=700 tmpfs "$(dirname "$KEY_FILE")"
    fi
    
    # Generate 256-bit key
    dd if=/dev/urandom bs=32 count=1 2>/dev/null > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    
    # Encrypt with AES-256-GCM
    ${pkgs.openssl}/bin/openssl enc -aes-256-gcm -pbkdf2 -iter 100000 \
        -in "$INPUT_FILE" -out "$OUTPUT_FILE" \
        -pass "file:$KEY_FILE"
    
    # Store key in kernel keyring (survives until reboot)
    KEY_ID=$(${pkgs.keyutils}/bin/keyctl add user "hypervisor-cred-key" \
        "$(base64 -w0 < "$KEY_FILE")" @s)
    
    echo "✓ Credentials encrypted with ephemeral key"
    echo "  Output: $OUTPUT_FILE"
    echo "  Key ID: $KEY_ID (in kernel keyring)"
    
    # Secure cleanup
    ${pkgs.coreutils}/bin/shred -vzu "$KEY_FILE"
    ${pkgs.coreutils}/bin/shred -vzu "$INPUT_FILE"
  '';
  
  # Credential unsealing utility
  credentialUnsealer = pkgs.writeScriptBin "unseal-credentials" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly SEALED_FILE="''${1:-}"
    readonly OUTPUT_FILE="''${2:-/run/hypervisor-creds/unsealed}"
    
    if [[ -z "$SEALED_FILE" ]]; then
        echo "Usage: $0 <sealed-file> [output-file]" >&2
        exit 1
    fi
    
    # Check if TPM2 sealed
    if [[ -f "$SEALED_FILE.pub" ]]; then
        echo "Unsealing TPM2-protected credentials..."
        
        # Start auth session with PCR policy
        ${pkgs.tpm2-tools}/bin/tpm2_startauthsession -S session.ctx --policy-session
        ${pkgs.tpm2-tools}/bin/tpm2_policypcr -S session.ctx -l sha256:0,1,2,3,7
        
        # Unseal
        ${pkgs.tpm2-tools}/bin/tpm2_unseal -c 0x81000001 -p session:session.ctx \
            -o "$OUTPUT_FILE"
        
        # Cleanup
        ${pkgs.tpm2-tools}/bin/tpm2_flushcontext session.ctx
        
        echo "✓ Credentials unsealed from TPM2"
    else
        echo "Decrypting software-encrypted credentials..."
        
        # Retrieve key from kernel keyring
        KEY_ID=$(${pkgs.keyutils}/bin/keyctl search @s user "hypervisor-cred-key" 2>/dev/null || echo "")
        
        if [[ -z "$KEY_ID" ]]; then
            echo "ERROR: Decryption key not found in keyring" >&2
            echo "The ephemeral key is lost after reboot" >&2
            exit 1
        fi
        
        # Get key from keyring
        KEY=$(${pkgs.keyutils}/bin/keyctl pipe "$KEY_ID" | base64 -d)
        
        # Decrypt
        echo -n "$KEY" | ${pkgs.openssl}/bin/openssl enc -aes-256-gcm -pbkdf2 -iter 100000 \
            -d -in "$SEALED_FILE" -out "$OUTPUT_FILE" \
            -pass stdin
        
        echo "✓ Credentials decrypted"
    fi
    
    # Set secure permissions
    chmod 600 "$OUTPUT_FILE"
    echo "  Output: $OUTPUT_FILE"
  '';
  
in
{
  options.hypervisor.security.credentialTransfer = {
    enable = lib.mkEnableOption "Secure credential transfer mechanism";
    
    method = lib.mkOption {
      type = lib.types.enum [ "auto" "tpm2" "software" ];
      default = "auto";
      description = "Credential sealing method (auto detects TPM2)";
    };
    
    persistentHandle = lib.mkOption {
      type = lib.types.str;
      default = "0x81000001";
      description = "TPM2 persistent handle for credential sealing";
    };
    
    pcrBanks = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ 0 1 2 3 7 ];
      description = "PCR banks to use for TPM2 sealing";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install utilities
    environment.systemPackages = [
      tpm2Sealer
      softwareSealer
      credentialUnsealer
    ] ++ lib.optionals (cfg.method != "software") [
      pkgs.tpm2-tools
      pkgs.tpm2-tss
    ];
    
    # Ensure TPM2 support if requested
    boot.kernelModules = lib.optionals (cfg.method != "software") [
      "tpm_tis"
      "tpm_crb"
    ];
    
    # TPM2 resource manager
    services.tcsd.enable = lib.mkIf (cfg.method == "tpm2") true;
    
    # Secure credential directory
    systemd.tmpfiles.rules = [
      "d /run/hypervisor-creds 0700 root root -"
    ];
    
    # Mount credential directory as tmpfs on boot
    fileSystems."/run/hypervisor-creds" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=700" "size=10M" "nodev" "nosuid" "noexec" ];
    };
  };
}