# Password Protection Module
# Prevents accidental password wipes during system rebuilds
# 
# This module enforces safe user management practices and warns
# administrators about dangerous configurations.

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce types;
  cfg = config.hypervisor.security.passwordProtection;
  
  # Check if a user has a password configured
  userHasPassword = user: userConfig:
    (userConfig.hashedPassword or null) != null ||
    (userConfig.password or null) != null ||
    (userConfig.initialPassword or null) != null ||
    (userConfig.initialHashedPassword or null) != null;
  
  # Get list of normal users without passwords
  usersWithoutPasswords = lib.filter
    (user: let
      userCfg = config.users.users.${user};
    in
      (userCfg.isNormalUser or false) && 
      !(userHasPassword user userCfg) &&
      user != "root"
    )
    (builtins.attrNames config.users.users);
  
  # Warning script for dangerous configurations
  passwordWarningScript = pkgs.writeScriptBin "check-password-config" ''
    #!${pkgs.bash}/bin/bash
    
    # Colors
    readonly RED='\033[0;31m'
    readonly YELLOW='\033[1;33m'
    readonly GREEN='\033[0;32m'
    readonly NC='\033[0m'
    
    echo -e "''${YELLOW}╔════════════════════════════════════════════════════════════════╗''${NC}"
    echo -e "''${YELLOW}║           Password Configuration Safety Check              ║''${NC}"
    echo -e "''${YELLOW}╚════════════════════════════════════════════════════════════════╝''${NC}"
    echo
    
    # Check mutableUsers setting
    ${if config.users.mutableUsers then ''
      echo -e "''${GREEN}✓ mutableUsers = true''${NC}"
      echo "  Passwords can be set with: passwd <username>"
      echo "  Passwords will persist across rebuilds"
    '' else ''
      echo -e "''${RED}⚠ mutableUsers = false''${NC}"
      echo "  WARNING: Passwords must be set in configuration!"
      echo "  Users without hashedPassword will be LOCKED OUT"
    ''}
    echo
    
    # Check for users without passwords
    ${if usersWithoutPasswords != [] then ''
      echo -e "''${YELLOW}⚠ Users without configured passwords:''${NC}"
      ${lib.concatMapStringsSep "\n" (user: ''
        echo "  • ${user}"
      '') usersWithoutPasswords}
      echo
      ${if config.users.mutableUsers then ''
        echo "Action required: Set passwords with 'sudo passwd <username>'"
      '' else ''
        echo -e "''${RED}CRITICAL: These users will be LOCKED OUT on next rebuild!''${NC}"
        echo "Fix: Add hashedPassword to each user in configuration.nix"
        echo "Generate hash: mkpasswd -m sha-512"
      ''}
    '' else ''
      echo -e "''${GREEN}✓ All normal users have passwords configured''${NC}"
    ''}
    echo
  '';

in {
  options.hypervisor.security.passwordProtection = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable password protection safety checks";
    };
    
    requirePasswordsOnRebuild = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If true, block system rebuild if users don't have passwords.
        WARNING: This can prevent emergency recovery!
      '';
    };
    
    warnOnMissingPasswords = mkOption {
      type = types.bool;
      default = true;
      description = "Show warnings for users without configured passwords";
    };
  };
  
  config = mkIf cfg.enable {
    # Add safety check script to system
    environment.systemPackages = [ passwordWarningScript ];
    
    # Force mutableUsers to true by default to prevent accidental lockouts
    users.mutableUsers = mkDefault true;
    
    # Add activation script to warn about password issues
    system.activationScripts.passwordSafetyCheck = mkIf cfg.warnOnMissingPasswords (
      lib.stringAfter [ "users" ] ''
        # Password Safety Check
        ${if !config.users.mutableUsers && usersWithoutPasswords != [] then ''
          echo "================================================" >&2
          echo "CRITICAL WARNING: PASSWORD CONFIGURATION ERROR" >&2
          echo "================================================" >&2
          echo "" >&2
          echo "mutableUsers = false, but these users have no password:" >&2
          ${lib.concatMapStringsSep "\n" (user: ''
            echo "  • ${user}" >&2
          '') usersWithoutPasswords}
          echo "" >&2
          echo "These users will be LOCKED OUT!" >&2
          echo "Fix: Set hashedPassword for each user" >&2
          echo "Generate: mkpasswd -m sha-512" >&2
          echo "================================================" >&2
          ${if cfg.requirePasswordsOnRebuild then ''
            exit 1
          '' else ''
            sleep 5
          ''}
        '' else if config.users.mutableUsers && usersWithoutPasswords != [] then ''
          echo "INFO: Users without passwords: ${lib.concatStringsSep ", " usersWithoutPasswords}" >&2
          echo "Set passwords with: sudo passwd <username>" >&2
        '' else ''
          # All good
          true
        ''}
      ''
    );
    
    # Add informational message to MOTD
    environment.etc."motd.d/40-password-safety".text = mkIf cfg.warnOnMissingPasswords ''
      ${if !config.users.mutableUsers && usersWithoutPasswords != [] then ''
      ╔════════════════════════════════════════════════════════════════╗
      ║  ⚠️  CRITICAL: PASSWORD CONFIGURATION ERROR                    ║
      ╠════════════════════════════════════════════════════════════════╣
      ║                                                                ║
      ║  Some users have no password configured!                      ║
      ║  Run: check-password-config                                   ║
      ║                                                                ║
      ╚════════════════════════════════════════════════════════════════╝
      
      '' else if config.users.mutableUsers && usersWithoutPasswords != [] then ''
      Password reminder: Some users need passwords set
      Run: sudo passwd <username>
      Check: check-password-config
      
      '' else ""}
    '';
    
    # Add shell alias for easy checking
    programs.bash.shellAliases = {
      check-passwords = "${passwordWarningScript}/bin/check-password-config";
    };
  };
}
