#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: NixOS Development Environment Quick Deploy (FIXED)
#
# Description:
#   Sets up a complete development environment with VSCodium, Claude Code,
#   and essential developer tools. Installs to user profile (persistent).
#
# Usage:
#   bash nixos-dev-quick-deploy.sh (no sudo needed for user env)
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

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
    nixpkgs.cargo \
    nixpkgs.zsh \
    nixpkgs.zsh-powerlevel10k \
    nixpkgs.zsh-autosuggestions \
    nixpkgs.zsh-fast-syntax-highlighting \
    nixpkgs.presenterm \
    nixpkgs.erdtree \
    nixpkgs.delta \
    nixpkgs.gdu \
    nixpkgs.dua \
    nixpkgs.bottom \
    nixpkgs.gping \
    nixpkgs.hyperfine \
    nixpkgs.lazygit \
    nixpkgs.micro \
    nixpkgs.helix \
    nixpkgs.termscp \
    nixpkgs.silicon \
    nixpkgs.yazi \
    nixpkgs.yadm \
    nixpkgs.zoxide \
    nixpkgs.dust \
    nixpkgs.procs \
    nixpkgs.bandwhich \
    nixpkgs.tealdeer \
    nixpkgs.tokei \
    nixpkgs.gh \
    nixpkgs.psmimic

echo -e "${GREEN}✓ Development packages installed to user profile${NC}"
echo ""

echo -e "${YELLOW}Step 2b: Installing Claude Code via npm...${NC}"
# Set up npm global directory
export NPM_CONFIG_PREFIX=~/.npm-global
mkdir -p ~/.npm-global
export PATH=~/.npm-global/bin:$PATH

# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# CRITICAL FIX: Create proper wrapper that points to the actual SDK
if [ -f ~/.npm-global/lib/node_modules/@anthropic-ai/claude-code/sdk.mjs ]; then
    echo -e "${GREEN}✓ Claude Code installed${NC}"
    
    # Create a proper bash wrapper for the claude command
    cat > ~/.npm-global/bin/claude << 'CLAUDE_WRAPPER'
#!/usr/bin/env bash
# Claude Code wrapper for NixOS
# This ensures the correct node and SDK are used

NODE_BIN="$HOME/.nix-profile/bin/node"
SDK_PATH="$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/sdk.mjs"

# Fallback to system node if user node not found
if [ ! -f "$NODE_BIN" ]; then
    NODE_BIN="/run/current-system/sw/bin/node"
fi

exec "$NODE_BIN" "$SDK_PATH" "$@"
CLAUDE_WRAPPER
    
    chmod +x ~/.npm-global/bin/claude
    echo -e "${GREEN}✓ Created custom Claude wrapper${NC}"
    
    # Create claude-code symlink
    ln -sf ~/.npm-global/bin/claude ~/.npm-global/bin/claude-code
    echo -e "${GREEN}✓ Symlink created: claude-code -> claude${NC}"
    
    # Test the installation
    if ~/.npm-global/bin/claude --version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Claude Code is working correctly${NC}"
    else
        echo -e "${YELLOW}⚠ Claude Code installed (may need authentication)${NC}"
    fi
else
    echo -e "${RED}✗ Claude Code SDK not found${NC}"
    exit 1
fi

# Add npm global to shell profiles
for profile in ~/.bashrc ~/.zshrc; do
    if [ -f "$profile" ]; then
        if ! grep -q "NPM_CONFIG_PREFIX" "$profile" 2>/dev/null; then
            cat >> "$profile" << 'PROFILE_NPM'

# NPM global packages
export NPM_CONFIG_PREFIX=~/.npm-global
export PATH=~/.npm-global/bin:$PATH
PROFILE_NPM
            echo -e "${GREEN}✓ Added npm config to $profile${NC}"
        fi
    fi
done

echo ""

echo -e "${YELLOW}Step 3: Creating VSCodium wrapper with proper PATH...${NC}"
mkdir -p ~/.local/bin

cat > ~/.local/bin/codium-wrapped << 'WRAPPER_EOF'
#!/usr/bin/env bash
# VSCodium wrapper that ensures Claude Code is in PATH
export NPM_CONFIG_PREFIX=~/.npm-global
export PATH=~/.npm-global/bin:$HOME/.local/bin:$PATH
export NODE_PATH=~/.npm-global/lib/node_modules

# Ensure Claude Code can find node
if [ -f "$HOME/.nix-profile/bin/node" ]; then
    export NODE_BIN="$HOME/.nix-profile/bin/node"
else
    export NODE_BIN="/run/current-system/sw/bin/node"
fi

exec codium "$@"
WRAPPER_EOF

chmod +x ~/.local/bin/codium-wrapped
echo -e "${GREEN}✓ VSCodium wrapper created${NC}"

# Add ~/.local/bin to shell profiles
for profile in ~/.bashrc ~/.zshrc; do
    if [ -f "$profile" ]; then
        if ! grep -q ".local/bin" "$profile" 2>/dev/null; then
            cat >> "$profile" << 'PROFILE_LOCAL'

# Local binaries
export PATH="$HOME/.local/bin:$PATH"
PROFILE_LOCAL
            echo -e "${GREEN}✓ Added local bin to $profile${NC}"
        fi
    fi
done

echo ""

echo -e "${YELLOW}Step 4: Setting up ZSH configuration...${NC}"

# Initialize zsh configuration if needed
if [ ! -f ~/.zshrc ]; then
    touch ~/.zshrc
    echo -e "${GREEN}✓ Created ~/.zshrc${NC}"
fi

# Add Powerlevel10k configuration
if ! grep -q "powerlevel10k" ~/.zshrc; then
    cat >> ~/.zshrc << 'ZSH_P10K'

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Powerlevel10k theme
source ~/.nix-profile/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSH_P10K
    echo -e "${GREEN}✓ Added Powerlevel10k to .zshrc${NC}"
fi

# Add ZSH plugins
if ! grep -q "zsh-autosuggestions" ~/.zshrc; then
    cat >> ~/.zshrc << 'ZSH_PLUGINS'

# ZSH plugins
source ~/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.nix-profile/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
ZSH_PLUGINS
    echo -e "${GREEN}✓ Added ZSH plugins to .zshrc${NC}"
fi

# Add zoxide initialization
if ! grep -q "zoxide init" ~/.zshrc; then
    cat >> ~/.zshrc << 'ZSH_ZOXIDE'

# Initialize zoxide (smart cd)
eval "$(zoxide init zsh)"
ZSH_ZOXIDE
    echo -e "${GREEN}✓ Added zoxide to .zshrc${NC}"
fi

# Add useful aliases
if ! grep -q "# Modern CLI aliases" ~/.zshrc; then
    cat >> ~/.zshrc << 'ZSH_ALIASES'

# Modern CLI aliases
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias tree='eza --tree --icons'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias top='btm'
alias du='dust'
alias df='dua'
ZSH_ALIASES
    echo -e "${GREEN}✓ Added modern CLI aliases to .zshrc${NC}"
fi

# Add same configurations to .bashrc
if [ -f ~/.bashrc ]; then
    if ! grep -q "zoxide init" ~/.bashrc; then
        cat >> ~/.bashrc << 'BASH_ZOXIDE'

# Initialize zoxide (smart cd)
eval "$(zoxide init bash)"
BASH_ZOXIDE
        echo -e "${GREEN}✓ Added zoxide to .bashrc${NC}"
    fi
    
    if ! grep -q "# Modern CLI aliases" ~/.bashrc; then
        cat >> ~/.bashrc << 'BASH_ALIASES'

# Modern CLI aliases
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias tree='eza --tree --icons'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias top='btm'
alias du='dust'
alias df='dua'
BASH_ALIASES
        echo -e "${GREEN}✓ Added modern CLI aliases to .bashrc${NC}"
    fi
fi

echo ""

echo -e "${YELLOW}Step 5: Installing VSCodium extensions...${NC}"

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

echo -e "${YELLOW}Step 6: Creating VSCodium settings for Claude Code...${NC}"
mkdir -p ~/.config/VSCodium/User

CURRENT_USER=$(whoami)

cat > ~/.config/VSCodium/User/settings.json << SETTINGS_EOF
{
  // Claude Code Configuration - NixOS Fixed
  "claudeCode.executablePath": "/home/${CURRENT_USER}/.npm-global/bin/claude",
  "claude.executablePath": "/home/${CURRENT_USER}/.npm-global/bin/claude",
  "anthropic.claude.executablePath": "/home/${CURRENT_USER}/.npm-global/bin/claude",
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
  "terminal.integrated.defaultProfile.linux": "bash",

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

echo -e "${YELLOW}Step 7: Upgrading NixOS system...${NC}"
sudo nixos-rebuild switch --upgrade
echo -e "${GREEN}✓ System upgraded${NC}"
echo ""

echo -e "${YELLOW}Step 8: Cleaning up old system generations...${NC}"
sudo nix-collect-garbage -d
echo -e "${GREEN}✓ Old generations cleaned${NC}"
echo ""

echo "========================================="
echo -e "${GREEN}Development Environment Ready!${NC}"
echo "========================================="
echo ""
echo -e "${BLUE}CRITICAL SETUP STEPS:${NC}"
echo ""
echo -e "${YELLOW}1. Authenticate Claude Code:${NC}"
echo "   $ source ~/.bashrc  # or source ~/.zshrc"
echo "   $ claude auth login"
echo ""
echo -e "${YELLOW}2. Test Claude Code CLI:${NC}"
echo "   $ claude --version"
echo "   $ which claude  # Should show ~/.npm-global/bin/claude"
echo ""
echo -e "${YELLOW}3. Launch VSCodium:${NC}"
echo "   $ codium-wrapped"
echo "   OR"
echo "   $ source ~/.bashrc && codium"
echo ""
echo -e "${YELLOW}4. Verify Claude Code in VSCodium:${NC}"
echo "   • Open Command Palette (Ctrl+Shift+P)"
echo "   • Type 'Claude Code'"
echo "   • Check for Error 127 - should be fixed!"
echo ""
echo -e "${YELLOW}5. Configure ZSH (Optional but Recommended):${NC}"
echo "   $ chsh -s \$(which zsh)  # Change default shell"
echo "   $ exec zsh              # Start zsh"
echo "   $ p10k configure        # Configure prompt"
echo ""
echo -e "${BLUE}Console Tools Quick Start:${NC}"
echo "  Modern replacements (now aliased):"
echo "    ls    → eza --icons"
echo "    ll    → eza -la --icons --git"
echo "    cat   → bat (syntax highlighting)"
echo "    find  → fd (faster, easier)"
echo "    grep  → rg (ripgrep - blazing fast)"
echo "    top   → btm (bottom - better resource monitor)"
echo "    du    → dust (visual disk usage)"
echo "    df    → dua (interactive disk usage)"
echo "    cd    → z (zoxide - smart jumping)"
echo ""
echo "  Try these commands:"
echo "    btm               # System monitor"
echo "    gdu               # Interactive disk usage"
echo "    gping google.com  # Ping with graph"
echo "    lazygit           # Git TUI"
echo "    erdtree           # File tree with sizes"
echo "    yazi              # File manager"
echo "    z <dir>           # Jump to recent directory"
echo ""
echo -e "${RED}Troubleshooting Error 127:${NC}"
echo "  1. Check Claude wrapper exists:"
echo "     $ cat ~/.npm-global/bin/claude"
echo ""
echo "  2. Test wrapper directly:"
echo "     $ ~/.npm-global/bin/claude --version"
echo ""
echo "  3. Check PATH in VSCodium terminal:"
echo "     Open VSCodium → Terminal → New Terminal"
echo "     $ echo \$PATH  # Should include ~/.npm-global/bin"
echo "     $ which claude"
echo ""
echo "  4. Check VSCodium logs:"
echo "     Help → Toggle Developer Tools → Console tab"
echo "     Look for 'Claude Code' errors"
echo ""
echo "  5. Restart VSCodium completely:"
echo "     $ killall codium"
echo "     $ codium-wrapped"
echo ""
echo "Current user profile generation:"
nix-env --list-generations | tail -n 1
echo ""
echo -e "${GREEN}Setup complete! Enjoy your NixOS dev environment! 🚀${NC}"
echo ""
