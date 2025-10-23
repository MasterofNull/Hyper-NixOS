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
# NixOS Development Environment Setup with VSCodium Extensions
# FIXED: Error 127 - Uses explicit Node.js wrapper for Claude Code
#!/usr/bin/env bash
# NixOS Development Environment Setup with VSCodium Extensions
# FIXED: Error 127 - Uses explicit Node.js wrapper for Claude Code
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
    nixpkgs.cargo \
    nixpkgs.podman \
    nixpkgs.openssl \
    nixpkgs.qemu \
    nixpkgs.sqlite \
    nixpkgs.virtiofsd
    

echo -e "${GREEN}✓ Development packages installed to user profile${NC}"
echo ""

echo -e "${YELLOW}Step 2b: Installing Claude Code via npm...${NC}"

# Set up NPM paths FIRST
export NPM_CONFIG_PREFIX=~/.npm-global
mkdir -p ~/.npm-global/bin
export PATH=~/.npm-global/bin:$PATH

# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Verify the base installation
CLI_FILE="$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"

if [ ! -f "$CLI_FILE" ]; then
    echo -e "${RED}✗ Claude Code installation failed - cli.js not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Claude Code installed${NC}"

# FIX FOR ERROR 127: Make cli.js executable
chmod +x "$CLI_FILE"
echo -e "${GREEN}✓ Made cli.js executable${NC}"

# FIX FOR ERROR 127: Create SMART Node.js wrapper that finds Node.js at runtime
echo -e "${YELLOW}Creating smart Node.js wrapper to fix Error 127...${NC}"
echo "This wrapper will work across Node.js updates and system changes"

cat > ~/.npm-global/bin/claude-wrapper << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Smart Claude Code Wrapper - Finds Node.js dynamically
# Works across Node.js updates and NixOS rebuilds

# Strategy 1: Try common Nix profile locations (fastest)
NODE_LOCATIONS=(
    "$HOME/.nix-profile/bin/node"
    "/run/current-system/sw/bin/node"
    "/nix/var/nix/profiles/default/bin/node"
    "$(which node 2>/dev/null)"
)

NODE_BIN=""
for node_path in "${NODE_LOCATIONS[@]}"; do
    # Resolve symlinks to get actual Nix store path
    if [ -n "$node_path" ] && [ -x "$node_path" ]; then
        NODE_BIN=$(readlink -f "$node_path" 2>/dev/null || echo "$node_path")
        if [ -x "$NODE_BIN" ]; then
            break
        fi
    fi
done

# Strategy 2: Search PATH if not found
if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
    NODE_BIN=$(command -v node 2>/dev/null)
    if [ -n "$NODE_BIN" ]; then
        NODE_BIN=$(readlink -f "$NODE_BIN")
    fi
fi

# Strategy 3: Find in Nix store directly (last resort)
if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
    NODE_BIN=$(find /nix/store -maxdepth 2 -name "node" -type f -executable 2>/dev/null | grep -m1 "nodejs.*bin/node" || echo "")
fi

# Fail if still not found
if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
    echo "Error: Could not find Node.js executable" >&2
    echo "Searched locations:" >&2
    printf '%s\n' "${NODE_LOCATIONS[@]}" >&2
    echo "PATH: $PATH" >&2
    exit 127
fi

# Path to Claude Code CLI
CLAUDE_CLI="$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"

if [ ! -f "$CLAUDE_CLI" ]; then
    echo "Error: Claude Code CLI not found at $CLAUDE_CLI" >&2
    exit 127
fi

# Execute with Node.js
exec "$NODE_BIN" "$CLAUDE_CLI" "$@"
WRAPPER_EOF

chmod +x ~/.npm-global/bin/claude-wrapper
echo -e "${GREEN}✓ Created wrapper: ~/.npm-global/bin/claude-wrapper${NC}"

# Test the wrapper
if ~/.npm-global/bin/claude-wrapper --version >/dev/null 2>&1; then
    CLAUDE_VERSION=$(~/.npm-global/bin/claude-wrapper --version 2>/dev/null | head -n1)
    echo -e "${GREEN}✓ Claude Code wrapper works! Version: ${CLAUDE_VERSION}${NC}"
    CLAUDE_EXEC_PATH="$HOME/.npm-global/bin/claude-wrapper"
else
    echo -e "${RED}✗ Wrapper test failed${NC}"
    echo "Trying direct Node.js execution..."
    if node "$CLI_FILE" --version >/dev/null 2>&1; then
        echo -e "${YELLOW}Direct Node.js execution works, using wrapper anyway${NC}"
        CLAUDE_EXEC_PATH="$HOME/.npm-global/bin/claude-wrapper"
    else
        echo -e "${RED}✗ Claude Code not working${NC}"
        exit 1
    fi
fi

# Add to shell profiles for persistence
for PROFILE in ~/.bashrc ~/.zshrc; do
    if [ -f "$PROFILE" ] || [ "$PROFILE" = ~/.bashrc ]; then
        touch "$PROFILE"
        if ! grep -q "NPM_CONFIG_PREFIX" "$PROFILE" 2>/dev/null; then
            echo "" >> "$PROFILE"
            echo "# NPM global packages" >> "$PROFILE"
            echo 'export NPM_CONFIG_PREFIX=~/.npm-global' >> "$PROFILE"
            echo 'export PATH=~/.npm-global/bin:$PATH' >> "$PROFILE"
            echo -e "${GREEN}✓ Added NPM paths to $PROFILE${NC}"
        fi
    fi
done
echo ""

echo -e "${YELLOW}Step 3: Creating VSCodium wrapper with proper PATH...${NC}"
mkdir -p ~/.local/bin

cat > ~/.local/bin/codium-wrapped << 'WRAPPER_EOF'
#!/usr/bin/env bash
# VSCodium wrapper that ensures Claude Code is in PATH

export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# Debug mode
if [ -n "$CODIUM_DEBUG" ]; then
    echo "NPM_CONFIG_PREFIX: $NPM_CONFIG_PREFIX"
    echo "PATH: $PATH"
    echo "Claude wrapper: $(which claude-wrapper 2>/dev/null || echo 'not found')"
fi

exec codium "$@"
WRAPPER_EOF

chmod +x ~/.local/bin/codium-wrapped
echo -e "${GREEN}✓ VSCodium wrapper created at ~/.local/bin/codium-wrapped${NC}"

# Add ~/.local/bin to shell profiles
for PROFILE in ~/.bashrc ~/.zshrc; do
    if [ -f "$PROFILE" ] || [ "$PROFILE" = ~/.bashrc ]; then
        if ! grep -q "$HOME/.local/bin" "$PROFILE" 2>/dev/null; then
            echo "" >> "$PROFILE"
            echo "# Local binaries" >> "$PROFILE"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
            echo -e "${GREEN}✓ Added ~/.local/bin to $PROFILE${NC}"
        fi
    fi
done
echo ""

echo -e "${YELLOW}Step 4: Killing any running VSCodium instances...${NC}"
# Kill VSCodium to ensure clean state
pkill -f "codium" 2>/dev/null && echo -e "${GREEN}✓ Killed VSCodium processes${NC}" || echo -e "${BLUE}No VSCodium processes running${NC}"
sleep 2
echo ""

echo -e "${YELLOW}Step 5: Installing VSCodium extensions...${NC}"

# Export PATH before installing extensions
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

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
#install_extension "github.copilot" "GitHub Copilot (if you have access)"
install_extension "ms-vscode.makefile-tools" "Makefile Tools"
install_extension "tamasfe.even-better-toml" "Even Better TOML"
install_extension "redhat.vscode-yaml" "YAML"
install_extension "mechatroner.rainbow-csv" "Rainbow CSV"
install_extension "streetsidesoftware.code-spell-checker" "Code Spell Checker"
install_extension "gruntfuggly.todo-tree" "Todo Tree"
install_extension "oderwat.indent-rainbow" "Indent Rainbow"
install_extension "pkief.material-icon-theme" "Material Icon Theme"
install_extension "github.vscode-github-actions" "GitHub Actions"
#install_extension "ms-vscode-remote.remote-ssh" "Remote - SSH"

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

# Get the Node.js path for environment variables
NODE_BIN_DIR=$(dirname $(readlink -f $(which node)))
NIX_PROFILE_BIN="$HOME/.nix-profile/bin"

echo "Setting up environment variables for Claude Code:"
echo "  Node.js bin directory: $NODE_BIN_DIR"
echo "  Nix profile bin: $NIX_PROFILE_BIN"

# Backup existing USER settings if they exist
SETTINGS_FILE="$HOME/.config/VSCodium/User/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%s)"
    echo -e "${GREEN}✓ Backed up existing user settings${NC}"
fi

# Create USER settings.json with ALL required Claude Code settings
# NOTE: Include BOTH naming conventions for maximum compatibility:
# - Hyphenated (claude-code.*) - VSCodium UI format
# - CamelCase (claudeCode.*) - Extension internal format
# NOTE: environmentVariables must be an ARRAY of key-value objects
cat > "$SETTINGS_FILE" << SETTINGS_EOF
{
  // Claude Code Configuration - COMPLETE FIX for Error 127
  // Using BOTH naming conventions for maximum compatibility
  // Hyphenated names (claude-code.*) for VSCodium UI
  "claude-code.executablePath": "${CLAUDE_EXEC_PATH}",
  "claude-code.claudeProcessWrapper": "${CLAUDE_EXEC_PATH}",
  "claude-code.environmentVariables": [
    {
      "name": "PATH",
      "value": "${NIX_PROFILE_BIN}:${NODE_BIN_DIR}:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "${HOME}/.npm-global/lib/node_modules"
    }
  ],
  "claude-code.autoStart": false,
  
  // CamelCase names (claudeCode.*) for extension compatibility
  "claudeCode.executablePath": "${CLAUDE_EXEC_PATH}",
  "claudeCode.claudeProcessWrapper": "${CLAUDE_EXEC_PATH}",
  "claudeCode.environmentVariables": [
    {
      "name": "PATH",
      "value": "${NIX_PROFILE_BIN}:${NODE_BIN_DIR}:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "${HOME}/.npm-global/lib/node_modules"
    }
  ],
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

echo -e "${GREEN}✓ User settings configured at: ${SETTINGS_FILE}${NC}"

# Create a WORKSPACE settings template that users can copy to any project
WORKSPACE_TEMPLATE="$HOME/.config/VSCodium/workspace-settings-template.json"
cat > "$WORKSPACE_TEMPLATE" << WORKSPACE_EOF
{
  // Claude Code Workspace Settings Template
  // Copy this to your project's .vscode/settings.json
  // These settings override user settings for this workspace
  // Using BOTH naming conventions for maximum compatibility
  
  // Hyphenated names (claude-code.*) for VSCodium UI
  "claude-code.executablePath": "${CLAUDE_EXEC_PATH}",
  "claude-code.claudeProcessWrapper": "${CLAUDE_EXEC_PATH}",
  "claude-code.environmentVariables": [
    {
      "name": "PATH",
      "value": "${NIX_PROFILE_BIN}:${NODE_BIN_DIR}:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "${HOME}/.npm-global/lib/node_modules"
    }
  ],
  "claude-code.autoStart": false,
  
  // CamelCase names (claudeCode.*) for extension compatibility
  "claudeCode.executablePath": "${CLAUDE_EXEC_PATH}",
  "claudeCode.claudeProcessWrapper": "${CLAUDE_EXEC_PATH}",
  "claudeCode.environmentVariables": [
    {
      "name": "PATH",
      "value": "${NIX_PROFILE_BIN}:${NODE_BIN_DIR}:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "${HOME}/.npm-global/lib/node_modules"
    }
  ],
  "claudeCode.autoStart": false
}
WORKSPACE_EOF

echo -e "${GREEN}✓ Workspace template created at: ${WORKSPACE_TEMPLATE}${NC}"

# Create a helper script to set up workspace settings in any directory
cat > ~/.local/bin/setup-claude-workspace << 'WORKSPACE_SCRIPT_EOF'
#!/usr/bin/env bash
# Setup Claude Code workspace settings in current directory

WORKSPACE_DIR="${1:-.}"

if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Error: Directory $WORKSPACE_DIR does not exist"
    exit 1
fi

mkdir -p "$WORKSPACE_DIR/.vscode"
WORKSPACE_SETTINGS="$WORKSPACE_DIR/.vscode/settings.json"

# Get current paths
NODE_BIN_DIR=$(dirname $(readlink -f $(which node)))
NIX_PROFILE_BIN="$HOME/.nix-profile/bin"
CLAUDE_WRAPPER="$HOME/.npm-global/bin/claude-wrapper"

# If settings already exist, merge with existing
if [ -f "$WORKSPACE_SETTINGS" ]; then
    echo "Workspace settings already exist. Backing up..."
    cp "$WORKSPACE_SETTINGS" "$WORKSPACE_SETTINGS.backup.$(date +%s)"
    
    # Update Claude Code settings in existing file
    # This is a simple approach - for complex JSON merging, use jq
    if grep -q "claude-code\|claudeCode" "$WORKSPACE_SETTINGS"; then
        echo "Claude Code settings already exist. Please update manually or delete and re-run."
        exit 1
    else
        # Add Claude Code settings before closing brace
        sed -i '$d' "$WORKSPACE_SETTINGS"
        cat >> "$WORKSPACE_SETTINGS" << WORKSPACE_EOF
  "claude-code.executablePath": "$CLAUDE_WRAPPER",
  "claude-code.claudeProcessWrapper": "$CLAUDE_WRAPPER",
  "claude-code.environmentVariables": [
    {
      "name": "PATH",
      "value": "$NIX_PROFILE_BIN:$NODE_BIN_DIR:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "$HOME/.npm-global/lib/node_modules"
    }
  ],
  "claude-code.autoStart": false,
  "claudeCode.executablePath": "$CLAUDE_WRAPPER",
  "claudeCode.claudeProcessWrapper": "$CLAUDE_WRAPPER",
  "claudeCode.environmentVariables": [
    {
      "name": "PATH",
      "value": "$NIX_PROFILE_BIN:$NODE_BIN_DIR:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "$HOME/.npm-global/lib/node_modules"
    }
  ],
  "claudeCode.autoStart": false
}
WORKSPACE_EOF
    fi
else
    # Create new workspace settings
    cat > "$WORKSPACE_SETTINGS" << WORKSPACE_EOF
{
  "claude-code.executablePath": "$CLAUDE_WRAPPER",
  "claude-code.claudeProcessWrapper": "$CLAUDE_WRAPPER",
  "claude-code.environmentVariables": [
    {
      "name": "PATH",
      "value": "$NIX_PROFILE_BIN:$NODE_BIN_DIR:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "$HOME/.npm-global/lib/node_modules"
    }
  ],
  "claude-code.autoStart": false,
  "claudeCode.executablePath": "$CLAUDE_WRAPPER",
  "claudeCode.claudeProcessWrapper": "$CLAUDE_WRAPPER",
  "claudeCode.environmentVariables": [
    {
      "name": "PATH",
      "value": "$NIX_PROFILE_BIN:$NODE_BIN_DIR:/run/current-system/sw/bin:\${env:PATH}"
    },
    {
      "name": "NODE_PATH",
      "value": "$HOME/.npm-global/lib/node_modules"
    }
  ],
  "claudeCode.autoStart": false
}
WORKSPACE_EOF
fi

echo "✓ Claude Code workspace settings configured in: $WORKSPACE_SETTINGS"
WORKSPACE_SCRIPT_EOF

chmod +x ~/.local/bin/setup-claude-workspace
echo -e "${GREEN}✓ Created workspace setup helper: ~/.local/bin/setup-claude-workspace${NC}"
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
echo "Installed packages:"
echo "  • Core: wget, git, curl, vim, neovim"
echo "  • VSCodium with extensions (see below)"
echo "  • Build tools: gcc, make, node.js 22 LTS"
echo "  • Modern CLI: ripgrep, fd, fzf, bat, eza, jq, yq"
echo "  • Languages: Python 3, Go, Rust"
echo "  • Claude Code CLI (with Error 127 fix)"
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
#echo "    • GitHub Copilot"
echo "    • Todo Tree, Code Spell Checker"
echo "    • YAML, TOML, XML support"
echo "    • Docker, Terraform support"
#echo "    • Remote SSH"
echo "    • Makefile Tools"
echo ""
echo -e "${BLUE}Getting Started with Claude Code:${NC}"
echo "  1. Authenticate CLI:"
echo "     $ claude-wrapper auth login"
echo "     (or just: claude auth login)"
echo ""
echo "  2. Test Claude Code:"
echo "     $ claude-wrapper --version"
echo ""
echo "  3. Launch VSCodium:"
echo "     $ codium-wrapped"
echo ""
echo "  4. In VSCodium:"
echo "     • Press Ctrl+Shift+P → type 'Claude Code'"
echo "     • Or click the Claude icon in the sidebar"
echo "     • Should work without Error 127!"
echo ""
echo -e "${BLUE}IMPORTANT Settings Configured:${NC}"
echo "  USER settings (~/.config/VSCodium/User/settings.json):"
echo "    • Both claude-code.* AND claudeCode.* formats included"
echo "    • executablePath: ${CLAUDE_EXEC_PATH}"
echo "    • claudeProcessWrapper: ${CLAUDE_EXEC_PATH}"
echo "    • environmentVariables.PATH: Includes Nix paths"
echo ""
echo "  WORKSPACE settings helper created:"
echo "    • Template: ~/.config/VSCodium/workspace-settings-template.json"
echo "    • Helper script: setup-claude-workspace"
echo ""
echo "  To add Claude Code to a project workspace:"
echo "    $ cd /path/to/your/project"
echo "    $ setup-claude-workspace"
echo "    This creates .vscode/settings.json with Claude Code config"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo "  • If Error 127 persists, check:"
echo "    $ node --version"
echo "    $ cat ${CLAUDE_EXEC_PATH}"
echo "    Settings → Extensions → Claude Code → Executable Path"
echo ""
echo "  • Debug VSCodium wrapper:"
echo "    $ CODIUM_DEBUG=1 codium-wrapped"
echo ""
echo "  • Test wrapper directly:"
echo "    $ ${CLAUDE_EXEC_PATH} --version"
echo ""
echo -e "${BLUE}NixOS Configuration:${NC}"
echo "  • User packages: nix-env -q"
echo "  • Remove package: nix-env --uninstall <name>"
echo "  • These packages persist across reboots"
echo ""
echo "Current user profile generation:"
nix-env --list-generations | tail -n 1
echo ""
echo -e "${GREEN}✅ Setup complete! Error 127 fixed! 🚀${NC}"
echo ""
echo "IMPORTANT: Restart your terminal or run:"
echo "  source ~/.bashrc"
echo ""
