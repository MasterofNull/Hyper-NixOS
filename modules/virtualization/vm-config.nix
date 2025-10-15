# Tag-Based VM Configuration Module with Policy Inheritance
# Uses a unique tag-based system for VM configuration with policy templates
{ config, lib, pkgs, ... }:

# Removed: with lib; - Using explicit lib. prefix for clarity
let
  cfg = config.hypervisor.compute;
  
  # Tag definitions for flexible VM configuration
  tagDefinition = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Tag name";
      };
      
      category = lib.mkOption {
        type = lib.types.enum [ "performance" "security" "network" "storage" "lifecycle" "compliance" ];
        description = "Tag category for organization";
      };
      
      values = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Tag-specific configuration values";
      };
      
      priority = lib.mkOption {
        type = lib.types.int;
        default = 50;
        description = "Priority for conflict resolution (higher wins)";
      };
    };
  };
  
  # Policy templates that can be inherited
  policyTemplate = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Policy template name";
      };
      
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Policy description";
      };
      
      tags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tags to apply when this policy is used";
      };
      
      constraints = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Constraints that must be satisfied";
      };
      
      defaults = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Default values provided by this policy";
      };
    };
  };
  
  # Compute unit definition (our unique VM abstraction)
  computeUnit = {
    options = {
      # Unique identification
      uuid = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Auto-generated UUID for the compute unit";
      };
      
      # Human-friendly naming
      labels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Key-value labels for identification";
        example = { app = "web"; env = "prod"; tier = "frontend"; };
      };
      
      # Tag-based configuration
      tags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tags to apply for configuration";
        example = [ "high-performance" "secure-boot" "gpu-enabled" ];
      };
      
      # Policy inheritance
      policies = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Policy templates to inherit";
        example = [ "web-server" "production" ];
      };
      
      # Resource requirements (abstract units)
      resources = {
        compute = lib.mkOption {
          type = lib.types.submodule {
            options = {
              units = lib.mkOption {
                type = lib.types.int;
                default = 100;
                description = "Abstract compute units (100 = 1 vCPU equivalent)";
              };
              
              burst = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Burst compute units available";
              };
              
              architecture = lib.mkOption {
                type = lib.types.enum [ "x86_64" "aarch64" "riscv64" "wasm" ];
                default = "x86_64";
                description = "Instruction set architecture";
              };
              
              features = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Required CPU features";
                example = [ "avx512" "aes" "vmx" ];
              };
            };
          };
          default = {};
          description = "Compute resource requirements";
        };
        
        memory = lib.mkOption {
          type = lib.types.submodule {
            options = {
              size = lib.mkOption {
                type = lib.types.str;
                default = "1Gi";
                description = "Memory size (Ki, Mi, Gi, Ti notation)";
              };
              
              hugepages = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Hugepage size if required";
              };
              
              bandwidth = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Memory bandwidth requirement in GB/s";
              };
            };
          };
          default = {};
          description = "Memory resource requirements";
        };
        
        accelerators = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [ "gpu" "fpga" "tpu" "dpu" ];
                description = "Accelerator type";
              };
              
              model = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Specific model requirement";
              };
              
              count = lib.mkOption {
                type = lib.types.int;
                default = 1;
                description = "Number of accelerators";
              };
              
              capabilities = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Required capabilities";
              };
            };
          });
          default = [];
          description = "Hardware accelerator requirements";
        };
      };
      
      # Workload definition
      workload = {
        type = lib.mkOption {
          type = lib.types.enum [ "persistent" "ephemeral" "batch" "interactive" ];
          default = "persistent";
          description = "Workload type affecting scheduling";
        };
        
        profile = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "cpu-intensive" "memory-intensive" "io-intensive" "gpu-compute" "realtime" ]);
          default = null;
          description = "Workload profile for optimization";
        };
        
        sla = lib.mkOption {
          type = lib.types.submodule {
            options = {
              availability = lib.mkOption {
                type = lib.types.nullOr lib.types.float;
                default = null;
                description = "Required availability (0.99 = 99%)";
              };
              
              latency = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Maximum latency tolerance";
                example = "10ms";
              };
              
              iops = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Required IOPS";
              };
            };
          };
          default = {};
          description = "Service level agreement requirements";
        };
      };
      
      # Storage attachments (referenced by capability)
      storage = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Storage attachment name";
            };
            
            capability = lib.mkOption {
              type = lib.types.str;
              description = "Required storage capability";
              example = "fast-nvme";
            };
            
            size = lib.mkOption {
              type = lib.types.str;
              description = "Size requirement";
              example = "100Gi";
            };
            
            performance = lib.mkOption {
              type = lib.types.nullOr (lib.types.submodule {
                options = {
                  iops = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
                  throughput = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
                };
              });
              default = null;
              description = "Performance requirements";
            };
            
            features = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Required features";
              example = [ "encryption" "snapshots" "replication" ];
            };
          };
        });
        default = [];
        description = "Storage attachments";
      };
      
      # Network attachments (capability-based)
      network = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Network attachment name";
            };
            
            capability = lib.mkOption {
              type = lib.types.str;
              description = "Network capability required";
              example = "public-internet";
            };
            
            bandwidth = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Bandwidth requirement";
              example = "10Gbps";
            };
            
            latency = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Latency requirement";
              example = "< 1ms";
            };
            
            features = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Required network features";
              example = [ "ipv6" "jumbo-frames" "sr-iov" ];
            };
          };
        });
        default = [];
        description = "Network attachments";
      };
      
      # Placement constraints
      placement = {
        affinity = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [ "required" "preferred" "anti" ];
                description = "Affinity type";
              };
              
              scope = lib.mkOption {
                type = lib.types.enum [ "host" "rack" "zone" "region" ];
                description = "Affinity scope";
              };
              
              labelSelector = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                description = "Label selector for affinity";
              };
              
              weight = lib.mkOption {
                type = lib.types.int;
                default = 100;
                description = "Weight for preferred affinity";
              };
            };
          });
          default = [];
          description = "Affinity rules";
        };
        
        spread = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              topology = lib.mkOption {
                type = lib.types.str;
                description = "Topology key for spreading";
                example = "kubernetes.io/hostname";
              };
              
              maximum = lib.mkOption {
                type = lib.types.int;
                default = 1;
                description = "Maximum units per topology domain";
              };
            };
          });
          default = null;
          description = "Spread constraints";
        };
      };
      
      # Lifecycle hooks
      lifecycle = {
        preStart = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Commands to run before starting";
        };
        
        postStart = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Commands to run after starting";
        };
        
        preStop = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Commands to run before stopping";
        };
        
        postStop = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Commands to run after stopping";
        };
        
        healthCheck = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [ "http" "tcp" "script" ];
                description = "Health check type";
              };
              
              config = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                description = "Health check configuration";
              };
              
              interval = lib.mkOption {
                type = lib.types.str;
                default = "30s";
                description = "Check interval";
              };
              
              timeout = lib.mkOption {
                type = lib.types.str;
                default = "5s";
                description = "Check timeout";
              };
            };
          });
          default = null;
          description = "Health check configuration";
        };
      };
      
      # Advanced features
      features = {
        isolation = lib.mkOption {
          type = lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [ "vm" "container" "firecracker" "kata" "wasm" ];
                default = "vm";
                description = "Isolation technology";
              };
              
              securityLevel = lib.mkOption {
                type = lib.types.enum [ "standard" "hardened" "confidential" ];
                default = "standard";
                description = "Security isolation level";
              };
              
              selinux = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable SELinux isolation";
              };
            };
          };
          default = {};
          description = "Isolation configuration";
        };
        
        persistence = lib.mkOption {
          type = lib.types.submodule {
            options = {
              stateful = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether the compute unit is stateful";
              };
              
              checkpoints = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable checkpoint/restore";
              };
              
              migration = lib.mkOption {
                type = lib.types.enum [ "none" "cold" "live" ];
                default = "cold";
                description = "Migration capability";
              };
            };
          };
          default = {};
          description = "Persistence features";
        };
      };
    };
  };
  
  # Function to resolve tags and policies into final configuration
  resolveConfiguration = unit: let
    # Collect all applicable tags
    allTags = unit.tags ++ (flatten (map (p: cfg.policies.${p}.tags or []) unit.policies));
    
    # Get tag configurations sorted by priority
    tagConfigs = sort (a: b: a.priority > b.priority) 
      (map (t: cfg.tags.${t} or null) allTags);
    
    # Merge configurations respecting priority
    mergedConfig = fold (a: b: recursiveUpdate b a.values) {} tagConfigs;
  in mergedConfig;
  
in
{
  options.hypervisor.compute = {
    # Global tags available for use
    tags = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule tagDefinition);
      default = {};
      description = "Available tags for compute units";
      example = literalExample ''
        {
          high-performance = {
            category = "performance";
            priority = 100;
            values = {
              resources.compute.units = 800;
              features.isolation.type = "vm";
            };
          };
          secure-boot = {
            category = "security";
            priority = 90;
            values = {
              features.isolation.securityLevel = "hardened";
            };
          };
        }
      '';
    };
    
    # Policy templates
    policies = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule policyTemplate);
      default = {};
      description = "Policy templates for compute units";
      example = literalExample ''
        {
          web-server = {
            description = "Standard web server configuration";
            tags = [ "network-optimized" "public-facing" ];
            defaults = {
              resources.memory.size = "2Gi";
              network = [{
                name = "eth0";
                capability = "public-internet";
              }];
            };
          };
        }
      '';
    };
    
    # Compute unit definitions
    units = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule computeUnit);
      default = {};
      description = "Compute unit definitions";
    };
    
    # Global defaults
    defaults = {
      resourceMultiplier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Global resource multiplier for all units";
      };
      
      defaultTags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tags applied to all units by default";
      };
      
      scheduling = {
        algorithm = lib.mkOption {
          type = lib.types.enum [ "binpack" "spread" "random" "custom" ];
          default = "binpack";
          description = "Default scheduling algorithm";
        };
        
        preemption = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow preemption of lower priority workloads";
        };
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Generate libvirt XML or other backend configurations
    system.activationScripts.generateComputeUnits = lib.mkIf (cfg.units != {}) ''
      echo "Generating compute unit configurations..."
      mkdir -p /var/lib/hypervisor/compute
      
      ${concatStringsSep "\n" (mapAttrsToList (name: unit: ''
        # Generate configuration for ${name}
        ${let
          config = resolveConfiguration unit;
          memory = if unit.resources.memory.size != "" then unit.resources.memory.size else "1Gi";
          cpus = toString (unit.resources.compute.units / 100);
        in ''
          cat > /var/lib/hypervisor/compute/${name}.json << EOF
          {
            "name": "${name}",
            "uuid": "${unit.uuid}",
            "labels": ${builtins.toJSON unit.labels},
            "resources": {
              "cpus": ${cpus},
              "memory": "${memory}",
              "compute_units": ${toString unit.resources.compute.units}
            },
            "workload": ${builtins.toJSON unit.workload},
            "features": ${builtins.toJSON unit.features},
            "resolved_config": ${builtins.toJSON config}
          }
          EOF
        ''}
      '') cfg.units)}
    '';
    
    # Create management commands
    environment.systemPackages = [
      (writeScriptBin "hv-compute" ''
        #!${pkgs.bash}/bin/bash
        # Compute unit management tool
        
        case "$1" in
          list)
            echo "Compute Units:"
            ls -1 /var/lib/hypervisor/compute/*.json 2>/dev/null | while read f; do
              name=$(basename "$f" .json)
              labels=$(jq -r '.labels | to_entries | map("\(.key)=\(.value)") | join(",")' "$f")
              echo "  $name [$labels]"
            done
            ;;
          show)
            if [ -z "$2" ]; then
              echo "Usage: hv-compute show <unit-name>"
              exit 1
            fi
            jq . "/var/lib/hypervisor/compute/$2.json"
            ;;
          *)
            echo "Usage: hv-compute {list|show}"
            ;;
        esac
      '')
    ];
  };
}