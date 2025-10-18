################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: Enhanced ZSH Configuration
# Purpose: ZSH with powerlevel10k, plugins, and modern features
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.features.zshEnhanced;
in {
  options.hypervisor.features.zshEnhanced = {
    enable = mkEnableOption "enhanced ZSH shell with powerlevel10k and plugins";

    powerlevel10k = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Powerlevel10k prompt (fast, customizable)";
      };

      instantPrompt = mkOption {
        type = types.bool;
        default = true;
        description = "Enable instant prompt for faster shell startup";
      };
    };

    plugins = {
      autosuggestions = mkOption {
        type = types.bool;
        default = true;
        description = "Enable zsh-autosuggestions (suggest commands as you type)";
      };

      syntaxHighlighting = mkOption {
        type = types.bool;
        default = true;
        description = "Enable fast-syntax-highlighting (highlight commands)";
      };

      historySubstringSearch = mkOption {
        type = types.bool;
        default = true;
        description = "Enable history substring search (search history with arrows)";
      };

      completions = mkOption {
        type = types.bool;
        default = true;
        description = "Enable zsh-completions (additional completion definitions)";
      };
    };

    setAsDefault = mkOption {
      type = types.bool;
      default = true;
      description = "Set ZSH as the default shell for users";
    };

    historySize = mkOption {
      type = types.int;
      default = 10000;
      description = "Number of commands to keep in history";
    };

    enableFzfIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable FZF integration for command history and file search";
    };

    enableZoxideIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zoxide (smarter cd) integration";
    };
  };

  config = mkIf cfg.enable {
    # Install ZSH and plugins
    programs.zsh = {
      enable = true;

      # Enable completion system
      enableCompletion = true;

      # Auto-suggest configuration
      autosuggestions.enable = cfg.plugins.autosuggestions;

      # Syntax highlighting
      syntaxHighlighting.enable = cfg.plugins.syntaxHighlighting;

      # Shell aliases (global for all users)
      shellAliases = {
        # Directory navigation
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";

        # Safety features
        rm = "rm -i";
        cp = "cp -i";
        mv = "mv -i";

        # Quick edits
        zshrc = "$EDITOR ~/.zshrc";
        zshenv = "$EDITOR ~/.zshenv";

        # Reload shell
        reload = "exec $SHELL";
      };

      # History configuration
      histSize = cfg.historySize;
      histFile = mkDefault "$HOME/.zsh_history";

      # Interactive shell init (runs for all users)
      interactiveShellInit = ''
        # Powerlevel10k instant prompt
        ${optionalString (cfg.powerlevel10k.enable && cfg.powerlevel10k.instantPrompt) ''
          # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
          # Initialization code that may require console input (password prompts, [y/n]
          # confirmations, etc.) must go above this block; everything else may go below.
          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi
        ''}

        # History configuration
        HISTFILE=~/.zsh_history
        HISTSIZE=${toString cfg.historySize}
        SAVEHIST=${toString cfg.historySize}

        # History options
        setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
        setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
        setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
        setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
        setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
        setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
        setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
        setopt HIST_VERIFY               # Do not execute immediately upon history expansion.
        setopt SHARE_HISTORY             # Share history between all sessions.

        # Directory navigation
        setopt AUTO_CD                   # Auto cd when typing directory name
        setopt AUTO_PUSHD                # Push the old directory onto the stack on cd.
        setopt PUSHD_IGNORE_DUPS         # Do not store duplicates in the stack.
        setopt PUSHD_SILENT              # Do not print the directory stack after pushd or popd.

        # Completion options
        setopt ALWAYS_TO_END             # Move cursor to end if word had one match
        setopt AUTO_LIST                 # Automatically list choices on ambiguous completion
        setopt AUTO_MENU                 # Show completion menu on a successive tab press
        setopt COMPLETE_IN_WORD          # Complete from both ends of a word
        unsetopt MENU_COMPLETE           # Do not autoselect the first completion entry

        # Correction
        setopt CORRECT                   # Spelling correction for commands

        # Enable comments in interactive shell
        setopt INTERACTIVE_COMMENTS

        # Key bindings (emacs-style by default, can be changed to vi-style)
        bindkey -e  # Emacs key bindings

        # History substring search key bindings
        ${optionalString cfg.plugins.historySubstringSearch ''
          bindkey '^[[A' history-substring-search-up
          bindkey '^[[B' history-substring-search-down
          bindkey "$terminfo[kcuu1]" history-substring-search-up
          bindkey "$terminfo[kcud1]" history-substring-search-down
        ''}

        # FZF integration
        ${optionalString cfg.enableFzfIntegration ''
          if [ -f ~/.fzf.zsh ]; then
            source ~/.fzf.zsh
          fi

          # FZF key bindings for ZSH
          if command -v fzf-share >/dev/null; then
            source "$(fzf-share)/key-bindings.zsh"
            source "$(fzf-share)/completion.zsh"
          fi
        ''}

        # Zoxide integration (smarter cd)
        ${optionalString cfg.enableZoxideIntegration ''
          if command -v zoxide >/dev/null; then
            eval "$(zoxide init zsh)"
            # Alias for zoxide
            alias cd='z'
          fi
        ''}

        # Load Powerlevel10k theme
        ${optionalString cfg.powerlevel10k.enable ''
          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

          # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
        ''}
      '';

      # Prompt init (for non-powerlevel10k setups)
      promptInit = mkIf (!cfg.powerlevel10k.enable) ''
        autoload -U promptinit && promptinit
        prompt fade blue
      '';
    };

    # Install required packages
    environment.systemPackages = with pkgs; [
      zsh
      zsh-completions
      nix-zsh-completions
    ] ++ optionals cfg.plugins.autosuggestions [
      zsh-autosuggestions
    ] ++ optionals cfg.plugins.syntaxHighlighting [
      zsh-fast-syntax-highlighting
    ] ++ optionals cfg.plugins.historySubstringSearch [
      zsh-history-substring-search
    ] ++ optionals cfg.powerlevel10k.enable [
      zsh-powerlevel10k
      # Fonts for powerline symbols
      (nerdfonts.override { fonts = [ "FiraCode" "Meslo" "JetBrainsMono" ]; })
    ] ++ optionals cfg.enableFzfIntegration [
      fzf
    ] ++ optionals cfg.enableZoxideIntegration [
      zoxide
    ];

    # Set ZSH as default shell
    users.defaultUserShell = mkIf cfg.setAsDefault pkgs.zsh;

    # Font configuration for powerline symbols
    fonts = mkIf cfg.powerlevel10k.enable {
      packages = with pkgs; [
        (nerdfonts.override { fonts = [ "FiraCode" "Meslo" "JetBrainsMono" ]; })
      ];
    };

    # Environment variables
    environment.variables = {
      # ZSH dotfiles location
      ZDOTDIR = mkDefault "$HOME";
    };

    # Create default .p10k.zsh configuration for new users
    environment.etc."skel/.p10k.zsh" = mkIf cfg.powerlevel10k.enable {
      text = ''
        # Powerlevel10k configuration
        # Run `p10k configure` to customize this file

        # Temporarily change options.
        'builtin' 'local' '-a' 'p10k_config_opts'
        [[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
        [[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
        [[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
        'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

        # Instant prompt mode.
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose

        # Basic configuration
        typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
          dir                     # current directory
          vcs                     # git status
          prompt_char             # prompt symbol
        )

        typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
          status                  # exit code of the last command
          command_execution_time  # duration of the last command
          background_jobs         # presence of background jobs
          virtualenv              # python virtual environment
          context                 # user@hostname
          time                    # current time
        )

        # Prompt symbol
        typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
        typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196

        # Directory
        typeset -g POWERLEVEL9K_DIR_FOREGROUND=31

        # Git
        typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
        typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
        typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=39

        # Restore original options.
        (( ''${#p10k_config_opts} )) && setopt ''${p10k_config_opts[@]}
        'builtin' 'unset' 'p10k_config_opts'
      '';
    };

    # Feature configuration file
    environment.etc."hypervisor/features/zsh-enhanced.conf".text = ''
      # Enhanced ZSH Configuration
      # ZSH with powerlevel10k and productivity plugins

      FEATURE_NAME="zsh-enhanced"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"

      # Configuration
      POWERLEVEL10K="${if cfg.powerlevel10k.enable then "yes" else "no"}"
      INSTANT_PROMPT="${if cfg.powerlevel10k.instantPrompt then "yes" else "no"}"
      AUTOSUGGESTIONS="${if cfg.plugins.autosuggestions then "yes" else "no"}"
      SYNTAX_HIGHLIGHTING="${if cfg.plugins.syntaxHighlighting then "yes" else "no"}"
      HISTORY_SEARCH="${if cfg.plugins.historySubstringSearch then "yes" else "no"}"
      FZF_INTEGRATION="${if cfg.enableFzfIntegration then "yes" else "no"}"
      ZOXIDE_INTEGRATION="${if cfg.enableZoxideIntegration then "yes" else "no"}"
      HISTORY_SIZE="${toString cfg.historySize}"

      # Quick reference
      echo "ZSH Enhanced Features:"
      echo "  - Powerlevel10k prompt (run 'p10k configure' to customize)"
      echo "  - Auto-suggestions (type and see suggestions from history)"
      echo "  - Syntax highlighting (valid commands in green, invalid in red)"
      echo "  - History search (use arrow keys to search)"
      echo "  - FZF integration (Ctrl+R for history, Ctrl+T for files)"
      echo "  - Zoxide (smart cd - 'z <partial-name>' to jump)"
      echo ""
      echo "Useful commands:"
      echo "  p10k configure  - Customize Powerlevel10k prompt"
      echo "  z <dir>         - Smart directory jump"
      echo "  Ctrl+R          - Fuzzy search command history"
      echo "  Ctrl+T          - Fuzzy search files"
    '';
  };
}
