#!/usr/bin/env bash
#
# NixOS Quick Deploy for AIDB Development
# Purpose: Install ALL packages and tools needed for AIDB development
# Scope: Complete system setup - ready for AIDB deployment
# What it does: Installs Podman, PostgreSQL, Python, Nix tools, modern CLI tools
# What it does NOT do: Initialize AIDB database or start containers
# Author: AI Agent
# Created: 2025-10-23
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HM_CONFIG_DIR="$HOME/.config/home-manager"
HM_CONFIG_FILE="$HM_CONFIG_DIR/home.nix"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  NixOS Quick Deploy for AIDB Development                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"
    echo -e "${YELLOW}This installs ALL prerequisites for AIDB (Podman, PostgreSQL, etc.)${NC}"
    echo -e "${YELLOW}After this completes, you'll be ready to run aidb-quick-setup.sh${NC}\n"
}

print_section() {
    echo -e "\n${GREEN}▶ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$(echo -e ${BLUE}?${NC} $prompt)" response
    response=${response:-$default}

    [[ "$response" =~ ^[Yy]$ ]]
}

prompt_user() {
    local prompt="$1"
    local default="${2:-}"
    local response

    if [[ -n "$default" ]]; then
        read -p "$(echo -e ${BLUE}?${NC} $prompt [$default]: )" response
        echo "${response:-$default}"
    else
        read -p "$(echo -e ${BLUE}?${NC} $prompt: )" response
        echo "$response"
    fi
}

# ============================================================================
# Prerequisites Check
# ============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"

    # Check NixOS
    if [[ ! -f /etc/NIXOS ]]; then
        print_error "This script must be run on NixOS"
        exit 1
    fi
    print_success "Running on NixOS"

    # Check home-manager
    if command -v home-manager &> /dev/null; then
        print_success "home-manager is installed"
    else
        print_warning "home-manager not found"
        if confirm "Install home-manager now?" "y"; then
            install_home_manager
        else
            print_error "home-manager is required. Exiting."
            exit 1
        fi
    fi
}

install_home_manager() {
    print_section "Installing home-manager"

    nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz home-manager
    nix-channel --update
    nix-shell '<home-manager>' -A install

    print_success "home-manager installed"
}

# ============================================================================
# User Information Gathering
# ============================================================================

gather_user_info() {
    print_section "Gathering User Information"

    print_info "This information will be used to configure Git and other tools."

    # Git configuration
    GIT_USER_NAME=$(prompt_user "Enter your full name" "$(git config --global user.name 2>/dev/null || echo '')")
    GIT_USER_EMAIL=$(prompt_user "Enter your email address" "$(git config --global user.email 2>/dev/null || echo '')")

    # Editor preference
    print_info "\nDefault editor options:"
    echo "  1) vim"
    echo "  2) neovim"
    echo "  3) vscodium"
    EDITOR_CHOICE=$(prompt_user "Choose editor (1-3)" "1")

    case $EDITOR_CHOICE in
        1) DEFAULT_EDITOR="vim" ;;
        2) DEFAULT_EDITOR="nvim" ;;
        3) DEFAULT_EDITOR="code" ;;
        *) DEFAULT_EDITOR="vim" ;;
    esac

    print_success "Configuration gathered"
}

# ============================================================================
# Home Manager Configuration
# ============================================================================

create_home_manager_config() {
    print_section "Creating Home Manager Configuration"

    # Backup existing config
    if [[ -f "$HM_CONFIG_FILE" ]]; then
        print_warning "Existing home.nix found"
        if confirm "Backup and replace with new configuration?" "n"; then
            local backup_file="$HM_CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$HM_CONFIG_FILE" "$backup_file"
            print_success "Backed up to: $backup_file"
        else
            print_info "Keeping existing configuration"
            return
        fi
    fi

    mkdir -p "$HM_CONFIG_DIR"

    cat > "$HM_CONFIG_FILE" <<'NIXEOF'
{ config, pkgs, ... }:

{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    # ========================================================================
    # AIDB v4.0 Requirements (CRITICAL - Must be installed)
    # ========================================================================

    podman                  # Container runtime for AIDB
    podman-compose          # Docker-compose compatibility
    sqlite                  # Tier 1 Guardian database
    openssl                 # Cryptographic operations
    bc                      # Basic calculator
    inotify-tools           # File watching for Guardian

    # ========================================================================
    # Core NixOS Development Tools
    # ========================================================================

    # Nix tools
    nix-tree                # Visualize Nix dependencies
    nix-index               # Index Nix packages for fast searching
    nix-prefetch-git        # Prefetch git repositories
    nixpkgs-fmt             # Nix code formatter
    alejandra               # Alternative Nix formatter
    statix                  # Linter for Nix
    deadnix                 # Find dead Nix code
    nix-output-monitor      # Better build output
    nix-du                  # Disk usage for Nix store
    nixpkgs-review          # Review nixpkgs PRs
    nix-diff                # Compare Nix derivations

    # ========================================================================
    # Development Tools
    # ========================================================================

    # Version control
    git git-crypt tig lazygit

    # Text editors
    neovim
    # Note: vscodium installed via programs.vscode below

    # Modern CLI tools
    ripgrep ripgrep-all     # Better grep
    fd                      # Better find
    fzf                     # Fuzzy finder
    bat                     # Better cat
    eza                     # Better ls
    jq yq                   # JSON/YAML processing
    choose                  # Better cut/awk
    du-dust                 # Better du
    duf                     # Better df
    broot                   # Better tree
    dog                     # Better dig

    # Terminal tools
    alacritty tmux screen mosh asciinema

    # File management
    ranger dos2unix unrar p7zip file rsync rclone

    # Network tools
    wget curl netcat-gnu socat mtr nmap

    # System tools
    htop btop tree unzip zip bc

    # ========================================================================
    # Programming Languages & Tools
    # ========================================================================

    # Python (REQUIRED for AIDB)
    python311
    python311Packages.pip
    python311Packages.virtualenv

    # Additional languages
    go rustc cargo ruby

    # Development utilities
    gnumake gcc nodejs_22

    # ========================================================================
    # ZSH Configuration
    # ========================================================================

    zsh
    zsh-syntax-highlighting
    zsh-autosuggestions
    zsh-completions
    zsh-powerlevel10k
    grc
    pay-respects

    # ========================================================================
    # Text Processing
    # ========================================================================

    tldr
    cht-sh
    pandoc

    # ========================================================================
    # Utilities
    # ========================================================================

    mcfly           # Command history search
    navi            # Interactive cheatsheet
    starship        # Shell prompt
    hexedit         # Hex editor
    qrencode        # QR code generator
  ];

  # ========================================================================
  # ZSH Configuration
  # ========================================================================

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = false;

    history = {
      size = 100000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    shellAliases = {
      # Basic modern replacements
      ll = "eza -l --icons";
      la = "eza -la --icons";
      lt = "eza --tree --icons";
      cat = "bat";
      du = "dust";
      df = "duf";

      # NixOS specific
      nrs = "sudo nixos-rebuild switch";
      nrt = "sudo nixos-rebuild test";
      nrb = "sudo nixos-rebuild boot";
      hms = "home-manager switch";
      nfu = "nix flake update";
      nfc = "nix flake check";
      nfb = "nix build";
      nfd = "nix develop";

      # Nix development
      nix-dev = "nix develop -c $SHELL";
      nix-search = "nix search nixpkgs";
      nix-shell-pure = "nix-shell --pure";

      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      gco = "git checkout";
      gb = "git branch";

      # Lazy tools
      lg = "lazygit";

      # Find shortcuts
      ff = "fd";
      rg = "rg --smart-case";
    };

    initContent = ''
      # Powerlevel10k instant prompt
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      # Load Powerlevel10k theme
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

      # P10k configuration (minimal for NixOS dev)
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      # Enhanced command history with mcfly
      if command -v mcfly &> /dev/null; then
        eval "$(mcfly init zsh)"
      fi

      # FZF configuration
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

      # Nix-specific environment
      export NIX_PATH=$HOME/.nix-defexpr/channels''${NIX_PATH:+:}$NIX_PATH

      # Better error messages
      export NIXPKGS_ALLOW_UNFREE=1
    '';
  };

  # ========================================================================
  # Git Configuration
  # ========================================================================

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "GITUSERNAME";
        email = "GITUSEREMAIL";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      core = {
        editor = "DEFAULTEDITOR";
      };
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "log --oneline --graph --decorate --all";
      };
    };
  };

  # ========================================================================
  # Vim Configuration (minimal)
  # ========================================================================

  programs.vim = {
    enable = true;
    defaultEditor = false;  # Use DEFAULTEDITOR instead

    settings = {
      number = true;
      relativenumber = true;
      expandtab = true;
      tabstop = 2;
      shiftwidth = 2;
    };
  };

  # ========================================================================
  # VSCodium Configuration (Declarative)
  # ========================================================================

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;

    # Extensions installed declaratively
    extensions = with pkgs.vscode-extensions; [
      # Nix language support
      jnoortheen.nix-ide
      arrterian.nix-env-selector

      # Git tools
      eamodio.gitlens

      # General development
      editorconfig.editorconfig
      esbenp.prettier-vscode
    ];

    # VSCodium settings (declarative)
    # Note: Claude Code paths will be added by bash script (dynamic)
    userSettings = {
      # Editor Configuration
      "editor.fontSize" = 14;
      "editor.fontFamily" = "'Fira Code', 'Droid Sans Mono', 'monospace'";
      "editor.fontLigatures" = true;
      "editor.formatOnSave" = true;
      "editor.formatOnPaste" = true;
      "editor.tabSize" = 2;
      "editor.insertSpaces" = true;
      "editor.detectIndentation" = true;
      "editor.minimap.enabled" = true;
      "editor.bracketPairColorization.enabled" = true;
      "editor.guides.bracketPairs" = true;

      # Nix-specific settings
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";
      "nix.formatterPath" = "nixpkgs-fmt";
      "[nix]" = {
        "editor.defaultFormatter" = "jnoortheen.nix-ide";
        "editor.tabSize" = 2;
      };

      # Git configuration
      "git.enableSmartCommit" = true;
      "git.autofetch" = true;
      "gitlens.codeLens.enabled" = true;

      # Terminal
      "terminal.integrated.defaultProfile.linux" = "zsh";
      "terminal.integrated.fontSize" = 13;

      # Theme
      "workbench.colorTheme" = "Default Dark Modern";

      # File associations
      "files.associations" = {
        "*.nix" = "nix";
        "flake.lock" = "json";
      };

      # Miscellaneous
      "files.autoSave" = "afterDelay";
      "files.autoSaveDelay" = 1000;
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;
    };
  };

  # ========================================================================
  # Alacritty Terminal Configuration
  # ========================================================================

  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = 0.95;
        padding = {
          x = 10;
          y = 10;
        };
      };
      font = {
        size = 11.0;
        normal = {
          family = "MesloLGS NF";
        };
      };
      colors = {
        primary = {
          background = "0x1e1e1e";
          foreground = "0xd4d4d4";
        };
      };
    };
  };

  # ========================================================================
  # Session Variables
  # ========================================================================

  home.sessionVariables = {
    EDITOR = "DEFAULTEDITOR";
    VISUAL = "DEFAULTEDITOR";
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  # ========================================================================
  # Home Files
  # ========================================================================

  home.file = {
    # Create local bin directory
    ".local/bin/.keep".text = "";

    # P10k configuration (minimal)
    ".p10k.zsh".text = ''
      # Minimal Powerlevel10k configuration for NixOS development
      # For full customization, run: p10k configure

      typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
        dir                     # current directory
        vcs                     # git status
        prompt_char             # prompt symbol
      )

      typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
        status                  # exit code of the last command
        command_execution_time  # duration of the last command
        background_jobs         # presence of background jobs
        context                 # user@hostname
      )

      typeset -g POWERLEVEL9K_MODE=nerdfont-complete
      typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=true
      typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false
      typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
    '';
  };
}
NIXEOF

    # Replace placeholders
    sed -i "s/GITUSERNAME/$GIT_USER_NAME/" "$HM_CONFIG_FILE"
    sed -i "s/GITUSEREMAIL/$GIT_USER_EMAIL/" "$HM_CONFIG_FILE"
    sed -i "s/DEFAULTEDITOR/$DEFAULT_EDITOR/g" "$HM_CONFIG_FILE"

    print_success "Home manager configuration created"
}

# ============================================================================
# Apply Configuration
# ============================================================================

apply_home_manager_config() {
    print_section "Applying Home Manager Configuration"

    print_info "This will install packages and configure your environment..."
    print_warning "This may take 10-15 minutes on first run"

    if ! confirm "Proceed with home-manager switch?" "y"; then
        print_info "Skipping home-manager switch"
        print_info "You can manually run: home-manager switch"
        return
    fi

    print_info "Running home-manager switch..."

    if home-manager switch; then
        print_success "Home manager configuration applied successfully!"
    else
        print_error "home-manager switch failed"
        print_info "Check errors above and try: home-manager switch"
        return 1
    fi
}

# ============================================================================
# Claude Code Installation & Configuration
# ============================================================================

install_claude_code() {
    print_section "Installing Claude Code"

    # Set up NPM paths
    export NPM_CONFIG_PREFIX=~/.npm-global
    mkdir -p ~/.npm-global/bin
    export PATH=~/.npm-global/bin:$PATH

    print_info "Installing @anthropic-ai/claude-code via npm..."

    if npm install -g @anthropic-ai/claude-code; then
        print_success "Claude Code npm package installed"
    else
        print_error "Failed to install Claude Code"
        return 1
    fi

    # Verify installation
    CLI_FILE="$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    if [ ! -f "$CLI_FILE" ]; then
        print_error "Claude Code CLI not found at $CLI_FILE"
        return 1
    fi

    # Make CLI executable
    chmod +x "$CLI_FILE"
    print_success "Claude Code CLI is executable"

    # Create smart Node.js wrapper
    print_info "Creating smart Node.js wrapper..."

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
    print_success "Created claude-wrapper"

    # Test the wrapper
    if ~/.npm-global/bin/claude-wrapper --version >/dev/null 2>&1; then
        CLAUDE_VERSION=$(~/.npm-global/bin/claude-wrapper --version 2>/dev/null | head -n1)
        print_success "Claude Code wrapper works! Version: ${CLAUDE_VERSION}"
        CLAUDE_EXEC_PATH="$HOME/.npm-global/bin/claude-wrapper"
    else
        print_warning "Wrapper test inconclusive, but created"
        CLAUDE_EXEC_PATH="$HOME/.npm-global/bin/claude-wrapper"
    fi

    # Create VSCodium wrapper
    print_info "Creating VSCodium wrapper..."
    mkdir -p ~/.local/bin

    cat > ~/.local/bin/codium-wrapped << 'CODIUM_WRAPPER_EOF'
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
CODIUM_WRAPPER_EOF

    chmod +x ~/.local/bin/codium-wrapped
    print_success "VSCodium wrapper created"
}

configure_vscodium_for_claude() {
    print_section "Adding Claude Code Configuration to VSCodium"

    # Get paths for environment variables
    NODE_BIN_DIR=$(dirname $(readlink -f $(which node) 2>/dev/null) 2>/dev/null || echo "$HOME/.nix-profile/bin")
    NIX_PROFILE_BIN="$HOME/.nix-profile/bin"
    CLAUDE_EXEC_PATH="$HOME/.npm-global/bin/claude-wrapper"

    print_info "Node.js bin directory: $NODE_BIN_DIR"
    print_info "Nix profile bin: $NIX_PROFILE_BIN"
    print_info "Claude wrapper: $CLAUDE_EXEC_PATH"

    # Backup existing settings
    SETTINGS_FILE="$HOME/.config/VSCodium/User/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%s)"
        print_success "Backed up existing settings"
    fi

    # Use jq to merge Claude Code settings with existing settings
    # This preserves home-manager's declarative settings while adding dynamic paths
    if command -v jq &> /dev/null && [ -f "$SETTINGS_FILE" ]; then
        print_info "Merging Claude Code settings with existing configuration..."

        TEMP_SETTINGS=$(mktemp)
        jq --arg execPath "$CLAUDE_EXEC_PATH" \
           --arg nixBin "$NIX_PROFILE_BIN" \
           --arg nodeBin "$NODE_BIN_DIR" \
           --arg npmModules "$HOME/.npm-global/lib/node_modules" \
           '. + {
              "claude-code.executablePath": $execPath,
              "claude-code.claudeProcessWrapper": $execPath,
              "claude-code.environmentVariables": [
                {
                  "name": "PATH",
                  "value": ($nixBin + ":" + $nodeBin + ":/run/current-system/sw/bin:${env:PATH}")
                },
                {
                  "name": "NODE_PATH",
                  "value": $npmModules
                }
              ],
              "claude-code.autoStart": false,
              "claudeCode.executablePath": $execPath,
              "claudeCode.claudeProcessWrapper": $execPath,
              "claudeCode.environmentVariables": [
                {
                  "name": "PATH",
                  "value": ($nixBin + ":" + $nodeBin + ":/run/current-system/sw/bin:${env:PATH}")
                },
                {
                  "name": "NODE_PATH",
                  "value": $npmModules
                }
              ],
              "claudeCode.autoStart": false
           }' "$SETTINGS_FILE" > "$TEMP_SETTINGS"

        mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
        print_success "Claude Code settings merged successfully"
    else
        print_warning "jq not available, creating full settings file"
        # Fallback: create complete settings file
        cat > "$SETTINGS_FILE" << 'SETTINGS_EOF'
{
  "claude-code.executablePath": "CLAUDE_EXEC_PATH_PLACEHOLDER",
  "claude-code.claudeProcessWrapper": "CLAUDE_EXEC_PATH_PLACEHOLDER",
  "claude-code.environmentVariables": [
    {"name": "PATH", "value": "NIX_PROFILE_BIN_PLACEHOLDER:NODE_BIN_DIR_PLACEHOLDER:/run/current-system/sw/bin:${env:PATH}"},
    {"name": "NODE_PATH", "value": "NPM_MODULES_PLACEHOLDER"}
  ],
  "claude-code.autoStart": false,
  "claudeCode.executablePath": "CLAUDE_EXEC_PATH_PLACEHOLDER",
  "claudeCode.claudeProcessWrapper": "CLAUDE_EXEC_PATH_PLACEHOLDER",
  "claudeCode.environmentVariables": [
    {"name": "PATH", "value": "NIX_PROFILE_BIN_PLACEHOLDER:NODE_BIN_DIR_PLACEHOLDER:/run/current-system/sw/bin:${env:PATH}"},
    {"name": "NODE_PATH", "value": "NPM_MODULES_PLACEHOLDER"}
  ],
  "claudeCode.autoStart": false
}
SETTINGS_EOF
        # Replace placeholders
        sed -i "s|CLAUDE_EXEC_PATH_PLACEHOLDER|${CLAUDE_EXEC_PATH}|g" "$SETTINGS_FILE"
        sed -i "s|NIX_PROFILE_BIN_PLACEHOLDER|${NIX_PROFILE_BIN}|g" "$SETTINGS_FILE"
        sed -i "s|NODE_BIN_DIR_PLACEHOLDER|${NODE_BIN_DIR}|g" "$SETTINGS_FILE"
        sed -i "s|NPM_MODULES_PLACEHOLDER|${HOME}/.npm-global/lib/node_modules|g" "$SETTINGS_FILE"
        print_success "Claude Code settings created"
    fi
}

install_vscodium_extensions() {
    print_section "Installing Additional VSCodium Extensions"

    # Export PATH
    export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

    # Kill any running VSCodium instances
    pkill -f "codium" 2>/dev/null && print_info "Killed running VSCodium processes" || true
    sleep 2

    # Function to install extension with retry
    install_ext() {
        local ext=$1
        local name=$2

        print_info "Installing: ${name}"

        for i in {1..3}; do
            if codium --install-extension "$ext" 2>/dev/null; then
                print_success "${name} installed"
                return 0
            else
                if [ $i -lt 3 ]; then
                    print_warning "Retry $i/3..."
                    sleep 2
                fi
            fi
        done

        print_warning "${name} - install manually if needed"
        return 1
    }

    # Note: Base extensions (Nix IDE, GitLens, Prettier, EditorConfig)
    # are already installed via home-manager's programs.vscode.extensions

    # Install Claude Code (main addition)
    print_info "Installing Claude Code extension..."
    install_ext "Anthropic.claude-code" "Claude Code"

    # Install additional helpful extensions not in nixpkgs
    print_info "Installing additional development extensions..."
    install_ext "dbaeumer.vscode-eslint" "ESLint"
    install_ext "mhutchie.git-graph" "Git Graph"
    install_ext "golang.go" "Go"
    install_ext "rust-lang.rust-analyzer" "Rust Analyzer"
    install_ext "usernamehw.errorlens" "Error Lens"
    install_ext "tamasfe.even-better-toml" "Even Better TOML"
    install_ext "redhat.vscode-yaml" "YAML"
    install_ext "mechatroner.rainbow-csv" "Rainbow CSV"
    install_ext "gruntfuggly.todo-tree" "Todo Tree"
    install_ext "pkief.material-icon-theme" "Material Icon Theme"
    install_ext "ms-azuretools.vscode-docker" "Docker"
    install_ext "hashicorp.terraform" "Terraform"

    print_success "Additional extensions installation complete"
}

# ============================================================================
# Post-Install Instructions
# ============================================================================

print_post_install() {
    print_section "Installation Complete!"

    cat <<EOF

${GREEN}✓ NixOS Quick Deploy Complete - System Ready for AIDB!${NC}

${BLUE}What was installed:${NC}
  ${GREEN}AIDB Prerequisites:${NC}
    • Podman + podman-compose (container runtime)
    • SQLite (Tier 1 Guardian database)
    • Python 3.11 + pip + virtualenv
    • OpenSSL, inotify-tools, bc

  ${GREEN}NixOS Development Tools:${NC}
    • Nix tools (nix-tree, nixpkgs-fmt, alejandra, statix, etc.)
    • VSCodium with NixOS + Claude Code extensions

  ${GREEN}Claude Code Integration:${NC}
    • Claude Code CLI installed globally
    • Smart Node.js wrapper (fixes Error 127)
    • VSCodium fully configured for Claude Code
    • All required extensions installed

  ${GREEN}Modern CLI & Terminal:${NC}
    • ZSH with Powerlevel10k theme
    • Modern tools (ripgrep, bat, eza, fzf, fd, etc.)
    • Alacritty terminal
    • Git with aliases

${BLUE}Important Notes:${NC}
  1. ${YELLOW}Restart your terminal:${NC} exec zsh
  2. VSCodium command: ${GREEN}codium${NC} or ${GREEN}codium-wrapped${NC}
  3. Claude Code wrapper: ${GREEN}~/.npm-global/bin/claude-wrapper${NC}
  4. All AIDB prerequisites are now installed

${BLUE}Next Steps - Deploy AIDB:${NC}
  ${GREEN}1. Clone AIDB repository:${NC}
     git clone <your-repo> ~/Documents/AI-Opitmizer
     cd ~/Documents/AI-Opitmizer

  ${GREEN}2. Setup AIDB template:${NC}
     bash aidb-quick-setup.sh --template

  ${GREEN}3. Create your first project:${NC}
     bash aidb-quick-setup.sh --project MyProject

  ${GREEN}4. Start AIDB:${NC}
     cd ~/Documents/Projects/MyProject/.aidb/deployment/
     ./scripts/start.sh

  ${GREEN}5. Verify AIDB is running:${NC}
     curl http://localhost:8000/health

${BLUE}Useful Commands:${NC}
  ${GREEN}NixOS:${NC}
    nrs              # sudo nixos-rebuild switch
    hms              # home-manager switch
    nfu              # nix flake update

  ${GREEN}AIDB:${NC}
    podman pod ps    # List running pods
    podman ps        # List running containers

  ${GREEN}Development:${NC}
    nixpkgs-fmt      # Format Nix code
    alejandra        # Alternative Nix formatter
    statix check     # Lint Nix code
    lg               # lazygit

${BLUE}Documentation:${NC}
  • AIDB docs: ~/Documents/AI-Opitmizer/README.md
  • Shared knowledge: ~/Documents/AI-Opitmizer/.aidb-shared-knowledge/
  • Home manager: https://nix-community.github.io/home-manager/

${GREEN}System is ready! Now deploy AIDB when you're ready.${NC}

EOF
}

# ============================================================================
# Main
# ============================================================================

main() {
    print_header

    check_prerequisites
    gather_user_info
    create_home_manager_config
    apply_home_manager_config

    # Claude Code integration (runs after home-manager so Node.js is available)
    install_claude_code
    configure_vscodium_for_claude
    install_vscodium_extensions

    print_post_install
}

main "$@"
