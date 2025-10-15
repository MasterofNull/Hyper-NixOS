#!/usr/bin/env bash
#
# Hyper-NixOS Installation Script
# One-command installation for the next-generation virtualization platform
#
# Note: You can also install directly without downloading this script using:
# bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/system_installer.sh --fast --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="${HYPER_NIXOS_REPO:-https://github.com/MasterofNull/Hyper-NixOS}"
BRANCH="${HYPER_NIXOS_BRANCH:-main}"
INSTALL_PATH="/etc/nixos/hyper-nixos"
MIN_RAM_GB=8
MIN_DISK_GB=100
MIN_CPU_CORES=4

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

# Banner
show_banner() {
    cat << 'EOF'
    __  __                          _   ___       ____  _____
   / / / /_  ______  ___  _____    / | / (_)  __ / __ \/ ___/
  / /_/ / / / / __ \/ _ \/ ___/   /  |/ / / |/_// / / /\__ \ 
 / __  / /_/ / /_/ /  __/ /      / /|  / />  < / /_/ /___/ / 
/_/ /_/\__, / .___/\___/_/      /_/ |_/_/_/|_| \____//____/  
      /____/_/                                                
                Next-Generation Virtualization Platform
EOF
    echo
    echo "Version: 2.0.0"
    echo "Repository: $REPO_URL"
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
    log_info "Checking system requirements..."
    
    # Check CPU
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt $MIN_CPU_CORES ]]; then
        log_error "Insufficient CPU cores: $cpu_cores (minimum: $MIN_CPU_CORES)"
        exit 1
    fi
    log_success "CPU cores: $cpu_cores ✓"
    
    # Check RAM
    local ram_gb=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
    if [[ $ram_gb -lt $MIN_RAM_GB ]]; then
        log_error "Insufficient RAM: ${ram_gb}GB (minimum: ${MIN_RAM_GB}GB)"
        exit 1
    fi
    log_success "RAM: ${ram_gb}GB ✓"
    
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

# Clone or copy repository
clone_repository() {
    # Get the directory where this script is located
    # Safe for piped execution: use default if BASH_SOURCE is undefined
    local source="${BASH_SOURCE[0]:-}"
    local script_dir
    if [[ -n "$source" ]]; then
        script_dir="$(cd "$(dirname "$source")" && pwd)"
    else
        script_dir="$(pwd)"
    fi
    
    # Check if we're running from a complete local installation
    if check_local_files "$script_dir"; then
        log_info "Detected complete local installation"
        log_info "Using local files from: $script_dir"
        
        if [[ -d "$INSTALL_PATH" ]]; then
            log_warn "Installation directory already exists. Backing up..."
            mv "$INSTALL_PATH" "${INSTALL_PATH}.bak.$(date +%Y%m%d%H%M%S)"
        fi
        
        # Copy the local files
        log_info "Copying files to $INSTALL_PATH..."
        mkdir -p "$(dirname "$INSTALL_PATH")"
        cp -r "$script_dir" "$INSTALL_PATH"
        
        log_success "Files copied from local installation"
    else
        log_info "Local installation incomplete or not detected"
        log_info "Attempting to clone from GitHub..."
        
        # Fix the repository URL to the correct one
        local actual_repo_url="https://github.com/MasterofNull/Hyper-NixOS"
        
        if [[ -d "$INSTALL_PATH" ]]; then
            log_warn "Installation directory already exists. Backing up..."
            mv "$INSTALL_PATH" "${INSTALL_PATH}.bak.$(date +%Y%m%d%H%M%S)"
        fi
        
        # Check if git is available
        if ! command -v git &> /dev/null; then
            log_error "Git is not installed and local files are incomplete"
            log_error "Please either:"
            log_error "  1. Download the complete ZIP file and extract it"
            log_error "  2. Install git: nix-env -iA nixos.git"
            exit 1
        fi
        
        # Try to clone from the correct repository
        if git clone --branch "$BRANCH" "$actual_repo_url" "$INSTALL_PATH"; then
            log_success "Repository cloned to $INSTALL_PATH"
        else
            log_error "Failed to clone repository"
            log_error "Please check your internet connection or download the ZIP file from:"
            log_error "https://github.com/MasterofNull/Hyper-NixOS/archive/refs/heads/main.zip"
            exit 1
        fi
    fi
}

# Generate hardware configuration if missing
generate_hardware_config() {
    if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
        log_info "Generating hardware configuration..."
        nixos-generate-config --root /
        log_success "Hardware configuration generated"
    fi
}

# Create base configuration
create_base_config() {
    log_info "Creating base configuration..."
    
    local config_file="/etc/nixos/configuration.nix"
    
    # Backup existing configuration
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "${config_file}.bak.$(date +%Y%m%d%H%M%S)"
        log_info "Backed up existing configuration"
    fi
    
    # Create new configuration
    cat > "$config_file" << 'EOF'
# Hyper-NixOS Configuration
# Generated by installer

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hyper-nixos/modules/default.nix
  ];

  # System identification
  networking.hostName = "hypervisor";
  time.timeZone = "UTC";

  # Hyper-NixOS base configuration
  hypervisor = {
    enable = true;
    
    # Enable core features (customize as needed)
    compute.enable = true;
    storage.enable = true;
    mesh.enable = false;  # Enable for multi-node
    security.capabilities.enable = true;
    backup.enable = true;
    composition.enable = true;
    monitoring.ai.enable = false;  # Enable if GPU available
    
    # Default configuration for single node
    storage.tiers = {
      fast = {
        level = 0;
        characteristics = {
          latency = "< 1ms";
          throughput = "> 1GB/s";
          iops = "> 50000";
        };
        providers = [{
          name = "local-ssd";
          type = "ssd-array";
          capacity = "1Ti";
          location = "local";
        }];
      };
    };
    
    # Basic security setup
    security.capabilities.capabilities = {
      admin = {
        description = "Administrator access";
        resources = {
          compute = {
            create = true;
            modify = true;
            delete = true;
            control = true;
            console = true;
          };
          storage = {
            read = true;
            write = true;
            allocate = true;
            snapshot = true;
          };
        };
      };
    };
  };

  # Basic system configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Networking
  networking = {
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 8081 ];
    };
  };

  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Users
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" ];
    # Add your SSH public key here
    openssh.authorizedKeys.keys = [
      # "ssh-rsa AAAAB3NzaC1... user@host"
    ];
  };

  # Allow unfree packages (needed for some components)
  nixpkgs.config.allowUnfree = true;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    tmux
    curl
    jq
  ];

  # Enable flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # This value determines the NixOS release
  system.stateVersion = "24.05";
}
EOF
    
    log_success "Base configuration created"
}

# Initialize system
initialize_system() {
    log_info "Initializing Hyper-NixOS components..."
    
    # Create required directories
    mkdir -p /var/lib/hypervisor/{compute,storage,mesh,backup,ai}
    mkdir -p /var/log/hypervisor
    
    # Set permissions
    chmod 700 /var/lib/hypervisor
    chmod 755 /var/log/hypervisor
    
    log_success "System directories created"
}

# Prompt for configuration
interactive_setup() {
    log_info "Starting interactive setup..."
    
    echo
    read -p "Enter hostname (default: hypervisor): " hostname
    hostname=${hostname:-hypervisor}
    
    read -p "Enter admin SSH public key: " ssh_key
    
    read -p "Enable clustering? (y/N): " enable_cluster
    
    read -p "Enable AI monitoring? (requires GPU) (y/N): " enable_ai
    
    # Update configuration
    sed -i "s/networking.hostName = \"hypervisor\"/networking.hostName = \"$hostname\"/" /etc/nixos/configuration.nix
    
    if [[ -n "$ssh_key" ]]; then
        sed -i "/openssh.authorizedKeys.keys = \[/a\      \"$ssh_key\"" /etc/nixos/configuration.nix
    fi
    
    if [[ "$enable_cluster" =~ ^[Yy]$ ]]; then
        sed -i "s/mesh.enable = false/mesh.enable = true/" /etc/nixos/configuration.nix
    fi
    
    if [[ "$enable_ai" =~ ^[Yy]$ ]]; then
        sed -i "s/monitoring.ai.enable = false/monitoring.ai.enable = true/" /etc/nixos/configuration.nix
    fi
    
    log_success "Configuration updated"
}

# Build and switch
build_system() {
    log_info "Building Hyper-NixOS configuration..."
    log_info "This may take several minutes on first run..."
    
    # Test build first
    if ! nixos-rebuild test; then
        log_error "Build failed. Check the configuration and try again."
        exit 1
    fi
    
    log_success "Build test passed"
    
    # Apply configuration
    log_info "Applying configuration..."
    nixos-rebuild switch
    
    log_success "Hyper-NixOS installed successfully!"
}

# Post-installation
post_install() {
    log_info "Running post-installation tasks..."
    
    # Initialize storage fabric
    if command -v hv-storage-fabric &> /dev/null; then
        hv-storage-fabric init || true
    fi
    
    # Show status
    cat << EOF

${GREEN}Installation Complete!${NC}

Next steps:
1. Review the configuration at /etc/nixos/configuration.nix
2. Check system status: systemctl status hypervisor-*
3. Access the GraphQL API at http://localhost:8081/
4. View documentation: https://github.com/yourusername/hyper-nixos

Quick commands:
- Create a compute unit: hv-compute create
- Check storage tiers: hv-storage-fabric tiers
- View AI monitoring: hv-ai status
- Manage backups: hv-backup status

For multi-node setup, see: ${INSTALL_PATH}/docs/DEPLOYMENT.md

EOF
}

# Uninstall function
uninstall() {
    log_warn "Uninstalling Hyper-NixOS..."
    
    read -p "This will remove Hyper-NixOS. Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi
    
    # Stop services
    systemctl stop hypervisor-* || true
    
    # Remove from configuration
    if [[ -f /etc/nixos/configuration.nix.bak.* ]]; then
        latest_backup=$(ls -t /etc/nixos/configuration.nix.bak.* | head -1)
        cp "$latest_backup" /etc/nixos/configuration.nix
        log_info "Restored configuration from backup"
    fi
    
    # Remove installation
    rm -rf "$INSTALL_PATH"
    rm -rf /var/lib/hypervisor
    rm -rf /var/log/hypervisor
    
    # Rebuild
    nixos-rebuild switch
    
    log_success "Hyper-NixOS uninstalled"
}

# Main installation flow
main() {
    show_banner
    
    # Parse arguments
    case "${1:-install}" in
        install)
            check_root
            check_requirements
            install_dependencies
            clone_repository
            generate_hardware_config
            create_base_config
            initialize_system
            interactive_setup
            build_system
            post_install
            ;;
        uninstall)
            check_root
            uninstall
            ;;
        update)
            check_root
            log_info "Updating Hyper-NixOS..."
            cd "$INSTALL_PATH"
            git pull origin "$BRANCH"
            nixos-rebuild switch
            log_success "Update complete"
            ;;
        *)
            echo "Usage: $0 {install|uninstall|update}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"