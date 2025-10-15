#!/usr/bin/env bash
#
# Hyper-NixOS Declarative Installation Script
# 
# Workflow:
# 1. Installer - Initial setup and preparation
# 2. System and user configuration migration
# 3. Switch to minimal install profile from NixOS declarative
# 4. First time boot full system setup
# 5. User custom features selection and guided install wizard (GUI)
# 6. Switch to completed system
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="${HYPER_NIXOS_REPO:-https://github.com/MasterofNull/Hyper-NixOS}"
BRANCH="${HYPER_NIXOS_BRANCH:-main}"
INSTALL_PATH="/etc/nixos"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo -e "${MAGENTA}[STEP]${NC} $*"
}

# Banner
show_banner() {
    cat << 'EOF'
    __  __                          _   ___       ____  _____
   / / / /_  ______  ___  _____    / | / (_)  __ / __ \/ ___/
  / /_/ / / / / __ \/ _ \/ ___/   /  |/ / / |/_// / / /\__ \ 
 / __  / /_/ / /_/ /  __/ /      / /|  / />  < / /_/ /___/ / 
/_/ /_/\__, / .___/\___/_/      /_/ |_/_/_/|_| \____//____/  
      /____/_/                                                
              Declarative Installation Workflow
EOF
    echo
    echo "Version: 2.0.0 - NixOS Declarative"
    echo "Repository: $REPO_URL"
    echo
    echo -e "${CYAN}Installation Workflow:${NC}"
    echo "  1. Installer setup and preparation"
    echo "  2. System and user configuration migration"
    echo "  3. Switch to NixOS minimal install profile"
    echo "  4. First boot with full system setup"
    echo "  5. GUI wizard for feature selection"
    echo "  6. Switch to completed system"
    echo
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Step 1: Installer - Initial setup and preparation
installer_setup() {
    log_step "Step 1: Installer setup and preparation"
    
    # Check if NixOS
    if [[ ! -f /etc/NIXOS ]]; then
        log_error "This installer requires NixOS"
        exit 1
    fi
    
    # Backup existing configuration
    if [[ -d "$INSTALL_PATH" ]]; then
        local backup_dir="$INSTALL_PATH.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backing up existing configuration to $backup_dir"
        cp -r "$INSTALL_PATH" "$backup_dir"
    fi
    
    # Get Hyper-NixOS files
    local source_dir=""
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if running from local installation
    if [[ -f "$script_dir/flake.nix" && -d "$script_dir/modules" ]]; then
        log_info "Using local installation files"
        source_dir="$script_dir"
    else
        log_info "Downloading Hyper-NixOS..."
        local temp_dir=$(mktemp -d)
        
        # Ensure git is available
        if ! command -v git &> /dev/null; then
            log_info "Installing git..."
            nix-env -iA nixos.git
        fi
        
        # Clone repository
        git clone --branch "$BRANCH" "$REPO_URL" "$temp_dir/hyper-nixos"
        source_dir="$temp_dir/hyper-nixos"
    fi
    
    # Copy files to installation directory
    log_info "Installing Hyper-NixOS files..."
    mkdir -p "$INSTALL_PATH"
    
    # Copy all necessary files
    for item in modules profiles scripts docs flake.nix flake.lock; do
        if [[ -e "$source_dir/$item" ]]; then
            cp -r "$source_dir/$item" "$INSTALL_PATH/"
        fi
    done
    
    log_success "Installation files prepared"
}

# Step 2: System and user configuration migration
migrate_configuration() {
    log_step "Step 2: System and user configuration migration"
    
    # Preserve hardware configuration
    if [[ ! -f "$INSTALL_PATH/hardware-configuration.nix" ]]; then
        log_info "Generating hardware configuration..."
        nixos-generate-config --root / --show-hardware-config > "$INSTALL_PATH/hardware-configuration.nix"
    fi
    
    # Migrate system configuration
    local system_config="$INSTALL_PATH/modules/system-migrated.nix"
    log_info "Migrating system configuration..."
    
    cat > "$system_config" << EOF
# System Configuration Migrated from Host
# Generated on $(date)

{ config, lib, pkgs, ... }:

{
  # Migrated hostname
  networking.hostName = "$(hostname -s)";
  
  # Migrated timezone
  time.timeZone = "$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")";
  
  # Migrated locale
  i18n.defaultLocale = "$(localectl status | grep 'System Locale' | cut -d= -f2 || echo "en_US.UTF-8")";
}
EOF
    
    # Migrate users
    local users_config="$INSTALL_PATH/modules/users-migrated.nix"
    log_info "Migrating user accounts..."
    
    cat > "$users_config" << 'EOF'
# User Configuration Migrated from Host
# Generated on $(date)

{ config, lib, pkgs, ... }:

{
  # Preserve mutable users setting
  users.mutableUsers = false;
  
  # Migrated users
  users.users = {
EOF
    
    # Find and migrate users
    local user_count=0
    while IFS=: read -r username _ uid gid gecos home shell; do
        # Skip system users unless in wheel group
        if [[ $uid -lt 1000 ]] && ! groups "$username" 2>/dev/null | grep -q wheel; then
            continue
        fi
        
        # Skip unwanted users
        if [[ "$username" =~ ^(nobody|nixbld.*)$ ]]; then
            continue
        fi
        
        log_info "  Migrating user: $username"
        
        # Get password hash
        local password_hash=$(getent shadow "$username" | cut -d: -f2)
        
        # Get groups
        local groups=$(id -nG "$username" 2>/dev/null | tr ' ' '\n' | grep -v "^$username$" | tr '\n' ' ')
        
        # Add required groups
        if groups "$username" | grep -q wheel; then
            groups="wheel libvirtd kvm $groups"
        else
            groups="libvirtd kvm $groups"
        fi
        
        # Write user configuration
        cat >> "$users_config" << EOF
    $username = {
      isNormalUser = true;
      uid = $uid;
      description = "$gecos";
      home = "$home";
      shell = pkgs.$(basename "$shell" | sed 's/-/_/g');
      hashedPassword = "$password_hash";
      extraGroups = [ $(echo $groups | xargs -n1 | sort -u | xargs printf '"%s" ') ];
    };
    
EOF
        ((user_count++))
    done < <(getent passwd)
    
    # Close users configuration
    cat >> "$users_config" << 'EOF'
  };
  
  # Migration marker
  system.activationScripts.migrationMarker = ''
    mkdir -p /var/lib/hypervisor
    echo "Migrated from $(hostname) on $(date)" > /var/lib/hypervisor/.migration-info
  '';
}
EOF
    
    log_success "Migrated $user_count users"
}

# Step 3: Switch to minimal install profile from NixOS declarative
switch_to_minimal() {
    log_step "Step 3: Switch to minimal install profile"
    
    # Create minimal configuration using NixOS declarative approach
    cat > "$INSTALL_PATH/configuration.nix" << 'EOF'
# Hyper-NixOS Minimal Installation Configuration
# This uses NixOS declarative minimal profile for first boot

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration
    ./hardware-configuration.nix
    
    # Migrated configurations
    ./modules/system-migrated.nix
    ./modules/users-migrated.nix
    
    # NixOS minimal installation profile
    <nixpkgs/nixos/modules/profiles/minimal.nix>
    
    # Hyper-NixOS first boot module
    ./modules/core/first-boot.nix
    
    # Enable GUI for setup wizard
    ./modules/gui/desktop.nix
  ];
  
  # Override minimal profile restrictions for our needs
  environment.noXlibs = false;  # We need GUI libraries
  documentation.enable = true;   # We want documentation
  
  # Essential boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Enable networking for setup
  networking.networkmanager.enable = true;
  
  # Enable first boot wizard
  hypervisor.firstBoot = {
    enable = true;
    autoStart = true;
  };
  
  # Enable GUI at boot for wizard
  hypervisor.gui.enableAtBoot = true;
  
  # Essential packages for setup
  environment.systemPackages = with pkgs; [
    vim
    git
    firefox  # For documentation access
    virt-manager  # For VM management
  ];
  
  # Enable SSH for remote access during setup
  services.openssh.enable = true;
  
  # This will be replaced after setup wizard completes
  system.stateVersion = "24.05";
}
EOF
    
    log_info "Building minimal system..."
    nixos-rebuild switch --show-trace || {
        log_error "Failed to switch to minimal profile"
        exit 1
    }
    
    log_success "Switched to minimal installation profile"
}

# Step 4: Prepare for first boot
prepare_first_boot() {
    log_step "Step 4: Preparing for first boot setup"
    
    # Create first boot marker
    mkdir -p /var/lib/hypervisor
    touch /var/lib/hypervisor/.pending-first-boot
    
    # Create GUI autostart for setup wizard
    mkdir -p /etc/xdg/autostart
    cat > /etc/xdg/autostart/hypervisor-setup-wizard.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Hyper-NixOS Setup Wizard
Comment=Complete system setup and feature selection
Exec=/etc/hypervisor/scripts/setup_wizard.sh --first-boot
Icon=system-software-install
X-GNOME-Autostart-enabled=true
EOF
    
    # Create completion script that will run after wizard
    cat > "$INSTALL_PATH/complete-setup.sh" << 'EOF'
#!/usr/bin/env bash
# This script is called by the setup wizard after feature selection

set -euo pipefail

echo "Completing Hyper-NixOS setup..."

# Remove first boot markers
rm -f /var/lib/hypervisor/.pending-first-boot
touch /var/lib/hypervisor/.first-boot-complete

# Create final configuration based on wizard selections
SELECTED_PROFILE="${1:-standard}"
SELECTED_FEATURES="${2:-}"

cat > /etc/nixos/configuration.nix << EOC
# Hyper-NixOS Production Configuration
# Generated by setup wizard

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/system-migrated.nix
    ./modules/users-migrated.nix
    ./profiles/configuration-${SELECTED_PROFILE}.nix
  ];
  
  # Features selected during setup
  hypervisor.features = {
    ${SELECTED_FEATURES}
  };
  
  # Disable first boot wizard
  hypervisor.firstBoot.enable = false;
  
  # Keep GUI if selected
  hypervisor.gui.enableAtBoot = ${3:-false};
  
  system.stateVersion = "24.05";
}
EOC

# Rebuild with final configuration
echo "Building final system configuration..."
nixos-rebuild switch

echo "Setup complete! Your Hyper-NixOS system is ready."
EOF
    
    chmod +x "$INSTALL_PATH/complete-setup.sh"
    
    log_success "First boot preparation complete"
}

# Show completion message
show_completion() {
    clear
    cat << EOF
${GREEN}════════════════════════════════════════════════════════════════════════${NC}
${GREEN}        Hyper-NixOS Minimal Installation Complete!                      ${NC}
${GREEN}════════════════════════════════════════════════════════════════════════${NC}

${CYAN}What happens next:${NC}

1. ${YELLOW}REBOOT YOUR SYSTEM${NC} to start the setup process

2. On first boot:
   • System will boot into a minimal GUI environment
   • ${BLUE}Setup Wizard${NC} will launch automatically
   • You can select:
     - System tier (minimal/standard/enhanced/professional/enterprise)
     - Optional features and modules
     - Network configuration
     - Storage setup
     - Security policies

3. After wizard completion:
   • System rebuilds with your selected configuration
   • Full Hyper-NixOS environment becomes available
   • You can start creating and managing VMs

${CYAN}Your system status:${NC}
  • Hardware: Detected and configured
  • Users: Migrated from host system
  • Profile: NixOS minimal (temporary)
  • Next step: Reboot to complete setup

${GREEN}════════════════════════════════════════════════════════════════════════${NC}

EOF
    
    read -p "Reboot now to complete setup? (Y/n): " reboot_now
    
    if [[ ! "$reboot_now" =~ ^[Nn]$ ]]; then
        log_info "Rebooting..."
        reboot
    fi
}

# Main installation flow
main() {
    show_banner
    check_root
    
    # Execute installation workflow
    installer_setup          # Step 1
    migrate_configuration    # Step 2
    switch_to_minimal       # Step 3
    prepare_first_boot      # Step 4
    show_completion
    
    # Steps 5-6 happen after reboot
}

# Run main function
main "$@"