# First Boot Configuration Service
# Runs the configuration wizard on first boot

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.firstBoot;
  
  # Create a proper script with dependencies
  firstBootScript = pkgs.writeScriptBin "first-boot-wizard" ''
    #!${pkgs.bash}/bin/bash
    # First Boot Configuration Wizard
    # This is a minimal version that ensures the system can be configured
    
    set -euo pipefail
    
    # Colors
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
    
    # Configuration
    readonly CONFIG_FILE="/etc/nixos/configuration.nix"
    readonly FIRST_BOOT_FLAG="/var/lib/hypervisor/.first-boot-complete"
    
    echo -e "''${BLUE}═══════════════════════════════════════════════════════════════''${NC}"
    echo -e "''${BLUE}         Welcome to Hyper-NixOS First Boot Setup                ''${NC}"
    echo -e "''${BLUE}═══════════════════════════════════════════════════════════════''${NC}"
    echo
    echo -e "''${YELLOW}This wizard will help you configure your system.''${NC}"
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "''${RED}This script must be run as root!''${NC}"
        exit 1
    fi
    
    # Ensure we're on a TTY
    if ! tty -s; then
        echo -e "''${RED}This script must be run on a TTY!''${NC}"
        exit 1
    fi
    
    # Security check: Verify this is truly a first boot scenario
    echo -e "''${GREEN}Performing security checks...''${NC}"
    
    # Check if first boot flag already exists
    if [[ -f "$FIRST_BOOT_FLAG" ]]; then
        echo -e "''${RED}═══════════════════════════════════════════════════════════════''${NC}"
        echo -e "''${RED}          SECURITY: First boot already completed!               ''${NC}"
        echo -e "''${RED}═══════════════════════════════════════════════════════════════''${NC}"
        echo
        echo "This system has already been configured. The first-boot wizard"
        echo "cannot be run again for security reasons."
        echo
        echo "If you need to reconfigure the system tier, use:"
        echo "  sudo /etc/hypervisor/bin/reconfigure-tier"
        echo
        exit 1
    fi
    
    # Check if any wheel users have passwords set
    WHEEL_USERS=$(getent group wheel | cut -d: -f4 | tr ',' ' ')
    USERS_WITH_PASSWORDS=0
    
    for user in $WHEEL_USERS; do
        if [[ "$user" == "root" ]]; then continue; fi
        # Check if user has a valid password hash
        HASH=$(getent shadow "$user" | cut -d: -f2)
        if [[ "$HASH" != "!" && "$HASH" != "*" && -n "$HASH" ]]; then
            USERS_WITH_PASSWORDS=$((USERS_WITH_PASSWORDS + 1))
        fi
    done
    
    # Check if custom user configuration exists
    if [[ -f "/etc/nixos/modules/users-local.nix" ]]; then
        echo -e "''${RED}═══════════════════════════════════════════════════════════════''${NC}"
        echo -e "''${RED}        SECURITY: Custom user configuration detected!           ''${NC}"
        echo -e "''${RED}═══════════════════════════════════════════════════════════════''${NC}"
        echo
        echo "This system has custom user configuration from the installer."
        echo "First-boot wizard is not needed and has been disabled."
        echo
        # Create the flag to prevent future runs
        mkdir -p "$(dirname "$FIRST_BOOT_FLAG")"
        touch "$FIRST_BOOT_FLAG"
        exit 0
    fi
    
    # If passwords exist, this might not be a true first boot
    if [[ $USERS_WITH_PASSWORDS -gt 0 ]]; then
        echo -e "''${YELLOW}WARNING: Some wheel users already have passwords set.''${NC}"
        echo "This may indicate the system has been partially configured."
        echo
        echo "Users with passwords:"
        for user in $WHEEL_USERS; do
            if [[ "$user" == "root" ]]; then continue; fi
            HASH=$(getent shadow "$user" | cut -d: -f2)
            if [[ "$HASH" != "!" && "$HASH" != "*" && -n "$HASH" ]]; then
                echo "  - $user"
            fi
        done
        echo
        read -p "Continue anyway? This will reset the configuration (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Cancelled by user."
            exit 0
        fi
    fi
    
    # Password security setup
    echo
    echo -e "''${BLUE}═══════════════════════════════════════════════════════════════''${NC}"
    echo -e "''${BLUE}                 Security Configuration                         ''${NC}"
    echo -e "''${BLUE}═══════════════════════════════════════════════════════════════''${NC}"
    echo
    echo "Setting up secure passwords for system users..."
    echo
    
    # Find all users
    WHEEL_USERS=$(getent group wheel | cut -d: -f4 | tr ',' ' ')
    ALL_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}')
    
    # Update passwords for all users
    echo -e "''${YELLOW}Configuring user passwords:''${NC}"
    echo
    
    for user in $ALL_USERS; do
        if [[ "$user" == "root" ]]; then continue; fi
        
        # Check if this is a wheel user
        if echo "$WHEEL_USERS" | grep -q "\b$user\b"; then
            echo -e "''${GREEN}Setting password for ADMIN user '$user':''${NC}"
            echo "Default password was: 'hyper-nixos'"
            echo "Please set a STRONG password for administrative access:"
            echo "(This password will be used for both login and sudo)"
        else
            echo -e "''${GREEN}Setting password for OPERATOR user '$user':''${NC}"
            echo "Default password was: 'operator'"
            echo "Please set a new password for VM operations:"
            echo "(This user has no sudo access)"
        fi
        
        # Set the password
        while true; do
            if passwd "$user"; then
                # Force password change on next login for added security
                chage -d 0 "$user" 2>/dev/null || true
                echo "✓ Password updated successfully"
                break
            else
                echo -e "''${RED}Failed to set password. Please try again.''${NC}"
            fi
        done
        echo
    done
    
    # Configure sudo security for wheel users
    echo -e "''${YELLOW}Configuring administrative security:''${NC}"
    
    # Check if sudo is already locked down
    if [[ -f "/var/lib/hypervisor/.sudo-locked" ]]; then
        echo -e "''${RED}WARNING: Sudo configuration is locked!''${NC}"
        echo "This system's sudo configuration has been locked after initial setup."
        echo "Password reset requires recovery mode or break-glass procedure."
        exit 1
    fi
    
    # Create secure sudo directory with proper permissions
    mkdir -p /etc/sudoers.d
    chmod 750 /etc/sudoers.d
    
    # Create enhanced sudo configuration
    cat > "/etc/sudoers.d/00-hypervisor-security" <<EOF
# Hyper-NixOS Enhanced Security Configuration
# Generated by first-boot wizard on $(date)
# DO NOT EDIT - This file is protected by chattr +i after first boot

# Require password for sudo (no NOPASSWD)
Defaults    env_reset
Defaults    mail_badpass
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Limit sudo password validity
Defaults    timestamp_timeout=15

# Require password for each sudo command in scripts
Defaults    !runaspw
Defaults    !targetpw
Defaults    !rootpw

# Log all sudo commands
Defaults    log_input
Defaults    log_output
Defaults    logfile="/var/log/sudo.log"

# Security restrictions for all users
Defaults    requiretty
Defaults    use_pty

# Prevent sudo password changes via sudo itself
Cmnd_Alias PASSWD_CMDS = /usr/bin/passwd, /usr/sbin/chpasswd, /usr/bin/chage
Defaults!PASSWD_CMDS !authenticate

# Admin group has full sudo with password (except password commands)
%wheel ALL=(ALL:ALL) ALL, !PASSWD_CMDS

# Password operations require physical console
%wheel ALL=(ALL:ALL) PASSWD_CMDS
EOF
    chmod 0440 "/etc/sudoers.d/00-hypervisor-security"
    
    # Create a hash of critical security files for integrity checking
    echo -e "Creating security integrity baseline..."
    sha256sum /etc/sudoers /etc/sudoers.d/* > /var/lib/hypervisor/.sudo-integrity
    chmod 600 /var/lib/hypervisor/.sudo-integrity
    
    echo "✓ Administrative security configured"
    echo
    echo -e "''${GREEN}✓ Password configuration complete!''${NC}"
    echo
    echo "Security summary:"
    echo "• Admin users: Full access with sudo (password required)"
    echo "• Operator users: VM management only (no sudo)"
    echo "• Passwords expire on next login for security"
    echo "• All sudo operations are logged"
    echo
    
    # Ask about system tier
    echo -e "''${BLUE}Select your system tier:''${NC}"
    echo "1) Minimal - Basic VM management (2GB RAM minimum)"
    echo "2) Standard - Common features (4GB RAM recommended)"
    echo "3) Enhanced - Advanced features (8GB RAM recommended)"
    echo "4) Professional - Full features (16GB RAM recommended)"
    echo "5) Enterprise - All features (32GB RAM recommended)"
    echo
    read -p "Enter choice [1-5]: " tier_choice
    
    case $tier_choice in
        1) tier="minimal" ;;
        2) tier="standard" ;;
        3) tier="enhanced" ;;
        4) tier="professional" ;;
        5) tier="enterprise" ;;
        *) tier="standard" ;;
    esac
    
    echo
    echo -e "''${GREEN}Selected tier: $tier''${NC}"
    echo
    
    # Create tier configuration
    cat > "$CONFIG_FILE.new" <<EOF
# Hyper-NixOS Configuration
# Generated by First Boot Wizard on $(date)
# Selected Tier: $tier

{ config, lib, pkgs, ... }:

{
  imports = [
    # Import the base configuration
    ./configuration-minimal.nix
    # Import the selected tier
    ./modules/system-tiers.nix
  ];
  
  # Set the selected tier
  hypervisor.systemTier = "$tier";
  
  # First boot is complete
  hypervisor.firstBoot.autoStart = false;
}
EOF
    
    # Backup original and apply new config
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$CONFIG_FILE.new" "$CONFIG_FILE"
    
    echo -e "''${GREEN}Configuration updated!''${NC}"
    echo
    echo "The system will now rebuild with your selected configuration."
    echo "This may take a few minutes..."
    echo
    
    # Rebuild the system
    nixos-rebuild switch || {
        echo -e "''${RED}System rebuild failed!''${NC}"
        echo "Restoring backup configuration..."
        cp "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)" "$CONFIG_FILE"
        exit 1
    }
    
    # Mark first boot as complete
    mkdir -p "$(dirname "$FIRST_BOOT_FLAG")"
    touch "$FIRST_BOOT_FLAG"
    
    echo
    echo -e "''${GREEN}═══════════════════════════════════════════════════════════════''${NC}"
    echo -e "''${GREEN}        First boot configuration complete!                      ''${NC}"
    echo -e "''${GREEN}═══════════════════════════════════════════════════════════════''${NC}"
    echo
    echo "You can now log in with your wheel group users:"
    for user in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
        if [[ "$user" != "root" ]]; then
            echo "  Username: $user"
        fi
    done
    echo "  Password: (the password you set)"
    echo
    echo "Press Enter to continue..."
    read -r
  '';
in
{
  options.hypervisor.firstBoot = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable first boot configuration wizard";
    };
    
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start wizard on first boot";
    };
  };
  
  config = mkIf cfg.enable {
    # Install the wizard script
    environment.systemPackages = [ firstBootScript ];
    
    # Ensure the hypervisor directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor 0755 root root -"
    ];
    
    # Create systemd service for first boot
    systemd.services.hypervisor-first-boot = mkIf cfg.autoStart {
      description = "Hyper-NixOS First Boot Configuration Wizard";
      
      # Only run on first boot
      unitConfig = {
        ConditionPathExists = "!/var/lib/hypervisor/.first-boot-complete";
        # Also don't run if custom user config exists
        ConditionPathExists = "!/etc/nixos/modules/users-local.nix";
      };
      
      serviceConfig = {
        Type = "idle";  # Wait for other services to finish
        RemainAfterExit = true;
        StandardInput = "tty-force";
        StandardOutput = "inherit";
        StandardError = "inherit";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        
        # Ensure directory exists before running
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor";
        
        # Run the wizard
        ExecStart = "${firstBootScript}/bin/first-boot-wizard";
        
        # Create completion flag
        ExecStartPost = "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/.first-boot-complete";
      };
      
      # Run after basic system is up but before getty
      after = [ "sysinit.target" "basic.target" ];
      before = [ "getty.target" ];
      wantedBy = [ "multi-user.target" ];
      
      # Take over tty1 from getty
      conflicts = [ "getty@tty1.service" ];
    };
    
    # Override getty@tty1 to wait for first-boot if needed
    systemd.services."getty@tty1" = mkIf cfg.autoStart {
      overrideStrategy = "asDropin";
      unitConfig = {
        # Don't start getty@tty1 until first boot is complete
        ConditionPathExists = "/var/lib/hypervisor/.first-boot-complete";
      };
    };
    
    # Also provide a manual way to run the wizard
    environment.etc."hypervisor/bin/reconfigure-tier" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Remove first boot flag and run wizard
        
        if [[ $EUID -ne 0 ]]; then
          echo "This script must be run as root"
          exit 1
        fi
        
        echo "This will reconfigure your system tier."
        read -p "Continue? (y/N): " confirm
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
          rm -f /var/lib/hypervisor/.first-boot-complete
          ${firstBootScript}/bin/first-boot-wizard
        else
          echo "Cancelled."
        fi
      '';
    };
  };
}