{ config, lib, pkgs, ... }:

# Development Tools Module
# Provides compilers, debuggers, and development utilities

let
  cfg = config.hypervisor.features.devTools;
in
{
  options.hypervisor.features.devTools = {
    enable = lib.mkEnableOption "development tools and compilers";
    
    compilers = {
      c = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable C/C++ compilers (gcc, clang)";
      };
      
      rust = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Rust toolchain";
      };
      
      go = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Go compiler";
      };
      
      python = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Python development tools";
      };
      
      nodejs = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Node.js and npm";
      };
    };
    
    debuggers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install debugging tools (gdb, lldb, valgrind)";
    };
    
    buildTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install build tools (make, cmake, ninja, meson)";
    };
    
    versionControl = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install version control tools (git, mercurial, subversion)";
    };
    
    editors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install development editors (vim, neovim, emacs)";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Base development packages
    environment.systemPackages = with pkgs; [
      # Version control (if enabled)
    ] ++ lib.optionals cfg.versionControl [
      pkgs.git
      pkgs.git-lfs
      pkgs.mercurial
      pkgs.subversion
      pkgs.tig          # Text-mode interface for git
      pkgs.gitui        # Terminal UI for git
    ] ++ lib.optionals cfg.compilers.c [
      # C/C++ Development
      pkgs.gcc
      pkgs.clang
      pkgs.llvm
      pkgs.binutils
      pkgs.glibc
      pkgs.gnumake
    ] ++ lib.optionals cfg.compilers.rust [
      # Rust Development
      pkgs.rustc
      pkgs.cargo
      pkgs.rustfmt
      pkgs.rust-analyzer
      pkgs.clippy
    ] ++ lib.optionals cfg.compilers.go [
      # Go Development
      pkgs.go
      pkgs.gopls
      pkgs.golangci-lint
      pkgs.delve        # Go debugger
    ] ++ lib.optionals cfg.compilers.python [
      # Python Development
      pkgs.python3Full
      pkgs.python3Packages.pip
      pkgs.python3Packages.virtualenv
      pkgs.python3Packages.pytest
      pkgs.python3Packages.black
      pkgs.python3Packages.pylint
      pkgs.python3Packages.mypy
    ] ++ lib.optionals cfg.compilers.nodejs [
      # Node.js Development
      pkgs.nodejs
      pkgs.nodePackages.npm
      pkgs.nodePackages.yarn
      pkgs.nodePackages.pnpm
      pkgs.nodePackages.typescript
      pkgs.nodePackages.eslint
    ] ++ lib.optionals cfg.debuggers [
      # Debuggers and profilers
      pkgs.gdb
      pkgs.lldb
      pkgs.valgrind
      pkgs.strace
      pkgs.ltrace
      pkgs.perf-tools
      pkgs.hotspot      # Perf GUI
    ] ++ lib.optionals cfg.buildTools [
      # Build systems
      pkgs.gnumake
      pkgs.cmake
      pkgs.ninja
      pkgs.meson
      pkgs.autoconf
      pkgs.automake
      pkgs.libtool
      pkgs.pkg-config
    ] ++ lib.optionals cfg.editors [
      # Development editors
      pkgs.vim
      pkgs.neovim
      pkgs.emacs
      pkgs.nano
    ] ++ [
      # Always include these essential tools
      pkgs.file
      pkgs.which
      pkgs.tree
      pkgs.ripgrep
      pkgs.fd
      pkgs.fzf
      pkgs.jq
      pkgs.yq
      pkgs.curl
      pkgs.wget
      pkgs.nmap
      pkgs.tcpdump
      pkgs.wireshark-cli
    ];
    
    # Development libraries
    environment.variables = {
      EDITOR = lib.mkDefault "vim";
      VISUAL = lib.mkDefault "vim";
    };
    
    # Enable documentation
    documentation.dev.enable = true;
    documentation.man.enable = true;
    documentation.info.enable = true;
    
    # System message
    environment.etc."hypervisor/features/dev-tools.conf".text = ''
      # Development Tools Configuration
      # This feature provides compilers, debuggers, and build tools
      
      FEATURE_NAME="dev-tools"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
      
      # Enabled components
      C_CPP_ENABLED="${if cfg.compilers.c then "yes" else "no"}"
      RUST_ENABLED="${if cfg.compilers.rust then "yes" else "no"}"
      GO_ENABLED="${if cfg.compilers.go then "yes" else "no"}"
      PYTHON_ENABLED="${if cfg.compilers.python then "yes" else "no"}"
      NODEJS_ENABLED="${if cfg.compilers.nodejs then "yes" else "no"}"
      DEBUGGERS_ENABLED="${if cfg.debuggers then "yes" else "no"}"
      BUILD_TOOLS_ENABLED="${if cfg.buildTools then "yes" else "no"}"
    '';
  };
}
