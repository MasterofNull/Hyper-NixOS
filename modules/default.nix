# Hyper-NixOS Default Module
# Import this to enable all Hyper-NixOS features

{ config, lib, pkgs, ... }:

{
  imports = [
    ./virtualization/vm-config.nix
    ./storage-management/storage-tiers.nix
    ./clustering/mesh-cluster.nix
    ./core/capability-security.nix
    ./automation/backup-dedup.nix
    ./virtualization/vm-composition.nix
    ./monitoring/ai-anomaly.nix
    ./api/interop-service.nix
  ];

  # Default configuration
  config = lib.mkIf config.hypervisor.enable {
    # Ensure required packages are installed
    environment.systemPackages = with pkgs; [
      # Core utilities
      qemu
      libvirt
      virt-manager
      
      # Storage tools
      zfs
      btrfs-progs
      lvm2
      ceph
      glusterfs
      
      # Clustering tools
      corosync
      pacemaker
      
      # Monitoring
      prometheus
      grafana
      
      # Development
      git
      go
      python3
      
      # Our custom scripts
      (pkgs.writeScriptBin "hv-init" ''
        #!${pkgs.bash}/bin/bash
        echo "Initializing Hyper-NixOS..."
        
        # Create directories
        mkdir -p /var/lib/hypervisor/{compute,storage,mesh,backup,ai}
        mkdir -p /var/log/hypervisor
        
        # Initialize storage
        hv-storage-fabric init 2>/dev/null || true
        
        # Initialize AI models
        hv-ai setup 2>/dev/null || true
        
        echo "Initialization complete!"
      '')
    ];
    
    # Enable required services
    virtualisation.libvirtd.enable = true;
    
    # Kernel parameters for performance
    boot.kernelParams = [
      "transparent_hugepage=never"
      "intel_iommu=on"
      "iommu=pt"
    ];
    
    # System groups
    users.groups = {
      hypervisor = {};
      hypervisor-admin = {};
    };
    
    # Base firewall rules
    networking.firewall = {
      allowedTCPPorts = [
        8081  # GraphQL API
        4222  # NATS
        7946  # Mesh clustering
        7947  # Mesh clustering
      ];
      allowedUDPPorts = [
        7946  # Mesh clustering
        7947  # Mesh clustering
      ];
    };
  };
  
  # Module options
  options.hypervisor = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Hyper-NixOS virtualization platform";
    };
    
    debug = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable debug mode";
      };
      
      verbosity = lib.mkOption {
        type = lib.types.enum [ "error" "warn" "info" "debug" "trace" ];
        default = "info";
        description = "Log verbosity level";
      };
      
      components = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Components to debug";
        example = [ "mesh" "storage" "ai" ];
      };
    };
  };
}