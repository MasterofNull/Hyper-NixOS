#!/bin/bash
# Security Framework Profile Selector
# Dynamically adjust security features based on system role

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration file
CONFIG_FILE="${SECURITY_CONFIG:-$HOME/.security/profile.conf}"

# Show current profile
show_current_profile() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local current=$(grep "PROFILE=" "$CONFIG_FILE" | cut -d'=' -f2)
        local memory=$(grep "MAX_MEMORY=" "$CONFIG_FILE" | cut -d'=' -f2)
        local modules=$(grep "ENABLED_MODULES=" "$CONFIG_FILE" | cut -d'=' -f2)
        
        echo -e "${BOLD}Current Security Profile${NC}"
        echo "========================"
        echo -e "Profile: ${GREEN}$current${NC}"
        echo -e "Memory Limit: ${YELLOW}$memory${NC}"
        echo -e "Enabled Modules: ${BLUE}$modules${NC}"
        echo
        
        # Show resource usage
        echo -e "${BOLD}Current Resource Usage${NC}"
        echo "====================="
        
        # Memory usage
        local mem_used=$(free -m | awk '/^Mem:/ {print $3}')
        local mem_total=$(free -m | awk '/^Mem:/ {print $2}')
        local mem_percent=$((mem_used * 100 / mem_total))
        echo -e "Memory: ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"
        
        # CPU usage
        local cpu_percent=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        echo -e "CPU: ${cpu_percent}%"
        
        # Disk usage
        local disk_used=$(df -h / | awk 'NR==2 {print $3}')
        local disk_total=$(df -h / | awk 'NR==2 {print $2}')
        local disk_percent=$(df -h / | awk 'NR==2 {print $5}')
        echo -e "Disk: ${disk_used} / ${disk_total} (${disk_percent})"
    else
        echo "No profile configured. Run with --select to choose a profile."
    fi
}

# Select profile interactively
select_profile() {
    echo -e "${BOLD}Security Framework Profile Selector${NC}"
    echo "==================================="
    echo
    echo "Select a profile based on your system role:"
    echo
    echo -e "${GREEN}1. Minimal${NC} - Lightweight security for constrained environments"
    echo "   • Memory: < 512MB"
    echo "   • Use cases: Containers, IoT, embedded systems"
    echo "   • Modules: Core scanning and monitoring only"
    echo
    echo -e "${BLUE}2. Standard${NC} - Balanced security for general systems"
    echo "   • Memory: < 2GB"
    echo "   • Use cases: Servers, workstations, VMs"
    echo "   • Modules: + Container security, compliance"
    echo
    echo -e "${CYAN}3. Advanced${NC} - Comprehensive security for critical systems"
    echo "   • Memory: < 4GB"
    echo "   • Use cases: Security operations, critical infrastructure"
    echo "   • Modules: + AI detection, forensics, API security"
    echo
    echo -e "${YELLOW}4. Enterprise${NC} - Full-featured for large deployments"
    echo "   • Memory: < 16GB"
    echo "   • Use cases: Enterprise SOC, multi-cloud environments"
    echo "   • Modules: All features enabled"
    echo
    echo -e "${BOLD}5. Custom${NC} - Build your own profile"
    echo
    
    read -p "Select profile [1-5]: " choice
    
    case $choice in
        1) configure_minimal ;;
        2) configure_standard ;;
        3) configure_advanced ;;
        4) configure_enterprise ;;
        5) configure_custom ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
}

# Configure minimal profile
configure_minimal() {
    echo -e "${GREEN}Configuring Minimal Profile...${NC}"
    
    cat > "$CONFIG_FILE" << EOF
# Security Framework Profile Configuration
PROFILE=minimal
MAX_MEMORY=512M
MAX_CPU_PERCENT=25
ENABLED_MODULES="core,cli,scanner,checker,monitor"

# Feature flags
ENABLE_AI=false
ENABLE_FORENSICS=false
ENABLE_CLOUD=false
ENABLE_ORCHESTRATION=false

# Performance settings
PARALLEL_SCANS=1
SCAN_TIMEOUT=300
MONITOR_INTERVAL=60
LOG_RETENTION_DAYS=7

# Security settings
AUTO_REMEDIATE=false
BLOCK_ON_CRITICAL=false
ALERT_THRESHOLD=high
EOF
    
    apply_profile
}

# Configure standard profile
configure_standard() {
    echo -e "${BLUE}Configuring Standard Profile...${NC}"
    
    cat > "$CONFIG_FILE" << EOF
# Security Framework Profile Configuration
PROFILE=standard
MAX_MEMORY=2048M
MAX_CPU_PERCENT=50
ENABLED_MODULES="core,cli,scanner,checker,monitor,containers,compliance,dashboard"

# Feature flags
ENABLE_AI=false
ENABLE_FORENSICS=false
ENABLE_CLOUD=false
ENABLE_ORCHESTRATION=false

# Performance settings
PARALLEL_SCANS=2
SCAN_TIMEOUT=600
MONITOR_INTERVAL=30
LOG_RETENTION_DAYS=30

# Security settings
AUTO_REMEDIATE=true
BLOCK_ON_CRITICAL=true
ALERT_THRESHOLD=medium
EOF
    
    apply_profile
}

# Configure advanced profile
configure_advanced() {
    echo -e "${CYAN}Configuring Advanced Profile...${NC}"
    
    cat > "$CONFIG_FILE" << EOF
# Security Framework Profile Configuration
PROFILE=advanced
MAX_MEMORY=4096M
MAX_CPU_PERCENT=75
ENABLED_MODULES="core,cli,scanner,checker,monitor,containers,compliance,dashboard,ai_detection,forensics,api_security"

# Feature flags
ENABLE_AI=true
ENABLE_FORENSICS=true
ENABLE_CLOUD=false
ENABLE_ORCHESTRATION=false

# Performance settings
PARALLEL_SCANS=4
SCAN_TIMEOUT=1200
MONITOR_INTERVAL=15
LOG_RETENTION_DAYS=90

# Security settings
AUTO_REMEDIATE=true
BLOCK_ON_CRITICAL=true
ALERT_THRESHOLD=low
EOF
    
    apply_profile
}

# Configure enterprise profile
configure_enterprise() {
    echo -e "${YELLOW}Configuring Enterprise Profile...${NC}"
    
    cat > "$CONFIG_FILE" << EOF
# Security Framework Profile Configuration
PROFILE=enterprise
MAX_MEMORY=16384M
MAX_CPU_PERCENT=90
ENABLED_MODULES="all"

# Feature flags
ENABLE_AI=true
ENABLE_FORENSICS=true
ENABLE_CLOUD=true
ENABLE_ORCHESTRATION=true

# Performance settings
PARALLEL_SCANS=8
SCAN_TIMEOUT=3600
MONITOR_INTERVAL=5
LOG_RETENTION_DAYS=365

# Security settings
AUTO_REMEDIATE=true
BLOCK_ON_CRITICAL=true
ALERT_THRESHOLD=info
EOF
    
    apply_profile
}

# Configure custom profile
configure_custom() {
    echo -e "${BOLD}Custom Profile Configuration${NC}"
    echo "=========================="
    
    # Memory limit
    read -p "Maximum memory (MB) [512-16384]: " memory
    memory=${memory:-1024}
    
    # CPU limit
    read -p "Maximum CPU percent [10-100]: " cpu
    cpu=${cpu:-50}
    
    # Select modules
    echo
    echo "Available modules:"
    echo "1. scanner - Network and vulnerability scanning"
    echo "2. checker - System security checking"
    echo "3. monitor - Real-time monitoring"
    echo "4. containers - Container security"
    echo "5. compliance - Compliance checking"
    echo "6. dashboard - Web dashboard"
    echo "7. ai_detection - AI-powered threat detection"
    echo "8. forensics - Digital forensics"
    echo "9. api_security - API gateway security"
    echo "10. cloud - Multi-cloud security"
    echo
    read -p "Select modules (comma-separated numbers): " module_nums
    
    # Convert numbers to module names
    local modules="core,cli"
    for num in ${module_nums//,/ }; do
        case $num in
            1) modules+=",scanner" ;;
            2) modules+=",checker" ;;
            3) modules+=",monitor" ;;
            4) modules+=",containers" ;;
            5) modules+=",compliance" ;;
            6) modules+=",dashboard" ;;
            7) modules+=",ai_detection" ;;
            8) modules+=",forensics" ;;
            9) modules+=",api_security" ;;
            10) modules+=",cloud" ;;
        esac
    done
    
    # Create custom configuration
    cat > "$CONFIG_FILE" << EOF
# Security Framework Profile Configuration
PROFILE=custom
MAX_MEMORY=${memory}M
MAX_CPU_PERCENT=$cpu
ENABLED_MODULES="$modules"

# Feature flags
ENABLE_AI=$(echo "$modules" | grep -q "ai_detection" && echo "true" || echo "false")
ENABLE_FORENSICS=$(echo "$modules" | grep -q "forensics" && echo "true" || echo "false")
ENABLE_CLOUD=$(echo "$modules" | grep -q "cloud" && echo "true" || echo "false")
ENABLE_ORCHESTRATION=false

# Performance settings
PARALLEL_SCANS=2
SCAN_TIMEOUT=600
MONITOR_INTERVAL=30
LOG_RETENTION_DAYS=30

# Security settings
AUTO_REMEDIATE=false
BLOCK_ON_CRITICAL=false
ALERT_THRESHOLD=medium
EOF
    
    apply_profile
}

# Apply profile configuration
apply_profile() {
    echo
    echo "Applying profile configuration..."
    
    # Source the configuration
    source "$CONFIG_FILE"
    
    # Create systemd service override
    if [[ -d "/etc/systemd/system" ]]; then
        sudo mkdir -p /etc/systemd/system/security-framework.service.d
        sudo cat > /etc/systemd/system/security-framework.service.d/profile.conf << EOF
[Service]
Environment="SECURITY_PROFILE=$PROFILE"
Environment="SECURITY_CONFIG=$CONFIG_FILE"
MemoryMax=$MAX_MEMORY
CPUQuota=$MAX_CPU_PERCENT%
EOF
        sudo systemctl daemon-reload
    fi
    
    # Update module symlinks
    local security_dir="${SECURITY_HOME:-$HOME/.security}"
    mkdir -p "$security_dir/enabled-modules"
    rm -f "$security_dir/enabled-modules"/*
    
    IFS=',' read -ra MODULES <<< "$ENABLED_MODULES"
    for module in "${MODULES[@]}"; do
        if [[ -d "$security_dir/modules/$module" ]]; then
            ln -s "../modules/$module" "$security_dir/enabled-modules/$module"
        fi
    done
    
    echo -e "${GREEN}Profile applied successfully!${NC}"
    echo
    show_current_profile
}

# Auto-detect best profile
auto_detect() {
    echo "Auto-detecting optimal profile..."
    
    # Get system resources
    local total_memory=$(free -m | awk '/^Mem:/ {print $2}')
    local cpu_cores=$(nproc)
    local is_container=$(systemd-detect-virt -c 2>/dev/null || echo "none")
    local is_vm=$(systemd-detect-virt -v 2>/dev/null || echo "none")
    
    echo "System detected:"
    echo "  Memory: ${total_memory}MB"
    echo "  CPU cores: $cpu_cores"
    echo "  Container: $is_container"
    echo "  VM: $is_vm"
    echo
    
    # Determine profile
    if [[ "$is_container" != "none" ]] || [[ $total_memory -lt 1024 ]]; then
        echo "Recommended: Minimal profile"
        configure_minimal
    elif [[ $total_memory -lt 4096 ]]; then
        echo "Recommended: Standard profile"
        configure_standard
    elif [[ $total_memory -lt 8192 ]]; then
        echo "Recommended: Advanced profile"
        configure_advanced
    else
        echo "Recommended: Enterprise profile"
        configure_enterprise
    fi
}

# Main execution
main() {
    case "${1:-}" in
        --show|status)
            show_current_profile
            ;;
        --select|select)
            select_profile
            ;;
        --auto|auto)
            auto_detect
            ;;
        --minimal)
            configure_minimal
            ;;
        --standard)
            configure_standard
            ;;
        --advanced)
            configure_advanced
            ;;
        --enterprise)
            configure_enterprise
            ;;
        --help|-h)
            echo "Security Framework Profile Selector"
            echo
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --show         Show current profile"
            echo "  --select       Select profile interactively"
            echo "  --auto         Auto-detect optimal profile"
            echo "  --minimal      Apply minimal profile"
            echo "  --standard     Apply standard profile"
            echo "  --advanced     Apply advanced profile"
            echo "  --enterprise   Apply enterprise profile"
            echo "  --help         Show this help"
            ;;
        *)
            show_current_profile
            echo
            echo "Run with --select to change profile or --help for options"
            ;;
    esac
}

# Create directory
mkdir -p "$(dirname "$CONFIG_FILE")"

# Run main
main "$@"