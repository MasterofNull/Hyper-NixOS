# Hyper-NixOS Tier Templates
# Pre-configured feature sets for different use cases

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.tierTemplates;
  
  # Define tier templates with their feature sets
  tierDefinitions = {
    minimal = {
      description = "Core virtualization functionality only";
      features = [
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "storage-basic"
      ];
      requirements = {
        minRam = 2048; # 2GB
        minCpu = 2;
        minDisk = 20; # GB
      };
    };
    
    standard = {
      description = "Production-ready with monitoring and security";
      features = [
        # Inherit minimal
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "storage-basic"
        # Additional features
        "monitoring"
        "security-base"
        "firewall"
        "ssh-hardening"
        "audit-logging"
        "backup-basic"
      ];
      requirements = {
        minRam = 4096; # 4GB
        minCpu = 4;
        minDisk = 50;
      };
    };
    
    enhanced = {
      description = "Advanced features with GUI and containers";
      features = [
        # Inherit standard
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "networking-advanced"
        "storage-basic"
        "storage-lvm"
        "monitoring"
        "logging"
        "alerting"
        "security-base"
        "firewall"
        "ssh-hardening"
        "audit-logging"
        "backup-basic"
        # Additional features
        "web-dashboard"
        "container-support"
        "vpn-server"
        "rest-api"
      ];
      requirements = {
        minRam = 8192; # 8GB
        minCpu = 4;
        minDisk = 100;
      };
    };
    
    professional = {
      description = "Enterprise features with AI/ML security";
      features = [
        # Inherit enhanced
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "networking-advanced"
        "storage-basic"
        "storage-lvm"
        "monitoring"
        "logging"
        "alerting"
        "tracing"
        "security-base"
        "firewall"
        "ssh-hardening"
        "audit-logging"
        "backup-basic"
        "backup-advanced"
        "web-dashboard"
        "container-support"
        "vpn-server"
        "rest-api"
        # Additional features
        "ai-security"
        "automation"
        "terraform"
        "compliance"
        "vulnerability-scanning"
        "ids-ips"
        "multi-host"
        "graphql-api"
        "websocket-api"
      ];
      requirements = {
        minRam = 16384; # 16GB
        minCpu = 8;
        minDisk = 200;
      };
    };
    
    enterprise = {
      description = "Full platform with HA clustering and multi-tenancy";
      features = [
        # Inherit professional
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "networking-advanced"
        "storage-basic"
        "storage-lvm"
        "storage-zfs"
        "storage-distributed"
        "storage-encryption"
        "monitoring"
        "logging"
        "alerting"
        "tracing"
        "metrics-export"
        "security-base"
        "firewall"
        "ssh-hardening"
        "audit-logging"
        "backup-basic"
        "backup-advanced"
        "backup-enterprise"
        "web-dashboard"
        "container-support"
        "kubernetes-tools"
        "vpn-server"
        "rest-api"
        "ai-security"
        "automation"
        "terraform"
        "ci-cd"
        "orchestration"
        "compliance"
        "vulnerability-scanning"
        "ids-ips"
        "multi-host"
        "graphql-api"
        "websocket-api"
        # Additional enterprise features
        "clustering"
        "high-availability"
        "multi-tenant"
        "federation"
        "disaster-recovery"
        "network-isolation"
        "live-migration"
      ];
      requirements = {
        minRam = 32768; # 32GB
        minCpu = 16;
        minDisk = 500;
      };
    };
    
    # Custom templates for specific use cases
    developer = {
      description = "Developer workstation with tools and desktop";
      features = [
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "storage-basic"
        "storage-lvm"
        "desktop-kde"
        "virt-manager"
        "dev-tools"
        "container-support"
        "kubernetes-tools"
        "database-tools"
        "monitoring"
        "web-dashboard"
        "remote-desktop"
      ];
      requirements = {
        minRam = 16384;
        minCpu = 8;
        minDisk = 200;
      };
    };
    
    security-focused = {
      description = "Maximum security configuration";
      features = [
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "networking-advanced"
        "storage-basic"
        "storage-encryption"
        "security-base"
        "firewall"
        "ssh-hardening"
        "audit-logging"
        "ai-security"
        "compliance"
        "vulnerability-scanning"
        "ids-ips"
        "network-isolation"
        "monitoring"
        "logging"
        "alerting"
      ];
      requirements = {
        minRam = 12288;
        minCpu = 8;
        minDisk = 150;
      };
    };
    
    lab = {
      description = "Home lab or testing environment";
      features = [
        "core"
        "cli-tools"
        "libvirt"
        "qemu-kvm"
        "networking-basic"
        "storage-basic"
        "desktop-xfce"
        "virt-manager"
        "container-support"
        "monitoring"
        "web-dashboard"
        "vm-templates"
      ];
      requirements = {
        minRam = 8192;
        minCpu = 4;
        minDisk = 100;
      };
    };
  };
  
  # Helper function to check if requirements are met
  checkRequirements = tier: 
    let
      memInfo = builtins.readFile "/proc/meminfo";
      memKb = lib.toInt (lib.head (lib.match ".*MemTotal:[ ]*([0-9]+).*" memInfo));
      memMb = memKb / 1024;
      cpuCount = lib.toInt (builtins.readFile "/proc/cpuinfo" 
        |> lib.splitString "\n"
        |> lib.filter (line: lib.hasPrefix "processor" line)
        |> lib.length);
    in {
      ram = memMb >= tierDefinitions.${tier}.requirements.minRam;
      cpu = cpuCount >= tierDefinitions.${tier}.requirements.minCpu;
      allMet = memMb >= tierDefinitions.${tier}.requirements.minRam && 
               cpuCount >= tierDefinitions.${tier}.requirements.minCpu;
    };

in {
  options.hypervisor.tierTemplates = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable tier template system";
    };
    
    availableTemplates = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          description = mkOption {
            type = types.str;
            description = "Template description";
          };
          features = mkOption {
            type = types.listOf types.str;
            description = "List of features in this template";
          };
          requirements = mkOption {
            type = types.submodule {
              options = {
                minRam = mkOption {
                  type = types.int;
                  description = "Minimum RAM in MB";
                };
                minCpu = mkOption {
                  type = types.int;
                  description = "Minimum CPU cores";
                };
                minDisk = mkOption {
                  type = types.int;
                  description = "Minimum disk space in GB";
                };
              };
            };
            description = "Hardware requirements";
          };
        };
      });
      default = tierDefinitions;
      description = "Available tier templates";
    };
    
    customTemplates = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          description = mkOption {
            type = types.str;
            description = "Template description";
          };
          baseTemplate = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Base template to inherit from";
          };
          addFeatures = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Features to add to base template";
          };
          removeFeatures = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Features to remove from base template";
          };
          features = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Complete feature list (if not using base template)";
          };
        };
      });
      default = {};
      description = "User-defined custom templates";
    };
  };
  
  config = mkIf cfg.enable {
    # Merge custom templates with defaults
    hypervisor.tierTemplates.availableTemplates = mkMerge [
      tierDefinitions
      (mapAttrs (name: template: 
        if template.baseTemplate != null then
          let
            base = tierDefinitions.${template.baseTemplate} or (throw "Unknown base template: ${template.baseTemplate}");
            baseFeatures = base.features;
            withAdded = baseFeatures ++ template.addFeatures;
            final = filter (f: ! elem f template.removeFeatures) withAdded;
          in {
            description = template.description;
            features = unique final;
            requirements = base.requirements; # Inherit base requirements
          }
        else {
          description = template.description;
          features = template.features;
          requirements = {
            minRam = 4096; # Default requirements for custom templates
            minCpu = 4;
            minDisk = 50;
          };
        }
      ) cfg.customTemplates)
    ];
    
    # Provide convenience functions
    environment.etc."hypervisor/tier-templates.json" = {
      text = builtins.toJSON cfg.availableTemplates;
      mode = "0644";
    };
    
    # Add template management script
    environment.systemPackages =  [
      (writeScriptBin "hv-template" ''
        #!${bash}/bin/bash
        case "$1" in
          list)
            echo "Available templates:"
            ${jq}/bin/jq -r 'to_entries | .[] | "  \(.key): \(.value.description)"' \
              /etc/hypervisor/tier-templates.json
            ;;
          show)
            if [ -z "$2" ]; then
              echo "Usage: hv-template show <template-name>"
              exit 1
            fi
            ${jq}/bin/jq ".\"$2\" // empty" /etc/hypervisor/tier-templates.json
            ;;
          check)
            template="$${2:-standard}"
            echo "Checking requirements for $template template..."
            ${jq}/bin/jq -r ".\"$template\".requirements // empty" \
              /etc/hypervisor/tier-templates.json
            ;;
          *)
            echo "Usage: hv-template {list|show|check} [template]"
            exit 1
            ;;
        esac
      '')
    ];
  };
}