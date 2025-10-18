#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091
#
# Hyper-NixOS Risk Notification Library
#
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Provides standardized risk notification functions for wizards
# to inform users about security implications of features.
#

# Prevent multiple sourcing
if [[ -n "${_HYPERVISOR_RISK_NOTIFICATIONS_LOADED:-}" ]]; then
    return 0
fi
readonly _HYPERVISOR_RISK_NOTIFICATIONS_LOADED=1

# Source UI library for colors (if not already loaded)
if [[ -z "${_HYPERVISOR_UI_LOADED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/ui.sh" 2>/dev/null || {
        # Fallback colors if ui.sh not available
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'
    }
fi

# Risk level icons
readonly RISK_ICON_MINIMAL="✓"
readonly RISK_ICON_LOW="ℹ"
readonly RISK_ICON_MODERATE="⚠"
readonly RISK_ICON_HIGH="⚠⚠"
readonly RISK_ICON_CRITICAL="🔴"

# Show risk notification with appropriate styling
# Usage: show_risk_notification <feature> <risk_level> <impacts> <mitigations>
show_risk_notification() {
    local feature="$1"
    local risk_level="$2"
    local impacts="$3"
    local mitigations="$4"

    echo ""

    case "$risk_level" in
        minimal)
            echo -e "${GREEN}${RISK_ICON_MINIMAL}${NC} ${BOLD}$feature${NC} - ${GREEN}Minimal Risk${NC}"
            echo "  This feature has no significant security implications."
            ;;
        low)
            echo -e "${BLUE}${RISK_ICON_LOW}${NC} ${BOLD}$feature${NC} - ${BLUE}Low Risk${NC}"
            echo "  Impacts: $impacts"
            if [[ -n "$mitigations" ]]; then
                echo "  Mitigations: $mitigations"
            fi
            ;;
        moderate)
            echo -e "${YELLOW}${RISK_ICON_MODERATE}${NC} ${BOLD}$feature${NC} - ${YELLOW}Moderate Risk${NC}"
            echo "  ${YELLOW}Impacts:${NC} $impacts"
            if [[ -n "$mitigations" ]]; then
                echo "  ${BLUE}Mitigations:${NC} $mitigations"
            fi
            ;;
        high)
            echo -e "${RED}${RISK_ICON_HIGH}${NC} ${BOLD}$feature${NC} - ${RED}High Risk${NC}"
            echo "  ${RED}WARNING:${NC} $impacts"
            if [[ -n "$mitigations" ]]; then
                echo "  ${YELLOW}Required Mitigations:${NC} $mitigations"
            fi
            echo ""
            read -rp "  ${YELLOW}Type 'I understand' to proceed:${NC} " confirm
            if [[ "$confirm" != "I understand" ]]; then
                echo -e "  ${RED}Aborting.${NC}"
                return 1
            fi
            ;;
        critical)
            echo -e "${RED}${RISK_ICON_CRITICAL} ${BOLD}$feature${NC} - ${RED}${BOLD}CRITICAL RISK${NC}"
            echo "  ${RED}${BOLD}DANGER:${NC} $impacts"
            if [[ -n "$mitigations" ]]; then
                echo "  ${YELLOW}${BOLD}MANDATORY Mitigations:${NC} $mitigations"
            fi
            echo ""
            echo -e "  ${RED}This feature poses significant security risks.${NC}"
            read -rp "  ${RED}Type 'I ACCEPT THE RISK' to proceed:${NC} " confirm
            if [[ "$confirm" != "I ACCEPT THE RISK" ]]; then
                echo -e "  ${RED}Aborting for your safety.${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}ERROR:${NC} Unknown risk level: $risk_level"
            return 1
            ;;
    esac

    echo ""
    return 0
}

# Show a summary of multiple features with their risk levels
# Usage: show_feature_risk_summary
show_feature_risk_summary() {
    cat << EOF

${BOLD}Feature Risk Summary:${NC}

${GREEN}${RISK_ICON_MINIMAL} Minimal Risk${NC}  - No security concerns
${BLUE}${RISK_ICON_LOW} Low Risk${NC}      - Minor considerations, easily mitigated
${YELLOW}${RISK_ICON_MODERATE} Moderate Risk${NC} - Requires attention and proper configuration
${RED}${RISK_ICON_HIGH} High Risk${NC}     - Significant security implications, use with caution
${RED}${RISK_ICON_CRITICAL} Critical Risk${NC} - Extreme risk, only for specific use cases

EOF
}

# Show security profile selector with risk explanations
show_security_profile_selector() {
    cat << EOF

${BOLD}Security Profiles:${NC}

${GREEN}1. Paranoid${NC}
   - Maximum security, minimal features
   - Suitable for: Production environments, internet-facing systems
   - Risk tolerance: ${GREEN}Minimal${NC}

${BLUE}2. Cautious${NC}
   - Balanced security with essential features
   - Suitable for: Home labs, development systems
   - Risk tolerance: ${BLUE}Low to Moderate${NC}

${YELLOW}3. Balanced${NC}
   - Good security with convenience features
   - Suitable for: Most use cases, trusted networks
   - Risk tolerance: ${YELLOW}Moderate${NC}

${RED}4. Accepting${NC}
   - Convenience over security
   - Suitable for: Isolated test environments only
   - Risk tolerance: ${RED}High${NC}

EOF
    read -rp "Select security profile [1-4]: " profile_choice

    case "$profile_choice" in
        1) echo "paranoid" ;;
        2) echo "cautious" ;;
        3) echo "balanced" ;;
        4)
            echo ""
            echo -e "${RED}WARNING:${NC} 'Accepting' profile is NOT recommended for production use."
            read -rp "Type 'I understand' to continue with accepting profile: " confirm
            if [[ "$confirm" == "I understand" ]]; then
                echo "accepting"
            else
                echo "balanced"  # Default to balanced
            fi
            ;;
        *)
            echo "balanced"  # Default
            ;;
    esac
}

# Show a feature enablement dialog with risk notification
# Usage: prompt_feature_enable <feature_name> <risk_level> <description> <impacts> <mitigations>
prompt_feature_enable() {
    local feature_name="$1"
    local risk_level="$2"
    local description="$3"
    local impacts="$4"
    local mitigations="$5"

    echo ""
    echo -e "${BOLD}Feature: $feature_name${NC}"
    echo "Description: $description"
    echo ""

    show_risk_notification "$feature_name" "$risk_level" "$impacts" "$mitigations" || return 1

    read -rp "Enable $feature_name? [y/N]: " response
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Display comprehensive risk matrix
show_risk_matrix() {
    cat << EOF

${BOLD}Security Risk Matrix:${NC}

┌─────────────┬──────────────────────────────────────────────────────┐
│ Risk Level  │ Description                                          │
├─────────────┼──────────────────────────────────────────────────────┤
│ ${GREEN}Minimal${NC}     │ No security impact, safe for all environments       │
│ ${BLUE}Low${NC}         │ Minor exposure, standard mitigations sufficient      │
│ ${YELLOW}Moderate${NC}    │ Requires active monitoring and configuration        │
│ ${RED}High${NC}        │ Significant risk, expert knowledge recommended       │
│ ${RED}Critical${NC}    │ Extreme risk, only for isolated test environments   │
└─────────────┴──────────────────────────────────────────────────────┘

${BOLD}Impact Categories:${NC}

• ${CYAN}Confidentiality${NC}: Risk of unauthorized information disclosure
• ${CYAN}Integrity${NC}:       Risk of unauthorized modification
• ${CYAN}Availability${NC}:    Risk of service disruption
• ${CYAN}Authentication${NC}:  Risk of unauthorized access
• ${CYAN}Authorization${NC}:   Risk of privilege escalation

EOF
}

# Export functions for use in other scripts
export -f show_risk_notification
export -f show_feature_risk_summary
export -f show_security_profile_selector
export -f prompt_feature_enable
export -f show_risk_matrix
