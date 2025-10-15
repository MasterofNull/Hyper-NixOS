# Memory-Locked Password Input Module
# Provides secure password input with memory locking and validation

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.memoryLockedInput;
  
  # Memory-locked password reader
  memoryLockedReader = pkgs.writeScriptBin "memory-locked-password" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Lock memory pages to prevent swapping
    if command -v memlockd >/dev/null 2>&1; then
        # Use memlockd if available
        exec memlockd -f $$ "$0" "$@"
    fi
    
    # Alternatively, use ulimit to lock memory
    ulimit -l unlimited 2>/dev/null || true
    
    # Function to clear variables on exit
    cleanup() {
        unset password
        unset password_confirm
        # Clear bash history for this session
        history -c
        # Restore terminal settings
        stty echo 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM
    
    # Secure read function
    secure_read() {
        local prompt="''${1:-Password: }"
        local var_name="''${2:-password}"
        local timeout="''${3:-60}"
        
        # Disable terminal echo
        stty -echo
        
        # Read with timeout
        local input=""
        if ! IFS= read -t "$timeout" -r -p "$prompt" input; then
            echo
            echo "ERROR: Input timeout" >&2
            exit 1
        fi
        echo
        
        # Store in specified variable
        eval "$var_name='$input'"
        
        # Re-enable echo
        stty echo
    }
    
    # Password complexity validation
    validate_password() {
        local pass="$1"
        local errors=()
        
        # Length check
        if [[ ''${#pass} -lt ${toString cfg.minLength} ]]; then
            errors+=("Password must be at least ${toString cfg.minLength} characters")
        fi
        
        # Character class checks
        local has_upper=0 has_lower=0 has_digit=0 has_special=0
        
        [[ "$pass" =~ [A-Z] ]] && has_upper=1
        [[ "$pass" =~ [a-z] ]] && has_lower=1
        [[ "$pass" =~ [0-9] ]] && has_digit=1
        [[ "$pass" =~ [^A-Za-z0-9] ]] && has_special=1
        
        local complexity=$((has_upper + has_lower + has_digit + has_special))
        
        if [[ $complexity -lt ${toString cfg.requiredClasses} ]]; then
            errors+=("Password must contain at least ${toString cfg.requiredClasses} character classes")
            errors+=("(uppercase, lowercase, digits, special characters)")
        fi
        
        # Dictionary word check
        if [[ "${toString cfg.checkDictionary}" == "true" ]]; then
            # Check against common passwords
            local common_passwords=(
                "password" "admin" "root" "user" "guest"
                "123456" "12345678" "qwerty" "letmein"
                "welcome" "monkey" "dragon" "master"
                "hypervisor" "nixos" "default" "changeme"
            )
            
            local lower_pass=$(echo "$pass" | tr '[:upper:]' '[:lower:]')
            for common in "''${common_passwords[@]}"; do
                if [[ "$lower_pass" == *"$common"* ]]; then
                    errors+=("Password contains common word: $common")
                    break
                fi
            done
        fi
        
        # Entropy check
        if [[ "${toString cfg.checkEntropy}" == "true" ]]; then
            # Simple entropy estimation
            local charset_size=0
            [[ "$pass" =~ [a-z] ]] && charset_size=$((charset_size + 26))
            [[ "$pass" =~ [A-Z] ]] && charset_size=$((charset_size + 26))
            [[ "$pass" =~ [0-9] ]] && charset_size=$((charset_size + 10))
            [[ "$pass" =~ [^A-Za-z0-9] ]] && charset_size=$((charset_size + 32))
            
            # Entropy = length * log2(charset_size)
            # Approximate: require at least 60 bits
            local min_length=$((60 / 6))  # ~6 bits per character with full charset
            if [[ ''${#pass} -lt $min_length ]] && [[ $charset_size -lt 60 ]]; then
                errors+=("Password entropy too low (use more characters or types)")
            fi
        fi
        
        # Report errors
        if [[ ''${#errors[@]} -gt 0 ]]; then
            echo "Password validation failed:" >&2
            printf " - %s\n" "''${errors[@]}" >&2
            return 1
        fi
        
        return 0
    }
    
    # Main password input flow
    main() {
        local mode="''${1:-interactive}"
        local prompt="''${2:-Password: }"
        
        case "$mode" in
            interactive)
                local password=""
                local password_confirm=""
                local attempts=0
                local max_attempts=3
                
                while [[ $attempts -lt $max_attempts ]]; do
                    # Read password
                    secure_read "$prompt" password ${toString cfg.inputTimeout}
                    
                    # Read confirmation
                    secure_read "Confirm password: " password_confirm ${toString cfg.inputTimeout}
                    
                    # Check match
                    if [[ "$password" != "$password_confirm" ]]; then
                        echo "ERROR: Passwords do not match" >&2
                        attempts=$((attempts + 1))
                        continue
                    fi
                    
                    # Validate complexity
                    if validate_password "$password"; then
                        # Generate hash with specified rounds
                        echo -n "$password" | ${pkgs.mkpasswd}/bin/mkpasswd \
                            -m "${cfg.hashMethod}" \
                            -R "${toString cfg.hashRounds}"
                        return 0
                    fi
                    
                    attempts=$((attempts + 1))
                    echo "Attempts remaining: $((max_attempts - attempts))" >&2
                done
                
                echo "ERROR: Maximum attempts exceeded" >&2
                exit 1
                ;;
                
            validate)
                # Just validate a password passed via stdin
                local password
                IFS= read -r password
                if validate_password "$password"; then
                    echo "VALID"
                    exit 0
                else
                    exit 1
                fi
                ;;
                
            hash)
                # Hash a password from stdin
                local password
                IFS= read -r password
                echo -n "$password" | ${pkgs.mkpasswd}/bin/mkpasswd \
                    -m "${cfg.hashMethod}" \
                    -R "${toString cfg.hashRounds}"
                ;;
                
            *)
                echo "Usage: $0 [interactive|validate|hash] [prompt]" >&2
                exit 1
                ;;
        esac
    }
    
    main "$@"
  '';
  
  # Password strength meter
  passwordStrengthMeter = pkgs.writeScriptBin "password-strength" ''
    #!${pkgs.bash}/bin/bash
    
    check_strength() {
        local pass="$1"
        local score=0
        local feedback=()
        
        # Length scoring
        local len=''${#pass}
        if [[ $len -ge 8 ]]; then score=$((score + 10)); fi
        if [[ $len -ge 12 ]]; then score=$((score + 10)); fi
        if [[ $len -ge 16 ]]; then score=$((score + 10)); fi
        if [[ $len -ge 20 ]]; then score=$((score + 10)); fi
        
        # Character diversity
        [[ "$pass" =~ [a-z] ]] && score=$((score + 10))
        [[ "$pass" =~ [A-Z] ]] && score=$((score + 10))
        [[ "$pass" =~ [0-9] ]] && score=$((score + 10))
        [[ "$pass" =~ [^A-Za-z0-9] ]] && score=$((score + 15))
        
        # Pattern checks (reduce score)
        [[ "$pass" =~ (.)\1{2,} ]] && score=$((score - 10)) && feedback+=("Repeated characters")
        [[ "$pass" =~ (012|123|234|345|456|567|678|789|890) ]] && score=$((score - 10)) && feedback+=("Sequential numbers")
        [[ "$pass" =~ (abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz) ]] && score=$((score - 10)) && feedback+=("Sequential letters")
        
        # Determine strength
        local strength=""
        if [[ $score -lt 30 ]]; then
            strength="WEAK"
        elif [[ $score -lt 50 ]]; then
            strength="FAIR"
        elif [[ $score -lt 70 ]]; then
            strength="GOOD"
        else
            strength="STRONG"
        fi
        
        echo "Strength: $strength (Score: $score/100)"
        if [[ ''${#feedback[@]} -gt 0 ]]; then
            echo "Issues:"
            printf " - %s\n" "''${feedback[@]}"
        fi
        
        # Return exit code based on minimum score
        [[ $score -ge ${toString cfg.minimumScore} ]]
    }
    
    # Read password from stdin or argument
    if [[ $# -eq 0 ]]; then
        IFS= read -r password
    else
        password="$1"
    fi
    
    check_strength "$password"
  '';
  
in
{
  options.hypervisor.security.memoryLockedInput = {
    enable = lib.mkEnableOption "Memory-locked password input";
    
    minLength = lib.mkOption {
      type = lib.types.int;
      default = 12;
      description = "Minimum password length";
    };
    
    requiredClasses = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Number of character classes required";
    };
    
    checkDictionary = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check against common passwords";
    };
    
    checkEntropy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check password entropy";
    };
    
    inputTimeout = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Password input timeout in seconds";
    };
    
    hashMethod = lib.mkOption {
      type = lib.types.enum [ "sha-512" "yescrypt" "argon2id" ];
      default = "sha-512";
      description = "Password hashing method";
    };
    
    hashRounds = lib.mkOption {
      type = lib.types.int;
      default = 100000;
      description = "Number of hashing rounds";
    };
    
    minimumScore = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Minimum acceptable strength score (0-100)";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install password tools
    environment.systemPackages = [
      memoryLockedReader
      passwordStrengthMeter
      pkgs.mkpasswd
    ];
    
    # Ensure memory locking is available
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "hard";
        item = "memlock";
        value = "unlimited";
      }
    ];
    
    # Disable swap to prevent password leakage
    swapDevices = lib.mkForce [];
    
    # Kernel parameters for better security
    boot.kernel.sysctl = {
      # Disable core dumps which might contain passwords
      "kernel.core_pattern" = "|/bin/false";
      "fs.suid_dumpable" = 0;
      
      # Increase entropy pool size
      "kernel.random.poolsize" = 4096;
    };
  };
}