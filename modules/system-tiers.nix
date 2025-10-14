# Hyper-NixOS System Configuration Tiers
# Defines different system configuration levels from minimal to full-featured

{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
in

{
  options.hypervisor.systemTier = mkOption {
    type = types.enum [ "minimal" "standard" "enhanced" "professional" "enterprise" ];
    default = "minimal";
    description = ''
      System configuration tier that determines which features are enabled.
      
      Tiers:
      - minimal: Core virtualization only (< 4GB RAM, 2 CPUs)
      - standard: Add monitoring and basic security (4-8GB RAM, 4 CPUs)
      - enhanced: Add advanced features and GUI (8-16GB RAM, 4-8 CPUs)
      - professional: Add AI/ML security, automation (16-32GB RAM, 8+ CPUs)
      - enterprise: Full feature set with clustering (32GB+ RAM, 16+ CPUs)
    '';
  };

  config = {
    # Define feature sets for each tier
    hypervisor.tiers = {
      minimal = {
        description = "Core Virtualization Platform";
        features = [
          "core"              # Basic system
          "libvirt"           # VM management
          "basic-networking"  # NAT networking
          "console-tools"     # CLI management
        ];
        services = [
          "libvirtd"
          "virtlogd"
        ];
        packages = [
          "qemu"
          "libvirt"
          "virt-manager"
          "virsh"
        ];
        requirements = {
          minRAM = 2048;      # 2GB minimum
          recRAM = 4096;      # 4GB recommended
          minCPUs = 2;
          recCPUs = 4;
          minDisk = 20;       # 20GB minimum
          recDisk = 50;       # 50GB recommended
        };
      };

      standard = {
        description = "Virtualization + Monitoring + Basic Security";
        inherits = [ "minimal" ];
        features = [
          "monitoring"        # Prometheus + Grafana
          "security-base"     # Basic security
          "firewall"          # NFTables firewall
          "ssh-hardening"     # Secure SSH
          "audit-logging"     # System audit logs
          "backup-basic"      # Basic backup tools
        ];
        services = [
          "prometheus"
          "grafana"
          "node-exporter"
          "auditd"
        ];
        packages = [
          "prometheus"
          "grafana"
          "htop"
          "iotop"
          "nftables"
        ];
        requirements = {
          minRAM = 4096;      # 4GB minimum
          recRAM = 8192;      # 8GB recommended
          minCPUs = 2;
          recCPUs = 4;
          minDisk = 50;       # 50GB minimum
          recDisk = 100;      # 100GB recommended
        };
      };

      enhanced = {
        description = "Advanced Features + Desktop Environment";
        inherits = [ "standard" ];
        features = [
          "desktop-gui"       # KDE/GNOME desktop
          "advanced-networking" # Bridges, VLANs
          "storage-management" # LVM, ZFS options
          "vm-templates"      # Pre-built VM templates
          "web-dashboard"     # Web management UI
          "container-support" # Podman/Docker
          "snapshot-automation" # Automated snapshots
        ];
        services = [
          "displayManager"
          "hypervisor-api"
          "hypervisor-web"
          "podman"
        ];
        packages = [
          "kde-plasma"        # or gnome
          "firefox"
          "virt-viewer"
          "cockpit"
          "podman"
          "docker-compose"
        ];
        requirements = {
          minRAM = 8192;      # 8GB minimum
          recRAM = 16384;     # 16GB recommended
          minCPUs = 4;
          recCPUs = 8;
          minDisk = 100;      # 100GB minimum
          recDisk = 250;      # 250GB recommended
          gpu = "recommended"; # For desktop acceleration
        };
      };

      professional = {
        description = "AI-Powered Security + Full Automation";
        inherits = [ "enhanced" ];
        features = [
          "threat-detection"  # AI/ML threat detection
          "behavioral-analysis" # Zero-day detection
          "threat-response"   # Automated responses
          "advanced-automation" # Full automation suite
          "performance-tuning" # Auto optimization
          "multi-host"        # Multi-host management
          "api-gateway"       # Full API access
          "secret-management" # Vault integration
        ];
        services = [
          "hypervisor-ml-detector"
          "hypervisor-threat-analyzer"
          "hypervisor-automation"
          "vault"
          "consul"
        ];
        packages = [
          "python3-ml"
          "tensorflow"
          "vault"
          "consul"
          "ansible"
          "terraform"
        ];
        requirements = {
          minRAM = 16384;     # 16GB minimum
          recRAM = 32768;     # 32GB recommended
          minCPUs = 8;
          recCPUs = 16;
          minDisk = 250;      # 250GB minimum
          recDisk = 500;      # 500GB recommended
          gpu = "required";   # For ML acceleration
        };
      };

      enterprise = {
        description = "Full Enterprise Platform with Clustering";
        inherits = [ "professional" ];
        features = [
          "clustering"        # Multi-node clusters
          "high-availability" # HA configurations
          "distributed-storage" # Ceph/GlusterFS
          "enterprise-backup" # Advanced backup
          "compliance"        # Compliance tools
          "reporting"         # Enterprise reporting
          "multi-tenant"      # Tenant isolation
          "federation"        # Identity federation
        ];
        services = [
          "corosync"
          "pacemaker"
          "ceph"
          "elasticsearch"
          "kibana"
          "keycloak"
        ];
        packages = [
          "corosync"
          "pacemaker"
          "ceph"
          "glusterfs"
          "elasticsearch"
          "kibana"
          "keycloak"
        ];
        requirements = {
          minRAM = 32768;     # 32GB minimum
          recRAM = 65536;     # 64GB recommended
          minCPUs = 16;
          recCPUs = 32;
          minDisk = 500;      # 500GB minimum
          recDisk = 1000;     # 1TB recommended
          gpu = "required";   # For ML and visualization
          nodes = "3+";       # Minimum 3 nodes for HA
        };
      };
    };
  };
}