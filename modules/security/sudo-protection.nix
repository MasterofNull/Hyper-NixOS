# Sudo Password Protection Module
# Prevents unauthorized sudo password resets

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.sudoProtection;
in
{
  options.hypervisor.security.sudoProtection = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable sudo password reset protection";
    };
    
    lockdownAfterBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Lock down sudo configuration after first boot";
    };
    
    requirePhysicalPresence = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require physical presence for sudo changes";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
    # Immutable sudo configuration
    systemd.services.sudo-lockdown = lib.mkIf cfg.lockdownAfterBoot {
      description = "Lock down sudo configuration after first boot";
      after = [ "hypervisor-first-boot.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "sudo-lockdown" ''
          #!/usr/bin/env bash
          set -euo pipefail
          
          # Check if first boot is complete
          if [[ -f /var/lib/hypervisor/.first-boot-complete ]]; then
            # Make sudoers files immutable
            chattr +i /etc/sudoers 2>/dev/null || true
            chattr +i /etc/sudoers.d/* 2>/dev/null || true
            
            # Create lockdown flag
            touch /var/lib/hypervisor/.sudo-locked
            
            echo "Sudo configuration locked down"
          fi
        '';
      };
    };
    
    # Password change protection script
    environment.etc."hypervisor/bin/sudo-password-reset" = {
      mode = "0700";  # Root only
      text = ''
        #!/usr/bin/env bash
        # Secure sudo password reset tool
        
        set -euo pipefail
        
        # Colors
        readonly RED='\033[0;31m'
        readonly GREEN='\033[0;32m'
        readonly YELLOW='\033[1;33m'
        readonly NC='\033[0m'
        
        # Security checks
        if [[ $EUID -ne 0 ]]; then
            echo -e "''${RED}This script must be run as root''${NC}"
            exit 1
        fi
        
        # Check if running on physical TTY (not SSH)
        if [[ -z "''${SSH_TTY:-}" ]] && tty -s && [[ "$(tty)" =~ ^/dev/tty[0-9]+$ ]]; then
            echo -e "''${GREEN}✓ Physical console access verified''${NC}"
        else
            echo -e "''${RED}ERROR: This operation requires physical console access''${NC}"
            echo "Please run this command from the physical console (TTY1-TTY6)"
            exit 1
        fi
        
        # Require boot media or recovery mode
        if ! grep -q "recovery" /proc/cmdline && ! [[ -f /run/recovery-mode ]]; then
            echo -e "''${YELLOW}WARNING: System is in normal operation mode''${NC}"
            echo
            echo "For security, sudo password resets require one of:"
            echo "1. Boot into recovery mode (add 'recovery' to kernel parameters)"
            echo "2. Boot from Hyper-NixOS installation media"
            echo "3. Use break-glass procedure (requires security token)"
            echo
            read -p "Do you have a break-glass token? (y/N): " token_confirm
            
            if [[ "''${token_confirm,,}" == "y" ]]; then
                echo "Enter break-glass token:"
                read -rs BREAK_GLASS_TOKEN
                
                # Verify token (in production, this would check against hardware token)
                EXPECTED_HASH="$(sha256sum /etc/machine-id | cut -d' ' -f1)"
                PROVIDED_HASH="$(echo -n "$BREAK_GLASS_TOKEN" | sha256sum | cut -d' ' -f1)"
                
                if [[ "$PROVIDED_HASH" != "$EXPECTED_HASH" ]]; then
                    echo -e "''${RED}Invalid break-glass token''${NC}"
                    logger -p auth.crit "SECURITY: Failed sudo password reset attempt"
                    exit 1
                fi
                
                echo -e "''${GREEN}✓ Break-glass token verified''${NC}"
                logger -p auth.warning "SECURITY: Break-glass sudo password reset initiated"
            else
                echo "Operation cancelled"
                exit 1
            fi
        fi
        
        # Unlock sudoers temporarily
        echo "Unlocking sudo configuration..."
        chattr -i /etc/sudoers 2>/dev/null || true
        chattr -i /etc/sudoers.d/* 2>/dev/null || true
        
        # Show current wheel users
        echo
        echo "Current administrative users:"
        getent group wheel | cut -d: -f4 | tr ',' '\n' | while read user; do
            [[ -z "$user" || "$user" == "root" ]] && continue
            echo "  - $user"
        done
        
        echo
        read -p "Enter username to reset sudo password: " username
        
        # Validate user exists and is in wheel group
        if ! id "$username" &>/dev/null; then
            echo -e "''${RED}User '$username' does not exist''${NC}"
            exit 1
        fi
        
        if ! groups "$username" | grep -q wheel; then
            echo -e "''${RED}User '$username' is not in wheel group''${NC}"
            exit 1
        fi
        
        # Reset password
        echo "Setting new password for $username:"
        if passwd "$username"; then
            echo -e "''${GREEN}✓ Password updated successfully''${NC}"
            
            # Log the action
            logger -p auth.warning "SECURITY: Sudo password reset for user $username by $USER"
            
            # Re-lock sudoers
            chattr +i /etc/sudoers 2>/dev/null || true
            chattr +i /etc/sudoers.d/* 2>/dev/null || true
            
            echo
            echo "Password reset complete. Security lockdown restored."
        else
            echo -e "''${RED}Failed to reset password''${NC}"
            
            # Re-lock sudoers even on failure
            chattr +i /etc/sudoers 2>/dev/null || true
            chattr +i /etc/sudoers.d/* 2>/dev/null || true
            
            exit 1
        fi
      '';
    };
    
    }
    
    # Security monitoring for sudo usage - only enable if audit is available
    (lib.mkIf (config.security ? auditd) {
      security.auditd.enable = lib.mkDefault true;
    })
    
    (lib.mkIf (config.security ? audit) {
      security.audit = {
        enable = true;
        rules = [
          # Monitor all sudo executions
          "-a always,exit -F path=/usr/bin/sudo -F perm=x -k sudo_exec"
          
          # Monitor sudoers file changes
          "-w /etc/sudoers -p wa -k sudoers_changes"
          "-w /etc/sudoers.d/ -p wa -k sudoers_changes"
        
          # Monitor password changes
          "-w /usr/bin/passwd -p x -k passwd_changes"
          
          # Monitor our security scripts
          "-w /etc/hypervisor/bin/ -p x -k hypervisor_security"
        ];
      };
    })
    
    {
    # Additional PAM security
    security.pam.services.sudo = {
      # Require additional authentication for sudo
      text = lib.mkAfter ''
        # Log all sudo attempts
        session    required     pam_exec.so /etc/hypervisor/bin/log-sudo-attempt
        
        # Require physical presence for certain operations
        auth       required     pam_exec.so /etc/hypervisor/bin/check-physical-presence
      '';
    };
    
    # Physical presence check script
    environment.etc."hypervisor/bin/check-physical-presence" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # For password changes and critical operations
        
        # If this is a password change attempt
        if [[ "''${PAM_SERVICE}" == "passwd" ]] || [[ "''${PAM_RUSER}" != "''${PAM_USER}" ]]; then
          # Check if on physical console
          if [[ -n "''${SSH_TTY:-}" ]]; then
            echo "This operation requires physical console access" >&2
            exit 1
          fi
        fi
        
        exit 0
      '';
    };
    
    # Sudo attempt logging
    environment.etc."hypervisor/bin/log-sudo-attempt" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        logger -p auth.info "SUDO: User ''${PAM_USER} (real: ''${PAM_RUSER}) attempted sudo from ''${PAM_TTY}"
        exit 0
      '';
    };
    }
  ]);
}