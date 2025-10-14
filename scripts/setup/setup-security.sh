#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Security Framework Setup
# Safe installation with proper naming

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Installation directory
readonly INSTALL_DIR="$HOME/security"
readonly BIN_DIR="$HOME/.local/bin"

# Ensure we're not overwriting system commands
check_conflicts() {
    echo "Checking for conflicts..."
    
    local commands=("sec" "sec-scan" "sec-check" "sec-comply" "sec-vuln")
    local conflicts=()
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            conflicts+=("$cmd")
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: The following commands already exist:${NC}"
        printf '%s\n' "${conflicts[@]}"
        echo
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 1
        fi
    fi
}

# Create directory structure
create_directories() {
    echo "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"/{scripts,configs,policies,logs,reports}
    mkdir -p "$BIN_DIR"
    
    # Ensure logs directory has proper permissions
    chmod 750 "$INSTALL_DIR/logs"
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Install main scripts
install_scripts() {
    echo "Installing security scripts..."
    
    # Copy main control script
    if [[ -f "sec" ]]; then
        cp sec "$INSTALL_DIR/sec"
        chmod +x "$INSTALL_DIR/sec"
        ln -sf "$INSTALL_DIR/sec" "$BIN_DIR/sec"
        echo -e "${GREEN}✓ Installed sec (main control)${NC}"
    fi
    
    # Copy scanner
    if [[ -f "sec-scan" ]]; then
        cp sec-scan "$INSTALL_DIR/scripts/sec-scan"
        chmod +x "$INSTALL_DIR/scripts/sec-scan"
        ln -sf "$INSTALL_DIR/scripts/sec-scan" "$BIN_DIR/sec-scan"
        echo -e "${GREEN}✓ Installed sec-scan (network scanner)${NC}"
    fi
    
    # Copy checker
    if [[ -f "sec-check" ]]; then
        cp sec-check "$INSTALL_DIR/scripts/sec-check"
        chmod +x "$INSTALL_DIR/scripts/sec-check"
        ln -sf "$INSTALL_DIR/scripts/sec-check" "$BIN_DIR/sec-check"
        echo -e "${GREEN}✓ Installed sec-check (security checker)${NC}"
    fi
    
    # Copy other scripts with safe names
    local script_mappings=(
        "scripts/security/container-security-manager.sh:sec-containers"
        "scripts/security/compliance-manager.sh:sec-comply"
        "scripts/security/vulnerability-management-system.py:vuln-check"
        "scripts/security/run-security-pipeline.sh:sec-test"
    )
    
    for mapping in "${script_mappings[@]}"; do
        local src="${mapping%%:*}"
        local dst="${mapping##*:}"
        
        if [[ -f "$src" ]]; then
            cp "$src" "$INSTALL_DIR/scripts/$dst"
            chmod +x "$INSTALL_DIR/scripts/$dst"
            echo -e "${GREEN}✓ Installed $dst${NC}"
        fi
    done
}

# Install configurations
install_configs() {
    echo "Installing configurations..."
    
    # Copy policy files
    if [[ -d "scripts/security/policies" ]]; then
        cp -r scripts/security/policies/* "$INSTALL_DIR/policies/" 2>/dev/null || true
    fi
    
    # Copy pipeline configurations
    if [[ -d "scripts/security/pipelines" ]]; then
        cp -r scripts/security/pipelines "$INSTALL_DIR/configs/" 2>/dev/null || true
    fi
    
    # Create default config
    cat > "$INSTALL_DIR/configs/security.conf" << EOF
# Security Framework Configuration
SECURITY_HOME="$INSTALL_DIR"
LOG_DIR="$INSTALL_DIR/logs"
REPORT_DIR="$INSTALL_DIR/reports"

# Alert settings
ALERT_EMAIL=""
WEBHOOK_URL=""

# Scan defaults
DEFAULT_SCAN_MODE="quick"
DEFAULT_CHECK_TYPE="all"
EOF
    
    echo -e "${GREEN}✓ Configurations installed${NC}"
}

# Setup shell integration
setup_shell() {
    echo "Setting up shell integration..."
    
    # Copy aliases file
    cp security-aliases.sh "$INSTALL_DIR/security-aliases.sh"
    
    # Create activation script
    cat > "$INSTALL_DIR/activate.sh" << EOF
#!/bin/bash
# Security Framework Activation

# Add bin directory to PATH
export PATH="\$HOME/.local/bin:\$PATH"

# Load security aliases
source "$INSTALL_DIR/security-aliases.sh"

# Set security home
export SECURITY_HOME="$INSTALL_DIR"
EOF
    
    # Add to shell RC files
    local shell_configs=(".bashrc" ".zshrc")
    local activation_line="source $INSTALL_DIR/activate.sh"
    
    for rc_file in "${shell_configs[@]}"; do
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

# Install dependencies
install_dependencies() {
    echo "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for required tools
    local required_tools=("python3" "nmap" "curl" "jq")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing dependencies: ${missing_deps[*]}${NC}"
        echo "Install with:"
        echo "  sudo apt update"
        echo "  sudo apt install ${missing_deps[*]}"
        
        read -p "Install now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt update
            sudo apt install -y "${missing_deps[@]}"
        fi
    else
        echo -e "${GREEN}✓ All dependencies satisfied${NC}"
    fi
    
    # Check for optional tools
    echo
    echo "Optional tools status:"
    local optional_tools=("docker" "trivy" "lynis" "fail2ban")
    
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "  $tool: ${GREEN}✓ Installed${NC}"
        else
            echo -e "  $tool: ${YELLOW}Not installed${NC}"
        fi
    done
}

# Create systemd service (optional)
create_service() {
    echo
    read -p "Create systemd service for continuous monitoring? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat > /tmp/security-monitor.service << EOF
[Unit]
Description=Security Monitoring Service
After=network.target

[Service]
Type=simple
User=$USER
Environment="PATH=$BIN_DIR:/usr/local/bin:/usr/bin:/bin"
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/scripts/sec-monitor
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
        
        sudo mv /tmp/security-monitor.service /etc/systemd/system/
        sudo systemctl daemon-reload
        echo -e "${GREEN}✓ Systemd service created${NC}"
        echo "  Start with: sudo systemctl start security-monitor"
        echo "  Enable with: sudo systemctl enable security-monitor"
    fi
}

# Main installation
main() {
    clear
    echo -e "${BLUE}Security Framework Setup${NC}"
    echo "======================="
    echo
    echo "This will install the security framework to: $INSTALL_DIR"
    echo "Commands will be added to: $BIN_DIR"
    echo
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Run installation steps
    check_conflicts
    create_directories
    install_scripts
    install_configs
    setup_shell
    install_dependencies
    create_service
    
    # Final message
    echo
    echo -e "${GREEN}Installation Complete!${NC}"
    echo "====================="
    echo
    echo "To activate the security framework:"
    echo "  source ~/.bashrc"
    echo "  # or"
    echo "  source $INSTALL_DIR/activate.sh"
    echo
    echo "Quick start:"
    echo "  sec-commands    # Show all available commands"
    echo "  sec            # Open control panel"
    echo "  sec-check      # Run security check"
    echo "  sec-scan       # Run network scan"
    echo
    echo "Documentation: $INSTALL_DIR/README.md"
}

# Create README
create_readme() {
    cat > "$INSTALL_DIR/README.md" << 'EOF'
# Security Framework

## Quick Start

After installation, use these commands:

- `sec` - Main security control panel
- `sec-check` - Check system security
- `sec-scan` - Scan network targets
- `sec-commands` - Show all available commands

## Command Reference

### Main Commands
- `sec status` - Security status overview
- `sec scan` - Run security scans
- `sec fix` - Auto-fix security issues
- `sec report` - Generate reports

### Scanning
- `sec-scan <target>` - Scan network target
- `sec-scan-quick <target>` - Quick scan
- `sec-scan-full <target>` - Full port scan
- `sec-scan-web <target>` - Web service scan

### Security Checking
- `sec-check` - Full security check
- `sec-check system` - System only
- `sec-check containers` - Containers only
- `sec-check --quick` - Quick check

### Other Tools
- `sec-comply` - Compliance checking
- `sec-containers` - Container security
- `sec-vuln` - Vulnerability scanning
- `sec-test` - Security testing pipelines

## Configuration

Edit `~/security/configs/security.conf` to customize settings.

## Logs and Reports

- Logs: `~/security/logs/`
- Reports: `~/security/reports/`

## Troubleshooting

If commands are not found:
1. Run: `source ~/.bashrc`
2. Check PATH: `echo $PATH | grep .local/bin`
3. Manually add to PATH: `export PATH="$HOME/.local/bin:$PATH"`
EOF
}

# Run main installation
main
create_readme