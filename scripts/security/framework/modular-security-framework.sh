#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Modular Security Framework Installer
# Scalable from lightweight to enterprise

set -e

# Colors and styling
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Framework profiles
readonly PROFILE_MINIMAL="minimal"
readonly PROFILE_STANDARD="standard"
readonly PROFILE_ADVANCED="advanced"
readonly PROFILE_ENTERPRISE="enterprise"

# Resource limits by profile
readonly MAX_MEMORY_MINIMAL="512M"
readonly MAX_MEMORY_STANDARD="2048M"
readonly MAX_MEMORY_ADVANCED="4096M"
readonly MAX_MEMORY_ENTERPRISE="16384M"

readonly MAX_CPU_MINIMAL="25"
readonly MAX_CPU_STANDARD="50"
readonly MAX_CPU_ADVANCED="75"
readonly MAX_CPU_ENTERPRISE="90"

# Installation directory
INSTALL_DIR="${SECURITY_HOME:-$HOME/.security}"
CONFIG_DIR="$INSTALL_DIR/config"
MODULES_DIR="$INSTALL_DIR/modules"

# Show banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ███████╗███████╗ ██████╗    ███████╗██████╗  █████╗ ███╗   ███╗███████╗ ║
║   ██╔════╝██╔════╝██╔════╝    ██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝ ║
║   ███████╗█████╗  ██║         █████╗  ██████╔╝███████║██╔████╔██║█████╗   ║
║   ╚════██║██╔══╝  ██║         ██╔══╝  ██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝   ║
║   ███████║███████╗╚██████╗    ██║     ██║  ██║██║  ██║██║ ╚═╝ ██║███████╗ ║
║   ╚══════╝╚══════╝ ╚═════╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝ ║
║                                                               ║
║                  Modular Security Framework v2.0              ║
║                     Scalable • Modular • Powerful             ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Profile descriptions
show_profiles() {
    echo -e "${BOLD}Available Installation Profiles:${NC}"
    echo
    echo -e "${GREEN}1. Minimal${NC} (< 50MB)"
    echo "   • Core security scanning"
    echo "   • Basic monitoring"
    echo "   • Essential CLI tools"
    echo "   • Perfect for: Hypervisors, containers, IoT"
    echo
    echo -e "${BLUE}2. Standard${NC} (< 200MB)"
    echo "   • Everything in Minimal +"
    echo "   • Container security"
    echo "   • Compliance checking"
    echo "   • Enhanced monitoring"
    echo "   • Perfect for: Servers, workstations"
    echo
    echo -e "${PURPLE}3. Advanced${NC} (< 500MB)"
    echo "   • Everything in Standard +"
    echo "   • AI threat detection"
    echo "   • Forensics toolkit"
    echo "   • API security"
    echo "   • Perfect for: Security teams, SOC"
    echo
    echo -e "${YELLOW}4. Enterprise${NC} (< 1GB)"
    echo "   • Everything in Advanced +"
    echo "   • Multi-cloud support"
    echo "   • Zero-trust components"
    echo "   • Full automation suite"
    echo "   • Perfect for: Large organizations"
    echo
    echo -e "${CYAN}5. Custom${NC}"
    echo "   • Choose individual modules"
    echo "   • Fine-grained control"
    echo "   • Perfect for: Specific use cases"
    echo
}

# Module definitions
declare -A MODULES=(
    # Core modules (Minimal)
    ["core"]="Core security framework|10MB|required"
    ["cli"]="Enhanced CLI with autocomplete|5MB|required"
    ["scanner"]="Network security scanner|15MB|minimal"
    ["checker"]="System security checker|10MB|minimal"
    ["monitor"]="Basic monitoring|20MB|minimal"
    
    # Standard modules
    ["containers"]="Container security|30MB|standard"
    ["compliance"]="Compliance framework|25MB|standard"
    ["dashboard"]="Security dashboard|40MB|standard"
    ["automation"]="Basic automation|20MB|standard"
    
    # Advanced modules
    ["ai_detection"]="AI-powered threat detection|100MB|advanced"
    ["forensics"]="Digital forensics toolkit|80MB|advanced"
    ["api_security"]="API gateway security|50MB|advanced"
    ["threat_hunt"]="Threat hunting platform|60MB|advanced"
    
    # Enterprise modules
    ["multi_cloud"]="Multi-cloud security|150MB|enterprise"
    ["zero_trust"]="Zero-trust architecture|200MB|enterprise"
    ["orchestration"]="Full orchestration suite|100MB|enterprise"
    ["reporting"]="Enterprise reporting|80MB|enterprise"
)

# Get modules for profile
get_profile_modules() {
    local profile=$1
    local modules=()
    
    case $profile in
        minimal)
            modules=("core" "cli" "scanner" "checker" "monitor")
            ;;
        standard)
            modules=("core" "cli" "scanner" "checker" "monitor" 
                    "containers" "compliance" "dashboard" "automation")
            ;;
        advanced)
            modules=("core" "cli" "scanner" "checker" "monitor" 
                    "containers" "compliance" "dashboard" "automation"
                    "ai_detection" "forensics" "api_security" "threat_hunt")
            ;;
        enterprise)
            modules=("${!MODULES[@]}")
            ;;
    esac
    
    echo "${modules[@]}"
}

# Calculate installation size
calculate_size() {
    local modules=($@)
    local total_size=0
    
    for module in "${modules[@]}"; do
        local module_info="${MODULES[$module]}"
        local size=$(echo "$module_info" | cut -d'|' -f2 | sed 's/MB//')
        total_size=$((total_size + size))
    done
    
    echo "${total_size}MB"
}

# Install module
install_module() {
    local module=$1
    local module_info="${MODULES[$module]}"
    local description=$(echo "$module_info" | cut -d'|' -f1)
    
    echo -e "${YELLOW}Installing: ${description}${NC}"
    
    # Create module directory
    mkdir -p "$MODULES_DIR/$module"
    
    # Simulate installation (in real implementation, download/extract here)
    case $module in
        core)
            install_core_module
            ;;
        cli)
            install_cli_module
            ;;
        scanner)
            install_scanner_module
            ;;
        checker)
            install_checker_module
            ;;
        monitor)
            install_monitor_module
            ;;
        containers)
            install_containers_module
            ;;
        compliance)
            install_compliance_module
            ;;
        ai_detection)
            install_ai_module
            ;;
        *)
            # Generic installation
            touch "$MODULES_DIR/$module/.installed"
            ;;
    esac
    
    echo -e "${GREEN}✓ Installed $module${NC}"
}

# Core module installation
install_core_module() {
    # Create directory structure
    mkdir -p "$INSTALL_DIR"/{bin,lib,config,logs,data}
    
    # Install core framework
    cat > "$INSTALL_DIR/bin/sec-framework" << 'EOF'
#!/bin/bash
# Security Framework Core
SECURITY_HOME="${SECURITY_HOME:-$HOME/.security}"
source "$SECURITY_HOME/lib/framework.sh"
main "$@"
EOF
    chmod +x "$INSTALL_DIR/bin/sec-framework"
    
    # Core libraries
    cat > "$INSTALL_DIR/lib/framework.sh" << 'EOF'
# Core framework functions
load_modules() {
    for module in "$SECURITY_HOME/modules"/*/init.sh; do
        [[ -f "$module" ]] && source "$module"
    done
}

main() {
    load_modules
    if [[ -z "$1" ]]; then
        show_menu
    else
        execute_command "$@"
    fi
}
EOF
}

# CLI module installation
install_cli_module() {
    # Enhanced prompt
    cat > "$INSTALL_DIR/config/prompt.sh" << 'EOF'
# Enhanced security prompt with git-like features
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

security_prompt() {
    local last_exit=$?
    local red='\[\033[0;31m\]'
    local green='\[\033[0;32m\]'
    local yellow='\[\033[1;33m\]'
    local blue='\[\033[0;34m\]'
    local purple='\[\033[0;35m\]'
    local cyan='\[\033[0;36m\]'
    local reset='\[\033[0m\]'
    
    # Status indicator
    local status_color="$green"
    [[ $last_exit -ne 0 ]] && status_color="$red"
    
    # Security status
    local sec_status="[SEC:OK]"
    if [[ -f /tmp/security_alert ]]; then
        sec_status="${red}[SEC:ALERT]${reset}"
    fi
    
    PS1="${cyan}┌─${reset}${status_color}●${reset} ${blue}\u${reset}@${green}\h${reset} ${purple}\w${reset} ${yellow}$(parse_git_branch)${reset} $sec_status\n${cyan}└─>${reset} "
}

PROMPT_COMMAND=security_prompt
EOF
    
    # Auto-completion
    cat > "$INSTALL_DIR/config/completion.bash" << 'EOF'
# Security framework bash completion
_sec_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    local commands="scan check monitor report fix help status"
    
    # Sub-commands
    case "${prev}" in
        scan)
            opts="network containers web api quick deep"
            ;;
        check)
            opts="system compliance vulnerabilities all"
            ;;
        monitor)
            opts="start stop status logs events"
            ;;
        *)
            opts="$commands"
            ;;
    esac
    
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

complete -F _sec_completion sec
complete -F _sec_completion security
EOF
    
    # Aliases and functions
    cat > "$INSTALL_DIR/config/aliases.sh" << 'EOF'
# Security aliases
alias sec='security'
alias scs='sec scan'
alias scc='sec check'
alias scm='sec monitor'
alias scr='sec report'

# Quick functions
scan-local() { sec scan 127.0.0.1 --quick; }
check-all() { sec check --all --report; }
monitor-tail() { sec monitor logs --tail -f; }

# Colored output helpers
sec-info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
sec-warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
sec-error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; }
sec-success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
EOF
}

# Scanner module installation
install_scanner_module() {
    cat > "$MODULES_DIR/scanner/init.sh" << 'EOF'
# Scanner module initialization
scanner_commands() {
    case "$1" in
        network) scan_network "$@" ;;
        web) scan_web "$@" ;;
        quick) quick_scan "$@" ;;
        *) scanner_help ;;
    esac
}

register_command "scan" scanner_commands
EOF
}

# Checker module installation
install_checker_module() {
    cat > "$MODULES_DIR/checker/init.sh" << 'EOF'
# Checker module initialization
checker_commands() {
    case "$1" in
        system) check_system ;;
        compliance) check_compliance "$@" ;;
        vulns) check_vulnerabilities ;;
        *) checker_help ;;
    esac
}

register_command "check" checker_commands
EOF
}

# Monitor module installation
install_monitor_module() {
    cat > "$MODULES_DIR/monitor/init.sh" << 'EOF'
# Monitor module initialization
monitor_commands() {
    case "$1" in
        start) start_monitoring ;;
        stop) stop_monitoring ;;
        status) monitor_status ;;
        *) monitor_help ;;
    esac
}

register_command "monitor" monitor_commands
EOF
}

# Containers module installation
install_containers_module() {
    echo "Installing container security module..."
    # Container-specific security tools
}

# Compliance module installation
install_compliance_module() {
    echo "Installing compliance framework..."
    # Compliance checking tools
}

# AI module installation
install_ai_module() {
    echo "Installing AI threat detection..."
    # Machine learning models and frameworks
}

# Create activation script
create_activation_script() {
    local profile=$1
    
    cat > "$INSTALL_DIR/activate.sh" << EOF
#!/bin/bash
# Security Framework Activation Script
# Profile: $profile

# Set environment
export SECURITY_HOME="$INSTALL_DIR"
export SECURITY_PROFILE="$profile"
export PATH="\$SECURITY_HOME/bin:\$PATH"

# Load configurations
[[ -f "\$SECURITY_HOME/config/prompt.sh" ]] && source "\$SECURITY_HOME/config/prompt.sh"
[[ -f "\$SECURITY_HOME/config/completion.bash" ]] && source "\$SECURITY_HOME/config/completion.bash"
[[ -f "\$SECURITY_HOME/config/aliases.sh" ]] && source "\$SECURITY_HOME/config/aliases.sh"

# Initialize modules
for module in "\$SECURITY_HOME/modules"/*/init.sh; do
    [[ -f "\$module" ]] && source "\$module"
done

# Show status
echo -e "\033[0;32mSecurity Framework ($profile) activated!\033[0m"
echo "Type 'sec help' for available commands"
EOF
    
    chmod +x "$INSTALL_DIR/activate.sh"
}

# Interactive installation
interactive_install() {
    show_banner
    show_profiles
    
    echo -e "${BOLD}Select installation profile:${NC}"
    echo "1) Minimal"
    echo "2) Standard"
    echo "3) Advanced"
    echo "4) Enterprise"
    echo "5) Custom"
    echo
    read -p "Enter choice [1-5]: " choice
    
    case $choice in
        1) install_profile "minimal" ;;
        2) install_profile "standard" ;;
        3) install_profile "advanced" ;;
        4) install_profile "enterprise" ;;
        5) custom_install ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
}

# Install profile
install_profile() {
    local profile=$1
    local modules=($(get_profile_modules $profile))
    local total_size=$(calculate_size "${modules[@]}")
    
    echo
    echo -e "${BOLD}Installing $profile profile${NC}"
    echo -e "Modules: ${#modules[@]}"
    echo -e "Total size: ~$total_size"
    echo
    read -p "Continue? [y/N] " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Create directories
    mkdir -p "$INSTALL_DIR"/{bin,lib,config,modules,logs,data}
    
    # Install modules
    for module in "${modules[@]}"; do
        install_module "$module"
    done
    
    # Create activation script
    create_activation_script "$profile"
    
    # Setup shell integration
    setup_shell_integration
    
    echo
    echo -e "${GREEN}Installation complete!${NC}"
    echo
    echo "To activate the security framework:"
    echo "  source $INSTALL_DIR/activate.sh"
    echo
    echo "Or add to your shell profile:"
    echo "  echo 'source $INSTALL_DIR/activate.sh' >> ~/.bashrc"
}

# Custom installation
custom_install() {
    echo -e "${BOLD}Custom Installation${NC}"
    echo "Select modules to install:"
    echo
    
    local selected_modules=()
    local index=1
    
    # Always include core modules
    selected_modules+=("core" "cli")
    
    # Show available modules
    for module in "${!MODULES[@]}"; do
        if [[ "$module" != "core" && "$module" != "cli" ]]; then
            local module_info="${MODULES[$module]}"
            local description=$(echo "$module_info" | cut -d'|' -f1)
            local size=$(echo "$module_info" | cut -d'|' -f2)
            
            echo "$index) $module - $description ($size)"
            ((index++))
        fi
    done
    
    echo
    echo "Enter module numbers separated by spaces (e.g., 1 3 5):"
    read -a choices
    
    # Process selections
    for choice in "${choices[@]}"; do
        # Add selected module logic here
        echo "Selected: $choice"
    done
    
    # Install selected modules
    local total_size=$(calculate_size "${selected_modules[@]}")
    echo
    echo -e "Total installation size: ~$total_size"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_profile "custom"
    fi
}

# Setup shell integration
setup_shell_integration() {
    local shells=(".bashrc" ".zshrc")
    local activation_line="source $INSTALL_DIR/activate.sh"
    
    for rc_file in "${shells[@]}"; do
        if [[ -f "$HOME/$rc_file" ]]; then
            if ! grep -q "$activation_line" "$HOME/$rc_file"; then
                echo "" >> "$HOME/$rc_file"
                echo "# Security Framework" >> "$HOME/$rc_file"
                echo "$activation_line" >> "$HOME/$rc_file"
                echo -e "${GREEN}✓ Added to $rc_file${NC}"
            fi
        fi
    done
}

# Main execution
main() {
    case "${1:-}" in
        --minimal)
            install_profile "minimal"
            ;;
        --standard)
            install_profile "standard"
            ;;
        --advanced)
            install_profile "advanced"
            ;;
        --enterprise)
            install_profile "enterprise"
            ;;
        --uninstall)
            uninstall_framework
            ;;
        --help|-h)
            show_help
            ;;
        *)
            interactive_install
            ;;
    esac
}

# Show help
show_help() {
    echo "Security Framework Installer"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --minimal      Install minimal profile (< 50MB)"
    echo "  --standard     Install standard profile (< 200MB)"
    echo "  --advanced     Install advanced profile (< 500MB)"
    echo "  --enterprise   Install enterprise profile (< 1GB)"
    echo "  --uninstall    Remove security framework"
    echo "  --help         Show this help message"
    echo
    echo "Without options, runs interactive installer"
}

# Uninstall framework
uninstall_framework() {
    echo -e "${YELLOW}Uninstalling Security Framework${NC}"
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove from shell configs
        for rc_file in .bashrc .zshrc; do
            if [[ -f "$HOME/$rc_file" ]]; then
                sed -i '/# Security Framework/,+1d' "$HOME/$rc_file"
            fi
        done
        
        # Remove installation
        rm -rf "$INSTALL_DIR"
        
        echo -e "${GREEN}Security Framework uninstalled${NC}"
    else
        echo "Uninstall cancelled"
    fi
}

# Run main
main "$@"