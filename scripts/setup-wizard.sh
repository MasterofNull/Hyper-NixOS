#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Interactive Setup Wizard
# Guides administrators through feature selection with security awareness
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Wizard configuration
readonly WIZARD_VERSION="1.0.0"
readonly CONFIG_FILE="/etc/nixos/hypervisor-features.nix"
readonly TEMP_CONFIG="/tmp/hypervisor-setup-$$"

# Colors for risk levels
readonly COLOR_MINIMAL='\033[0;32m'    # Green
readonly COLOR_LOW='\033[0;34m'        # Blue
readonly COLOR_MODERATE='\033[0;33m'   # Yellow
readonly COLOR_HIGH='\033[1;33m'       # Bright Yellow
readonly COLOR_CRITICAL='\033[0;31m'   # Red
readonly NC='\033[0m'                  # No Color

# Risk level symbols
readonly RISK_MINIMAL="🟢"
readonly RISK_LOW="🔵"
readonly RISK_MODERATE="🟡"
readonly RISK_HIGH="🟠"
readonly RISK_CRITICAL="🔴"

# Global variables
SELECTED_FEATURES=()
RISK_TOLERANCE="balanced"
USER_EXPERIENCE="intermediate"
ENABLE_EXPLANATIONS=true

# Cleanup on exit
cleanup() {
    rm -f "$TEMP_CONFIG"*
}
trap cleanup EXIT

# Print wizard header
print_header() {
    clear
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              Hyper-NixOS Setup Wizard v1.0                    ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  This wizard will help you configure Hyper-NixOS features     ║
║  with full awareness of security implications.                ║
║                                                               ║
║  For each feature, you'll see:                                ║
║  • Description and benefits                                   ║
║  • Security risk assessment                                   ║
║  • Specific security impacts                                  ║
║  • Recommended mitigations                                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
}

# Get risk color
get_risk_color() {
    local risk="$1"
    case "$risk" in
        minimal) echo "$COLOR_MINIMAL" ;;
        low) echo "$COLOR_LOW" ;;
        moderate) echo "$COLOR_MODERATE" ;;
        high) echo "$COLOR_HIGH" ;;
        critical) echo "$COLOR_CRITICAL" ;;
        *) echo "$NC" ;;
    esac
}

# Get risk symbol
get_risk_symbol() {
    local risk="$1"
    case "$risk" in
        minimal) echo "$RISK_MINIMAL" ;;
        low) echo "$RISK_LOW" ;;
        moderate) echo "$RISK_MODERATE" ;;
        high) echo "$RISK_HIGH" ;;
        critical) echo "$RISK_CRITICAL" ;;
        *) echo "?" ;;
    esac
}

# Step 1: User profile selection
select_user_profile() {
    print_header
    echo "Step 1: User Experience Level"
    echo "=============================="
    echo
    echo "Please select your experience level with virtualization:"
    echo
    echo "1) Beginner"
    echo "   - New to virtualization"
    echo "   - Want detailed explanations"
    echo "   - Prefer guided setup"
    echo
    echo "2) Intermediate" 
    echo "   - Familiar with VMs"
    echo "   - Understand basic concepts"
    echo "   - Want balanced information"
    echo
    echo "3) Expert"
    echo "   - Deep virtualization knowledge"
    echo "   - Just show me the options"
    echo "   - Minimal explanations needed"
    echo
    
    read -p "Select your experience level (1-3): " choice
    
    case "$choice" in
        1) USER_EXPERIENCE="beginner"; ENABLE_EXPLANATIONS=true ;;
        2) USER_EXPERIENCE="intermediate"; ENABLE_EXPLANATIONS=true ;;
        3) USER_EXPERIENCE="expert"; ENABLE_EXPLANATIONS=false ;;
        *) USER_EXPERIENCE="intermediate"; ENABLE_EXPLANATIONS=true ;;
    esac
}

# Step 2: Risk tolerance selection
select_risk_tolerance() {
    print_header
    echo "Step 2: Security Risk Tolerance"
    echo "================================"
    echo
    echo "Select your security stance:"
    echo
    echo "1) Paranoid ${RISK_MINIMAL}"
    echo "   - Maximum security, minimal features"
    echo "   - No features above 'low' risk"
    echo "   - Suitable for high-security environments"
    echo
    echo "2) Cautious ${RISK_LOW}"
    echo "   - Security-focused with some flexibility"
    echo "   - No features above 'moderate' risk"
    echo "   - Good for production environments"
    echo
    echo "3) Balanced ${RISK_MODERATE}"
    echo "   - Balance between security and features"
    echo "   - No 'critical' risk features"
    echo "   - Suitable for most use cases"
    echo
    echo "4) Accepting ${RISK_HIGH}"
    echo "   - Feature-rich, accept security trade-offs"
    echo "   - All features available with warnings"
    echo "   - For development/lab environments"
    echo
    
    read -p "Select risk tolerance (1-4) [3]: " choice
    
    case "$choice" in
        1) RISK_TOLERANCE="paranoid" ;;
        2) RISK_TOLERANCE="cautious" ;;
        3) RISK_TOLERANCE="balanced" ;;
        4) RISK_TOLERANCE="accepting" ;;
        *) RISK_TOLERANCE="balanced" ;;
    esac
}

# Display feature details
show_feature_details() {
    local category="$1"
    local feature="$2"
    local risk="$3"
    local description="$4"
    shift 4
    local impacts=("$@")
    
    local risk_color=$(get_risk_color "$risk")
    local risk_symbol=$(get_risk_symbol "$risk")
    
    echo
    echo "─────────────────────────────────────────────────────────"
    echo -e "Feature: ${risk_color}$feature${NC} $risk_symbol"
    echo "Category: $category"
    echo "Risk Level: $risk"
    echo
    
    if [[ "$ENABLE_EXPLANATIONS" == "true" ]]; then
        echo "Description:"
        echo "  $description"
        echo
        
        if [[ ${#impacts[@]} -gt 0 ]]; then
            echo "Security Impacts:"
            for impact in "${impacts[@]}"; do
                echo "  • $impact"
            done
            echo
        fi
    fi
}

# Check if feature is allowed by risk tolerance
is_feature_allowed() {
    local risk="$1"
    
    case "$RISK_TOLERANCE" in
        paranoid)
            [[ "$risk" == "minimal" || "$risk" == "low" ]]
            ;;
        cautious)
            [[ "$risk" != "high" && "$risk" != "critical" ]]
            ;;
        balanced)
            [[ "$risk" != "critical" ]]
            ;;
        accepting)
            true
            ;;
    esac
}

# Step 3: Feature selection by category
select_features() {
    local categories=(
        "core:Core Features:Essential VM management"
        "userExperience:User Experience:Interfaces and usability"
        "networking:Advanced Networking:Network capabilities"
        "storage:Storage Features:Storage options"
        "backup:Backup & Recovery:Data protection"
        "monitoring:Monitoring:System monitoring"
        "integration:Integrations:Third-party services"
        "developer:Developer Tools:Development features"
        "experimental:Experimental:Cutting-edge features"
    )
    
    for cat_entry in "${categories[@]}"; do
        IFS=':' read -r cat_id cat_name cat_desc <<< "$cat_entry"
        
        print_header
        echo "Step 3: Feature Selection - $cat_name"
        echo "========================================"
        echo "$cat_desc"
        echo
        
        # Show features in this category
        case "$cat_id" in
            core)
                # Core features - some are mandatory
                echo "✓ VM Management (Required)"
                echo "✓ Privilege Separation (Required)"
                echo
                
                prompt_feature "$cat_name" "auditLogging" "minimal" \
                    "Audit Logging" \
                    "Log all operations for security tracking" \
                    "Disk usage for log storage"
                ;;
                
            userExperience)
                prompt_feature "$cat_name" "webDashboard" "moderate" \
                    "Web Dashboard" \
                    "Browser-based VM management interface" \
                    "Opens web ports (default: 8443)" \
                    "Requires TLS certificate management" \
                    "Increases attack surface via web interface"
                    
                prompt_feature "$cat_name" "cliEnhancements" "low" \
                    "Enhanced CLI" \
                    "Advanced command-line features and auto-completion" \
                    "Stores command history" \
                    "May cache sensitive data in shell completion"
                ;;
                
            networking)
                prompt_feature "$cat_name" "microSegmentation" "low" \
                    "Network Micro-segmentation" \
                    "Per-VM firewall rules and isolation" \
                    "Complexity in network configuration" \
                    "Potential for misconfiguration"
                    
                if [[ "$RISK_TOLERANCE" == "accepting" ]]; then
                    prompt_feature "$cat_name" "sriov" "high" \
                        "SR-IOV Support" \
                        "Direct hardware network access for VMs" \
                        "VMs get direct hardware access" \
                        "Bypasses hypervisor network controls" \
                        "Potential for hardware-level attacks"
                fi
                ;;
                
            storage)
                prompt_feature "$cat_name" "encryption" "minimal" \
                    "Storage Encryption" \
                    "Encrypt VM disks at rest" \
                    "Slight performance overhead" \
                    "Key management complexity"
                    
                prompt_feature "$cat_name" "deduplication" "low" \
                    "Storage Deduplication" \
                    "Reduce storage usage via deduplication" \
                    "CPU overhead for dedup processing" \
                    "Potential data correlation attacks"
                ;;
                
            backup)
                prompt_feature "$cat_name" "remoteBackup" "moderate" \
                    "Remote Backup" \
                    "Backup to remote locations" \
                    "Network bandwidth usage" \
                    "Remote credential management" \
                    "Data leaves premises"
                ;;
                
            monitoring)
                prompt_feature "$cat_name" "prometheus" "low" \
                    "Prometheus Export" \
                    "Export metrics to Prometheus" \
                    "Opens metrics endpoint" \
                    "Potential information disclosure"
                ;;
                
            integration)
                if [[ "$RISK_TOLERANCE" != "paranoid" ]]; then
                    prompt_feature "$cat_name" "kubernetes" "moderate" \
                        "Kubernetes Integration" \
                        "Use VMs as Kubernetes nodes or storage" \
                        "Requires API exposure" \
                        "Complex permission model" \
                        "Container escape risks"
                fi
                ;;
                
            developer)
                if [[ "$RISK_TOLERANCE" != "paranoid" ]]; then
                    prompt_feature "$cat_name" "api" "high" \
                        "REST/GraphQL API" \
                        "Programmatic access to VM operations" \
                        "API attack surface" \
                        "Authentication complexity" \
                        "Rate limiting required"
                fi
                ;;
                
            experimental)
                if [[ "$RISK_TOLERANCE" == "accepting" ]]; then
                    echo "⚠️  Warning: Experimental features may be unstable!"
                    echo
                    
                    prompt_feature "$cat_name" "liveMigration" "high" \
                        "Live Migration" \
                        "Move running VMs between hosts" \
                        "Memory contents transmitted" \
                        "Network security critical" \
                        "Complex failure modes"
                fi
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Prompt for individual feature
prompt_feature() {
    local category="$1"
    local feature_id="$2"
    local risk="$3"
    local name="$4"
    local description="$5"
    shift 5
    local impacts=("$@")
    
    # Check if allowed by risk tolerance
    if ! is_feature_allowed "$risk"; then
        echo "⊗ $name (Blocked by risk tolerance)"
        return
    fi
    
    show_feature_details "$category" "$name" "$risk" "$description" "${impacts[@]}"
    
    # Default based on risk
    local default="n"
    if [[ "$risk" == "minimal" || "$risk" == "low" ]]; then
        default="y"
    fi
    
    read -p "Enable this feature? (y/N) [$default]: " choice
    choice=${choice:-$default}
    
    if [[ "$choice" =~ ^[Yy] ]]; then
        SELECTED_FEATURES+=("$feature_id")
        echo "  ✓ Feature enabled"
        
        # Show mitigations for risky features
        if [[ "$risk" == "high" || "$risk" == "critical" ]]; then
            echo
            echo "  ⚠️  Recommended mitigations:"
            echo "     • Implement strong authentication"
            echo "     • Monitor access logs closely"
            echo "     • Restrict network access"
            echo "     • Keep security patches current"
        fi
    else
        echo "  ⊗ Feature disabled"
    fi
}

# Step 4: Review and confirm
review_configuration() {
    print_header
    echo "Step 4: Review Configuration"
    echo "============================="
    echo
    echo "User Experience: $USER_EXPERIENCE"
    echo "Risk Tolerance: $RISK_TOLERANCE"
    echo
    echo "Selected Features:"
    echo "─────────────────"
    
    # Calculate risk score
    local total_risk=0
    for feature in "${SELECTED_FEATURES[@]}"; do
        echo "  ✓ $feature"
        # In real implementation, would look up risk values
        total_risk=$((total_risk + 1))
    done
    
    echo
    echo "Security Profile Summary:"
    echo "────────────────────────"
    echo "Total features enabled: ${#SELECTED_FEATURES[@]}"
    echo "Estimated risk score: $total_risk"
    
    if [[ $total_risk -lt 10 ]]; then
        echo -e "Overall stance: ${COLOR_MINIMAL}Hardened${NC} $RISK_MINIMAL"
    elif [[ $total_risk -lt 20 ]]; then
        echo -e "Overall stance: ${COLOR_MODERATE}Balanced${NC} $RISK_MODERATE"
    else
        echo -e "Overall stance: ${COLOR_HIGH}Permissive${NC} $RISK_HIGH"
    fi
    
    echo
    read -p "Proceed with this configuration? (y/N): " confirm
    
    [[ "$confirm" =~ ^[Yy] ]]
}

# Generate NixOS configuration
generate_config() {
    cat > "$TEMP_CONFIG" <<EOF
# Hyper-NixOS Feature Configuration
# Generated by setup wizard on $(date)
# DO NOT EDIT - Regenerate with setup-wizard.sh

{ config, lib, pkgs, ... }:

{
  # User experience settings
  hypervisor.documentation = {
    enable = true;
    profile = "${USER_EXPERIENCE}";
    verbosity = $(
        case "$USER_EXPERIENCE" in
            beginner) echo '"high"' ;;
            intermediate) echo '"medium"' ;;
            expert) echo '"low"' ;;
        esac
    );
    enableHints = $(
        [[ "$USER_EXPERIENCE" != "expert" ]] && echo "true" || echo "false"
    );
    enableTutorials = $(
        [[ "$USER_EXPERIENCE" == "beginner" ]] && echo "true" || echo "false"
    );
  };
  
  # Feature management
  hypervisor.featureManager = {
    enable = true;
    profile = "custom";
    riskTolerance = "${RISK_TOLERANCE}";
    enabledFeatures = [
      # Core features (always enabled)
      "vmManagement"
      "privilegeSeparation"
      
      # User-selected features
$(for feature in "${SELECTED_FEATURES[@]}"; do
    echo "      \"$feature\""
done)
    ];
    generateReport = true;
  };
  
  # Enable modules based on features
$(if [[ " ${SELECTED_FEATURES[*]} " =~ " webDashboard " ]]; then
    echo "  services.nginx.enable = true;"
    echo "  hypervisor.webDashboard.enable = true;"
fi)
  
$(if [[ " ${SELECTED_FEATURES[*]} " =~ " api " ]]; then
    echo "  hypervisor.api.enable = true;"
fi)
  
$(if [[ " ${SELECTED_FEATURES[*]} " =~ " prometheus " ]]; then
    echo "  services.prometheus.enable = true;"
fi)
  
  # Security hardening based on risk tolerance
$(case "$RISK_TOLERANCE" in
    paranoid)
        echo "  # Paranoid security settings"
        echo "  networking.firewall.enable = true;"
        echo "  networking.firewall.allowPing = false;"
        echo "  services.fail2ban.enable = true;"
        ;;
    cautious)
        echo "  # Cautious security settings"
        echo "  networking.firewall.enable = true;"
        echo "  services.fail2ban.enable = true;"
        ;;
    balanced)
        echo "  # Balanced security settings"
        echo "  networking.firewall.enable = true;"
        ;;
    accepting)
        echo "  # Permissive settings - monitor closely!"
        echo "  # Consider enabling additional monitoring"
        ;;
esac)
}
EOF
}

# Step 5: Apply configuration
apply_configuration() {
    print_header
    echo "Step 5: Apply Configuration"
    echo "==========================="
    echo
    
    echo "Generated configuration:"
    echo "───────────────────────"
    cat "$TEMP_CONFIG"
    echo
    
    echo "This will:"
    echo "1. Save configuration to $CONFIG_FILE"
    echo "2. Update your NixOS configuration"
    echo "3. Rebuild the system"
    echo
    
    read -p "Apply configuration now? (y/N): " apply
    
    if [[ "$apply" =~ ^[Yy] ]]; then
        # Backup existing config
        if [[ -f "$CONFIG_FILE" ]]; then
            cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"
            echo "✓ Backed up existing configuration"
        fi
        
        # Copy new config
        sudo cp "$TEMP_CONFIG" "$CONFIG_FILE"
        echo "✓ Configuration saved"
        
        # Update main configuration to import features
        if ! grep -q "hypervisor-features.nix" /etc/nixos/configuration.nix; then
            echo "✓ Adding import to configuration.nix"
            sudo sed -i '/imports = \[/a\    ./hypervisor-features.nix' /etc/nixos/configuration.nix
        fi
        
        echo
        echo "Ready to rebuild. Run:"
        echo "  sudo nixos-rebuild switch"
        echo
        echo "Or test first with:"
        echo "  sudo nixos-rebuild test"
    else
        echo
        echo "Configuration saved to: $TEMP_CONFIG"
        echo "To apply later:"
        echo "  sudo cp $TEMP_CONFIG $CONFIG_FILE"
        echo "  sudo nixos-rebuild switch"
    fi
}

# Show post-setup recommendations
show_recommendations() {
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    Setup Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "Next Steps:"
    echo "──────────"
    
    if [[ "$USER_EXPERIENCE" == "beginner" ]]; then
        echo "1. Run the quick-start tutorial:"
        echo "   hv-tutorial quick-start"
        echo
        echo "2. Read the beginner's guide:"
        echo "   hv-docs --level beginner"
        echo
        echo "3. Try creating your first VM:"
        echo "   hv vm create my-first-vm --template debian-11"
    else
        echo "1. Review the security report:"
        echo "   cat /etc/hypervisor/reports/feature-security-impact.md"
        echo
        echo "2. Configure user access:"
        echo "   sudo vim /etc/nixos/configuration.nix"
        echo
        echo "3. Monitor system logs:"
        echo "   journalctl -u hypervisor -f"
    fi
    
    echo
    echo "Documentation Commands:"
    echo "─────────────────────"
    echo "  hv-help <topic>     - Get help on any topic"
    echo "  hv-cheatsheet       - Quick reference card"
    echo "  hv-tutorial         - Interactive tutorials"
    echo "  hv-docs             - Full documentation"
    echo
    
    # Risk-specific recommendations
    case "$RISK_TOLERANCE" in
        paranoid|cautious)
            echo "Security Recommendations:"
            echo "────────────────────────"
            echo "  • Enable audit logging: journalctl -u audit"
            echo "  • Review firewall rules: sudo iptables -L"
            echo "  • Monitor access: sudo aureport -au"
            ;;
        accepting)
            echo "⚠️  High-Risk Configuration:"
            echo "────────────────────────"
            echo "  • Monitor logs closely for anomalies"
            echo "  • Implement additional access controls"
            echo "  • Consider network segmentation"
            echo "  • Regular security audits recommended"
            ;;
    esac
}

# Main wizard flow
main() {
    # Check if running with appropriate permissions
    if [[ $EUID -eq 0 ]]; then
        echo "Please run this wizard as a regular user, not as root."
        echo "The wizard will ask for sudo when needed."
        exit 1
    fi
    
    # Step through wizard
    select_user_profile
    select_risk_tolerance
    select_features
    
    if review_configuration; then
        generate_config
        apply_configuration
        show_recommendations
    else
        echo
        echo "Setup cancelled. No changes made."
        exit 0
    fi
}

# Run the wizard
main "$@"