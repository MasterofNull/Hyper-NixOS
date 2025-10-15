#!/usr/bin/env bash
#
# Hyper-NixOS Installation Script
# Minimal installation that prepares for first boot configuration
#
# This script:
# 1. Applies minimal configuration with current username/password from host
# 2. Migrates hardware configuration
# 3. Sets up for first boot menu and system setup wizard
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
MIN_RAM_GB=2  # Reduced for minimal install
MIN_DISK_GB=50  # Reduced for minimal install
MIN_CPU_CORES=2  # Reduced for minimal install

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
            Minimal Installation & First Boot Setup
EOF
    echo
    echo "Version: 2.0.0 - Minimal Install"
    echo "Repository: $REPO_URL"
    echo
    echo -e "${CYAN}This installer will:${NC}"
    echo "  1. Install minimal Hyper-NixOS configuration"
    echo "  2. Migrate your current users and hardware config"
    echo "  3. Prepare for first boot configuration wizard"
    echo
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking minimal system requirements..."
    
    # Check CPU
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt $MIN_CPU_CORES ]]; then
        log_warn "Low CPU cores: $cpu_cores (recommended: $MIN_CPU_CORES)"
        echo "  The system will work but performance may be limited."
        read -p "Continue anyway? (y/N): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
    else
        log_success "CPU cores: $cpu_cores ✓"
    fi
    
    # Check RAM
    local ram_gb=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
    if [[ $ram_gb -lt $MIN_RAM_GB ]]; then
        log_warn "Low RAM: ${ram_gb}GB (recommended: ${MIN_RAM_GB}GB)"
        echo "  Minimal tier will be selected by default."
        FORCE_MINIMAL_TIER=true
    else
        log_success "RAM: ${ram_gb}GB ✓"
    fi
    
    # Check disk space
    local disk_gb=$(df / | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [[ $disk_gb -lt $MIN_DISK_GB ]]; then
        log_error "Insufficient disk space: ${disk_gb}GB (minimum: ${MIN_DISK_GB}GB)"
        exit 1
    fi
    log_success "Available disk: ${disk_gb}GB ✓"
    
    # Check virtualization support
    if ! grep -E 'vmx|svm' /proc/cpuinfo > /dev/null; then
        log_warn "Hardware virtualization not detected. Performance may be limited."
    else
        log_success "Hardware virtualization: enabled ✓"
    fi
    
    # Check if NixOS
    if [[ ! -f /etc/NIXOS ]]; then
        log_error "This installer requires NixOS. Please install NixOS first."
        echo "Download from: https://nixos.org/download.html"
        exit 1
    fi
    log_success "NixOS detected ✓"
    
    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]] && [[ "$arch" != "aarch64" ]]; then
        log_error "Unsupported architecture: $arch (supported: x86_64, aarch64)"
        exit 1
    fi
    log_success "Architecture: $arch ✓"
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Update channels
    nix-channel --update
    
    # Install required packages
    nix-env -iA nixos.git nixos.curl nixos.jq nixos.tmux || true
    
    log_success "Dependencies installed"
}

# Check if we have a complete local installation
check_local_files() {
    local dir="$1"
    local required_files=(
        "flake.nix"
        "configuration.nix"
        "scripts/system_installer.sh"
        "modules/core/options.nix"
        "modules/security/base.nix"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$dir/$file" ]]; then
            return 1
        fi
    done
    
    # Check for required directories
    local required_dirs=(
        "modules"
        "scripts"
        "docs"
    )
    
    for dir_check in "${required_dirs[@]}"; do
        if [[ ! -d "$dir/$dir_check" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Setup repository files
setup_repository() {
    log_step "Setting up Hyper-NixOS files..."
    
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Backup existing NixOS configuration
    if [[ -d "/etc/nixos" ]]; then
        local backup_dir="/etc/nixos.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "Backing up existing configuration to $backup_dir"
        cp -r /etc/nixos "$backup_dir"
    fi
    
    # Check if we're running from a complete local installation
    if check_local_files "$script_dir"; then
        log_info "Using local installation files"
        SOURCE_DIR="$script_dir"
    else
        log_info "Downloading from repository..."
        
        # Create temporary directory
        local temp_dir=$(mktemp -d)
        
        # Check if git is available
        if ! command -v git &> /dev/null; then
            log_info "Installing git..."
            nix-env -iA nixos.git || {
                log_error "Failed to install git"
                exit 1
            }
        fi
        
        # Clone repository
        if git clone --branch "$BRANCH" "$REPO_URL" "$temp_dir/hyper-nixos"; then
            SOURCE_DIR="$temp_dir/hyper-nixos"
            log_success "Repository downloaded"
        else
            log_error "Failed to download repository"
            exit 1
        fi
    fi
    
    # Copy only necessary files for minimal install
    log_info "Installing minimal configuration files..."
    
    # Essential directories
    for dir in modules profiles scripts docs; do
        if [[ -d "$SOURCE_DIR/$dir" ]]; then
            cp -r "$SOURCE_DIR/$dir" "$INSTALL_PATH/"
        fi
    done
    
    # Essential files  
    for file in flake.nix flake.lock hardware-configuration.nix; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            cp "$SOURCE_DIR/$file" "$INSTALL_PATH/"
        fi
    done
    
    log_success "Files installed"
}

# Generate or update hardware configuration
generate_hardware_config() {
    log_step "Detecting hardware configuration..."
    
    # Always regenerate to ensure current hardware is detected
    nixos-generate-config --root / --show-hardware-config > "$INSTALL_PATH/hardware-configuration.nix.new"
    
    # If existing hardware config exists, show differences
    if [[ -f "$INSTALL_PATH/hardware-configuration.nix" ]]; then
        if ! diff -q "$INSTALL_PATH/hardware-configuration.nix" "$INSTALL_PATH/hardware-configuration.nix.new" > /dev/null; then
            log_warn "Hardware configuration has changed"
            mv "$INSTALL_PATH/hardware-configuration.nix" "$INSTALL_PATH/hardware-configuration.nix.backup"
        fi
    fi
    
    mv "$INSTALL_PATH/hardware-configuration.nix.new" "$INSTALL_PATH/hardware-configuration.nix"
    log_success "Hardware configuration updated"
}

# Migrate existing users from current system
migrate_users() {
    log_step "Migrating users from current system..."
    
    local users_file="$INSTALL_PATH/modules/users-migrated.nix"
    local migrate_info="$INSTALL_PATH/modules/.migration-info"
    
    # Start the users configuration
    cat > "$users_file" << 'EOF'
# Migrated Users Configuration
# Auto-generated from host system during Hyper-NixOS installation
# This file preserves existing user accounts and credentials

{ config, lib, pkgs, ... }:

{
  # Mark that credentials were migrated
  system.activationScripts.migrationMarker = ''
    mkdir -p /etc/hypervisor
    echo "$(hostname)" > /etc/hypervisor/migrated-from
    date >> /etc/hypervisor/migrated-from
  '';

  users = {
    # Preserve mutable users setting from host
    mutableUsers = false;
    
    users = {
EOF
    
    # Track what we migrated
    echo "Migration performed on: $(date)" > "$migrate_info"
    echo "Source hostname: $(hostname)" >> "$migrate_info"
    echo "Migrated users:" >> "$migrate_info"
    
    # Find all human users (UID >= 1000) and system users in wheel group
    local migrated_count=0
    while IFS=: read -r username _ uid gid gecos home shell; do
        # Skip if UID < 1000 unless they're in wheel group
        if [[ $uid -lt 1000 ]]; then
            if ! groups "$username" 2>/dev/null | grep -q wheel; then
                continue
            fi
        fi
        
        # Skip system users we don't want to migrate
        if [[ "$username" == "nobody" || "$username" == "nixbld"* ]]; then
            continue
        fi
        
        log_info "  Migrating user: $username (UID: $uid)"
        echo "  - $username (UID: $uid)" >> "$migrate_info"
        
        # Get user's groups
        local user_groups=$(groups "$username" 2>/dev/null | cut -d: -f2 | tr ' ' '\n' | grep -v "^$username$" | tr '\n' ' ')
        
        # Get password hash
        local password_hash=$(getent shadow "$username" | cut -d: -f2)
        
        # Determine if this should be an admin or operator
        local extra_groups="libvirtd kvm"
        if groups "$username" 2>/dev/null | grep -q wheel; then
            extra_groups="wheel libvirtd kvm"
        fi
        
        # Write user configuration
        cat >> "$users_file" << EOF
      $username = {
        isNormalUser = true;
        uid = $uid;
        description = "$gecos";
        home = "$home";
        shell = pkgs.$(basename "$shell");
        hashedPassword = "$password_hash";
        extraGroups = [ $(echo $extra_groups | xargs -n1 | sort -u | xargs printf '"%s" ') ];
      };
      
EOF
        
        ((migrated_count++))
    done < <(getent passwd | awk -F: '$3 >= 1000 || $1 == "root" {print}')
    
    # Close the configuration
    cat >> "$users_file" << 'EOF'
    };
  };
  
  # Ensure wheel group has sudo access
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [ { command = "ALL"; } ];
  }];
}
EOF
    
    chmod 600 "$users_file"  # Protect the file with password hashes
    
    log_success "Migrated $migrated_count users"
    
    # Create credential chain marker
    mkdir -p /var/lib/hypervisor
    cp "$migrate_info" /var/lib/hypervisor/.credential-chain
}

# Create minimal configuration
create_minimal_config() {
    log_step "Creating minimal configuration..."
    
    local config_file="$INSTALL_PATH/configuration.nix"
    local current_hostname=$(hostname -s)
    local current_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    
    # Create the minimal configuration
    cat > "$config_file" << EOF
# Hyper-NixOS Minimal Configuration
# Generated by installer on $(date)
# This configuration will be completed by the first boot wizard

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration
    ./hardware-configuration.nix
    
    # Use the minimal profile that includes first boot wizard
    ./profiles/configuration-minimal.nix
  ];

  # System identification (from current host)
  networking.hostName = "$current_hostname";
  time.timeZone = "$current_timezone";
  
  # This will be updated by first boot wizard
  system.stateVersion = "24.05";
}
EOF
    
    log_success "Minimal configuration created"
    
    # Show what will happen
    echo
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo "  • Hostname: $current_hostname"
    echo "  • Timezone: $current_timezone"  
    echo "  • Profile: Minimal (includes first boot wizard)"
    echo "  • Users: Migrated from current system"
    echo
}

# Create system directories
create_system_dirs() {
    log_step "Creating system directories..."
    
    # Create required directories
    mkdir -p /var/lib/hypervisor
    mkdir -p /var/log/hypervisor
    mkdir -p /etc/hypervisor
    
    # Set permissions
    chmod 755 /var/lib/hypervisor
    chmod 755 /var/log/hypervisor
    chmod 755 /etc/hypervisor
    
    log_success "System directories created"
}

# Build and switch to minimal configuration
build_minimal_system() {
    log_step "Building minimal Hyper-NixOS configuration..."
    
    # Show what will be built
    echo -e "${CYAN}The system will now build with:${NC}"
    echo "  • Minimal Hyper-NixOS base"
    echo "  • Essential VM management tools"
    echo "  • First boot configuration wizard"
    echo "  • Migrated user accounts"
    echo
    log_info "This may take 10-15 minutes on first run..."
    echo
    
    # Build the system
    cd "$INSTALL_PATH"
    
    # Test build first
    if ! nixos-rebuild test --show-trace; then
        log_error "Build test failed. Checking common issues..."
        
        # Check for common problems
        if [[ ! -f "$INSTALL_PATH/hardware-configuration.nix" ]]; then
            log_error "Missing hardware-configuration.nix"
        fi
        
        if [[ ! -f "$INSTALL_PATH/profiles/configuration-minimal.nix" ]]; then
            log_error "Missing minimal profile"
        fi
        
        exit 1
    fi
    
    log_success "Build test passed"
    
    # Apply configuration
    log_info "Applying configuration (this will activate the new system)..."
    nixos-rebuild switch || {
        log_error "Failed to switch to new configuration"
        log_info "You can try manually with: nixos-rebuild switch"
        exit 1
    }
    
    log_success "Minimal Hyper-NixOS installed successfully!"
}

# Post-installation message
show_post_install() {
    # Clear screen for important message
    clear
    
    cat << EOF
${GREEN}════════════════════════════════════════════════════════════════════════${NC}
${GREEN}           Hyper-NixOS Minimal Installation Complete!                   ${NC}
${GREEN}════════════════════════════════════════════════════════════════════════${NC}

${CYAN}What happens next:${NC}

1. ${YELLOW}REBOOT YOUR SYSTEM${NC} to start the first boot wizard
   
2. On first boot, you will see:
   • ${BLUE}First Boot Configuration Wizard${NC} on TTY1
   • This wizard will help you:
     - Set secure passwords (if not migrated)
     - Select your system tier (minimal/standard/enhanced/etc)
     - Configure final system settings

3. The wizard will ONLY run once for security reasons

${CYAN}Your migrated users:${NC}
EOF
    
    # Show migrated users
    if [[ -f "$INSTALL_PATH/modules/.migration-info" ]]; then
        grep "^  -" "$INSTALL_PATH/modules/.migration-info" | sed 's/^/  /'
    else
        echo "  (No users were migrated - defaults will be used)"
    fi
    
    cat << EOF

${CYAN}To reboot now:${NC}
  sudo reboot

${CYAN}To reboot later:${NC}
  The first boot wizard will run whenever you're ready

${YELLOW}Important:${NC} The first boot wizard will help you complete the setup.
Don't skip it as it configures critical security settings!

${GREEN}════════════════════════════════════════════════════════════════════════${NC}
EOF
    
    # Ask if user wants to reboot now
    echo
    read -p "Would you like to reboot now? (Y/n): " reboot_now
    
    if [[ ! "$reboot_now" =~ ^[Nn]$ ]]; then
        log_info "Rebooting system..."
        sleep 2
        reboot
    else
        log_info "Remember to reboot to complete the installation!"
    fi
}

# Quick safety check before install
safety_check() {
    log_step "Performing safety check..."
    
    # Check if Hyper-NixOS is already installed
    if [[ -f /var/lib/hypervisor/.first-boot-complete ]]; then
        log_warn "Hyper-NixOS appears to be already installed!"
        echo "  First boot has already been completed."
        echo
        read -p "Continue with reinstall? This will reset the system (y/N): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
        
        # Remove first boot marker to allow wizard to run again
        rm -f /var/lib/hypervisor/.first-boot-complete
    fi
    
    # Warn about configuration changes
    if [[ -f /etc/nixos/configuration.nix ]]; then
        echo
        log_warn "This will replace your current NixOS configuration!"
        echo "  A backup will be created, but please ensure you want to proceed."
        echo
        read -p "Continue with installation? (y/N): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
    fi
}

# Main installation flow
main() {
    # Check if help requested
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_banner
        echo "Usage: sudo $0"
        echo
        echo "This installer will:"
        echo "  1. Install minimal Hyper-NixOS configuration"
        echo "  2. Migrate your existing users and passwords"
        echo "  3. Prepare the system for first boot configuration"
        echo
        echo "No options required - the installer is interactive."
        exit 0
    fi
    
    # Start installation
    show_banner
    check_root
    safety_check
    check_requirements
    
    # Main installation steps
    install_dependencies
    setup_repository
    generate_hardware_config
    migrate_users
    create_minimal_config
    create_system_dirs
    build_minimal_system
    show_post_install
}

# Run main function
main "$@"