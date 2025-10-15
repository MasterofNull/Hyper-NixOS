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
    
    # Dual-password security setup
    echo
    echo -e "''${BLUE}═══════════════════════════════════════════════════════════════''${NC}"
    echo -e "''${BLUE}              Dual-Password Security Configuration              ''${NC}"
    echo -e "''${BLUE}═══════════════════════════════════════════════════════════════''${NC}"
    echo
    echo "Hyper-NixOS uses a dual-password system for enhanced security:"
    echo "• Login password: For regular system access"
    echo "• Sudo password: For administrative operations"
    echo
    
    # Find all users
    WHEEL_USERS=$(getent group wheel | cut -d: -f4 | tr ',' ' ')
    ALL_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}')
    
    # Configure sudo passwords for wheel users
    echo -e "''${YELLOW}Step 1: Configure SUDO passwords for administrators''${NC}"
    echo "These passwords will be required for all administrative operations."
    echo
    
    for user in $WHEEL_USERS; do
        if [[ "$user" == "root" ]]; then continue; fi
        echo -e "''${GREEN}Setting SUDO password for admin user '$user':''${NC}"
        echo "(This should be different from the login password)"
        
        # Create a sudo password file
        SUDO_PASS_FILE="/etc/sudoers.d/00-$user-askpass"
        
        # Set the sudo password (this is the critical security password)
        while true; do
            passwd "$user" || {
                echo -e "''${RED}Failed to set password for $user!''${NC}"
                continue
            }
            
            # Configure sudo to always ask for password
            cat > "$SUDO_PASS_FILE" <<EOF
# Require password for sudo operations for $user
# Generated by Hyper-NixOS first-boot wizard
Defaults:$user timestamp_timeout=5
Defaults:$user !targetpw
Defaults:$user !rootpw
Defaults:$user runaspw
$user ALL=(ALL:ALL) ALL
EOF
            chmod 0440 "$SUDO_PASS_FILE"
            break
        done
        echo
    done
    
    # Now handle login passwords for all users
    echo -e "''${YELLOW}Step 2: Update LOGIN passwords''${NC}"
    echo "These are the passwords for regular system login."
    echo
    
    for user in $ALL_USERS; do
        if [[ "$user" == "root" ]]; then continue; fi
        
        # Check if this is a wheel user
        if echo "$WHEEL_USERS" | grep -q "\b$user\b"; then
            echo -e "''${GREEN}Admin user '$user' login password:''${NC}"
            echo "Current: 'hyper-nixos' (MUST be changed)"
            echo "Please set a NEW login password (different from sudo):"
        else
            echo -e "''${GREEN}Operator user '$user' login password:''${NC}"
            echo "Current: 'operator' (MUST be changed)"
            echo "Please set a NEW login password:"
        fi
        
        # Force password change on next login
        passwd "$user" || {
            echo -e "''${RED}Failed to set login password for $user!''${NC}"
            # Continue with other users
        }
        
        # Force password change flag
        chage -d 0 "$user"
        echo "→ Password change will be required on next login"
        echo
    done
    
    echo
    echo -e "''${GREEN}✓ Dual-password configuration complete!''${NC}"
    echo
    echo "Summary:"
    echo "• Admin users: Separate login and sudo passwords"
    echo "• Operator users: Login password only (no sudo access)"
    echo "• All passwords must be changed on first login"
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