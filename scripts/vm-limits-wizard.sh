#!/usr/bin/env bash
#
# VM Limits Configuration Wizard
# Interactive wizard for configuring VM creation and resource limits
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under MIT License

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration paths
readonly CONFIG_FILE="/etc/nixos/configuration.nix"
readonly PRESETS_FILE="/home/hyperd/Documents/Hyper-NixOS/templates/vm-limits-presets.nix"
readonly OUTPUT_FILE="/tmp/vm-limits-config.nix"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Helper functions
print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${BOLD}VM Limits Configuration Wizard${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BLUE}▸ $1${NC}"
    echo -e "${BLUE}$(printf '─%.0s' {1..60})${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Show preset descriptions
show_presets() {
    print_header
    print_section "Available VM Limits Presets"
    echo ""
    echo -e "${BOLD}1) Personal Workstation${NC}"
    echo "   → Single user, development and testing"
    echo "   → Max VMs: 20 (10 running) | Storage: 1TB | Per hour: 5"
    echo ""
    echo -e "${BOLD}2) Small Team Server${NC}"
    echo "   → 3-5 users, shared development environment"
    echo "   → Max VMs: 50 (25 running) | Storage: 2TB | Per hour: 10"
    echo "   → Per-user: 15 VMs (8 running)"
    echo ""
    echo -e "${BOLD}3) Medium Organization${NC}"
    echo "   → 10-20 users, departmental server"
    echo "   → Max VMs: 100 (50 running) | Storage: 5TB | Per hour: 15"
    echo "   → Per-user: 20 VMs (10 running)"
    echo ""
    echo -e "${BOLD}4) Large Enterprise${NC}"
    echo "   → 50+ users, production environment"
    echo "   → Max VMs: 500 (250 running) | Storage: 20TB | Per hour: 30"
    echo "   → Per-user: 30 VMs (15 running)"
    echo ""
    echo -e "${BOLD}5) Cloud/Hosting Provider${NC}"
    echo "   → Multi-tenant hosting, strict resource control"
    echo "   → Max VMs: 1000 (500 running) | Storage: 50TB | Per hour: 50"
    echo "   → Per-user: 50 VMs (25 running)"
    echo ""
    echo -e "${BOLD}6) Education/Training Lab${NC}"
    echo "   → Many users, temporary VMs, frequent turnover"
    echo "   → Max VMs: 200 (100 running) | Storage: 3TB | Per hour: 25"
    echo "   → Per-user: 10 VMs (5 running)"
    echo ""
    echo -e "${BOLD}7) Testing/CI Environment${NC}"
    echo "   → Automated testing, high VM churn"
    echo "   → Max VMs: 150 (75 running) | Storage: 4TB | Per hour: 50"
    echo "   → Per-user: 50 VMs (25 running) | Warning mode only"
    echo ""
    echo -e "${BOLD}8) Minimal/Resource-Constrained${NC}"
    echo "   → Low-end hardware, single user"
    echo "   → Max VMs: 10 (5 running) | Storage: 500GB | Per hour: 3"
    echo ""
    echo -e "${BOLD}9) Custom Configuration${NC}"
    echo "   → Manually configure all limits"
    echo ""
}

# Get user choice for preset
select_preset() {
    local choice
    while true; do
        show_presets
        echo -ne "${GREEN}Select a preset [1-9]:${NC} "
        read -r choice

        case $choice in
            1) echo "personal"; return 0 ;;
            2) echo "smallTeam"; return 0 ;;
            3) echo "mediumOrg"; return 0 ;;
            4) echo "enterprise"; return 0 ;;
            5) echo "hosting"; return 0 ;;
            6) echo "education"; return 0 ;;
            7) echo "testing"; return 0 ;;
            8) echo "minimal"; return 0 ;;
            9) echo "custom"; return 0 ;;
            *) print_error "Invalid choice. Please select 1-9." ; sleep 2 ;;
        esac
    done
}

# Custom configuration wizard
configure_custom() {
    local max_total max_running max_per_hour
    local enable_per_user max_per_user max_running_per_user
    local max_disk_per_vm max_total_storage max_snapshots
    local block_creation notify admin_override

    print_header
    print_section "Custom VM Limits Configuration"
    echo ""

    # Global limits
    print_info "Global Limits"
    echo ""

    read -p "Maximum total VMs on system [100]: " max_total
    max_total=${max_total:-100}

    read -p "Maximum running VMs concurrently [50]: " max_running
    max_running=${max_running:-50}

    read -p "Maximum VMs created per hour (rate limit) [10]: " max_per_hour
    max_per_hour=${max_per_hour:-10}

    echo ""
    print_info "Per-User Limits"
    echo ""

    read -p "Enable per-user limits? [Y/n]: " enable_per_user
    enable_per_user=${enable_per_user:-Y}

    if [[ "$enable_per_user" =~ ^[Yy] ]]; then
        enable_per_user="true"
        read -p "Maximum VMs per user [20]: " max_per_user
        max_per_user=${max_per_user:-20}

        read -p "Maximum running VMs per user [10]: " max_running_per_user
        max_running_per_user=${max_running_per_user:-10}
    else
        enable_per_user="false"
        max_per_user=20
        max_running_per_user=10
    fi

    echo ""
    print_info "Storage Limits"
    echo ""

    read -p "Maximum disk size per VM (GB) [500]: " max_disk_per_vm
    max_disk_per_vm=${max_disk_per_vm:-500}

    read -p "Maximum total storage for all VMs (GB) [5000]: " max_total_storage
    max_total_storage=${max_total_storage:-5000}

    read -p "Maximum snapshots per VM [10]: " max_snapshots
    max_snapshots=${max_snapshots:-10}

    echo ""
    print_info "Enforcement Options"
    echo ""

    read -p "Block VM creation when limits exceeded? [Y/n]: " block_creation
    block_creation=${block_creation:-Y}
    block_creation=$([[ "$block_creation" =~ ^[Yy] ]] && echo "true" || echo "false")

    read -p "Notify users when approaching limits (90%)? [Y/n]: " notify
    notify=${notify:-Y}
    notify=$([[ "$notify" =~ ^[Yy] ]] && echo "true" || echo "false")

    read -p "Allow admin override with --force flag? [Y/n]: " admin_override
    admin_override=${admin_override:-Y}
    admin_override=$([[ "$admin_override" =~ ^[Yy] ]] && echo "true" || echo "false")

    # Return configuration as JSON-like structure
    cat <<EOF
{
  "maxTotalVMs": $max_total,
  "maxRunningVMs": $max_running,
  "maxVMsPerHour": $max_per_hour,
  "enablePerUser": $enable_per_user,
  "maxVMsPerUser": $max_per_user,
  "maxRunningVMsPerUser": $max_running_per_user,
  "maxDiskPerVM": $max_disk_per_vm,
  "maxTotalStorage": $max_total_storage,
  "maxSnapshotsPerVM": $max_snapshots,
  "blockExcessCreation": $block_creation,
  "notifyOnApproach": $notify,
  "adminOverride": $admin_override
}
EOF
}

# Generate NixOS configuration
generate_nix_config() {
    local preset="$1"

    print_header
    print_section "Generating Configuration"
    echo ""

    if [[ "$preset" == "custom" ]]; then
        print_info "Using custom configuration..."
        local config_json=$(configure_custom)

        # Parse JSON and create Nix config
        cat > "$OUTPUT_FILE" <<EOF
# VM Limits Configuration
# Generated by vm-limits-wizard.sh
# $(date)

hypervisor.vmLimits = {
  enable = true;

  global = {
    maxTotalVMs = $(echo "$config_json" | grep maxTotalVMs | cut -d: -f2 | tr -d ' ,');
    maxRunningVMs = $(echo "$config_json" | grep maxRunningVMs | cut -d: -f2 | tr -d ' ,');
    maxVMsPerHour = $(echo "$config_json" | grep maxVMsPerHour | cut -d: -f2 | tr -d ' ,');
  };

  perUser = {
    enable = $(echo "$config_json" | grep enablePerUser | cut -d: -f2 | tr -d ' ,');
    maxVMsPerUser = $(echo "$config_json" | grep maxVMsPerUser | cut -d: -f2 | tr -d ' ,');
    maxRunningVMsPerUser = $(echo "$config_json" | grep maxRunningVMsPerUser | cut -d: -f2 | tr -d ' ,');
  };

  storage = {
    maxDiskPerVM = $(echo "$config_json" | grep maxDiskPerVM | cut -d: -f2 | tr -d ' ,');
    maxTotalStorage = $(echo "$config_json" | grep maxTotalStorage | cut -d: -f2 | tr -d ' ,');
    maxSnapshotsPerVM = $(echo "$config_json" | grep maxSnapshotsPerVM | cut -d: -f2 | tr -d ' ,');
  };

  enforcement = {
    blockExcessCreation = $(echo "$config_json" | grep blockExcessCreation | cut -d: -f2 | tr -d ' ,');
    notifyOnApproach = $(echo "$config_json" | grep notifyOnApproach | cut -d: -f2 | tr -d ' ,');
    adminOverride = $(echo "$config_json" | grep adminOverride | cut -d: -f2 | tr -d ' ,');
  };
};
EOF
    else
        print_info "Using preset: $preset"

        # Read preset values (simplified - in production would parse the .nix file properly)
        case "$preset" in
            personal)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Personal Workstation Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 20; maxRunningVMs = 10; maxVMsPerHour = 5; };
  perUser = { enable = false; maxVMsPerUser = 20; maxRunningVMsPerUser = 10; };
  storage = { maxDiskPerVM = 200; maxTotalStorage = 1000; maxSnapshotsPerVM = 5; };
  enforcement = { blockExcessCreation = true; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
            smallTeam)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Small Team Server Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 50; maxRunningVMs = 25; maxVMsPerHour = 10; };
  perUser = { enable = true; maxVMsPerUser = 15; maxRunningVMsPerUser = 8; };
  storage = { maxDiskPerVM = 300; maxTotalStorage = 2000; maxSnapshotsPerVM = 8; };
  enforcement = { blockExcessCreation = true; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
            mediumOrg)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Medium Organization Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 100; maxRunningVMs = 50; maxVMsPerHour = 15; };
  perUser = { enable = true; maxVMsPerUser = 20; maxRunningVMsPerUser = 10; };
  storage = { maxDiskPerVM = 500; maxTotalStorage = 5000; maxSnapshotsPerVM = 10; };
  enforcement = { blockExcessCreation = true; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
            enterprise)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Large Enterprise Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 500; maxRunningVMs = 250; maxVMsPerHour = 30; };
  perUser = { enable = true; maxVMsPerUser = 30; maxRunningVMsPerUser = 15; };
  storage = { maxDiskPerVM = 1000; maxTotalStorage = 20000; maxSnapshotsPerVM = 15; };
  enforcement = { blockExcessCreation = true; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
            hosting)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Cloud/Hosting Provider Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 1000; maxRunningVMs = 500; maxVMsPerHour = 50; };
  perUser = { enable = true; maxVMsPerUser = 50; maxRunningVMsPerUser = 25; };
  storage = { maxDiskPerVM = 2000; maxTotalStorage = 50000; maxSnapshotsPerVM = 20; };
  enforcement = { blockExcessCreation = true; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
            education)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Education/Training Lab Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 200; maxRunningVMs = 100; maxVMsPerHour = 25; };
  perUser = { enable = true; maxVMsPerUser = 10; maxRunningVMsPerUser = 5; };
  storage = { maxDiskPerVM = 100; maxTotalStorage = 3000; maxSnapshotsPerVM = 3; };
  enforcement = { blockExcessCreation = true; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
            testing)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Testing/CI Environment Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 150; maxRunningVMs = 75; maxVMsPerHour = 50; };
  perUser = { enable = true; maxVMsPerUser = 50; maxRunningVMsPerUser = 25; };
  storage = { maxDiskPerVM = 200; maxTotalStorage = 4000; maxSnapshotsPerVM = 5; };
  enforcement = { blockExcessCreation = false; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
            minimal)
                cat > "$OUTPUT_FILE" <<'EOF'
# VM Limits Configuration - Minimal/Resource-Constrained Preset
hypervisor.vmLimits = {
  enable = true;
  global = { maxTotalVMs = 10; maxRunningVMs = 5; maxVMsPerHour = 3; };
  perUser = { enable = false; maxVMsPerUser = 10; maxRunningVMsPerUser = 5; };
  storage = { maxDiskPerVM = 100; maxTotalStorage = 500; maxSnapshotsPerVM = 3; };
  enforcement = { blockExcessCreation = true; notifyOnApproach = true; adminOverride = true; };
};
EOF
                ;;
        esac
    fi

    print_success "Configuration generated: $OUTPUT_FILE"
}

# Show configuration preview
show_preview() {
    print_header
    print_section "Configuration Preview"
    echo ""
    cat "$OUTPUT_FILE"
    echo ""
}

# Apply configuration
apply_configuration() {
    print_header
    print_section "Applying Configuration"
    echo ""

    # Backup current configuration
    local backup_file="/etc/nixos/configuration.nix.backup-$(date +%Y%m%d-%H%M%S)"
    print_info "Creating backup: $backup_file"
    cp "$CONFIG_FILE" "$backup_file"
    print_success "Backup created"

    # Check if vmLimits section already exists
    if grep -q "hypervisor.vmLimits" "$CONFIG_FILE"; then
        print_warning "VM limits configuration already exists in $CONFIG_FILE"
        echo -ne "${YELLOW}Replace existing configuration? [y/N]:${NC} "
        read -r replace

        if [[ "$replace" =~ ^[Yy]$ ]]; then
            # Remove existing vmLimits section
            print_info "Removing existing VM limits configuration..."
            # This is simplified - in production would use proper Nix parsing
            sed -i '/hypervisor\.vmLimits = {/,/^  };/d' "$CONFIG_FILE"
        else
            print_warning "Configuration not applied. Manual merge required."
            echo ""
            print_info "Generated configuration saved to: $OUTPUT_FILE"
            print_info "Please manually merge this into: $CONFIG_FILE"
            return 1
        fi
    fi

    # Find the right place to insert (after security section, before defaults)
    if grep -q "# Default VM configuration" "$CONFIG_FILE"; then
        print_info "Inserting VM limits configuration..."

        # Insert before "# Default VM configuration"
        sed -i "/# Default VM configuration/i\\
    # VM Creation and Resource Limits\\
$(cat "$OUTPUT_FILE" | sed 's/^/    /')\\
\\
" "$CONFIG_FILE"

        print_success "Configuration inserted into $CONFIG_FILE"
    else
        print_warning "Could not find insertion point in $CONFIG_FILE"
        print_info "Generated configuration saved to: $OUTPUT_FILE"
        print_info "Please manually add this to your configuration.nix"
        return 1
    fi

    echo ""
    print_success "VM limits configuration applied successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Review the changes in $CONFIG_FILE"
    echo "  2. Rebuild your system: sudo nixos-rebuild switch"
    echo "  3. Check limits status: hv-check-vm-limits status"
    echo ""
}

# Main wizard flow
main() {
    print_header
    echo "This wizard will help you configure VM creation limits for your"
    echo "Hyper-NixOS system. You can choose from preset configurations or"
    echo "create a custom configuration."
    echo ""
    echo "Press Enter to continue..."
    read -r

    # Step 1: Select preset
    local preset
    preset=$(select_preset)

    # Step 2: Generate configuration
    generate_nix_config "$preset"

    # Step 3: Preview
    show_preview

    echo -ne "${GREEN}Apply this configuration? [Y/n]:${NC} "
    read -r apply
    apply=${apply:-Y}

    if [[ "$apply" =~ ^[Yy]$ ]]; then
        apply_configuration
    else
        print_info "Configuration saved to: $OUTPUT_FILE"
        print_info "You can manually apply it later."
    fi

    echo ""
    print_success "VM Limits Configuration Wizard completed!"
    echo ""
}

# Run the wizard
main "$@"
