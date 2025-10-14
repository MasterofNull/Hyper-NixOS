#!/usr/bin/env bash
#
# Hyper-NixOS Feature Management Wizard
# Allows users to customize system features at any time
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
readonly NC='\033[0m' # No Color

# Configuration files
readonly CONFIG_FILE="/etc/nixos/configuration.nix"
readonly FEATURES_FILE="/etc/nixos/hypervisor-features.nix"
readonly BACKUP_DIR="/etc/nixos/backups"
readonly FEATURES_DB="/etc/hypervisor/features/features-database.json"

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
)

# Feature dependencies
declare -A FEATURE_DEPS=(
    ["web-dashboard"]="monitoring"
    ["ai-security"]="monitoring security-base"
    ["clustering"]="monitoring networking-advanced"
    ["desktop-kde"]="core"
    ["desktop-gnome"]="core"
)

# Tier templates
declare -A TIER_FEATURES=(
    ["minimal"]="core libvirt networking-basic"
    ["standard"]="core libvirt networking-basic monitoring security-base firewall ssh-hardening backup-basic"
    ["enhanced"]="core libvirt networking-advanced monitoring security-base firewall ssh-hardening backup-basic web-dashboard container-support storage-lvm"
    ["professional"]="core libvirt networking-advanced monitoring security-advanced firewall ssh-hardening backup-advanced web-dashboard container-support storage-lvm automation ai-security multi-host"
    ["enterprise"]="core libvirt networking-advanced monitoring security-advanced firewall ssh-hardening backup-enterprise web-dashboard container-support storage-distributed automation ai-security clustering high-availability multi-tenant"
)

# Global variables
declare -a SELECTED_FEATURES=()
declare -a AVAILABLE_FEATURES=()
declare SYSTEM_RAM=0
declare SYSTEM_CPUS=0
declare CURRENT_TIER=""

# Detect system resources
detect_system_resources() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    SYSTEM_RAM=$((mem_kb / 1024))  # Convert to MB
    SYSTEM_CPUS=$(nproc)
    
    # Detect current tier if configured
    if [[ -f "$FEATURES_FILE" ]]; then
        CURRENT_TIER=$(grep -oP 'systemTier\s*=\s*"\K[^"]+' "$FEATURES_FILE" 2>/dev/null || echo "custom")
    fi
}

# Load current features
load_current_features() {
    if [[ -f "$FEATURES_FILE" ]]; then
        # Extract enabled features from configuration
        local features=$(grep -oP 'enabledFeatures\s*=\s*\[\s*\K[^\]]+' "$FEATURES_FILE" 2>/dev/null || echo "")
        if [[ -n "$features" ]]; then
            # Parse features list
            IFS=' ' read -ra SELECTED_FEATURES <<< "$(echo "$features" | tr -d '[]"' | tr ',' ' ')"
        fi
    fi
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
║         ${BOLD}Hyper-NixOS Feature Management Wizard${NC}${CYAN}                ║
║                                                                ║
║  Customize your system features and configuration              ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
${NC}

${BOLD}System Resources:${NC}
  • RAM: ${GREEN}${SYSTEM_RAM} MB${NC}
  • CPUs: ${GREEN}${SYSTEM_CPUS} cores${NC}
  • Current Configuration: ${YELLOW}${CURRENT_TIER:-Not Set}${NC}

EOF
}

# Main menu
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
        echo "  7) Exit"
        echo
        read -r -p "Select option (1-7): " choice
        
        case $choice in
            1) tier_template_menu ;;
            2) custom_feature_menu ;;
            3) view_current_config ;;
            4) feature_information ;;
            5) export_import_menu ;;
            6) apply_configuration ;;
            7) exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Tier template menu
tier_template_menu() {
    local choice
    
    while true; do
        show_header
        echo -e "${BOLD}Select Configuration Tier:${NC}\n"
        
        echo -e "${BLUE}1) Minimal${NC} (2-4GB RAM)"
        echo "   • Core virtualization only"
        echo "   • Basic networking"
        echo "   • CLI management"
        echo
        
        echo -e "${GREEN}2) Standard${NC} (4-8GB RAM)"
        echo "   • Monitoring (Prometheus/Grafana)"
        echo "   • Security hardening"
        echo "   • Basic backup tools"
        echo
        
        echo -e "${YELLOW}3) Enhanced${NC} (8-16GB RAM)"
        echo "   • Web dashboard"
        echo "   • Advanced networking"
        echo "   • Container support"
        echo "   • LVM storage"
        echo
        
        echo -e "${MAGENTA}4) Professional${NC} (16-32GB RAM)"
        echo "   • AI/ML security"
        echo "   • Automation tools"
        echo "   • Multi-host management"
        echo "   • Advanced backup"
        echo
        
        echo -e "${RED}5) Enterprise${NC} (32GB+ RAM)"
        echo "   • High availability"
        echo "   • Clustering support"
        echo "   • Distributed storage"
        echo "   • Multi-tenant isolation"
        echo
        
        echo "6) Back to Main Menu"
        echo
        read -r -p "Select tier (1-6): " choice
        
        case $choice in
            1) load_tier_template "minimal" ;;
            2) load_tier_template "standard" ;;
            3) load_tier_template "enhanced" ;;
            4) load_tier_template "professional" ;;
            5) load_tier_template "enterprise" ;;
            6) return ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Load tier template
load_tier_template() {
    local tier=$1
    
    show_header
    echo -e "${CYAN}Loading ${BOLD}$tier${NC}${CYAN} tier template...${NC}\n"
    
    # Load features for tier
    IFS=' ' read -ra SELECTED_FEATURES <<< "${TIER_FEATURES[$tier]}"
    
    # Show what will be enabled
    echo -e "${BOLD}Features to be enabled:${NC}"
    for feature in "${SELECTED_FEATURES[@]}"; do
        echo -e "  ${GREEN}✓${NC} $feature - ${FEATURE_DESC[$feature]:-No description}"
    done
    
    # Calculate requirements
    local ram_req=$(calculate_ram_requirement)
    echo -e "\n${BOLD}Total RAM Requirement:${NC} ${ram_req} MB"
    
    if [[ $ram_req -gt $SYSTEM_RAM ]]; then
        echo -e "\n${YELLOW}⚠ Warning:${NC} This configuration requires more RAM than available!"
        echo -e "  Required: ${ram_req} MB, Available: ${SYSTEM_RAM} MB"
    fi
    
    echo -e "\n${BOLD}Customize this template?${NC}"
    echo "1) Use as-is"
    echo "2) Customize features"
    echo "3) Cancel"
    
    read -r -p "Choice (1-3): " choice
    
    case $choice in
        1) 
            CURRENT_TIER="$tier"
            echo -e "\n${GREEN}Template loaded!${NC}"
            sleep 2
            ;;
        2) 
            CURRENT_TIER="$tier-custom"
            custom_feature_menu
            ;;
        3) 
            SELECTED_FEATURES=()
            ;;
    esac
}

# Custom feature selection menu
custom_feature_menu() {
    local category
    local feature
    local page=1
    local per_page=5
    
    while true; do
        show_header
        echo -e "${BOLD}Custom Feature Selection${NC}\n"
        
        # Show categories
        echo -e "${BOLD}Categories:${NC}"
        local i=1
        for cat in "${!FEATURE_CATEGORIES[@]}"; do
            echo "  $i) ${FEATURE_CATEGORIES[$cat]}"
            ((i++))
        done
        echo "  0) Done selecting features"
        echo
        
        # Show currently selected features
        if [[ ${#SELECTED_FEATURES[@]} -gt 0 ]]; then
            echo -e "${BOLD}Selected Features:${NC}"
            for feature in "${SELECTED_FEATURES[@]}"; do
                echo -e "  ${GREEN}✓${NC} $feature"
            done
            echo
        fi
        
        read -r -p "Select category (0 to finish): " choice
        
        if [[ "$choice" == "0" ]]; then
            break
        fi
        
        # Convert choice to category
        local i=1
        for cat in "${!FEATURE_CATEGORIES[@]}"; do
            if [[ "$i" == "$choice" ]]; then
                select_features_in_category "$cat"
                break
            fi
            ((i++))
        done
    done
}

# Select features within a category
select_features_in_category() {
    local category=$1
    
    while true; do
        show_header
        echo -e "${BOLD}${FEATURE_CATEGORIES[$category]} Features:${NC}\n"
        
        # List features in category (this would be populated from actual feature list)
        case $category in
            "core")
                show_feature_toggle "core" "Essential system components"
                show_feature_toggle "cli-tools" "Command-line management tools"
                ;;
            "virtualization")
                show_feature_toggle "libvirt" "LibVirt VM management"
                show_feature_toggle "qemu-kvm" "QEMU/KVM hypervisor"
                show_feature_toggle "virt-manager" "Virt-Manager GUI (requires desktop)"
                ;;
            "networking")
                show_feature_toggle "networking-basic" "NAT networking"
                show_feature_toggle "networking-advanced" "Bridges, VLANs, OVS"
                show_feature_toggle "firewall" "NFTables firewall"
                show_feature_toggle "network-isolation" "Network segregation"
                ;;
            "storage")
                show_feature_toggle "storage-basic" "Basic file storage"
                show_feature_toggle "storage-lvm" "LVM volume management"
                show_feature_toggle "storage-zfs" "ZFS advanced filesystem"
                show_feature_toggle "storage-distributed" "Ceph/GlusterFS"
                ;;
            "security")
                show_feature_toggle "security-base" "Basic hardening"
                show_feature_toggle "ssh-hardening" "SSH security"
                show_feature_toggle "audit-logging" "Audit trail"
                show_feature_toggle "ai-security" "AI/ML threat detection"
                show_feature_toggle "compliance" "Compliance tools"
                ;;
            "monitoring")
                show_feature_toggle "monitoring" "Prometheus + Grafana"
                show_feature_toggle "logging" "Centralized logging"
                show_feature_toggle "alerting" "Alert manager"
                show_feature_toggle "tracing" "Distributed tracing"
                ;;
            "automation")
                show_feature_toggle "automation" "Ansible integration"
                show_feature_toggle "terraform" "Terraform support"
                show_feature_toggle "ci-cd" "CI/CD pipelines"
                show_feature_toggle "orchestration" "Kubernetes operator"
                ;;
            "desktop")
                show_feature_toggle "desktop-kde" "KDE Plasma desktop"
                show_feature_toggle "desktop-gnome" "GNOME desktop"
                show_feature_toggle "desktop-xfce" "XFCE lightweight desktop"
                ;;
            "enterprise")
                show_feature_toggle "clustering" "HA clustering"
                show_feature_toggle "high-availability" "Automatic failover"
                show_feature_toggle "multi-tenant" "Tenant isolation"
                show_feature_toggle "federation" "Identity federation"
                ;;
        esac
        
        echo
        echo "0) Back to categories"
        echo
        read -r -p "Toggle feature or go back (0): " choice
        
        if [[ "$choice" == "0" ]]; then
            break
        fi
    done
}

# Show feature with toggle status
show_feature_toggle() {
    local feature=$1
    local description=$2
    local status="${RED}✗${NC}"
    local ram_info=""
    
    # Check if feature is selected
    if [[ " ${SELECTED_FEATURES[@]} " =~ " ${feature} " ]]; then
        status="${GREEN}✓${NC}"
    fi
    
    # Show RAM requirement if available
    if [[ -n "${FEATURE_RAM[$feature]:-}" ]]; then
        ram_info=" ${DIM}(${FEATURE_RAM[$feature]} MB RAM)${NC}"
    fi
    
    echo -e "  $status $feature - $description$ram_info"
}

# View current configuration
view_current_config() {
    show_header
    echo -e "${BOLD}Current Configuration:${NC}\n"
    
    if [[ ${#SELECTED_FEATURES[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No features selected yet.${NC}"
    else
        echo -e "${BOLD}Selected Features:${NC}"
        for feature in "${SELECTED_FEATURES[@]}"; do
            local desc="${FEATURE_DESC[$feature]:-No description}"
            local ram="${FEATURE_RAM[$feature]:-0}"
            echo -e "  ${GREEN}✓${NC} $feature"
            echo -e "    ${DIM}$desc (${ram} MB RAM)${NC}"
        done
        
        echo -e "\n${BOLD}Resource Requirements:${NC}"
        local total_ram=$(calculate_ram_requirement)
        echo -e "  Total RAM: ${total_ram} MB"
        echo -e "  Available: ${SYSTEM_RAM} MB"
        
        if [[ $total_ram -gt $SYSTEM_RAM ]]; then
            echo -e "  ${RED}⚠ WARNING: Insufficient RAM!${NC}"
        else
            echo -e "  ${GREEN}✓ Requirements met${NC}"
        fi
    fi
    
    echo -e "\nPress Enter to continue..."
    read -r
}

# Feature information browser
feature_information() {
    while true; do
        show_header
        echo -e "${BOLD}Feature Information:${NC}\n"
        
        echo "1) View all features"
        echo "2) View by category"
        echo "3) View dependencies"
        echo "4) View resource requirements"
        echo "5) Back to main menu"
        echo
        
        read -r -p "Select option (1-5): " choice
        
        case $choice in
            1) view_all_features ;;
            2) view_features_by_category ;;
            3) view_dependencies ;;
            4) view_resource_requirements ;;
            5) return ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# View all features
view_all_features() {
    show_header
    echo -e "${BOLD}All Available Features:${NC}\n"
    
    for feature in "${!FEATURE_DESC[@]}"; do
        echo -e "${BOLD}$feature${NC}"
        echo -e "  Description: ${FEATURE_DESC[$feature]}"
        if [[ -n "${FEATURE_RAM[$feature]:-}" ]]; then
            echo -e "  RAM Required: ${FEATURE_RAM[$feature]} MB"
        fi
        if [[ -n "${FEATURE_DEPS[$feature]:-}" ]]; then
            echo -e "  Dependencies: ${FEATURE_DEPS[$feature]}"
        fi
        echo
    done
    
    echo "Press Enter to continue..."
    read -r
}

# Generate feature configuration
generate_feature_config() {
    cat > "$FEATURES_FILE" << EOF
# Hyper-NixOS Feature Configuration
# Generated by Feature Management Wizard on $(date)
# Configuration Tier: ${CURRENT_TIER:-custom}

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
  };
  
  # Feature-specific configurations
$(generate_feature_configs)
}
EOF
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
        esac
    done
}

# Apply configuration
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
    
    # Generate new configuration
    echo -e "${BLUE}Generating configuration...${NC}"
    generate_feature_config
    
    # Update main configuration to import features
    if ! grep -q "$FEATURES_FILE" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${BLUE}Updating main configuration...${NC}"
        # Add import to configuration.nix
        sed -i "/imports = \[/a\    $FEATURES_FILE" "$CONFIG_FILE"
    fi
    
    # Test configuration
    echo -e "\n${BLUE}Testing configuration...${NC}"
    if nixos-rebuild dry-build; then
        echo -e "${GREEN}✓ Configuration is valid${NC}"
        
        echo -e "\n${BOLD}Ready to apply. This will rebuild your system.${NC}"
        echo "1) Apply now (nixos-rebuild switch)"
        echo "2) Apply on next boot (nixos-rebuild boot)"
        echo "3) Test in VM first (nixos-rebuild build-vm)"
        echo "4) Cancel"
        
        read -r -p "Choice (1-4): " rebuild_choice
        
        case $rebuild_choice in
            1)
                echo -e "\n${BLUE}Applying configuration...${NC}"
                if sudo nixos-rebuild switch; then
                    echo -e "\n${GREEN}✓ Configuration applied successfully!${NC}"
                    echo "Your system has been reconfigured with the selected features."
                else
                    echo -e "\n${RED}✗ Configuration failed!${NC}"
                    echo "Check the error messages above."
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
                echo "Configuration cancelled."
                ;;
        esac
    else
        echo -e "${RED}✗ Configuration test failed!${NC}"
        echo "Please check the error messages above."
        echo -e "\n${YELLOW}Restoring backup...${NC}"
        cp "$backup_name.nix" "$CONFIG_FILE" 2>/dev/null || true
        if [[ -f "$backup_name-features.nix" ]]; then
            cp "$backup_name-features.nix" "$FEATURES_FILE"
        fi
    fi
    
    echo -e "\nPress Enter to continue..."
    read -r
}

# Export/Import menu
export_import_menu() {
    while true; do
        show_header
        echo -e "${BOLD}Export/Import Configuration:${NC}\n"
        
        echo "1) Export current configuration"
        echo "2) Import configuration from file"
        echo "3) Share configuration (generate code)"
        echo "4) Load shared configuration"
        echo "5) Back to main menu"
        echo
        
        read -r -p "Select option (1-5): " choice
        
        case $choice in
            1) export_configuration ;;
            2) import_configuration ;;
            3) share_configuration ;;
            4) load_shared_configuration ;;
            5) return ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Export configuration
export_configuration() {
    show_header
    echo -e "${BOLD}Export Configuration${NC}\n"
    
    local export_file="$HOME/hypervisor-config-$(date +%Y%m%d-%H%M%S).json"
    
    # Create JSON export
    cat > "$export_file" << EOF
{
  "version": "1.0",
  "date": "$(date -Iseconds)",
  "tier": "${CURRENT_TIER:-custom}",
  "system": {
    "ram": $SYSTEM_RAM,
    "cpus": $SYSTEM_CPUS
  },
  "features": [
$(for i in "${!SELECTED_FEATURES[@]}"; do
    if [[ $i -eq $((${#SELECTED_FEATURES[@]} - 1)) ]]; then
        echo "    \"${SELECTED_FEATURES[$i]}\""
    else
        echo "    \"${SELECTED_FEATURES[$i]}\","
    fi
done)
  ]
}
EOF
    
    echo -e "${GREEN}✓ Configuration exported to:${NC}"
    echo "  $export_file"
    echo
    echo "You can share this file or import it on another system."
    echo
    echo "Press Enter to continue..."
    read -r
}

# Main execution
main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}Note: Running as root. Configuration will affect system-wide settings.${NC}"
    else
        echo -e "${YELLOW}Note: Running as user. You'll need sudo for system changes.${NC}"
    fi
    
    # Detect system resources
    detect_system_resources
    
    # Load current configuration
    load_current_features
    
    # Start main menu
    show_main_menu
}

# Run main function
main "$@"