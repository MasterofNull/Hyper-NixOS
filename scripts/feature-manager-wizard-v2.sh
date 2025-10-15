#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Feature Management Wizard v2
# Enhanced with incompatibility detection and automatic testing
#

set -euo pipefail

# Colors for UI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly STRIKE='\033[9m'
readonly NC='\033[0m' # No Color

# Configuration files
readonly CONFIG_FILE="/etc/nixos/configuration/configuration.nix"
readonly FEATURES_FILE="/etc/nixos/hypervisor-features.nix"
readonly BACKUP_DIR="/etc/nixos/backups"
readonly FEATURES_DB="/etc/hypervisor/features/features-database.json"
readonly LOG_FILE="/var/log/hypervisor/feature-manager.log"

# System capabilities detection
declare -A SYSTEM_CAPABILITIES
declare -A INCOMPATIBILITY_REASONS

# Feature categories
declare -A FEATURE_CATEGORIES=(
    ["core"]="Core System"
    ["virtualization"]="Virtualization"
    ["networking"]="Networking"
    ["storage"]="Storage Management"
    ["security"]="Security"
    ["monitoring"]="Monitoring & Metrics"
    ["automation"]="Automation"
    ["desktop"]="Desktop Environment"
    ["development"]="Development Tools"
    ["enterprise"]="Enterprise Features"
)

# Feature requirements (RAM in MB)
declare -A FEATURE_RAM=(
    ["core"]=512
    ["libvirt"]=256
    ["monitoring"]=1024
    ["security-base"]=512
    ["desktop-kde"]=2048
    ["desktop-gnome"]=2048
    ["ai-security"]=4096
    ["clustering"]=8192
    ["web-dashboard"]=512
    ["container-support"]=1024
    ["storage-zfs"]=1024
    ["virt-manager"]=512
)

# Feature CPU requirements
declare -A FEATURE_CPU=(
    ["ai-security"]=4
    ["clustering"]=8
    ["high-availability"]=4
    ["enterprise"]=8
)

# Feature hardware requirements
declare -A FEATURE_HARDWARE=(
    ["qemu-kvm"]="cpu_virt"
    ["ai-security"]="cpu_avx"
    ["storage-zfs"]="ram_ecc"
    ["clustering"]="network_multi"
    ["gpu-passthrough"]="gpu_iommu"
)

# Feature descriptions
declare -A FEATURE_DESC=(
    ["core"]="Essential system components and CLI tools"
    ["libvirt"]="VM management with QEMU/KVM"
    ["monitoring"]="Prometheus + Grafana monitoring stack"
    ["security-base"]="Basic security hardening and firewall"
    ["security-advanced"]="AI/ML threat detection and response"
    ["desktop-kde"]="KDE Plasma desktop environment"
    ["desktop-gnome"]="GNOME desktop environment"
    ["web-dashboard"]="Web-based management interface"
    ["container-support"]="Podman/Docker container runtime"
    ["automation"]="Ansible and automation tools"
    ["clustering"]="High availability clustering support"
    ["backup-advanced"]="Enterprise backup solutions"
    ["storage-zfs"]="ZFS advanced filesystem"
    ["gpu-passthrough"]="GPU passthrough for VMs"
)

# Feature dependencies
declare -A FEATURE_DEPS=(
    ["web-dashboard"]="monitoring"
    ["ai-security"]="monitoring security-base"
    ["clustering"]="monitoring networking-advanced"
    ["desktop-kde"]="core"
    ["desktop-gnome"]="core"
    ["virt-manager"]="libvirt"
    ["gpu-passthrough"]="libvirt"
)

# Feature conflicts
declare -A FEATURE_CONFLICTS=(
    ["desktop-kde"]="desktop-gnome desktop-xfce"
    ["desktop-gnome"]="desktop-kde desktop-xfce"
    ["desktop-xfce"]="desktop-kde desktop-gnome"
)

# Global variables
declare -a SELECTED_FEATURES=()
declare -a AVAILABLE_FEATURES=()
declare SYSTEM_RAM=0
declare SYSTEM_CPUS=0
declare CURRENT_TIER=""
declare AUTO_TEST=true
declare AUTO_SWITCH=true

# Initialize logging
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Feature Manager started" >> "$LOG_FILE"
}

# Log message
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Detect system capabilities
detect_system_capabilities() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    SYSTEM_RAM=$((mem_kb / 1024))  # Convert to MB
    SYSTEM_CPUS=$(nproc)
    
    # Check CPU virtualization
    if grep -q -E '(vmx|svm)' /proc/cpuinfo; then
        SYSTEM_CAPABILITIES["cpu_virt"]="true"
    else
        SYSTEM_CAPABILITIES["cpu_virt"]="false"
        INCOMPATIBILITY_REASONS["cpu_virt"]="CPU virtualization (VT-x/AMD-V) not available"
    fi
    
    # Check AVX support for AI
    if grep -q avx /proc/cpuinfo; then
        SYSTEM_CAPABILITIES["cpu_avx"]="true"
    else
        SYSTEM_CAPABILITIES["cpu_avx"]="false"
        INCOMPATIBILITY_REASONS["cpu_avx"]="CPU AVX instructions not supported (required for AI/ML)"
    fi
    
    # Check ECC RAM (simplified check)
    if dmidecode -t memory 2>/dev/null | grep -q "Error Correction Type: Multi-bit ECC"; then
        SYSTEM_CAPABILITIES["ram_ecc"]="true"
    else
        SYSTEM_CAPABILITIES["ram_ecc"]="false"
        INCOMPATIBILITY_REASONS["ram_ecc"]="ECC RAM not detected (recommended for ZFS)"
    fi
    
    # Check multiple network interfaces
    local nic_count=$(ip link show | grep -c "^[0-9]" || echo 1)
    if [[ $nic_count -gt 2 ]]; then
        SYSTEM_CAPABILITIES["network_multi"]="true"
    else
        SYSTEM_CAPABILITIES["network_multi"]="false"
        INCOMPATIBILITY_REASONS["network_multi"]="Multiple network interfaces required for clustering"
    fi
    
    # Check IOMMU for GPU passthrough
    if [[ -d /sys/kernel/iommu_groups ]] && [[ $(ls /sys/kernel/iommu_groups | wc -l) -gt 0 ]]; then
        SYSTEM_CAPABILITIES["gpu_iommu"]="true"
    else
        SYSTEM_CAPABILITIES["gpu_iommu"]="false"
        INCOMPATIBILITY_REASONS["gpu_iommu"]="IOMMU not enabled (required for GPU passthrough)"
    fi
    
    # Check disk space
    local disk_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    SYSTEM_CAPABILITIES["disk_space"]="$disk_gb"
    
    # Current tier detection
    if [[ -f "$FEATURES_FILE" ]]; then
        CURRENT_TIER=$(grep -oP 'systemTier\s*=\s*"\K[^"]+' "$FEATURES_FILE" 2>/dev/null || echo "custom")
    fi
    
    log_message "System capabilities detected: RAM=$SYSTEM_RAM MB, CPUs=$SYSTEM_CPUS, Virt=${SYSTEM_CAPABILITIES[cpu_virt]}"
}

# Check if feature is compatible
is_feature_compatible() {
    local feature=$1
    local reason=""
    
    # Check RAM requirement
    if [[ -n "${FEATURE_RAM[$feature]:-}" ]]; then
        local total_ram=$(calculate_ram_requirement)
        local feature_ram=${FEATURE_RAM[$feature]}
        if [[ $((total_ram + feature_ram)) -gt $SYSTEM_RAM ]]; then
            reason="Insufficient RAM: requires ${feature_ram}MB, would exceed system capacity"
            echo "$reason"
            return 1
        fi
    fi
    
    # Check CPU requirement
    if [[ -n "${FEATURE_CPU[$feature]:-}" ]]; then
        if [[ ${FEATURE_CPU[$feature]} -gt $SYSTEM_CPUS ]]; then
            reason="Insufficient CPUs: requires ${FEATURE_CPU[$feature]}, have $SYSTEM_CPUS"
            echo "$reason"
            return 1
        fi
    fi
    
    # Check hardware requirements
    if [[ -n "${FEATURE_HARDWARE[$feature]:-}" ]]; then
        local hw_req="${FEATURE_HARDWARE[$feature]}"
        if [[ "${SYSTEM_CAPABILITIES[$hw_req]}" == "false" ]]; then
            reason="${INCOMPATIBILITY_REASONS[$hw_req]}"
            echo "$reason"
            return 1
        fi
    fi
    
    # Check dependencies
    if [[ -n "${FEATURE_DEPS[$feature]:-}" ]]; then
        for dep in ${FEATURE_DEPS[$feature]}; do
            if [[ ! " ${SELECTED_FEATURES[@]} " =~ " ${dep} " ]]; then
                reason="Missing dependency: $dep must be enabled first"
                echo "$reason"
                return 1
            fi
        done
    fi
    
    # Check conflicts
    if [[ -n "${FEATURE_CONFLICTS[$feature]:-}" ]]; then
        for conflict in ${FEATURE_CONFLICTS[$feature]}; do
            if [[ " ${SELECTED_FEATURES[@]} " =~ " ${conflict} " ]]; then
                reason="Conflicts with already selected: $conflict"
                echo "$reason"
                return 1
            fi
        done
    fi
    
    return 0
}

# Calculate total RAM requirement
calculate_ram_requirement() {
    local total=0
    for feature in "${SELECTED_FEATURES[@]}"; do
        if [[ -n "${FEATURE_RAM[$feature]:-}" ]]; then
            total=$((total + FEATURE_RAM[$feature]))
        fi
    done
    echo "$total"
}

# Show header
show_header() {
    clear
    cat << EOF
${CYAN}
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║         ${BOLD}Hyper-NixOS Feature Management Wizard v2${NC}${CYAN}             ║
║                                                                ║
║  Enhanced with compatibility checking and auto-testing         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
${NC}

${BOLD}System Resources:${NC}
  • RAM: ${GREEN}${SYSTEM_RAM} MB${NC}
  • CPUs: ${GREEN}${SYSTEM_CPUS} cores${NC}
  • Disk: ${GREEN}${SYSTEM_CAPABILITIES[disk_space]} GB free${NC}
  • Current Configuration: ${YELLOW}${CURRENT_TIER:-Not Set}${NC}
  • Auto-test: ${AUTO_TEST && echo "${GREEN}Enabled${NC}" || echo "${YELLOW}Disabled${NC}"}
  • Auto-switch: ${AUTO_SWITCH && echo "${GREEN}Enabled${NC}" || echo "${YELLOW}Disabled${NC}"}

EOF
}

# Show feature toggle with compatibility
show_feature_toggle_v2() {
    local feature=$1
    local description=$2
    local status="${RED}✗${NC}"
    local ram_info=""
    local selectable=true
    local display_text=""
    
    # Check if feature is selected
    if [[ " ${SELECTED_FEATURES[@]} " =~ " ${feature} " ]]; then
        status="${GREEN}✓${NC}"
    fi
    
    # Check compatibility
    local compat_reason
    if ! compat_reason=$(is_feature_compatible "$feature"); then
        selectable=false
        status="${DIM}✗${NC}"
    fi
    
    # Show RAM requirement if available
    if [[ -n "${FEATURE_RAM[$feature]:-}" ]]; then
        ram_info=" ${DIM}(${FEATURE_RAM[$feature]} MB RAM)${NC}"
    fi
    
    # Format display
    if [[ $selectable == true ]]; then
        display_text="  $status $feature - $description$ram_info"
    else
        display_text="  $status ${DIM}${STRIKE}$feature${NC} - ${DIM}$description$ram_info${NC}"
        display_text+="\n      ${RED}└─ $compat_reason${NC}"
    fi
    
    echo -e "$display_text"
    
    # Store selectability for menu handling
    FEATURE_SELECTABILITY["$feature"]=$selectable
}

# Generate feature configuration
generate_feature_config() {
    log_message "Generating feature configuration for: ${SELECTED_FEATURES[*]}"
    
    cat > "$FEATURES_FILE" << EOF
# Hyper-NixOS Feature Configuration
# Generated by Feature Management Wizard v2 on $(date)
# Configuration Tier: ${CURRENT_TIER:-custom}
#
# This file is automatically generated and managed by the feature wizard.
# Manual edits may be overwritten. Use the feature manager to make changes.

{ config, lib, pkgs, ... }:

{
  # System tier
  hypervisor.systemTier = "${CURRENT_TIER:-custom}";
  
  # Enabled features
  hypervisor.featureManager = {
    enable = true;
    enabledFeatures = [
$(for feature in "${SELECTED_FEATURES[@]}"; do
    echo "      \"$feature\""
done)
    ];
    
    # Feature-specific settings
    settings = {
$(generate_feature_settings)
    };
  };
  
  # Feature-specific configurations
$(generate_feature_configs)
}
EOF
}

# Generate feature-specific settings
generate_feature_settings() {
    for feature in "${SELECTED_FEATURES[@]}"; do
        case $feature in
            "ai-security")
                cat << EOF
      ai-security = {
        sensitivity = "balanced";
        updateInterval = "6h";
        autoResponse = true;
      };
EOF
                ;;
            "monitoring")
                cat << EOF
      monitoring = {
        retention = 30;
        scrapeInterval = "15s";
        alerting = true;
      };
EOF
                ;;
            "clustering")
                cat << EOF
      clustering = {
        autoFailover = true;
        quorumSize = 2;
        fencingEnabled = true;
      };
EOF
                ;;
        esac
    done
}

# Generate feature-specific configurations
generate_feature_configs() {
    for feature in "${SELECTED_FEATURES[@]}"; do
        case $feature in
            "desktop-kde")
                cat << EOF
  
  # KDE Desktop
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
  };
EOF
                ;;
            "desktop-gnome")
                cat << EOF
  
  # GNOME Desktop
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };
EOF
                ;;
            "monitoring")
                cat << EOF
  
  # Monitoring Stack
  services.prometheus = {
    enable = true;
    port = 9090;
  };
  
  services.grafana = {
    enable = true;
    port = 3000;
  };
EOF
                ;;
            "web-dashboard")
                cat << EOF
  
  # Web Dashboard
  hypervisor.web = {
    enable = true;
    port = 8080;
    ssl = true;
  };
EOF
                ;;
            "container-support")
                cat << EOF
  
  # Container Support
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
EOF
                ;;
            "storage-zfs")
                cat << EOF
  
  # ZFS Support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = true;
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };
EOF
                ;;
        esac
    done
}

# Test configuration
test_configuration() {
    echo -e "\n${BLUE}Testing configuration...${NC}"
    log_message "Testing configuration with nixos-rebuild dry-build"
    
    # Create a test marker
    local test_marker="/tmp/.nixos-test-$$"
    
    # Run dry build with detailed output
    if nixos-rebuild dry-build 2>&1 | tee "$test_marker"; then
        echo -e "${GREEN}✓ Configuration is valid${NC}"
        log_message "Configuration test passed"
        rm -f "$test_marker"
        return 0
    else
        echo -e "${RED}✗ Configuration test failed!${NC}"
        log_message "Configuration test failed"
        
        # Parse common errors
        if grep -q "undefined variable" "$test_marker"; then
            echo -e "${YELLOW}Hint: Check for missing module imports${NC}"
        elif grep -q "collision between" "$test_marker"; then
            echo -e "${YELLOW}Hint: Package conflicts detected${NC}"
        elif grep -q "assertion" "$test_marker"; then
            echo -e "${YELLOW}Hint: A system assertion failed${NC}"
        fi
        
        rm -f "$test_marker"
        return 1
    fi
}

# Apply configuration with automatic testing
apply_configuration() {
    show_header
    echo -e "${BOLD}Apply Configuration${NC}\n"
    
    if [[ ${#SELECTED_FEATURES[@]} -eq 0 ]]; then
        echo -e "${RED}No features selected!${NC}"
        echo "Please select features first."
        sleep 3
        return
    fi
    
    # Show what will be done
    echo "The following changes will be applied:"
    echo -e "\n${BOLD}Features to enable:${NC}"
    for feature in "${SELECTED_FEATURES[@]}"; do
        echo -e "  ${GREEN}+${NC} $feature"
    done
    
    # Check requirements
    local total_ram=$(calculate_ram_requirement)
    echo -e "\n${BOLD}Resource Check:${NC}"
    echo "  Required RAM: $total_ram MB"
    echo "  Available RAM: $SYSTEM_RAM MB"
    
    if [[ $total_ram -gt $SYSTEM_RAM ]]; then
        echo -e "\n${RED}⚠ WARNING: System does not meet RAM requirements!${NC}"
        echo "Continue anyway? (not recommended)"
    else
        echo -e "\n${GREEN}✓ System meets all requirements${NC}"
    fi
    
    echo
    read -r -p "Apply this configuration? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Configuration cancelled."
        sleep 2
        return
    fi
    
    # Backup current configuration
    echo -e "\n${BLUE}Creating backup...${NC}"
    mkdir -p "$BACKUP_DIR"
    local backup_name="$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG_FILE" "$backup_name.nix" 2>/dev/null || true
    cp "$FEATURES_FILE" "$backup_name-features.nix" 2>/dev/null || true
    log_message "Backup created: $backup_name"
    
    # Generate new configuration
    echo -e "${BLUE}Generating configuration...${NC}"
    generate_feature_config
    
    # Update main configuration to import features
    if ! grep -q "$FEATURES_FILE" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${BLUE}Updating main configuration...${NC}"
        # Add import to configuration.nix
        sed -i "/imports = \[/a\    $FEATURES_FILE" "$CONFIG_FILE"
    fi
    
    # Auto-test if enabled
    if [[ $AUTO_TEST == true ]]; then
        if ! test_configuration; then
            echo -e "\n${RED}Configuration test failed!${NC}"
            echo "Would you like to:"
            echo "1) View the full error log"
            echo "2) Restore backup and abort"
            echo "3) Continue anyway (not recommended)"
            
            read -r -p "Choice (1-3): " error_choice
            
            case $error_choice in
                1)
                    less "$LOG_FILE"
                    echo -e "\nPress Enter to continue..."
                    read -r
                    return
                    ;;
                2)
                    echo -e "\n${YELLOW}Restoring backup...${NC}"
                    cp "$backup_name.nix" "$CONFIG_FILE" 2>/dev/null || true
                    if [[ -f "$backup_name-features.nix" ]]; then
                        cp "$backup_name-features.nix" "$FEATURES_FILE"
                    fi
                    echo -e "${GREEN}Backup restored${NC}"
                    return
                    ;;
                3)
                    echo -e "${YELLOW}Proceeding despite test failure...${NC}"
                    ;;
            esac
        fi
    fi
    
    # Apply configuration
    if [[ $AUTO_SWITCH == true ]]; then
        echo -e "\n${BLUE}Applying configuration automatically...${NC}"
        log_message "Auto-switching to new configuration"
        
        # Show progress
        echo -e "${DIM}This may take several minutes...${NC}"
        
        if sudo nixos-rebuild switch --show-trace 2>&1 | tee -a "$LOG_FILE"; then
            echo -e "\n${GREEN}✓ Configuration applied successfully!${NC}"
            echo "Your system has been reconfigured with the selected features."
            log_message "Configuration switch successful"
            
            # Show post-apply information
            echo -e "\n${BOLD}Next Steps:${NC}"
            echo "• New features are now active"
            echo "• Check service status: systemctl status"
            echo "• View logs: journalctl -f"
            echo "• Access web dashboard (if enabled): https://localhost:8080"
            
        else
            echo -e "\n${RED}✗ Configuration switch failed!${NC}"
            log_message "Configuration switch failed"
            echo "Check the error messages above."
            echo -e "\n${YELLOW}You can restore the backup with:${NC}"
            echo "  sudo cp $backup_name.nix $CONFIG_FILE"
            echo "  sudo cp $backup_name-features.nix $FEATURES_FILE"
            echo "  sudo nixos-rebuild switch"
        fi
    else
        echo -e "\n${BOLD}Ready to apply. Choose an option:${NC}"
        echo "1) Apply now (nixos-rebuild switch)"
        echo "2) Apply on next boot (nixos-rebuild boot)"
        echo "3) Test in VM first (nixos-rebuild build-vm)"
        echo "4) Manual apply later"
        
        read -r -p "Choice (1-4): " rebuild_choice
        
        case $rebuild_choice in
            1)
                echo -e "\n${BLUE}Applying configuration...${NC}"
                if sudo nixos-rebuild switch; then
                    echo -e "\n${GREEN}✓ Configuration applied successfully!${NC}"
                else
                    echo -e "\n${RED}✗ Configuration failed!${NC}"
                fi
                ;;
            2)
                echo -e "\n${BLUE}Applying configuration for next boot...${NC}"
                if sudo nixos-rebuild boot; then
                    echo -e "\n${GREEN}✓ Configuration will be applied on next boot!${NC}"
                else
                    echo -e "\n${RED}✗ Configuration failed!${NC}"
                fi
                ;;
            3)
                echo -e "\n${BLUE}Building VM for testing...${NC}"
                if nixos-rebuild build-vm; then
                    echo -e "\n${GREEN}✓ VM built successfully!${NC}"
                    echo "Run ./result/bin/run-*-vm to test"
                else
                    echo -e "\n${RED}✗ VM build failed!${NC}"
                fi
                ;;
            4)
                echo -e "\n${GREEN}Configuration saved.${NC}"
                echo "To apply manually, run: sudo nixos-rebuild switch"
                ;;
        esac
    fi
    
    echo -e "\nPress Enter to continue..."
    read -r
}

# Settings menu
settings_menu() {
    while true; do
        show_header
        echo -e "${BOLD}Settings:${NC}\n"
        
        echo "1) Auto-test before applying: $([ $AUTO_TEST == true ] && echo "${GREEN}Enabled${NC}" || echo "${RED}Disabled${NC}")"
        echo "2) Auto-switch after testing: $([ $AUTO_SWITCH == true ] && echo "${GREEN}Enabled${NC}" || echo "${RED}Disabled${NC}")"
        echo "3) View current log file"
        echo "4) Clear feature selection"
        echo "5) Reset to defaults"
        echo "6) Back to main menu"
        echo
        
        read -r -p "Select option (1-6): " choice
        
        case $choice in
            1)
                AUTO_TEST=$([ $AUTO_TEST == true ] && echo false || echo true)
                echo -e "${GREEN}Auto-test $([ $AUTO_TEST == true ] && echo "enabled" || echo "disabled")${NC}"
                sleep 1
                ;;
            2)
                AUTO_SWITCH=$([ $AUTO_SWITCH == true ] && echo false || echo true)
                echo -e "${GREEN}Auto-switch $([ $AUTO_SWITCH == true ] && echo "enabled" || echo "disabled")${NC}"
                sleep 1
                ;;
            3)
                less "$LOG_FILE"
                ;;
            4)
                SELECTED_FEATURES=()
                echo -e "${GREEN}Feature selection cleared${NC}"
                sleep 1
                ;;
            5)
                AUTO_TEST=true
                AUTO_SWITCH=true
                SELECTED_FEATURES=()
                echo -e "${GREEN}Settings reset to defaults${NC}"
                sleep 1
                ;;
            6)
                return
                ;;
        esac
    done
}

# Main menu with settings
show_main_menu() {
    local choice
    
    while true; do
        show_header
        echo -e "${BOLD}Main Menu:${NC}\n"
        echo "  1) Quick Setup - Use Tier Template"
        echo "  2) Custom Setup - Select Individual Features"
        echo "  3) View Current Configuration"
        echo "  4) Feature Information"
        echo "  5) Export/Import Configuration"
        echo "  6) Apply Configuration"
        echo "  7) Settings"
        echo "  8) Exit"
        echo
        read -r -p "Select option (1-8): " choice
        
        case $choice in
            1) tier_template_menu ;;
            2) custom_feature_menu ;;
            3) view_current_config ;;
            4) feature_information ;;
            5) export_import_menu ;;
            6) apply_configuration ;;
            7) settings_menu ;;
            8) 
                log_message "Feature Manager exited normally"
                exit 0 
                ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Main execution
main() {
    # Initialize
    init_logging
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}Note: Running as root. Configuration will affect system-wide settings.${NC}"
    else
        echo -e "${YELLOW}Note: Running as user. You'll need sudo for system changes.${NC}"
    fi
    
    # Detect system capabilities
    detect_system_capabilities
    
    # Load current configuration
    load_current_features
    
    # Start main menu
    show_main_menu
}

# Feature selectability tracking
declare -A FEATURE_SELECTABILITY

# Run main function
main "$@"