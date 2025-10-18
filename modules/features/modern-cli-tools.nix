################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: Modern CLI Tools
# Purpose: Next-generation command-line tools for enhanced productivity
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.features.modernCliTools;
in {
  options.hypervisor.features.modernCliTools = {
    enable = mkEnableOption "modern CLI tools for development and administration";

    fileManagement = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install modern file management tools:
        - diskonaut: Visual disk space analyzer
        - erdtree: Better tree with disk usage
        - fd: Modern alternative to find
        - yazi: Feature-rich file manager
        - superfile: Powerful TUI file browser
      '';
    };

    viewers = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install modern file viewers:
        - bat: Better cat with syntax highlighting
        - fx: JSON viewer and processor
        - otree: JSON/YAML tree viewer
        - delta: Better git diffs
      '';
    };

    monitoring = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install system monitoring tools:
        - bottom (btm): Modern system monitor
        - gdu/dua: Interactive disk usage analyzers
        - gping: Ping with graphs
        - bandwhich: Network bandwidth monitor
      '';
    };

    productivity = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install productivity tools:
        - fzf: Fuzzy finder
        - zoxide: Smarter cd command
        - ripgrep: Fast grep replacement
        - hyperfine: Command-line benchmarking
      '';
    };

    git = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install modern git tools:
        - lazygit: TUI for git
        - delta: Beautiful diffs
        - gh: GitHub CLI
      '';
    };

    editors = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install modern terminal editors:
        - micro: Modern nano alternative
        - helix: Post-modern modal editor
      '';
    };

    networking = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install networking tools:
        - sshs: TUI for SSH connections
        - termscp: TUI for SCP/SFTP
        - curlie: Better curl with httpie syntax
      '';
    };

    presentation = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install presentation tools:
        - presenterm: Terminal slideshow tool
        - silicon: Beautiful code screenshots
      '';
    };

    dotfileManagement = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install dotfile management:
        - yadm: Yet Another Dotfiles Manager
        - chezmoi: Dotfiles manager
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # File Management Tools
    ] ++ optionals cfg.fileManagement [
      diskonaut           # Visual disk space analyzer
      erdtree             # Better tree with disk usage
      fd                  # Modern find alternative
      yazi                # Feature-rich file manager
      # superfile         # Not yet in nixpkgs, can add from flake
      lsd                 # Modern ls with colors and icons
      eza                 # Modern ls replacement (fork of exa)
      dust                # Disk usage visualization
      procs               # Modern ps replacement
    ] ++ optionals cfg.viewers [
      bat                 # Better cat with syntax highlighting
      fx                  # JSON viewer and processor
      jless               # JSON viewer
      # otree             # Not yet in nixpkgs
      hexyl               # Hex viewer
      grex                # Generate regex from examples
    ] ++ optionals cfg.monitoring [
      bottom              # Modern system monitor (btm)
      gdu                 # Interactive disk usage (Go)
      dua                 # Interactive disk usage (Rust)
      gping               # Ping with graphs
      bandwhich           # Network bandwidth monitor
      zenith              # System monitor with histogram
    ] ++ optionals cfg.productivity [
      fzf                 # Fuzzy finder
      zoxide              # Smarter cd
      ripgrep             # Fast grep
      hyperfine           # Benchmarking tool
      tealdeer            # TLDR pages (quick help)
      choose              # Cut alternative
      sd                  # Sed alternative
      tokei               # Code statistics
    ] ++ optionals cfg.git [
      lazygit             # TUI for git
      delta               # Better diffs
      gh                  # GitHub CLI
      git-absorb          # Auto git commit --fixup
      onefetch            # Git repo summary
    ] ++ optionals cfg.editors [
      micro               # Modern nano alternative
      helix               # Post-modern modal editor
    ] ++ optionals cfg.networking [
      # sshs              # Not yet in nixpkgs
      termscp             # TUI for SCP/SFTP
      curlie              # Better curl
      xh                  # HTTPie replacement in Rust
      bore-cli            # Tunnel TCP connections
    ] ++ optionals cfg.presentation [
      presenterm          # Terminal slideshows
      silicon             # Code screenshots
      slides              # Terminal presentation tool
    ] ++ optionals cfg.dotfileManagement [
      yadm                # Dotfiles manager
      chezmoi             # Dotfiles manager
    ] ++ [
      # Always include these essential modern tools
      jq                  # JSON processor
      yq-go               # YAML processor
      navi                # Interactive cheatsheets
      mcfly               # Shell history search
    ];

    # Git delta configuration
    programs.git = mkIf cfg.git {
      enable = true;
      config = {
        core = {
          pager = "delta";
        };
        interactive = {
          diffFilter = "delta --color-only";
        };
        delta = {
          navigate = true;
          light = false;
          side-by-side = true;
          line-numbers = true;
        };
        merge = {
          conflictstyle = "diff3";
        };
        diff = {
          colorMoved = "default";
        };
      };
    };

    # Bat configuration
    home-manager.users = mkIf cfg.viewers (
      let
        batConfig = {
          programs.bat = {
            enable = true;
            config = {
              theme = "TwoDark";
              pager = "less -FR";
              map-syntax = [
                "*.jenkinsfile:Groovy"
                "*.props:Java Properties"
              ];
            };
          };
        };
      in
        # Apply to all users who have home-manager enabled
        lib.genAttrs (builtins.attrNames config.home-manager.users) (_: batConfig)
    );

    # Environment variables for tools
    environment.variables = {
      # FZF configuration
      FZF_DEFAULT_COMMAND = mkIf cfg.productivity "fd --type f --hidden --follow --exclude .git";
      FZF_CTRL_T_COMMAND = mkIf cfg.productivity "$FZF_DEFAULT_COMMAND";
      FZF_ALT_C_COMMAND = mkIf cfg.productivity "fd --type d --hidden --follow --exclude .git";

      # Bat as man pager
      MANPAGER = mkIf cfg.viewers "sh -c 'col -bx | bat -l man -p'";
      MANROFFOPT = mkIf cfg.viewers "-c";

      # Use bat for less
      LESSOPEN = mkIf cfg.viewers "|${pkgs.bat}/bin/bat --color=always %s";
    };

    # Shell aliases for convenience
    environment.shellAliases = mkMerge [
      (mkIf cfg.viewers {
        cat = "bat";
        less = "bat --paging=always";
      })
      (mkIf cfg.fileManagement {
        ls = "eza --icons";
        ll = "eza -l --icons --git";
        la = "eza -la --icons --git";
        tree = "eza --tree --icons";
        find = "fd";
      })
      (mkIf cfg.git {
        lg = "lazygit";
        gd = "git diff";
        gs = "git status";
        gl = "git log --graph --oneline --decorate";
      })
      (mkIf cfg.monitoring {
        top = "btm";
        htop = "btm";
        du = "dua interactive";
      })
      (mkIf cfg.productivity {
        help = "tldr";
      })
    ];

    # Feature configuration file
    environment.etc."hypervisor/features/modern-cli-tools.conf".text = ''
      # Modern CLI Tools Configuration
      # Next-generation command-line tools for enhanced productivity

      FEATURE_NAME="modern-cli-tools"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"

      # Enabled components
      FILE_MANAGEMENT="${if cfg.fileManagement then "yes" else "no"}"
      VIEWERS="${if cfg.viewers then "yes" else "no"}"
      MONITORING="${if cfg.monitoring then "yes" else "no"}"
      PRODUCTIVITY="${if cfg.productivity then "yes" else "no"}"
      GIT_TOOLS="${if cfg.git then "yes" else "no"}"
      EDITORS="${if cfg.editors then "yes" else "no"}"
      NETWORKING="${if cfg.networking then "yes" else "no"}"
      PRESENTATION="${if cfg.presentation then "yes" else "no"}"
      DOTFILE_MGMT="${if cfg.dotfileManagement then "yes" else "no"}"

      # Quick reference
      echo "Modern CLI Tools Available:"
      ${optionalString cfg.fileManagement "echo '  File Management: diskonaut, erdtree, fd, yazi, eza, dust'"}
      ${optionalString cfg.viewers "echo '  Viewers: bat, fx, jless, hexyl'"}
      ${optionalString cfg.monitoring "echo '  Monitoring: bottom (btm), gdu, dua, gping, bandwhich'"}
      ${optionalString cfg.productivity "echo '  Productivity: fzf, zoxide, ripgrep, hyperfine, tldr'"}
      ${optionalString cfg.git "echo '  Git: lazygit, delta, gh, onefetch'"}
      ${optionalString cfg.editors "echo '  Editors: micro, helix'"}
      ${optionalString cfg.networking "echo '  Networking: termscp, curlie, xh'"}
    '';
  };
}
