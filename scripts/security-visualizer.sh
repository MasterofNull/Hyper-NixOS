#!/usr/bin/env bash
#
# Security Impact Visualizer
# Shows real-time security posture based on enabled features
#
# Copyright (c) 2025 Hyper-NixOS Contributors
# License: MIT
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ANSI colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Risk colors and symbols
readonly RISK_COLORS=(
    [minimal]="$GREEN"
    [low]="$BLUE"
    [moderate]="$YELLOW"
    [high]="$YELLOW"
    [critical]="$RED"
)

readonly RISK_SYMBOLS=(
    [minimal]="🟢"
    [low]="🔵"
    [moderate]="🟡"
    [high]="🟠"
    [critical]="🔴"
)

# Load current configuration
load_config() {
    if [[ -f /etc/hypervisor/features.json ]]; then
        ENABLED_FEATURES=$(jq -r '.enabledFeatures[]' /etc/hypervisor/features.json 2>/dev/null || echo "")
        RISK_SCORE=$(jq -r '.riskScore' /etc/hypervisor/features.json 2>/dev/null || echo "0")
        SECURITY_PROFILE=$(jq -r '.securityProfile' /etc/hypervisor/features.json 2>/dev/null || echo "unknown")
    else
        echo "Error: Feature configuration not found. Run setup-wizard.sh first."
        exit 1
    fi
}

# Draw ASCII security meter
draw_security_meter() {
    local score=$1
    local max_score=50
    local meter_width=40
    local filled=$((score * meter_width / max_score))
    
    echo -n "Security Risk Meter: ["
    
    # Draw filled portion
    for ((i = 0; i < filled; i++)); do
        if ((score <= 10)); then
            echo -ne "${GREEN}█${NC}"
        elif ((score <= 20)); then
            echo -ne "${YELLOW}█${NC}"
        else
            echo -ne "${RED}█${NC}"
        fi
    done
    
    # Draw empty portion
    for ((i = filled; i < meter_width; i++)); do
        echo -n "░"
    done
    
    echo "] $score/$max_score"
}

# Show attack surface visualization
show_attack_surface() {
    cat <<'EOF'
                     Attack Surface Visualization
    ┌─────────────────────────────────────────────────────┐
    │                  🖥️  Hypervisor Host                 │
    │  ┌─────────────────────────────────────────────┐   │
    │  │              Management Layer                │   │
EOF

    # Show enabled high-risk features
    if echo "$ENABLED_FEATURES" | grep -q "webDashboard"; then
        echo "    │  │  🌐 Web Dashboard (Port 8443)          🟡   │   │"
    fi
    if echo "$ENABLED_FEATURES" | grep -q "api"; then
        echo "    │  │  🔌 REST API (Port 8080)               🟠   │   │"
    fi
    if echo "$ENABLED_FEATURES" | grep -q "kubernetes"; then
        echo "    │  │  ☸️  Kubernetes API (Port 6443)         🟡   │   │"
    fi
    
    cat <<'EOF'
    │  └─────────────────────────────────────────────┘   │
    │                         │                           │
    │  ┌──────────────────────┴──────────────────────┐   │
    │  │              Virtualization Layer            │   │
EOF

    # Show VM isolation status
    if echo "$ENABLED_FEATURES" | grep -q "microSegmentation"; then
        echo "    │  │  ✓ Micro-segmentation Enabled          🟢   │   │"
    else
        echo "    │  │  ✗ Basic Network Isolation Only        🟡   │   │"
    fi
    
    if echo "$ENABLED_FEATURES" | grep -q "sriov"; then
        echo "    │  │  ⚠️  SR-IOV Direct Hardware Access      🟠   │   │"
    fi

    cat <<'EOF'
    │  │                                             │   │
    │  │    ┌──────┐  ┌──────┐  ┌──────┐            │   │
    │  │    │ VM 1 │  │ VM 2 │  │ VM 3 │            │   │
    │  │    └──────┘  └──────┘  └──────┘            │   │
    │  └─────────────────────────────────────────────┘   │
    │                         │                           │
    │  ┌──────────────────────┴──────────────────────┐   │
    │  │              Storage Layer                   │   │
EOF

    if echo "$ENABLED_FEATURES" | grep -q "encryption"; then
        echo "    │  │  ✓ Encryption at Rest Enabled          🟢   │   │"
    else
        echo "    │  │  ✗ No Encryption at Rest               🟡   │   │"
    fi

    cat <<'EOF'
    │  └─────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────┘
EOF
}

# Show feature risk matrix
show_risk_matrix() {
    echo
    echo "Feature Risk Matrix"
    echo "==================="
    echo
    
    # Parse feature definitions and show risk levels
    local categories=("Core" "Networking" "Storage" "Integration" "Monitoring")
    
    for category in "${categories[@]}"; do
        echo -e "${BOLD}$category Features:${NC}"
        echo "─────────────────"
        
        # This would parse actual feature definitions
        case "$category" in
            "Core")
                check_feature "VM Management" "vmManagement" "minimal"
                check_feature "Audit Logging" "auditLogging" "minimal"
                ;;
            "Networking")
                check_feature "Micro-segmentation" "microSegmentation" "low"
                check_feature "SR-IOV Support" "sriov" "high"
                check_feature "Public Bridge" "publicBridge" "critical"
                ;;
            "Storage")
                check_feature "Encryption" "encryption" "minimal"
                check_feature "Deduplication" "deduplication" "low"
                check_feature "Remote Storage" "remoteStorage" "moderate"
                ;;
            "Integration")
                check_feature "Kubernetes" "kubernetes" "moderate"
                check_feature "API Access" "api" "high"
                check_feature "LDAP/AD" "ldap" "high"
                ;;
            "Monitoring")
                check_feature "Metrics" "metrics" "minimal"
                check_feature "Prometheus" "prometheus" "low"
                check_feature "AI Detection" "aiAnomalyDetection" "moderate"
                ;;
        esac
        echo
    done
}

# Check if feature is enabled and show risk
check_feature() {
    local name="$1"
    local feature_id="$2"
    local risk="$3"
    
    local status="[ ]"
    local color="${NC}"
    
    if echo "$ENABLED_FEATURES" | grep -q "$feature_id"; then
        status="[✓]"
        color="${RISK_COLORS[$risk]}"
    fi
    
    printf "  %-25s %s ${color}%-10s${NC} %s\n" \
        "$name" "$status" "$risk" "${RISK_SYMBOLS[$risk]}"
}

# Show security recommendations
show_recommendations() {
    echo
    echo "Security Recommendations"
    echo "========================"
    echo
    
    case "$SECURITY_PROFILE" in
        "hardened")
            echo "✅ Excellent security posture!"
            echo
            echo "Your configuration is highly secure. Maintain by:"
            echo "• Regular security updates"
            echo "• Monitoring audit logs"
            echo "• Periodic security reviews"
            ;;
            
        "balanced")
            echo "⚠️  Good security with some considerations"
            echo
            echo "Recommended actions:"
            echo "• Review enabled moderate-risk features"
            echo "• Implement suggested mitigations"
            echo "• Enable additional monitoring"
            echo "• Consider disabling unused features"
            ;;
            
        "flexible"|"permissive")
            echo "⚠️  Higher risk configuration detected"
            echo
            echo "Critical recommendations:"
            echo "• Review all high-risk features"
            echo "• Implement strong authentication (MFA)"
            echo "• Enable comprehensive logging"
            echo "• Network segmentation is crucial"
            echo "• Regular security audits"
            echo "• Consider disabling unnecessary features"
            ;;
    esac
    
    # Feature-specific recommendations
    echo
    echo "Feature-Specific Actions:"
    echo "────────────────────────"
    
    if echo "$ENABLED_FEATURES" | grep -q "webDashboard"; then
        echo "• Web Dashboard: Ensure HTTPS with valid certificates"
        echo "  Configure: hypervisor.webDashboard.tls.enable = true"
    fi
    
    if echo "$ENABLED_FEATURES" | grep -q "api"; then
        echo "• API Access: Implement rate limiting and API keys"
        echo "  Configure: hypervisor.api.rateLimit.enable = true"
    fi
    
    if echo "$ENABLED_FEATURES" | grep -q "remoteBackup"; then
        echo "• Remote Backup: Encrypt backups in transit and at rest"
        echo "  Configure: hypervisor.backup.encryption.enable = true"
    fi
}

# Interactive mode
interactive_mode() {
    while true; do
        clear
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║              Security Impact Visualizer                       ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo
        echo "Security Profile: $SECURITY_PROFILE"
        draw_security_meter "$RISK_SCORE"
        echo
        echo "1) View Attack Surface Map"
        echo "2) Show Feature Risk Matrix"
        echo "3) Security Recommendations"
        echo "4) Export Security Report"
        echo "5) Real-time Monitoring"
        echo "Q) Quit"
        echo
        read -p "Select option: " choice
        
        case "$choice" in
            1)
                clear
                show_attack_surface
                ;;
            2)
                clear
                show_risk_matrix
                ;;
            3)
                clear
                show_recommendations
                ;;
            4)
                export_report
                ;;
            5)
                realtime_monitor
                ;;
            [Qq])
                exit 0
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Export comprehensive security report
export_report() {
    local report_file="/tmp/hypervisor-security-report-$(date +%Y%m%d-%H%M%S).html"
    
    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Hyper-NixOS Security Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .risk-minimal { color: green; }
        .risk-low { color: blue; }
        .risk-moderate { color: orange; }
        .risk-high { color: darkorange; }
        .risk-critical { color: red; }
        .feature-enabled { font-weight: bold; }
        .meter { 
            width: 400px; 
            height: 30px; 
            border: 1px solid #ccc;
            background: linear-gradient(to right, 
                green 0%, green 20%, 
                yellow 20%, yellow 40%, 
                orange 40%, orange 60%,
                red 60%, red 100%);
        }
        .meter-fill {
            height: 100%;
            background: rgba(255,255,255,0.8);
            float: right;
        }
    </style>
</head>
<body>
    <h1>Hyper-NixOS Security Report</h1>
    <p>Generated: $(date)</p>
    
    <h2>Security Profile: $SECURITY_PROFILE</h2>
    <p>Risk Score: $RISK_SCORE</p>
    
    <div class="meter">
        <div class="meter-fill" style="width: $((100 - RISK_SCORE * 2))%"></div>
    </div>
    
    <h2>Enabled Features</h2>
    <ul>
$(for feature in $ENABLED_FEATURES; do
    echo "        <li class='feature-enabled'>$feature</li>"
done)
    </ul>
    
    <h2>Recommendations</h2>
    <p>See attached recommendations based on your configuration.</p>
</body>
</html>
EOF
    
    echo "Report exported to: $report_file"
    echo "Open with: xdg-open $report_file"
}

# Real-time monitoring mode
realtime_monitor() {
    echo "Real-time Security Monitoring"
    echo "Press Ctrl+C to exit"
    echo
    
    while true; do
        # Monitor for security-relevant events
        echo -n "$(date '+%H:%M:%S') "
        
        # Check for failed auth attempts
        local failed_auth=$(journalctl -u sshd -n 1 --no-pager | grep -c "Failed" || true)
        if [[ $failed_auth -gt 0 ]]; then
            echo -e "${RED}[AUTH]${NC} Failed authentication attempt detected"
        fi
        
        # Check for new VM starts
        local new_vms=$(virsh event --all --event lifecycle --timeout 1 2>/dev/null | grep -c "Started" || true)
        if [[ $new_vms -gt 0 ]]; then
            echo -e "${YELLOW}[VM]${NC} New VM started"
        fi
        
        # Check API access if enabled
        if echo "$ENABLED_FEATURES" | grep -q "api"; then
            local api_requests=$(journalctl -u hypervisor-api -n 1 --no-pager | grep -c "request" || true)
            if [[ $api_requests -gt 0 ]]; then
                echo -e "${BLUE}[API]${NC} API request logged"
            fi
        fi
        
        sleep 1
    done
}

# Main execution
main() {
    load_config
    
    case "${1:-interactive}" in
        --matrix)
            show_risk_matrix
            ;;
        --surface)
            show_attack_surface
            ;;
        --recommendations)
            show_recommendations
            ;;
        --export)
            export_report
            ;;
        --monitor)
            realtime_monitor
            ;;
        *)
            interactive_mode
            ;;
    esac
}

main "$@"