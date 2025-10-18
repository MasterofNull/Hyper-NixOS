# CLI Tools Guide for Hyper-NixOS

This guide explains the modern CLI tools available in Hyper-NixOS for different purposes.

## Two Environments

### 1. Development Environment (Pre-Deployment)

**Purpose**: For developers working ON Hyper-NixOS itself (before it's deployed)

**Setup Script**: `scripts/setup-dev-environment.sh`

This script installs modern CLI tools on your development machine (Mac, Linux, etc.) so you can work on the Hyper-NixOS project with enhanced productivity.

**Usage**:
```bash
cd /path/to/Hyper-NixOS
./scripts/setup-dev-environment.sh
```

**Includes**:
- ZSH with Powerlevel10k prompt
- Modern file tools (fd, eza, bat, etc.)
- Git tools (lazygit, delta)
- System monitors (bottom, gdu, gping)
- Editors (micro, helix)
- And more...

---

### 2. Admin Environment (Deployed System)

**Purpose**: For users/administrators managing their Hyper-NixOS hypervisor

**Module**: `modules/features/modern-cli-tools.nix` + `modules/features/zsh-enhanced.nix`

These modules can be enabled on a deployed Hyper-NixOS system to provide modern CLI tools for system administration.

**Configuration Example**:
```nix
{
  # Enable modern CLI tools for system administration
  hypervisor.features.modernCliTools = {
    enable = true;

    fileManagement = true;    # fd, eza, yazi
    viewers = true;           # bat, fx
    monitoring = true;        # bottom, gdu, gping
    productivity = true;      # fzf, zoxide, ripgrep
    git = true;              # lazygit, delta, gh
    editors = true;          # micro, helix
  };

  # Optional: Enhanced ZSH
  hypervisor.features.zshEnhanced = {
    enable = true;
    powerlevel10k.enable = true;
    plugins.autosuggestions = true;
    plugins.syntaxHighlighting = true;
  };
}
```

---

## Tool Categories

### File Management
- **fd**: Modern find alternative with better defaults
- **eza**: Modern ls replacement with colors and icons
- **erdtree**: Tree view with disk usage
- **diskonaut**: Visual disk space analyzer
- **yazi**: Feature-rich TUI file manager
- **dust**: Disk usage visualization

### Viewers
- **bat**: Cat with syntax highlighting
- **fx**: Interactive JSON viewer
- **jless**: JSON viewer for large files
- **hexyl**: Hex viewer

### System Monitoring
- **bottom (btm)**: Modern system monitor (like htop but better)
- **gdu**: Interactive disk usage analyzer (Go version)
- **dua**: Interactive disk usage analyzer (Rust version)
- **gping**: Ping with real-time graphs
- **bandwhich**: Network bandwidth monitor
- **zenith**: System monitor with histograms

### Productivity
- **fzf**: Fuzzy finder for files and command history
- **zoxide**: Smarter cd command that learns your patterns
- **ripgrep (rg)**: Fast grep replacement
- **hyperfine**: Command-line benchmarking tool
- **tealdeer (tldr)**: Quick command examples
- **tokei**: Code statistics

### Git Tools
- **lazygit**: Beautiful TUI for git operations
- **delta**: Better git diffs with syntax highlighting
- **gh**: GitHub CLI for issues, PRs, etc.
- **onefetch**: Git repository summary with stats

### Editors
- **micro**: Modern text editor like nano but powerful
- **helix**: Post-modern modal editor (vim-like)

### Networking
- **termscp**: TUI for SCP/SFTP file transfers
- **curlie**: Better curl with httpie-like syntax
- **xh**: HTTPie replacement written in Rust

### Presentation & Screenshots
- **presenterm**: Terminal-based slideshow presentations
- **silicon**: Create beautiful code screenshots

### Dotfile Management
- **yadm**: Yet Another Dotfiles Manager
- **chezmoi**: Manage dotfiles across machines

---

## Quick Start

### For Developers (Pre-Deployment)

1. Run the setup script:
   ```bash
   ./scripts/setup-dev-environment.sh
   ```

2. Change your shell to ZSH:
   ```bash
   chsh -s $(which zsh)
   ```

3. Start a new shell:
   ```bash
   exec zsh
   ```

4. Configure your prompt:
   ```bash
   p10k configure
   ```

### For System Administrators (Deployed System)

1. Enable the modules in your configuration:
   ```nix
   # /etc/hypervisor/configuration.nix
   hypervisor.features.modernCliTools.enable = true;
   hypervisor.features.zshEnhanced.enable = true;
   ```

2. Rebuild your system:
   ```bash
   sudo nixos-rebuild switch --flake /etc/hypervisor
   ```

3. Configure your prompt (if using ZSH):
   ```bash
   p10k configure
   ```

---

## Common Use Cases

### File Navigation
```bash
# Old way
cd ~/Development/project-name
ls -la

# New way
z project    # Jumps to most used directory matching "project"
eza -la      # Better ls with colors and git status
```

### Searching Files
```bash
# Old way
find . -name "*.nix" -type f

# New way
fd "\.nix$"  # Simpler syntax, faster, respects .gitignore
```

### Viewing Files
```bash
# Old way
cat file.txt

# New way
bat file.txt  # Syntax highlighting, line numbers, git integration
```

### System Monitoring
```bash
# Old way
top
htop

# New way
btm  # Beautiful, customizable, interactive
```

### Git Operations
```bash
# Old way
git status
git add .
git commit -m "message"
git push

# New way
lg   # Opens lazygit - do everything visually
```

### Disk Usage
```bash
# Old way
du -sh *

# New way
gdu        # Interactive, visual, fast
diskonaut  # Even more visual with graphs
```

### History Search
```bash
# Old way
history | grep command

# New way
Ctrl+R     # Opens fzf with fuzzy search
```

---

## ZSH with Powerlevel10k

### Features
- **Instant Prompt**: Shell starts in <40ms
- **Auto-suggestions**: Suggests commands as you type (from history)
- **Syntax Highlighting**: Valid commands in green, invalid in red
- **History Search**: Use arrow keys to search through history
- **FZF Integration**: Ctrl+R for history, Ctrl+T for files
- **Zoxide Integration**: `z <partial>` to jump to directories

### Key Bindings
- `Ctrl+R`: Fuzzy search command history
- `Ctrl+T`: Fuzzy search files
- `Alt+C`: Fuzzy search directories (cd)
- `Up/Down Arrows`: Search history with current command prefix

### Aliases (Auto-configured)
```bash
cat → bat        # Syntax-highlighted cat
ls → eza         # Modern ls
ll → eza -l      # Long listing
la → eza -la     # All files
tree → eza --tree
top → btm        # System monitor
lg → lazygit     # Git TUI
```

---

## Customization

### Adding Custom Aliases

For **development environment**, edit `~/.zshrc`:
```bash
# Your custom aliases
alias myproject='cd ~/Development/my-project'
alias deploy='./scripts/deploy.sh'
```

For **deployed system**, add to your NixOS configuration:
```nix
programs.zsh.shellAliases = {
  myproject = "cd ~/Development/my-project";
  deploy = "./scripts/deploy.sh";
};
```

### FZF Configuration

Customize FZF colors and behavior:
```bash
export FZF_DEFAULT_OPTS='
  --color=fg:#d0d0d0,bg:#121212,hl:#5f87af
  --color=fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff
  --preview "bat --color=always {}"
'
```

---

## Troubleshooting

### ZSH not default shell
```bash
chsh -s $(which zsh)
# Then log out and log back in
```

### Powerlevel10k not showing
```bash
# Reinstall the theme
p10k configure
```

### Icons/symbols not showing
Install a Nerd Font:
```bash
# Development environment
./scripts/setup-dev-environment.sh  # Installs fonts automatically

# Or manually install: https://www.nerdfonts.com/
# Recommended: FiraCode Nerd Font, JetBrainsMono Nerd Font
```

### Command not found
Make sure the tool category is enabled:
```nix
hypervisor.features.modernCliTools = {
  enable = true;
  fileManagement = true;  # For fd, eza, etc.
  git = true;             # For lazygit, delta, etc.
  # ... enable categories as needed
};
```

---

## Resources

- [fd documentation](https://github.com/sharkdp/fd)
- [bat documentation](https://github.com/sharkdp/bat)
- [eza documentation](https://github.com/eza-community/eza)
- [bottom documentation](https://github.com/ClementTsang/bottom)
- [lazygit documentation](https://github.com/jesseduffield/lazygit)
- [zoxide documentation](https://github.com/ajeetdsouza/zoxide)
- [Powerlevel10k documentation](https://github.com/romkatv/powerlevel10k)

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
