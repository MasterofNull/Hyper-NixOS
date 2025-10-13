{ config, lib, pkgs, ... }:

# SSH Hardening Configuration
# Consolidated SSH security settings

{
  config = {
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
        KexAlgorithms = if config.hypervisor.security.sshStrictMode then [
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
        Ciphers = if config.hypervisor.security.sshStrictMode then [
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
        Macs = if config.hypervisor.security.sshStrictMode then [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
        ] else lib.mkDefault [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "hmac-sha2-512"
        ];
        
        # Connection limits (strict mode)
        MaxAuthTries = lib.mkIf config.hypervisor.security.sshStrictMode 2;
        MaxSessions = lib.mkIf config.hypervisor.security.sshStrictMode 2;
        LoginGraceTime = lib.mkIf config.hypervisor.security.sshStrictMode 30;
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
