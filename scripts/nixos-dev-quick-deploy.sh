#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform  
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: NixOS Development Environment Quick Deploy (HOME-MANAGER VERSION)
#
# Description:
#   Sets up a complete development environment using home-manager for proper
#   declarative configuration. Installs Claude Code, VSCodium, and modern CLI
#   tools with proper initialization.
#
# Usage:
#   bash nixos-dev-quick-deploy.sh
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

#!/usr/bin/env bash
# NixOS Development Environment Setup with VSCodium Extensions
# Packages installed are persistent but managed through user profile
# Run with: bash deploy-nixos.sh (no sudo needed for user env)

set -e  # Exit on error

echo "========================================="
echo "NixOS Development Environment Setup"
echo "========================================="
echo "Sets up persistent dev environment with"
echo "VSCodium, Claude Code, and extensions"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if NOT running as root (we want user environment)
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Warning: Running as root will install to root profile${NC}"
   echo -e "${YELLOW}For user environment, run without sudo${NC}"
   read -p "Continue anyway? (y/n) " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

echo -e "${YELLOW}Step 1: Setting up Nix channels and configuration...${NC}"

# Create ~/.config/nixpkgs directory if it doesn't exist
mkdir -p ~/.config/nixpkgs

# Enable unfree packages for user environment
echo "Enabling unfree packages..."
cat > ~/.config/nixpkgs/config.nix << 'EOF'
{
  allowUnfree = true;
}
EOF
echo -e "${GREEN}✓ Unfree packages enabled in ~/.config/nixpkgs/config.nix${NC}"

# Add nixos channel if not present (requires sudo)
if ! sudo nix-channel --list | grep -q nixos; then
    echo "Adding nixos channel..."
    sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos
fi

# Add nixpkgs channel for user environment (no sudo)
if ! nix-channel --list | grep -q "^nixpkgs"; then
    echo "Adding nixpkgs channel to user profile..."
    nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
fi

echo "Updating system channels..."
sudo nix-channel --update

echo "Updating user channels..."
nix-channel --update

echo "Channels configured:"
echo "System channels:"
sudo nix-channel --list
echo "User channels:"
nix-channel --list
echo -e "${GREEN}✓ Channels configured and updated${NC}"
echo ""

echo -e "${YELLOW}Step 2: Installing development packages to USER environment...${NC}"
echo -e "${BLUE}These will persist across reboots${NC}"

# Install packages to user profile (persistent)
nix-env -iA \
    nixpkgs.wget \
    nixpkgs.git \
    nixpkgs.vscodium \
    nixpkgs.vim \
    nixpkgs.neovim \
    nixpkgs.curl \
    nixpkgs.htop \
    nixpkgs.btop \
    nixpkgs.tree \
    nixpkgs.unzip \
    nixpkgs.zip \
    nixpkgs.gnumake \
    nixpkgs.gcc \
    nixpkgs.nodejs_22 \
    nixpkgs.ripgrep \
    nixpkgs.fd \
    nixpkgs.fzf \
    nixpkgs.bat \
    nixpkgs.eza \
    nixpkgs.bash \
    nixpkgs.jq \
    nixpkgs.yq \
    nixpkgs.python3 \
    nixpkgs.go \
    nixpkgs.rustc \
    nixpkgs.cargo

echo -e "${GREEN}✓ Development packages installed to user profile${NC}"
echo ""

echo -e "${YELLOW}Step 2b: Installing Claude Code via npm...${NC}"
# Claude Code needs to be installed via npm for proper PATH integration
# This ensures VSCodium can find it
export NPM_CONFIG_PREFIX=~/.npm-global
mkdir -p ~/.npm-global
export PATH=~/.npm-global/bin:$PATH

# Install Claude Code globally (creates 'claude' binary)
npm install -g @anthropic-ai/claude-code

# Verify installation
if [ -f ~/.npm-global/bin/claude ]; then
    echo -e "${GREEN}✓ Claude Code installed to ~/.npm-global/bin/claude${NC}"
    
    # Create claude-code symlink for consistency
    ln -sf ~/.npm-global/bin/claude ~/.npm-global/bin/claude-code
    echo -e "${GREEN}✓ Symlink created: claude-code -> claude${NC}"
    
    # Create a wrapper with absolute bash path for NixOS compatibility
    cat > ~/.npm-global/bin/claude-wrapper << 'WRAPPER_EOF'
#!/run/current-system/sw/bin/bash
exec "$HOME/.npm-global/bin/claude" "$@"
WRAPPER_EOF
    chmod +x ~/.npm-global/bin/claude-wrapper
    echo -e "${GREEN}✓ NixOS-compatible wrapper created at claude-wrapper${NC}"
    
    # Test the installation
    if bash ~/.npm-global/bin/claude --version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Claude Code is working correctly${NC}"
    else
        echo -e "${YELLOW}⚠ Claude Code installed but may need manual configuration${NC}"
    fi
else
    echo -e "${RED}✗ Claude Code installation failed${NC}"
    exit 1
fi

# Add to shell profile for persistence
if ! grep -q "NPM_CONFIG_PREFIX" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# NPM global packages" >> ~/.bashrc
    echo 'export NPM_CONFIG_PREFIX=~/.npm-global' >> ~/.bashrc
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
fi

if [ -f ~/.zshrc ] && ! grep -q "NPM_CONFIG_PREFIX" ~/.zshrc; then
    echo "" >> ~/.zshrc
    echo "# NPM global packages" >> ~/.zshrc
    echo 'export NPM_CONFIG_PREFIX=~/.npm-global' >> ~/.zshrc
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
fi
echo ""

echo -e "${YELLOW}Step 3: Creating VSCodium wrapper with proper PATH...${NC}"
# Create a wrapper script that ensures Claude Code is in PATH
mkdir -p ~/.local/bin

cat > ~/.local/bin/codium-wrapped << 'WRAPPER_EOF'
#!/usr/bin/env bash
# VSCodium wrapper that ensures Claude Code is in PATH
export NPM_CONFIG_PREFIX=~/.npm-global
export PATH=~/.npm-global/bin:$PATH
exec codium "$@"
WRAPPER_EOF

chmod +x ~/.local/bin/codium-wrapped

# Add ~/.local/bin to PATH if not already there
if ! grep -q "$HOME/.local/bin" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Local binaries" >> ~/.bashrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

if [ -f ~/.zshrc ] && ! grep -q "$HOME/.local/bin" ~/.zshrc; then
    echo "" >> ~/.zshrc
    echo "# Local binaries" >> ~/.zshrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
fi

echo -e "${GREEN}✓ VSCodium wrapper created at ~/.local/bin/codium-wrapped${NC}"
echo ""

echo -e "${YELLOW}Step 4: Installing VSCodium extensions...${NC}"

# Function to install extension with retry
install_extension() {
    local ext=$1
    local name=$2
    echo -e "${BLUE}Installing: ${name}${NC}"
    
    for i in {1..3}; do
        if codium --install-extension "$ext" 2>/dev/null; then
            echo -e "${GREEN}✓ ${name} installed${NC}"
            return 0
        else
            if [ $i -lt 3 ]; then
                echo -e "${YELLOW}Retry $i/3...${NC}"
                sleep 2
            fi
        fi
    done
    
    echo -e "${YELLOW}⚠ ${name} - install manually if needed${NC}"
    return 1
}

# Core extensions requested
echo "Installing requested extensions..."
install_extension "Anthropic.claude-code" "Claude Code"
install_extension "dbaeumer.vscode-eslint" "ESLint"
install_extension "mhutchie.git-graph" "Git Graph"
install_extension "eamodio.gitlens" "GitLens"
install_extension "golang.go" "Go"
install_extension "esbenp.prettier-vscode" "Prettier"
install_extension "rust-lang.rust-analyzer" "Rust Analyzer"

# NixOS-specific extensions
echo ""
echo "Installing NixOS development extensions..."
install_extension "jnoortheen.nix-ide" "Nix IDE"
install_extension "arrterian.nix-env-selector" "Nix Environment Selector"
install_extension "bbenoist.nix" "Nix Language Support"

# Additional valuable extensions for development
echo ""
echo "Installing additional productivity extensions..."
install_extension "usernamehw.errorlens" "Error Lens"
install_extension "github.copilot" "GitHub Copilot (if you have access)"
install_extension "ms-vscode.makefile-tools" "Makefile Tools"
install_extension "tamasfe.even-better-toml" "Even Better TOML"
install_extension "redhat.vscode-yaml" "YAML"
install_extension "mechatroner.rainbow-csv" "Rainbow CSV"
install_extension "streetsidesoftware.code-spell-checker" "Code Spell Checker"
install_extension "gruntfuggly.todo-tree" "Todo Tree"
install_extension "oderwat.indent-rainbow" "Indent Rainbow"
install_extension "pkief.material-icon-theme" "Material Icon Theme"
install_extension "github.vscode-github-actions" "GitHub Actions"
install_extension "ms-vscode-remote.remote-ssh" "Remote - SSH"

# DevOps and Infrastructure extensions
echo ""
echo "Installing DevOps/Infrastructure extensions..."
install_extension "redhat.vscode-xml" "XML"
install_extension "dotjoshjohnson.xml" "XML Tools"
install_extension "hashicorp.terraform" "Terraform (if using IaC)"
install_extension "ms-azuretools.vscode-docker" "Docker"

echo -e "${GREEN}✓ Extensions installation complete${NC}"
echo ""

echo -e "${YELLOW}Step 5: Creating VSCodium settings for Claude Code...${NC}"
# Create settings.json with Claude Code configuration
mkdir -p ~/.config/VSCodium/User

cat > ~/.config/VSCodium/User/settings.json << SETTINGS_EOF
{
  // Claude Code Configuration - NixOS compatible
  "claudeCode.executablePath": "$HOME/.npm-global/bin/claude-wrapper",
  "claudeCode.autoStart": false,
  
  // Editor Configuration
  "editor.fontSize": 14,
  "editor.fontFamily": "'Fira Code', 'Droid Sans Mono', 'monospace'",
  "editor.fontLigatures": true,
  "editor.formatOnSave": true,
  "editor.formatOnPaste": true,
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.detectIndentation": true,
  "editor.minimap.enabled": true,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,
  
  // Nix-specific settings
  "nix.enableLanguageServer": true,
  "nix.serverPath": "nil",
  "nix.formatterPath": "nixpkgs-fmt",
  "[nix]": {
    "editor.defaultFormatter": "jnoortheen.nix-ide",
    "editor.tabSize": 2
  },
  
  // Language-specific formatting
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[yaml]": {
    "editor.defaultFormatter": "redhat.vscode-yaml"
  },
  "[go]": {
    "editor.defaultFormatter": "golang.go"
  },
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust-analyzer"
  },
  
  // Git Configuration
  "git.enableSmartCommit": true,
  "git.confirmSync": false,
  "git.autofetch": true,
  "gitlens.hovers.currentLine.over": "line",
  
  // File Management
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  
  // Terminal
  "terminal.integrated.fontFamily": "monospace",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.shell.linux": "/run/current-system/sw/bin/bash",
  
  // Telemetry
  "telemetry.telemetryLevel": "off",
  
  // Workbench
  "workbench.iconTheme": "material-icon-theme",
  "workbench.colorTheme": "Default Dark+",
  
  // Error Lens
  "errorLens.enabledDiagnosticLevels": ["error", "warning"],
  
  // Security
  "security.workspace.trust.enabled": true
}
SETTINGS_EOF

echo -e "${GREEN}✓ VSCodium settings configured${NC}"
echo ""

echo -e "${YELLOW}Step 6: Upgrading NixOS system...${NC}"
sudo nixos-rebuild switch --upgrade
echo -e "${GREEN}✓ System upgraded${NC}"
echo ""

echo -e "${YELLOW}Step 7: Cleaning up old system generations...${NC}"
sudo nix-collect-garbage -d
echo -e "${GREEN}✓ Old generations cleaned${NC}"
echo ""

echo "========================================="
echo -e "${GREEN}Development Environment Ready!${NC}"
echo "========================================="
echo ""
echo "Installed packages:"
echo "  • Core: wget, git, curl, vim, neovim"
echo "  • VSCodium with extensions (see below)"
echo "  • Build tools: gcc, make, node.js 22 LTS"
echo "  • Modern CLI: ripgrep, fd, fzf, bat, eza, jq, yq"
echo "  • Languages: Python 3, Go, Rust"
echo "  • Claude Code CLI"
echo ""
echo -e "${BLUE}VSCodium Extensions Installed:${NC}"
echo "  Core Requested:"
echo "    • Claude Code"
echo "    • ESLint, Prettier"
echo "    • Git Graph, GitLens"
echo "    • Go, Rust Analyzer"
echo ""
echo "  NixOS Development:"
echo "    • Nix IDE"
echo "    • Nix Environment Selector"
echo "    • Nix Language Support"
echo ""
echo "  Productivity & DevOps:"
echo "    • Error Lens (inline errors)"
echo "    • GitHub Copilot"
echo "    • Todo Tree, Code Spell Checker"
echo "    • YAML, TOML, XML support"
echo "    • Docker, Terraform support"
echo "    • Remote SSH"
echo "    • Makefile Tools"
echo ""
echo -e "${BLUE}Getting Started with Claude Code:${NC}"
echo "  1. Authenticate CLI:"
echo "     $ bash ~/.npm-global/bin/claude auth login"
echo "     (or: $ claude auth login if PATH is set)"
echo ""
echo "  2. Test Claude Code:"
echo "     $ bash ~/.npm-global/bin/claude --version"
echo ""
echo "  3. Launch VSCodium:"
echo "     $ codium-wrapped"
echo "     or: $ codium"
echo ""
echo "  4. In VSCodium:"
echo "     • Press Ctrl+Shift+P → type 'Claude Code'"
echo "     • Or use Ctrl+Esc to quick launch"
echo "     • Should work automatically with the wrapper"
echo ""
echo "  5. If Claude Code still has issues:"
echo "     • Wrapper path: $HOME/.npm-global/bin/claude-wrapper"
echo "     • Direct path: $HOME/.npm-global/bin/claude"
echo "     • Settings → Extensions → Claude Code → Executable Path"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo "  • If extensions fail to install, open VSCodium once first"
echo "  • Then re-run this script or install manually"
echo "  • Check extension logs: View → Output → Extension Host"
echo ""
echo -e "${BLUE}NixOS Configuration:${NC}"
echo "  • User packages: nix-env -q"
echo "  • Remove package: nix-env --uninstall <name>"
echo "  • Remove all user packages: nix-env --uninstall '*'"
echo "  • These packages persist across reboots"
echo "  • To make permanent, add to /etc/nixos/configuration.nix"
echo ""
echo "Current user profile generation:"
nix-env --list-generations | tail -n 1
echo ""
echo -e "${GREEN}Setup complete! Happy coding with Claude! 🚀${NC}"
echo ""
