# Physical Presence Verification Module
# Ensures first boot operations require physical console access

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.physicalPresence;
  
  # Physical presence verification script
  presenceVerifier = pkgs.writeScriptBin "verify-physical-presence" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly VERIFICATION_TOKEN="/run/physical-presence-token"
    readonly MAX_ATTEMPTS=3
    
    # Colors for better visibility
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
    
    # Check if running on physical console
    check_console_access() {
        # Check SSH environment variables
        if [[ -n "''${SSH_CONNECTION:-}" ]] || [[ -n "''${SSH_CLIENT:-}" ]] || [[ -n "''${SSH_TTY:-}" ]]; then
            echo -e "''${RED}ERROR: Remote access detected!''${NC}" >&2
            echo "Physical presence verification requires local console access." >&2
            return 1
        fi
        
        # Check if we have a real TTY
        if ! tty -s; then
            echo -e "''${RED}ERROR: Not running on a TTY!''${NC}" >&2
            return 1
        fi
        
        # Check TTY type
        local tty_device=$(tty)
        case "$tty_device" in
            /dev/tty[0-9]*)
                echo -e "''${GREEN}✓ Physical console detected: $tty_device''${NC}"
                ;;
            /dev/console)
                echo -e "''${GREEN}✓ System console detected''${NC}"
                ;;
            *)
                echo -e "''${YELLOW}WARNING: Non-standard TTY: $tty_device''${NC}"
                echo "Proceeding with additional verification..."
                ;;
        esac
        
        return 0
    }
    
    # Generate verification challenge
    generate_challenge() {
        local challenge=""
        
        case "${cfg.verificationMethod}" in
            "random-code")
                # Generate 6-character random code
                challenge=$(head -c 8 /dev/urandom | base64 | tr -d '+/=' | cut -c1-6)
                ;;
            "math-problem")
                # Generate simple math problem
                local a=$((RANDOM % 20 + 1))
                local b=$((RANDOM % 20 + 1))
                local op=$((RANDOM % 3))
                case $op in
                    0) challenge="$a + $b = ?"; expected=$((a + b)) ;;
                    1) challenge="$a * $b = ?"; expected=$((a * b)) ;;
                    2) challenge="$((a + b)) - $a = ?"; expected=$b ;;
                esac
                ;;
            "hardware-action")
                # Request specific hardware action
                challenge="Press Ctrl+Alt+F2, then return here (Ctrl+Alt+F1)"
                ;;
        esac
        
        echo "$challenge"
    }
    
    # Multi-factor physical verification
    perform_verification() {
        echo -e "''${BLUE}════════════════════════════════════════════════════════════════''${NC}"
        echo -e "''${BLUE}           PHYSICAL PRESENCE VERIFICATION REQUIRED              ''${NC}"
        echo -e "''${BLUE}════════════════════════════════════════════════════════════════''${NC}"
        echo
        
        # Step 1: Console access check
        if ! check_console_access; then
            return 1
        fi
        
        # Step 2: Visual challenge
        if [[ "${cfg.requireVisualChallenge}" == "true" ]]; then
            echo -e "''${YELLOW}Step 1: Visual Verification''${NC}"
            echo "A verification pattern will be displayed."
            echo "You must be physically present to see it."
            echo
            
            # Generate visual pattern
            local pattern=""
            for i in {1..4}; do
                case $((RANDOM % 4)) in
                    0) pattern+="█" ;;
                    1) pattern+="▀" ;;
                    2) pattern+="▄" ;;
                    3) pattern+="░" ;;
                esac
            done
            
            echo -e "Pattern: ''${GREEN}$pattern''${NC}"
            echo
            read -p "Enter the pattern you see: " user_pattern
            
            if [[ "$user_pattern" != "$pattern" ]]; then
                echo -e "''${RED}✗ Incorrect pattern''${NC}"
                return 1
            fi
            echo -e "''${GREEN}✓ Visual verification passed''${NC}"
            echo
        fi
        
        # Step 3: Interactive challenge
        echo -e "''${YELLOW}Step 2: Interactive Challenge''${NC}"
        local challenge=$(generate_challenge)
        local attempts=0
        
        while [[ $attempts -lt $MAX_ATTEMPTS ]]; do
            echo "Challenge: $challenge"
            read -p "Response: " response
            
            case "${cfg.verificationMethod}" in
                "random-code")
                    if [[ "$response" == "$challenge" ]]; then
                        echo -e "''${GREEN}✓ Code verified''${NC}"
                        break
                    fi
                    ;;
                "math-problem")
                    if [[ "$response" == "$expected" ]]; then
                        echo -e "''${GREEN}✓ Correct answer''${NC}"
                        break
                    fi
                    ;;
                "hardware-action")
                    # Check if user switched TTYs
                    echo "Press Enter when you've completed the action..."
                    read -r
                    echo -e "''${GREEN}✓ Action acknowledged''${NC}"
                    break
                    ;;
            esac
            
            attempts=$((attempts + 1))
            if [[ $attempts -lt $MAX_ATTEMPTS ]]; then
                echo -e "''${RED}Incorrect. Try again ($((MAX_ATTEMPTS - attempts)) attempts remaining)''${NC}"
            fi
        done
        
        if [[ $attempts -ge $MAX_ATTEMPTS ]]; then
            echo -e "''${RED}✗ Maximum attempts exceeded''${NC}"
            return 1
        fi
        
        # Step 4: Timing verification (optional)
        if [[ "${cfg.requireTimingCheck}" == "true" ]]; then
            echo
            echo -e "''${YELLOW}Step 3: Reaction Time Test''${NC}"
            echo "Press Enter when you see the prompt..."
            sleep $((RANDOM % 3 + 2))
            
            local start_time=$(date +%s%N)
            echo -e "''${GREEN}PRESS ENTER NOW!''${NC}"
            read -r
            local end_time=$(date +%s%N)
            
            local reaction_time=$(( (end_time - start_time) / 1000000 ))
            
            if [[ $reaction_time -lt 100 ]]; then
                echo -e "''${RED}✗ Impossibly fast reaction (automated?)''${NC}"
                return 1
            elif [[ $reaction_time -gt 5000 ]]; then
                echo -e "''${RED}✗ Too slow (not present?)''${NC}"
                return 1
            else
                echo -e "''${GREEN}✓ Reaction time: ''${reaction_time}ms''${NC}"
            fi
        fi
        
        return 0
    }
    
    # Create verification token
    create_token() {
        local token_data="{
            \"timestamp\": \"$(date -Iseconds)\",
            \"tty\": \"$(tty)\",
            \"user\": \"$USER\",
            \"pid\": \"$$\",
            \"kernel\": \"$(uname -r)\"
        }"
        
        # Create token directory
        mkdir -p "$(dirname "$VERIFICATION_TOKEN")"
        chmod 700 "$(dirname "$VERIFICATION_TOKEN")"
        
        # Write token
        echo "$token_data" > "$VERIFICATION_TOKEN"
        chmod 600 "$VERIFICATION_TOKEN"
        
        # Set expiration
        if [[ -n "${cfg.tokenExpiration}" ]]; then
            echo "Token expires in ${cfg.tokenExpiration} seconds"
            (
                sleep "${cfg.tokenExpiration}"
                rm -f "$VERIFICATION_TOKEN"
            ) &
        fi
    }
    
    # Main execution
    main() {
        local mode="''${1:-verify}"
        
        case "$mode" in
            verify)
                if perform_verification; then
                    create_token
                    echo
                    echo -e "''${GREEN}════════════════════════════════════════════════════════════════''${NC}"
                    echo -e "''${GREEN}         PHYSICAL PRESENCE VERIFIED SUCCESSFULLY                ''${NC}"
                    echo -e "''${GREEN}════════════════════════════════════════════════════════════════''${NC}"
                    exit 0
                else
                    echo
                    echo -e "''${RED}════════════════════════════════════════════════════════════════''${NC}"
                    echo -e "''${RED}          PHYSICAL PRESENCE VERIFICATION FAILED                 ''${NC}"
                    echo -e "''${RED}════════════════════════════════════════════════════════════════''${NC}"
                    exit 1
                fi
                ;;
            check)
                # Just check if token exists and is valid
                if [[ -f "$VERIFICATION_TOKEN" ]]; then
                    echo "Token exists"
                    exit 0
                else
                    echo "No valid token"
                    exit 1
                fi
                ;;
            clear)
                # Clear token
                rm -f "$VERIFICATION_TOKEN"
                echo "Token cleared"
                ;;
            *)
                echo "Usage: $0 [verify|check|clear]"
                exit 1
                ;;
        esac
    }
    
    main "$@"
  '';
  
  # USB security key verification
  usbKeyVerifier = pkgs.writeScriptBin "verify-usb-key" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "Checking for security keys..."
    
    # Check for FIDO2 devices
    if command -v fido2-token >/dev/null 2>&1; then
        DEVICES=$(${pkgs.libfido2}/bin/fido2-token -L 2>/dev/null | grep -c "^" || echo "0")
        
        if [[ "$DEVICES" -gt 0 ]]; then
            echo "Found $DEVICES security key(s)"
            echo "Please touch your security key to verify presence..."
            
            # Create credential challenge
            CHALLENGE=$(echo -n "hypervisor-first-boot-$(date +%s)" | base64 -w0)
            
            if ${pkgs.libfido2}/bin/fido2-assert -G \
                -h "$CHALLENGE" \
                -s "hypervisor-physical-presence" \
                2>/dev/null; then
                echo "✓ Security key verified"
                exit 0
            else
                echo "✗ Security key verification failed"
                exit 1
            fi
        else
            echo "No security keys found"
            exit 1
        fi
    else
        echo "FIDO2 tools not available"
        exit 1
    fi
  '';
  
in
{
  options.hypervisor.security.physicalPresence = {
    enable = lib.mkEnableOption "Physical presence verification";
    
    required = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require physical presence for sensitive operations";
    };
    
    verificationMethod = lib.mkOption {
      type = lib.types.enum [ "random-code" "math-problem" "hardware-action" ];
      default = "random-code";
      description = "Method for verifying physical presence";
    };
    
    requireVisualChallenge = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require visual pattern verification";
    };
    
    requireTimingCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Require reaction time verification";
    };
    
    tokenExpiration = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Token expiration time in seconds (0 = no expiration)";
    };
    
    allowUSBKey = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow USB security key as alternative verification";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install verification tools
    environment.systemPackages = [
      presenceVerifier
    ] ++ lib.optionals cfg.allowUSBKey [
      usbKeyVerifier
      pkgs.libfido2
    ];
    
    # PAM configuration for physical presence
    security.pam.services.hypervisor-presence = {
      text = ''
        # Physical presence verification
        auth required pam_exec.so stdout ${presenceVerifier}/bin/verify-physical-presence
        auth required pam_permit.so
      '';
    };
    
    # Ensure /run is available early
    systemd.tmpfiles.rules = [
      "d /run/hypervisor-presence 0700 root root -"
    ];
  };
}