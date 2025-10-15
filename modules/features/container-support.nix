{ config, lib, pkgs, ... }:

# Container Support Module
# Provides Podman, Docker, and container management tools

let
  cfg = config.hypervisor.features.containerSupport;
in
{
  options.hypervisor.features.containerSupport = {
    enable = lib.mkEnableOption "container runtime and management tools";
    
    runtime = lib.mkOption {
      type = lib.types.enum [ "podman" "docker" "both" ];
      default = "podman";
      description = "Container runtime to use";
    };
    
    buildah = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Buildah for building OCI images";
    };
    
    compose = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable docker-compose/podman-compose";
    };
    
    registries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "docker.io" "quay.io" "ghcr.io" ];
      description = "Container registries to configure";
    };
    
    storageDriver = lib.mkOption {
      type = lib.types.enum [ "overlay2" "btrfs" "zfs" "vfs" ];
      default = "overlay2";
      description = "Container storage driver";
    };
    
    rootless = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable rootless container support";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Podman configuration
    virtualisation.podman = lib.mkIf (cfg.runtime == "podman" || cfg.runtime == "both") {
      enable = true;
      dockerCompat = true;  # Create docker symlink for compatibility
      defaultNetwork.settings.dns_enabled = true;
      
      # Enable rootless support
      extraPackages = lib.optionals cfg.rootless [
        pkgs.slirp4netns
        pkgs.fuse-overlayfs
      ];
    };
    
    # Docker configuration
    virtualisation.docker = lib.mkIf (cfg.runtime == "docker" || cfg.runtime == "both") {
      enable = true;
      storageDriver = cfg.storageDriver;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      
      # Rootless docker
      rootless = lib.mkIf cfg.rootless {
        enable = true;
        setSocketVariable = true;
      };
    };
    
    # Container management tools
    environment.systemPackages = [
      # Core tools
      pkgs.skopeo        # Container image operations
      pkgs.podman-tui    # TUI for podman
      pkgs.dive          # Explore Docker images
      pkgs.ctop          # Top-like interface for containers
      
      # Registry tools
      pkgs.crane         # Container registry client
      pkgs.regctl        # Docker registry client
    ] ++ lib.optionals cfg.buildah [
      pkgs.buildah       # OCI image builder
    ] ++ lib.optionals cfg.compose [
      pkgs.docker-compose
      pkgs.podman-compose
    ] ++ lib.optionals (cfg.runtime == "podman" || cfg.runtime == "both") [
      pkgs.podman
    ] ++ lib.optionals (cfg.runtime == "docker" || cfg.runtime == "both") [
      pkgs.docker-client
    ];
    
    # Container networking
    networking.firewall.trustedInterfaces = lib.optionals (cfg.runtime != "none") [
      "podman0"
      "docker0"
    ];
    
    # User groups for container access
    users.groups.podman = lib.mkIf (cfg.runtime == "podman" || cfg.runtime == "both") {};
    users.groups.docker = lib.mkIf (cfg.runtime == "docker" || cfg.runtime == "both") {};
    
    # Add management user to container groups
    users.users.${config.hypervisor.management.userName or "admin"}.extraGroups = 
      lib.optional (cfg.runtime == "podman" || cfg.runtime == "both") "podman" ++
      lib.optional (cfg.runtime == "docker" || cfg.runtime == "both") "docker";
    
    # Registry configuration
    environment.etc."containers/registries.conf".text = ''
      unqualified-search-registries = ${builtins.toJSON cfg.registries}
      
      ${lib.concatMapStrings (registry: ''
        [[registry]]
        location = "${registry}"
        
      '') cfg.registries}
    '';
    
    # Policy configuration
    environment.etc."containers/policy.json".text = builtins.toJSON {
      default = [{ type = "insecureAcceptAnything"; }];
      transports = {
        docker-daemon = {
          "" = [{ type = "insecureAcceptAnything"; }];
        };
      };
    };
    
    # Feature status file
    environment.etc."hypervisor/features/container-support.conf".text = ''
      # Container Support Configuration
      FEATURE_NAME="container-support"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
      
      RUNTIME="${cfg.runtime}"
      STORAGE_DRIVER="${cfg.storageDriver}"
      ROOTLESS_ENABLED="${if cfg.rootless then "yes" else "no"}"
      BUILDAH_ENABLED="${if cfg.buildah then "yes" else "no"}"
      COMPOSE_ENABLED="${if cfg.compose then "yes" else "no"}"
    '';
    
    # Create helper scripts
    environment.systemPackages = [
      (pkgs.writeScriptBin "container-info" ''
        #!${pkgs.bash}/bin/bash
        echo "Container Runtime Configuration"
        echo "================================"
        echo "Runtime: ${cfg.runtime}"
        echo "Storage Driver: ${cfg.storageDriver}"
        echo "Rootless: ${if cfg.rootless then "enabled" else "disabled"}"
        echo ""
        
        ${lib.optionalString (cfg.runtime == "podman" || cfg.runtime == "both") ''
          if command -v podman &> /dev/null; then
            echo "Podman version:"
            podman --version
            echo ""
            echo "Podman info:"
            podman info --format "{{.Store.GraphDriverName}}: {{.Store.GraphRoot}}"
          fi
        ''}
        
        ${lib.optionalString (cfg.runtime == "docker" || cfg.runtime == "both") ''
          if command -v docker &> /dev/null; then
            echo "Docker version:"
            docker --version
            echo ""
            echo "Docker info:"
            docker info --format "{{.Driver}}: {{.DockerRootDir}}"
          fi
        ''}
      '')
    ];
  };
}
