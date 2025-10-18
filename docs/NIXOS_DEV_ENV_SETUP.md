# NixOS Development Environment Quick Deploy

**Quick deployment script for setting up a complete NixOS development environment with VSCodium, Claude Code, and essential developer tools.**

## Overview

This deployment script (`deploy-nixos.sh`) provides a one-command setup for a persistent development environment on NixOS systems. It installs all necessary packages to your user profile (no system configuration changes required) and configures VSCodium with Claude Code and popular extensions.

**Key Features:**
- 🔒 **User-level installation** - No sudo required for packages (uses `nix-env`)
- 💾 **Persistent across reboots** - Installed packages survive system updates
- 🤖 **Claude Code integration** - Pre-configured with fixed CLI wrapper
- 🛠️ **Complete toolchain** - Modern CLI tools, build tools, and language support
- 📦 **VSCodium extensions** - 25+ pre-installed extensions for productivity

## Prerequisites

- NixOS system (tested on NixOS 24.05+)
- Internet connection for package downloads
- ~2GB free disk space for packages
- User with home directory

## Quick Start

### Download and Run

```bash
# Download the script
curl -O https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/scripts/deploy-nixos.sh

# Make executable
chmod +x deploy-nixos.sh

# Run as regular user (NOT with sudo)
./deploy-nixos.sh
```

**Installation time:** 10-20 minutes depending on your internet speed

## What Gets Installed

### Core Development Tools

| Category | Packages |
|----------|----------|
| **Editors** | VSCodium, Vim, Neovim |
| **Version Control** | Git |
| **Build Tools** | GCC, GNU Make |
| **Network** | wget, curl |
| **Utilities** | htop, btop, tree, unzip, zip, psmisc |

### Modern CLI Tools

| Tool | Purpose |
|------|---------|
| `ripgrep` | Fast grep alternative (used by Claude Code) |
| `fd` | Fast find alternative |
| `fzf` | Fuzzy finder |
| `bat` | Cat with syntax highlighting |
| `eza` | Modern ls replacement |
| `jq` | JSON processor |
| `yq` | YAML processor |

### Programming Languages

- **Node.js 22** (LTS) - JavaScript/TypeScript runtime
- **Python 3** - Latest Python 3.x
- **Go** - Google's Go language
- **Rust** - Rustc + Cargo

### Claude Code

- **CLI Tool** - `~/.npm-global/bin/claude`
- **Fixed Wrapper** - Resolves NixOS-specific infinite recursion bug
- **VSCodium Extension** - Pre-configured with executable path
- **Symlinks** - `claude` and `claude-code` commands

### VSCodium Extensions (25+)

#### Core Development
- **Claude Code** - AI-powered coding assistant
- **ESLint** - JavaScript/TypeScript linting
- **Prettier** - Code formatting
- **Git Graph** - Visual git history
- **GitLens** - Enhanced git integration

#### Language Support
- **Go** - Full Go language support
- **Rust Analyzer** - Rust language server
- **Nix IDE** - NixOS configuration editing
- **Nix Environment Selector** - Switch Nix environments
- **Nix Language Support** - Syntax highlighting

#### Productivity
- **Error Lens** - Inline error messages
- **GitHub Copilot** - AI code completion (requires subscription)
- **Todo Tree** - Highlight TODOs and FIXMEs
- **Code Spell Checker** - Catch typos
- **Indent Rainbow** - Colorize indentation
- **Material Icon Theme** - Beautiful file icons

#### DevOps & Infrastructure
- **Docker** - Container management
- **Terraform** - Infrastructure as Code
- **GitHub Actions** - CI/CD workflows
- **Remote - SSH** - Remote development
- **YAML** - YAML language support
- **TOML** - TOML language support
- **XML Tools** - XML editing
- **Makefile Tools** - Makefile support

## Post-Installation Setup

### 1. Authenticate Claude Code CLI

```bash
# Authenticate with Anthropic
~/.npm-global/bin/claude auth login
# OR (if PATH is updated)
claude auth login
```

Follow the browser authentication flow.

### 2. Configure Claude Code in VSCodium

**CRITICAL STEP** - Claude Code won't work without this:

1. Launch VSCodium:
   ```bash
   codium
   ```

2. Open Settings (`Ctrl+,` or `Cmd+,`)

3. Search for: `Claude Code: Executable Path`

4. Set the path to:
   ```
   /home/<your-username>/.npm-global/bin/claude
   ```
   Replace `<your-username>` with your actual username.

5. Close and reopen VSCodium

### 3. Use Claude Code

- Press `Ctrl+Shift+P` (Command Palette)
- Type: `Claude Code`
- Select a Claude Code command
- Or use the keyboard shortcuts shown

### 4. Reload Shell Environment

To activate PATH changes without logout:

```bash
# Bash users
source ~/.bashrc

# Zsh users
source ~/.zshrc
```

## Troubleshooting

### Error 127: Command Not Found

**Symptom:** VSCodium shows "Error 127" when trying to use Claude Code

**Solutions:**

1. **Verify CLI works:**
   ```bash
   ~/.npm-global/bin/claude --version
   ```

2. **Check VSCodium Settings:**
   - Open Settings (`Ctrl+,`)
   - Search: `Claude Code: Executable Path`
   - Ensure it's set to: `/home/<username>/.npm-global/bin/claude`

3. **Check VSCodium logs:**
   - Press `F12` or `Ctrl+Shift+I` (Developer Tools)
   - Go to Console tab
   - Look for Claude Code errors

4. **Verify wrapper fix:**
   ```bash
   cat ~/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js
   ```
   Should reference `sdk.mjs`, not `cli.js` (infinite recursion).

5. **Reinstall Claude Code:**
   ```bash
   npm uninstall -g @anthropic-ai/claude-code
   npm install -g @anthropic-ai/claude-code
   # Re-run the wrapper fix from the script
   ```

### Extensions Failed to Install

**Symptom:** Extension installation errors during script run

**Solutions:**

1. **Launch VSCodium first:**
   ```bash
   codium
   ```
   Let it initialize, then close it.

2. **Re-run the script:**
   ```bash
   ./deploy-nixos.sh
   ```

3. **Install manually:**
   - Open VSCodium
   - Press `Ctrl+Shift+X` (Extensions)
   - Search for extension name
   - Click Install

### Claude Code Authentication Issues

**Symptom:** `claude auth login` fails

**Solutions:**

1. **Check internet connection**

2. **Verify firewall allows HTTPS:**
   ```bash
   curl -I https://api.anthropic.com
   ```

3. **Use browser authentication:**
   - Visit https://console.anthropic.com/
   - Generate API key
   - Set manually:
     ```bash
     export ANTHROPIC_API_KEY="your-key-here"
     ```

### PATH Not Updating

**Symptom:** `claude` command not found after installation

**Solutions:**

1. **Reload shell:**
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

2. **Check PATH manually:**
   ```bash
   echo $PATH | grep npm-global
   ```

3. **Add to PATH manually:**
   ```bash
   echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

## Architecture & Design

### Why User Profile Installation?

The script uses `nix-env -iA` instead of system-wide installation for several reasons:

1. **No root required** - Users can set up their own environments
2. **Isolated from system** - Won't break on `nixos-rebuild`
3. **User-specific** - Each user can have different tool versions
4. **Persistent** - Survives system updates and reboots
5. **Reversible** - Easy to remove without affecting system

### File Locations

```
User Environment:
~/.nix-profile/                    # Nix user profile (managed)
~/.npm-global/                     # NPM global packages
  ├── bin/claude                   # Claude Code CLI
  ├── bin/claude-code              # Symlink to claude
  └── lib/node_modules/
      └── @anthropic-ai/claude-code/
          ├── cli.js               # Fixed wrapper
          └── sdk.mjs              # Actual implementation

~/.config/nixpkgs/
  └── config.nix                   # User Nix configuration

~/.config/VSCodium/
  └── User/
      └── settings.json            # VSCodium settings

~/.local/bin/
  └── codium-wrapped               # VSCodium wrapper script

Shell Configuration:
~/.bashrc                          # PATH and env setup
~/.zshrc                           # PATH and env setup (if using zsh)
```

### Claude Code Wrapper Fix

The script fixes a critical bug in the NPM-installed Claude Code:

**Problem:**
```javascript
// Default cli.js (BROKEN)
#!/usr/bin/env node
require('./cli.js')  // ← Infinite recursion!
```

**Solution:**
```bash
#!/run/current-system/sw/bin/bash
exec $HOME/.nix-profile/bin/node \
  $HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/sdk.mjs "$@"
```

This directly executes `sdk.mjs` instead of recursively calling `cli.js`.

## Managing Your Environment

### List Installed Packages

```bash
# Show all user-installed packages
nix-env -q

# Show package versions
nix-env -q --description
```

### Remove a Package

```bash
# Remove single package
nix-env --uninstall <package-name>

# Example: Remove vim
nix-env --uninstall vim
```

### Remove ALL User Packages

```bash
# Nuclear option - removes everything
nix-env --uninstall '*'
```

### Update User Packages

```bash
# Update user channel
nix-channel --update

# Upgrade all packages
nix-env -u
```

### List Generations

```bash
# Show all user profile generations
nix-env --list-generations

# Rollback to previous generation
nix-env --rollback

# Switch to specific generation
nix-env --switch-generation 42
```

### Clean Up Old Generations

```bash
# Remove old user profile generations
nix-collect-garbage -d

# System-wide cleanup (requires sudo)
sudo nix-collect-garbage -d
```

## Making Permanent (System-Wide)

If you want these packages available for all users and persist through system rebuilds, add them to `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  # ... existing configuration ...

  environment.systemPackages = with pkgs; [
    # Core tools
    wget git curl vim neovim

    # Modern CLI
    ripgrep fd fzf bat eza jq yq

    # Development
    vscodium nodejs_22 python3 go rustc cargo
    gcc gnumake

    # Utilities
    htop btop tree unzip zip psmisc
  ];

  # Enable unfree packages globally
  nixpkgs.config.allowUnfree = true;
}
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

## Advanced Customization

### Adding More Extensions

Edit the script and add to the extension list:

```bash
install_extension "publisher.extension-id" "Extension Name"
```

Find extension IDs from the VSCodium marketplace URL or:
```bash
codium --list-extensions
```

### Custom VSCodium Settings

Edit `~/.config/VSCodium/User/settings.json`:

```json
{
  "editor.fontSize": 16,
  "workbench.colorTheme": "Monokai",
  // ... other settings
}
```

Changes take effect immediately (no restart needed).

### Add More Development Tools

Add to the `nix-env -iA` command:

```bash
nix-env -iA \
    nixpkgs.existing-package \
    nixpkgs.your-new-package
```

Search for packages:
```bash
nix search nixpkgs <package-name>
```

## Security Considerations

### Unfree Packages

The script enables unfree packages in `~/.config/nixpkgs/config.nix`:

```nix
{ allowUnfree = true; }
```

This allows installation of:
- VSCodium (technically free, but some extensions may be unfree)
- GitHub Copilot (proprietary)
- Other proprietary tools

**If you want to restrict this**, remove the config file:
```bash
rm ~/.config/nixpkgs/config.nix
```

### Telemetry

VSCodium has telemetry **disabled by default** (unlike VS Code).

The script additionally sets:
```json
"telemetry.telemetryLevel": "off"
```

### Workspace Trust

Enabled by default for security:
```json
"security.workspace.trust.enabled": true
```

Always review code before trusting a workspace.

## Updating the Script

### Get Latest Version

```bash
curl -O https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/scripts/deploy-nixos.sh
chmod +x deploy-nixos.sh
```

### Run Updates

Re-running the script is safe and will:
- ✅ Update existing packages
- ✅ Install new extensions
- ✅ Preserve your VSCodium settings
- ✅ Fix any broken configurations

## Uninstallation

### Remove User Packages Only

```bash
# Remove all user-installed packages
nix-env --uninstall '*'

# Clean up old generations
nix-collect-garbage -d
```

### Complete Removal

```bash
# Remove user packages
nix-env --uninstall '*'

# Remove configurations
rm -rf ~/.config/nixpkgs
rm -rf ~/.config/VSCodium
rm -rf ~/.npm-global
rm -f ~/.local/bin/codium-wrapped

# Remove shell modifications
# Edit ~/.bashrc and ~/.zshrc to remove added lines

# Clean up Nix store
nix-collect-garbage -d
```

## FAQ

### Q: Why not use Home Manager?

**A:** This script provides a simpler, quicker setup without learning Home Manager's declarative configuration. It's ideal for:
- Quick prototypes
- Testing tools temporarily
- Users new to NixOS
- One-off environments

For long-term reproducibility, consider migrating to Home Manager.

### Q: Can I use this on non-NixOS systems?

**A:** Partially. The `nix-env` commands will work on any system with Nix installed, but the VSCodium wrapper and some paths are NixOS-specific.

### Q: Will this break my existing NixOS setup?

**A:** No. This script:
- Only modifies user profile (not system configuration)
- Doesn't touch `/etc/nixos/configuration.nix`
- Can be completely reversed
- Won't affect system rebuilds

### Q: How much disk space does this use?

**A:** Approximately 1.5-2GB for all packages and dependencies.

Check usage:
```bash
nix-env -q --description | wc -l  # Package count
du -sh ~/.nix-profile              # Profile size
```

### Q: Can I run this multiple times?

**A:** Yes! Re-running is safe and will:
- Update packages to latest versions
- Install any missing extensions
- Re-apply configuration fixes
- Not duplicate existing packages

### Q: Why does Claude Code need a wrapper fix?

**A:** The NPM package has a bug where `cli.js` calls itself recursively. Our fix points directly to the actual implementation in `sdk.mjs`. This is NixOS-specific due to how Nix manages paths.

## Contributing

Found a bug or want to add features? Submit issues or pull requests:

**Repository:** https://github.com/MasterofNull/Hyper-NixOS

**Script Location:** `scripts/deploy-nixos.sh`

### Improvement Ideas

- [ ] Add language-specific profiles (Python dev, Go dev, etc.)
- [ ] Support for other editors (Emacs, etc.)
- [ ] Integration with Home Manager
- [ ] Automated backup/restore of configurations
- [ ] Extension update checker

## Related Documentation

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Package Search](https://search.nixos.org/packages)
- [VSCodium Documentation](https://vscodium.com/)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)

## License

This script is part of the Hyper-NixOS project.

**License:** MIT License

**Copyright:** © 2024-2025 MasterofNull

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
