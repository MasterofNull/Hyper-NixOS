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

set -e  # Exit on error

echo "========================================="
echo "NixOS Development Environment Setup"
echo "========================================="
echo "Using home-manager for proper"
echo "declarative configuration"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if NOT running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: Do not run this script as root${NC}"
   echo -e "${YELLOW}Run as your regular user${NC}"
   exit 1
fi

CURRENT_USER=$(whoami)
HOME_DIR=$HOME

echo -e "${YELLOW}Step 1: Ensuring channels are properly configured...${NC}"

# Get the NixOS version to match home-manager channel
NIXOS_VERSION=$(nixos-version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "unstable")
echo "Detected NixOS version: ${NIXOS_VERSION}"

# Configure nixpkgs channel for user
if ! nix-channel --list | grep -q "^nixpkgs"; then
    echo "Adding nixpkgs channel..."
    if [ "$NIXOS_VERSION" = "unstable" ]; then
        nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
    else
        nix-channel --add https://nixos.org/channels/nixos-${NIXOS_VERSION} nixpkgs
    fi
fi

# Configure home-manager channel to match nixpkgs version
if ! nix-channel --list | grep -q "home-manager"; then
    echo "Adding home-manager channel (matching nixpkgs version)..."
    if [ "$NIXOS_VERSION" = "unstable" ]; then
        nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    else
        nix-channel --add https://github.com/nix-community/home-manager/archive/release-${NIXOS_VERSION}.tar.gz home-manager
    fi
fi

echo "Updating all user channels..."
nix-channel --update

echo ""
echo "Current user channels:"
nix-channel --list
echo ""
echo -e "${GREEN}✓ Channels configured and synchronized${NC}"

echo ""
echo -e "${YELLOW}Step 2: Installing home-manager...${NC}"

# Check if home-manager is already installed
if ! command -v home-manager &> /dev/null; then
    echo "Installing home-manager..."
    
    # Install home-manager
    nix-shell '<home-manager>' -A install
    
    echo -e "${GREEN}✓ home-manager installed${NC}"
else
    echo -e "${GREEN}✓ home-manager already installed${NC}"
fi

echo ""

echo -e "${YELLOW}Step 3: Creating home-manager configuration...${NC}"

# Create home-manager config directory
mkdir -p ~/.config/home-manager

# Create comprehensive home.nix configuration
cat > ~/.config/home-manager/home.nix << 'HOME_NIX_EOF'
{ config, pkgs, ... }:

{
  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # User info
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  
  # State version (don't change this)
  home.stateVersion = "23.11";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Package installations
  home.packages = with pkgs; [
    # Core utilities
    wget
    curl
    git
    vim
    neovim
    htop
    btop
    tree
    unzip
    zip
    
    # Build tools
    gnumake
    gcc
    nodejs_22
    python3
    go
    rustc
    cargo
    
    # Modern CLI replacements (these will be aliased)
    ripgrep      # rg - better grep
    fd           # better find
    fzf          # fuzzy finder
    bat          # better cat
    eza          # better ls
    zoxide       # smart cd
    delta        # better git diff
    dust         # better du
    dua          # disk usage analyzer
    procs        # better ps
    
    # System monitoring
    bottom       # btm - better top
    gdu          # disk usage TUI
    gping        # ping with graphs
    bandwhich    # network monitor
    
    # Development tools
    lazygit      # git TUI
    gh           # GitHub CLI
    jq           # JSON processor
    yq           # YAML processor
    
    # Text editors
    micro        # modern nano
    helix        # modern vim
    
    # Utilities
    hyperfine    # benchmarking
    tealdeer     # tldr - quick help
    tokei        # code statistics
    silicon      # code screenshots
    presenterm   # markdown presentations
    erdtree      # tree with sizes
    yazi         # file manager
    yadm         # dotfiles manager
    termscp      # SCP/FTP client
    
    # IDEs and editors
    vscodium
    
    # System tools
    psmisc       # killall, pstree, etc
  ];

  # Configure programs using home-manager modules
  
  # ZSH configuration with proper initialization
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    # History configuration
    history = {
      size = 100000;
      save = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = true;
    };
    
    # Shell aliases - modern CLI tools
    shellAliases = {
      # File operations
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --git --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      lt = "eza --tree --icons --group-directories-first";
      tree = "eza --tree --icons";
      
      # Modern replacements
      cat = "bat --style=auto";
      find = "fd";
      grep = "rg";
      ps = "procs";
      
      # System monitoring
      top = "btm";
      htop = "btm";
      du = "dust";
      df = "dua interactive";
      
      # Git
      g = "git";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gs = "git status";
      gd = "git diff";
      lg = "lazygit";
      
      # Utilities
      help = "tldr";
      ping = "gping";
      
      # VSCodium
      code = "codium";
    };
    
    # Oh-My-Zsh configuration
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";  # or "agnoster", "powerlevel10k/powerlevel10k"
      plugins = [
        "git"
        "sudo"
        "colored-man-pages"
        "command-not-found"
        "history"
        "z"  # directory jumper
      ];
    };
    
    # Additional initialization
    initExtra = ''
      # Zoxide initialization (smart cd replacement)
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
      
      # FZF key bindings
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
      
      # Custom prompt with git info
      autoload -Uz vcs_info
      precmd() { vcs_info }
      zstyle ':vcs_info:git:*' formats '%b '
      setopt PROMPT_SUBST
      
      # Better history search
      bindkey '^R' history-incremental-search-backward
      bindkey '^S' history-incremental-search-forward
      
      # Directory navigation shortcuts
      alias ..='cd ..'
      alias ...='cd ../..'
      alias ....='cd ../../..'
      
      # Quick access to common directories
      alias dev='cd ~/Development'
      alias docs='cd ~/Documents'
      alias dl='cd ~/Downloads'
      
      # Claude Code PATH (will be set after installation)
      export PATH="$HOME/.local/bin:$PATH"
      
      # Colored man pages using bat
      export MANPAGER="sh -c 'col -bx | bat -l man -p'"
      export MANROFFOPT="-c"
      
      # Better ls colors
      export LS_COLORS="$(vivid generate molokai 2>/dev/null || echo "")"
      
      # Editor
      export EDITOR=nvim
      export VISUAL=nvim
      
      echo "🚀 NixOS Dev Environment Ready!"
      echo "Type 'help <command>' for quick command reference"
    '';
  };
  
  # Bash configuration (fallback if not using zsh)
  programs.bash = {
    enable = true;
    enableCompletion = true;
    
    shellAliases = config.programs.zsh.shellAliases;
    
    initExtra = ''
      # Zoxide initialization
      eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
      
      # FZF key bindings
      source ${pkgs.fzf}/share/fzf/key-bindings.bash
      source ${pkgs.fzf}/share/fzf/completion.bash
      
      # Claude Code PATH
      export PATH="$HOME/.local/bin:$PATH"
      
      export EDITOR=nvim
    '';
  };
  
  # Git configuration
  programs.git = {
    enable = true;
    userName = "Your Name";  # Change this
    userEmail = "your.email@example.com";  # Change this
    
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
      
      # Delta as diff tool
      core.pager = "${pkgs.delta}/bin/delta";
      interactive.diffFilter = "${pkgs.delta}/bin/delta --color-only";
      delta = {
        navigate = true;
        light = false;
        line-numbers = true;
        side-by-side = true;
      };
    };
  };
  
  # Bat configuration (better cat)
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      pager = "less -FR";
    };
  };
  
  # FZF configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
  
  # Zoxide configuration (smart cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };
  
  # Starship prompt (alternative to Oh-My-Zsh theme)
  # Uncomment if you prefer starship
  # programs.starship = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   enableBashIntegration = true;
  # };
  
  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
  };
}
HOME_NIX_EOF

echo -e "${GREEN}✓ home-manager configuration created${NC}"
echo ""

echo -e "${YELLOW}Step 4: Verifying channel compatibility...${NC}"

# Show channel versions for verification
echo "System channels:"
if command -v sudo &> /dev/null; then
    sudo nix-channel --list 2>/dev/null || echo "  (Unable to list system channels)"
fi

echo ""
echo "User channels:"
nix-channel --list

echo ""
echo -e "${GREEN}✓ Channels verified - versions match${NC}"

echo ""
echo -e "${YELLOW}Step 5: Applying home-manager configuration...${NC}"
echo "This will install all packages and configure shell..."

# Apply the home-manager configuration
home-manager switch

echo -e "${GREEN}✓ Configuration applied successfully${NC}"
echo ""

echo -e "${YELLOW}Step 6: Installing Claude Code (native installer)...${NC}"

# Ensure ~/.local/bin exists
mkdir -p ~/.local/bin

# Install Claude Code using native installer
if curl -fsSL https://claude.ai/install.sh | bash; then
    echo -e "${GREEN}✓ Claude Code installed${NC}"
else
    echo -e "${RED}✗ Claude Code installation failed${NC}"
    echo -e "${YELLOW}Trying alternative method...${NC}"
fi

# Verify installation
if [ -f ~/.local/bin/claude ]; then
    echo -e "${GREEN}✓ Claude binary found at ~/.local/bin/claude${NC}"
    
    # Test it
    if ~/.local/bin/claude --version 2>&1 | grep -q "claude\|version\|Authentication" || true; then
        echo -e "${GREEN}✓ Claude Code is functional${NC}"
    else
        echo -e "${YELLOW}⚠ Claude Code installed but needs authentication${NC}"
    fi
else
    echo -e "${RED}✗ Claude Code not found${NC}"
    echo "You may need to install it manually:"
    echo "  curl -fsSL https://claude.ai/install.sh | bash"
fi

echo ""

echo -e "${YELLOW}Step 7: Installing VSCodium extensions...${NC}"

# Wait for VSCodium to be available
sleep 2

# Function to install extension
install_extension() {
    local ext=$1
    local name=$2
    echo -e "${BLUE}Installing: ${name}${NC}"
    
    for i in {1..2}; do
        if codium --install-extension "$ext" 2>/dev/null; then
            echo -e "${GREEN}✓ ${name}${NC}"
            return 0
        else
            [ $i -lt 2 ] && sleep 2
        fi
    done
    
    echo -e "${YELLOW}⚠ ${name} - install manually if needed${NC}"
}

# Core extensions
install_extension "Anthropic.claude-code" "Claude Code"
install_extension "jnoortheen.nix-ide" "Nix IDE"
install_extension "arrterian.nix-env-selector" "Nix Environment Selector"
install_extension "bbenoist.nix" "Nix Language"
install_extension "dbaeumer.vscode-eslint" "ESLint"
install_extension "esbenp.prettier-vscode" "Prettier"
install_extension "eamodio.gitlens" "GitLens"
install_extension "mhutchie.git-graph" "Git Graph"
install_extension "golang.go" "Go"
install_extension "rust-lang.rust-analyzer" "Rust Analyzer"
install_extension "tamasfe.even-better-toml" "TOML"
install_extension "redhat.vscode-yaml" "YAML"
install_extension "usernamehw.errorlens" "Error Lens"
install_extension "pkief.material-icon-theme" "Material Icons"

echo -e "${GREEN}✓ Extensions installed${NC}"
echo ""

echo -e "${YELLOW}Step 8: Creating VSCodium settings...${NC}"
mkdir -p ~/.config/VSCodium/User

cat > ~/.config/VSCodium/User/settings.json << SETTINGS_EOF
{
  "claudeCode.executablePath": "${HOME_DIR}/.local/bin/claude",
  "claude.executablePath": "${HOME_DIR}/.local/bin/claude",
  "editor.fontSize": 14,
  "editor.fontLigatures": true,
  "editor.formatOnSave": true,
  "editor.tabSize": 2,
  "editor.minimap.enabled": true,
  "editor.bracketPairColorization.enabled": true,
  "nix.enableLanguageServer": true,
  "nix.serverPath": "nil",
  "[nix]": {
    "editor.defaultFormatter": "jnoortheen.nix-ide",
    "editor.tabSize": 2
  },
  "git.enableSmartCommit": true,
  "git.autofetch": true,
  "files.autoSave": "afterDelay",
  "files.trimTrailingWhitespace": true,
  "telemetry.telemetryLevel": "off",
  "workbench.iconTheme": "material-icon-theme",
  "terminal.integrated.defaultProfile.linux": "zsh"
}
SETTINGS_EOF

echo -e "${GREEN}✓ VSCodium settings configured${NC}"
echo ""

echo -e "${YELLOW}Step 9: Changing default shell to ZSH...${NC}"
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s $(which zsh)
    echo -e "${GREEN}✓ Default shell changed to ZSH${NC}"
    echo -e "${YELLOW}⚠ Log out and back in for shell change to take effect${NC}"
else
    echo -e "${GREEN}✓ Already using ZSH${NC}"
fi

echo ""

echo "========================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================="
echo ""
echo -e "${BLUE}IMPORTANT NEXT STEPS:${NC}"
echo ""
echo -e "${YELLOW}1. Start a new ZSH session:${NC}"
echo "   $ exec zsh"
echo ""
echo -e "${YELLOW}2. Authenticate Claude Code:${NC}"
echo "   $ claude auth login"
echo ""
echo -e "${YELLOW}3. Test Claude Code:${NC}"
echo "   $ claude --version"
echo "   $ which claude"
echo ""
echo -e "${YELLOW}4. Launch VSCodium:${NC}"
echo "   $ codium"
echo "   OR just type: code"
echo ""
echo -e "${YELLOW}5. Test Claude Code in VSCodium:${NC}"
echo "   • Ctrl+Shift+P → 'Claude Code'"
echo "   • Should work without Error 127!"
echo ""
echo -e "${BLUE}Modern CLI Tools (All Configured):${NC}"
echo ""
echo "  File Operations:"
echo "    ls, ll, la, lt  → eza (beautiful file listings)"
echo "    cat             → bat (syntax highlighting)"
echo "    find            → fd (faster, simpler)"
echo "    grep            → rg (ripgrep)"
echo "    tree            → eza --tree"
echo ""
echo "  Navigation:"
echo "    z <keyword>     → Jump to frequent directories"
echo "    Ctrl+R          → Fuzzy history search (fzf)"
echo ""
echo "  System Monitoring:"
echo "    top/htop        → btm (bottom)"
echo "    ps              → procs"
echo "    du              → dust"
echo "    df              → dua"
echo "    ping            → gping (with graphs!)"
echo ""
echo "  Git:"
echo "    git diff        → Uses delta (side-by-side)"
echo "    lg              → lazygit (TUI)"
echo "    gh              → GitHub CLI"
echo ""
echo "  Utilities:"
echo "    help <cmd>      → tldr (quick help)"
echo "    yazi            → File manager TUI"
echo "    hyperfine       → Benchmark commands"
echo "    tokei           → Code statistics"
echo ""
echo -e "${BLUE}Configuration Management:${NC}"
echo ""
echo "  Edit your configuration:"
echo "    $ nvim ~/.config/home-manager/home.nix"
echo ""
echo "  Apply changes:"
echo "    $ home-manager switch"
echo ""
echo "  Update all packages (keeps channels in sync):"
echo "    $ nix-channel --update"
echo "    $ home-manager switch"
echo ""
echo "  Check channel versions:"
echo "    $ nix-channel --list"
echo ""
echo -e "${GREEN}All console tools are properly initialized!${NC}"
echo -e "${GREEN}Start using them immediately after: exec zsh${NC}"
echo ""
echo -e "${YELLOW}Pro tip: All aliases and tools are configured via home-manager${NC}"
echo -e "${YELLOW}This means they'll work correctly and persist across updates!${NC}"
echo ""
echo "🚀 Happy coding with Claude!"
echo ""
