{ config, lib, pkgs, ... }:

# SSH Hardening Configuration
# Consolidated SSH security settings

let
  cfg = config.hypervisor.security;
in
{
  options.hypervisor.security.sshStrictMode = lib.mkEnableOption "Enable strictest SSH configuration";
  
  options.hypervisor.security.sshHardening = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SSH hardening configuration";
    };
  };

  config = lib.mkIf config.hypervisor.security.sshHardening.enable {
    # ═══════════════════════════════════════════════════════════════
    # Standard SSH Configuration (Secure)
    # ═══════════════════════════════════════════════════════════════
    services.openssh = {
      enable = true;
      settings = {
        # Disable password authentication (keys only)
        PasswordAuthentication = false;
        ChallengeResponseAuthentication = false;
        KbdInteractiveAuthentication = false;
        
        # No root login
        PermitRootLogin = "no";
        
        # Only allow admin users via SSH
        AllowUsers = [ "admin" ];
        DenyUsers = [ "hypervisor-operator" ];  # Operator only on console
        
        # Strong key exchange algorithms
        # In strict mode, use only the strongest algorithms
        KexAlgorithms = if cfg.sshStrictMode then [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
        ] else lib.mkDefault [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];
        
        # Modern ciphers only
        # In strict mode, use only the strongest ciphers
        Ciphers = if cfg.sshStrictMode then [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
        ] else lib.mkDefault [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
          "aes256-ctr"
        ];
        
        # Strong MACs
        # In strict mode, use only the strongest MACs
        Macs = if cfg.sshStrictMode then [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
        ] else lib.mkDefault [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "hmac-sha2-512"
        ];
        
        # Connection limits (strict mode)
        MaxAuthTries = if cfg.sshStrictMode then 2 else lib.mkDefault 6;
        MaxSessions = if cfg.sshStrictMode then 2 else lib.mkDefault 10;
        LoginGraceTime = if cfg.sshStrictMode then 30 else lib.mkDefault 120;
      };
    };
    
    # Fail2ban for SSH protection
    services.fail2ban = {
      enable = true;
      maxretry = 3;
      ignoreIP = [
        "127.0.0.1/8"
        "::1"
        # Add your trusted networks here
      ];
    };
  };
}
