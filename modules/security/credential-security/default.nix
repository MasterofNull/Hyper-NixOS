# Comprehensive Credential Security Module
# Integrates all credential security features for first boot

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.credentialSecurity;
in
{
  imports = [
    ./secure-transfer.nix
    ./memory-locked-input.nix
    ./physical-presence.nix
    ./anti-tampering.nix
    ./time-window.nix
    ./hardware-auth.nix
    ./encrypted-storage.nix
    ./split-secret.nix
  ];
  
  options.hypervisor.security.credentialSecurity = {
    enable = lib.mkEnableOption "Comprehensive credential security";
    
    profile = lib.mkOption {
      type = lib.types.enum [ "basic" "enhanced" "paranoid" ];
      default = "enhanced";
      description = ''
        Security profile:
        - basic: Essential security (password complexity, secure input)
        - enhanced: Recommended security (+ physical presence, time windows, encryption)
        - paranoid: Maximum security (+ hardware auth, split secrets, anti-tampering)
      '';
    };
    
    firstBoot = {
      requirePhysicalPresence = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Require physical console access for first boot";
      };
      
      timeWindowMinutes = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Time window for first boot in minutes";
      };
      
      secureCredentialTransfer = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use encrypted credential transfer instead of plaintext";
      };
    };
    
    passwords = {
      minLength = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Minimum password length";
      };
      
      requireComplexity = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Require complex passwords";
      };
      
      hashRounds = lib.mkOption {
        type = lib.types.int;
        default = 100000;
        description = "Password hashing rounds";
      };
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Basic profile - Essential security
    (lib.mkIf (cfg.profile == "basic") {
      hypervisor.security = {
        # Memory-locked password input
        memoryLockedInput = {
          enable = true;
          minLength = cfg.passwords.minLength;
          requiredClasses = 3;
          checkDictionary = true;
          hashRounds = cfg.passwords.hashRounds;
        };
        
        # Basic credential transfer
        credentialTransfer = {
          enable = cfg.firstBoot.secureCredentialTransfer;
          method = "software";  # No TPM requirement
        };
        
        # Time window for first boot
        timeWindow = {
          enable = true;
          firstBootWindow = cfg.firstBoot.timeWindowMinutes * 60;
          enforceBusinessHours = false;
        };
      };
    })
    
    # Enhanced profile - Recommended security
    (lib.mkIf (cfg.profile == "enhanced") {
      hypervisor.security = {
        # All basic features plus:
        memoryLockedInput = {
          enable = true;
          minLength = cfg.passwords.minLength;
          requiredClasses = 3;
          checkDictionary = true;
          checkEntropy = true;
          hashRounds = cfg.passwords.hashRounds;
        };
        
        # Auto-detect TPM for encryption
        credentialTransfer = {
          enable = true;
          method = "auto";
        };
        
        # Physical presence verification
        physicalPresence = {
          enable = cfg.firstBoot.requirePhysicalPresence;
          required = true;
          verificationMethod = "random-code";
        };
        
        # Time windows with business hours
        timeWindow = {
          enable = true;
          firstBootWindow = cfg.firstBoot.timeWindowMinutes * 60;
          enforceBusinessHours = false;  # Optional
          allowWeekends = true;
        };
        
        # Encrypted storage for credentials
        encryptedStorage = {
          enable = true;
          backend = "systemd-creds";  # Use systemd's credential system
        };
        
        # Basic anti-tampering
        antiTampering = {
          enable = true;
          warningThreshold = 30;
          criticalThreshold = 60;
          enableLockdown = false;  # Manual intervention required
        };
      };
    })
    
    # Paranoid profile - Maximum security
    (lib.mkIf (cfg.profile == "paranoid") {
      hypervisor.security = {
        # All enhanced features plus:
        memoryLockedInput = {
          enable = true;
          minLength = 16;  # Longer passwords
          requiredClasses = 4;  # All character classes
          checkDictionary = true;
          checkEntropy = true;
          hashRounds = 200000;  # More rounds
          inputTimeout = 30;  # Shorter timeout
        };
        
        # Require TPM2
        credentialTransfer = {
          enable = true;
          method = "tpm2";
          pcrBanks = [ 0 1 2 3 4 7 ];  # More PCRs
        };
        
        # Strict physical presence
        physicalPresence = {
          enable = true;
          required = true;
          verificationMethod = "random-code";
          requireVisualChallenge = true;
          requireTimingCheck = true;
          tokenExpiration = 120;  # 2 minutes
        };
        
        # Strict time windows
        timeWindow = {
          enable = true;
          firstBootWindow = 30 * 60;  # 30 minutes only
          enforceBusinessHours = true;
          allowWeekends = false;
        };
        
        # Hardware authentication required
        hardwareAuth = {
          enable = true;
          fido2 = {
            enable = true;
            required = true;  # Mandatory
          };
          tpm2.enable = true;
          backupCodes.enable = true;
        };
        
        # Full encrypted storage
        encryptedStorage = {
          enable = true;
          backend = "both";  # Use all available methods
          autoRotation = {
            enable = true;
            interval = "weekly";
          };
        };
        
        # Aggressive anti-tampering
        antiTampering = {
          enable = true;
          warningThreshold = 20;
          criticalThreshold = 40;
          enableLockdown = true;  # Automatic lockdown
          checkInterval = "1min";
        };
        
        # Split secret for admin password
        splitSecret = {
          enable = true;
          threshold = 3;
          shares = 5;
          autoSplit = true;
        };
      };
    })
    
    # Common configuration for all profiles
    {
      # Enhanced first boot script that uses security features
      systemd.services.hypervisor-secure-first-boot = lib.mkAfter {
        description = "Secure Hyper-NixOS First Boot";
        
        # Dependencies based on enabled features
        after = [ "multi-user.target" ]
          ++ lib.optional config.hypervisor.security.antiTampering.enable "anti-tamper-check.service";
        
        # Only run if not completed
        unitConfig = {
          ConditionPathExists = "!/var/lib/hypervisor/.first-boot-complete";
        };
        
        serviceConfig = {
          Type = "idle";
          StandardInput = "tty";
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          TTYPath = "/dev/tty1";
          
          # Security restrictions
          PrivateDevices = false;  # Need access to TPM, USB
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [
            "/etc/nixos"
            "/var/lib/hypervisor"
            "/run"
          ];
          
          # Run the secure wizard
          ExecStart = let
            secureFirstBootScript = pkgs.writeScript "secure-first-boot" ''
              #!${pkgs.bash}/bin/bash
              set -euo pipefail
              
              echo "Starting secure first boot process..."
              
              # 1. Anti-tampering check (if enabled)
              ${lib.optionalString config.hypervisor.security.antiTampering.enable ''
                echo "Checking system integrity..."
                if ! ${pkgs.anti-tamper-check}/bin/anti-tamper-check check; then
                  echo "SECURITY: System integrity check failed!"
                  exit 1
                fi
              ''}
              
              # 2. Time window check (if enabled)
              ${lib.optionalString config.hypervisor.security.timeWindow.enable ''
                echo "Verifying time window..."
                if ! ${pkgs.check-time-window}/bin/check-time-window check first-boot; then
                  echo "ERROR: First boot time window expired!"
                  exit 1
                fi
              ''}
              
              # 3. Physical presence verification (if enabled)
              ${lib.optionalString config.hypervisor.security.physicalPresence.enable ''
                echo "Verifying physical presence..."
                if ! ${pkgs.verify-physical-presence}/bin/verify-physical-presence; then
                  echo "ERROR: Physical presence verification failed!"
                  exit 1
                fi
              ''}
              
              # 4. Create admin user with secure password
              echo
              echo "Creating administrative user..."
              
              # Use memory-locked password input
              HASH=$(${pkgs.memory-locked-password}/bin/memory-locked-password interactive "Admin password: ")
              
              # 5. Store credentials securely (if enabled)
              ${lib.optionalString config.hypervisor.security.encryptedStorage.enable ''
                echo "Storing credentials securely..."
                echo "$HASH" | ${pkgs.credential-vault}/bin/credential-vault store \
                  "admin-password" "admin" "-" "First boot admin password"
              ''}
              
              # 6. Split secret (if enabled)
              ${lib.optionalString config.hypervisor.security.splitSecret.enable ''
                echo "Creating secret shares..."
                echo "$HASH" > /run/admin-password-hash
                chmod 600 /run/admin-password-hash
              ''}
              
              # 7. Setup hardware auth (if enabled and required)
              ${lib.optionalString (config.hypervisor.security.hardwareAuth.enable && 
                                    config.hypervisor.security.hardwareAuth.fido2.required) ''
                echo
                echo "Hardware authentication is required!"
                ${pkgs.setup-mfa}/bin/setup-mfa
              ''}
              
              # Create configuration
              cat > /etc/nixos/secure-admin.nix <<EOF
              { config, lib, pkgs, ... }:
              {
                users.users.admin = {
                  isNormalUser = true;
                  extraGroups = [ "wheel" "libvirtd" "kvm" ];
                  hashedPassword = "$HASH";
                };
              }
              EOF
              
              chmod 600 /etc/nixos/secure-admin.nix
              
              # Mark completion
              touch /var/lib/hypervisor/.first-boot-complete
              
              echo
              echo "Secure first boot complete!"
            '';
          in secureFirstBootScript;
        };
      };
      
      # Ensure all security tools are available
      environment.systemPackages = with pkgs; [
        mkpasswd
        openssl
        gnupg
      ];
      
      # Security assertions
      assertions = [
        {
          assertion = cfg.passwords.minLength >= 8;
          message = "Minimum password length must be at least 8 characters";
        }
        {
          assertion = cfg.firstBoot.timeWindowMinutes >= 30;
          message = "First boot time window should be at least 30 minutes";
        }
        {
          assertion = !(cfg.profile == "paranoid" && !config.hypervisor.security.hardwareAuth.enable);
          message = "Paranoid profile requires hardware authentication";
        }
      ];
    }
  ]);
}