{ config, lib, pkgs, ... }:

# Portable Base Configuration for Hyper-NixOS
# Ensures system can run on various platforms and architectures

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.portable;
  
  # Platform detection
  platform = pkgs.stdenv.hostPlatform;
  isX86_64 = platform.isx86_64;
  isAarch64 = platform.isAarch64;
  isRiscV = platform.isRiscV;
  
  # Portable package selection
  portablePackages =  [
    # Core utilities (available on all platforms)
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gawk
    pkgs.diffutils
    pkgs.patch
    pkgs.which
    pkgs.file
    
    # Shell and scripting
    pkgs.bash
    pkgs.dash  # POSIX sh
    pkgs.busybox  # Fallback utilities
    
    # Compression (universal)
    pkgs.gzip
    pkgs.bzip2
    pkgs.xz
    pkgs.zstd
    
    # Network tools (portable)
    pkgs.curl
    pkgs.wget
    pkgs.netcat-openbsd
    pkgs.socat
    
    # Development tools
    pkgs.git
    pkgs.jq
    pkgs.yq
    
    # Monitoring (cross-platform)
    pkgs.htop
    pkgs.iotop
    pkgs.nethogs
    
    # Container tools (if supported)
  ] ++ optionals platform.isLinux [
    # Linux-specific tools
    pkgs.util-linux
    pkgs.procps
    pkgs.sysstat
    pkgs.iproute2
    pkgs.iptables
    
    # Virtualization (Linux only)
    pkgs.qemu
    pkgs.libvirt
    pkgs.virt-viewer
  ] ++ optionals (platform.isLinux && platform.isx86_64) [
    # x86_64 Linux specific
    pkgs.dmidecode
    pkgs.pciutils
    pkgs.usbutils
  ];
  
  # Portable paths configuration
  portablePaths = {
    config = if config.hypervisor.portable.useXDG
      then "$XDG_CONFIG_HOME/hypervisor"
      else "/etc/hypervisor";
      
    data = if config.hypervisor.portable.useXDG
      then "$XDG_DATA_HOME/hypervisor"
      else "/var/lib/hypervisor";
      
    runtime = if config.hypervisor.portable.useXDG
      then "$XDG_RUNTIME_DIR/hypervisor"
      else "/run/hypervisor";
      
    cache = if config.hypervisor.portable.useXDG
      then "$XDG_CACHE_HOME/hypervisor"
      else "/var/cache/hypervisor";
  };
  
  # Architecture-specific optimizations
  archOptimizations = {
    x86_64 = {
      compiler = "-march=x86-64 -mtune=generic";
      kernelConfig = {
        GENERIC_CPU = "y";
        X86_GENERIC = "y";
      };
    };
    aarch64 = {
      compiler = "-march=armv8-a";
      kernelConfig = {
        ARM64_4K_PAGES = "y";
        ARM64_MODULE_PLTS = "y";
      };
    };
    riscv64 = {
      compiler = "-march=rv64gc";
      kernelConfig = {
        RISCV_ISA_C = "y";
        RISCV_ISA_M = "y";
        RISCV_ISA_A = "y";
      };
    };
  };
in
{
  options.hypervisor.portable = {
    enable = mkEnableOption "Enable portable configuration";
    
    useXDG = mkOption {
      type = types.bool;
      default = false;
      description = "Use XDG Base Directory specification for paths";
    };
    
    supportedArchitectures = mkOption {
      type = types.listOf types.str;
      default = [ platform.system ];
      description = "List of architectures to support";
    };
    
    enableCrossCompilation = mkOption {
      type = types.bool;
      default = false;
      description = "Enable cross-compilation support";
    };
    
    compatibility = {
      posixScripts = mkOption {
        type = types.bool;
        default = true;
        description = "Ensure all scripts are POSIX-compliant";
      };
      
      staticBinaries = mkOption {
        type = types.bool;
        default = false;
        description = "Build static binaries for maximum portability";
      };
      
      minimalDependencies = mkOption {
        type = types.bool;
        default = false;
        description = "Use minimal external dependencies";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Portable packages
    environment.systemPackages = portablePackages;
    
    # Environment variables for portable paths
    environment.variables = {
      HYPERVISOR_CONFIG_DIR = portablePaths.config;
      HYPERVISOR_DATA_DIR = portablePaths.data;
      HYPERVISOR_RUNTIME_DIR = portablePaths.runtime;
      HYPERVISOR_CACHE_DIR = portablePaths.cache;
    };
    
    # POSIX shell as default for scripts
    environment.binsh = mkIf cfg.compatibility.posixScripts "${pkgs.dash}/bin/dash";
    
    # Portable script wrapper
    environment.etc."hypervisor/scripts/portable-wrapper.sh" = {
      text = ''
        #!/bin/sh
        # Portable wrapper for Hyper-NixOS scripts
        
        # Detect environment
        detect_shell() {
            if [ -n "$BASH_VERSION" ]; then
                echo "bash"
            elif [ -n "$ZSH_VERSION" ]; then
                echo "zsh"
            else
                echo "sh"
            fi
        }
        
        # Setup portable environment
        setup_portable_env() {
            # Use XDG paths if available
            : ''${XDG_CONFIG_HOME:=$HOME/.config}
            : ''${XDG_DATA_HOME:=$HOME/.local/share}
            : ''${XDG_RUNTIME_DIR:=/run/user/$(id -u)}
            : ''${XDG_CACHE_HOME:=$HOME/.cache}
            
            # Set Hypervisor paths
            export HYPERVISOR_CONFIG_DIR="''${HYPERVISOR_CONFIG_DIR:-$XDG_CONFIG_HOME/hypervisor}"
            export HYPERVISOR_DATA_DIR="''${HYPERVISOR_DATA_DIR:-$XDG_DATA_HOME/hypervisor}"
            export HYPERVISOR_RUNTIME_DIR="''${HYPERVISOR_RUNTIME_DIR:-$XDG_RUNTIME_DIR/hypervisor}"
            export HYPERVISOR_CACHE_DIR="''${HYPERVISOR_CACHE_DIR:-$XDG_CACHE_HOME/hypervisor}"
            
            # Create directories if needed
            mkdir -p "$HYPERVISOR_CONFIG_DIR" "$HYPERVISOR_DATA_DIR" "$HYPERVISOR_RUNTIME_DIR" "$HYPERVISOR_CACHE_DIR"
        }
        
        # Platform detection
        PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
        ARCH="$(uname -m)"
        
        case "$PLATFORM" in
            linux*) PLATFORM="linux" ;;
            darwin*) PLATFORM="macos" ;;
            freebsd*) PLATFORM="freebsd" ;;
            *) PLATFORM="unknown" ;;
        esac
        
        export HYPERVISOR_PLATFORM="$PLATFORM"
        export HYPERVISOR_ARCH="$ARCH"
        
        setup_portable_env
        
        # Execute the actual script
        exec "$@"
      '';
      mode = "0755";
    };
    
    # Cross-compilation support
    nixpkgs.crossSystem = mkIf cfg.enableCrossCompilation {
      config = elemAt cfg.supportedArchitectures 0;
    };
    
    # Multi-arch container support
    virtualisation.containers = mkIf platform.isLinux {
      enable = true;
      registries.search = [ "docker.io" "quay.io" ];
      
      # Enable foreign architecture support
      binfmt = mkIf cfg.enableCrossCompilation {
        enable = true;
        emulatedSystems = cfg.supportedArchitectures;
      };
    };
    
    # Portable systemd services
    systemd.services = mkIf platform.isLinux {
      hypervisor-portable-init = {
        description = "Initialize portable Hyper-NixOS environment";
        wantedBy = [ "multi-user.target" ];
        before = [ "hypervisor-menu.service" ];
        
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'source /etc/hypervisor/scripts/portable-wrapper.sh && echo Portable environment initialized'";
          RemainAfterExit = true;
        };
      };
    };
    
    # Architecture-specific kernel config
    boot.kernelPatches = mkIf platform.isLinux [
      {
        name = "portable-config";
        patch = null;
        extraConfig = let
          arch = if isX86_64 then "x86_64"
                else if isAarch64 then "aarch64"
                else if isRiscV then "riscv64"
                else "generic";
          archConfig = archOptimizations.${arch}.kernelConfig or {};
        in ''
          ${concatStringsSep "\n" (mapAttrsToList (k: v: "${k} ${v}") archConfig)}
          
          # Universal options
          IKCONFIG y
          IKCONFIG_PROC y
          MAGIC_SYSRQ y
          
          # Virtualization support (if available)
          ${optionalString (isX86_64 || isAarch64) ''
            VIRTUALIZATION y
            KVM y
            ${optionalString isX86_64 "KVM_INTEL m"}
            ${optionalString isX86_64 "KVM_AMD m"}
            VHOST_NET m
            VHOST_SCSI m
          ''}
        '';
      }
    ];
    
    # Compiler flags for portability
    nixpkgs.config.packageOverrides = pkgs: {
      stdenv = pkgs.stdenvAdapters.addAttrsToDerivation {
        NIX_CFLAGS_COMPILE = toString [
          "-O2"
          "-pipe"
          "-fstack-protector-strong"
          "-fPIC"
          (archOptimizations.${platform.parsed.cpu.name}.compiler or "-march=native")
        ];
      } pkgs.stdenv;
    };
    
    # Documentation for platform support
    environment.etc."hypervisor/PLATFORMS.md" = {
      text = ''
        # Supported Platforms
        
        Current Platform: ${platform.system}
        Architecture: ${platform.parsed.cpu.name}
        
        ## Fully Supported
        - x86_64-linux (Intel/AMD 64-bit Linux)
        - aarch64-linux (ARM 64-bit Linux)
        
        ## Experimental Support
        - riscv64-linux (RISC-V 64-bit Linux)
        - x86_64-darwin (Intel macOS)
        - aarch64-darwin (Apple Silicon macOS)
        
        ## Planned Support
        - armv7l-linux (ARM 32-bit Linux)
        - powerpc64le-linux (POWER9 Linux)
        - x86_64-freebsd (FreeBSD)
        
        ## Container Platforms
        - Docker (all architectures)
        - Podman (all architectures)
        - Kubernetes (via DaemonSet)
        
        ## Cloud Platforms
        - AWS EC2 (x86_64, arm64)
        - Google Cloud (x86_64)
        - Azure (x86_64)
        - OpenStack (x86_64, arm64)
        
        For platform-specific documentation, see:
        /etc/hypervisor/docs/platforms/
      '';
    };
  };
}