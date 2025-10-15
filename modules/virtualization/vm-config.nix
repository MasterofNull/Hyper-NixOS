# Tag-Based VM Configuration Module with Policy Inheritance
# Uses a unique tag-based system for VM configuration with policy templates
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.compute;
  
  # Tag definitions for flexible VM configuration
  tagDefinition = {
    options = {
      name = mkOption {
        type = types.str;
        description = "Tag name";
      };
      
      category = mkOption {
        type = types.enum [ "performance" "security" "network" "storage" "lifecycle" "compliance" ];
        description = "Tag category for organization";
      };
      
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Tag-specific configuration values";
      };
      
      priority = mkOption {
        type = types.int;
        default = 50;
        description = "Priority for conflict resolution (higher wins)";
      };
    };
  };
  
  # Policy templates that can be inherited
  policyTemplate = {
    options = {
      name = mkOption {
        type = types.str;
        description = "Policy template name";
      };
      
      description = mkOption {
        type = types.str;
        default = "";
        description = "Policy description";
      };
      
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Tags to apply when this policy is used";
      };
      
      constraints = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Constraints that must be satisfied";
      };
      
      defaults = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Default values provided by this policy";
      };
    };
  };
  
  # Compute unit definition (our unique VM abstraction)
  computeUnit = {
    options = {
      # Unique identification
      uuid = mkOption {
        type = types.str;
        default = "";
        description = "Auto-generated UUID for the compute unit";
      };
      
      # Human-friendly naming
      labels = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Key-value labels for identification";
        example = { app = "web"; env = "prod"; tier = "frontend"; };
      };
      
      # Tag-based configuration
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Tags to apply for configuration";
        example = [ "high-performance" "secure-boot" "gpu-enabled" ];
      };
      
      # Policy inheritance
      policies = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Policy templates to inherit";
        example = [ "web-server" "production" ];
      };
      
      # Resource requirements (abstract units)
      resources = {
        compute = mkOption {
          type = types.submodule {
            options = {
              units = mkOption {
                type = types.int;
                default = 100;
                description = "Abstract compute units (100 = 1 vCPU equivalent)";
              };
              
              burst = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Burst compute units available";
              };
              
              architecture = mkOption {
                type = types.enum [ "x86_64" "aarch64" "riscv64" "wasm" ];
                default = "x86_64";
                description = "Instruction set architecture";
              };
              
              features = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Required CPU features";
                example = [ "avx512" "aes" "vmx" ];
              };
            };
          };
          default = {};
          description = "Compute resource requirements";
        };
        
        memory = mkOption {
          type = types.submodule {
            options = {
              size = mkOption {
                type = types.str;
                default = "1Gi";
                description = "Memory size (Ki, Mi, Gi, Ti notation)";
              };
              
              hugepages = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Hugepage size if required";
              };
              
              bandwidth = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Memory bandwidth requirement in GB/s";
              };
            };
          };
          default = {};
          description = "Memory resource requirements";
        };
        
        accelerators = mkOption {
          type = types.listOf (types.submodule {
            options = {
              type = mkOption {
                type = types.enum [ "gpu" "fpga" "tpu" "dpu" ];
                description = "Accelerator type";
              };
              
              model = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Specific model requirement";
              };
              
              count = mkOption {
                type = types.int;
                default = 1;
                description = "Number of accelerators";
              };
              
              capabilities = mkOption {
                type = types.listOf types.str;
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
        type = mkOption {
          type = types.enum [ "persistent" "ephemeral" "batch" "interactive" ];
          default = "persistent";
          description = "Workload type affecting scheduling";
        };
        
        profile = mkOption {
          type = types.nullOr (types.enum [ "cpu-intensive" "memory-intensive" "io-intensive" "gpu-compute" "realtime" ]);
          default = null;
          description = "Workload profile for optimization";
        };
        
        sla = mkOption {
          type = types.submodule {
            options = {
              availability = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Required availability (0.99 = 99%)";
              };
              
              latency = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Maximum latency tolerance";
                example = "10ms";
              };
              
              iops = mkOption {
                type = types.nullOr types.int;
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
      storage = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Storage attachment name";
            };
            
            capability = mkOption {
              type = types.str;
              description = "Required storage capability";
              example = "fast-nvme";
            };
            
            size = mkOption {
              type = types.str;
              description = "Size requirement";
              example = "100Gi";
            };
            
            performance = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  iops = mkOption { type = types.nullOr types.int; default = null; };
                  throughput = mkOption { type = types.nullOr types.str; default = null; };
                };
              });
              default = null;
              description = "Performance requirements";
            };
            
            features = mkOption {
              type = types.listOf types.str;
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
      network = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Network attachment name";
            };
            
            capability = mkOption {
              type = types.str;
              description = "Network capability required";
              example = "public-internet";
            };
            
            bandwidth = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Bandwidth requirement";
              example = "10Gbps";
            };
            
            latency = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Latency requirement";
              example = "< 1ms";
            };
            
            features = mkOption {
              type = types.listOf types.str;
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
        affinity = mkOption {
          type = types.listOf (types.submodule {
            options = {
              type = mkOption {
                type = types.enum [ "required" "preferred" "anti" ];
                description = "Affinity type";
              };
              
              scope = mkOption {
                type = types.enum [ "host" "rack" "zone" "region" ];
                description = "Affinity scope";
              };
              
              labelSelector = mkOption {
                type = types.attrsOf types.str;
                description = "Label selector for affinity";
              };
              
              weight = mkOption {
                type = types.int;
                default = 100;
                description = "Weight for preferred affinity";
              };
            };
          });
          default = [];
          description = "Affinity rules";
        };
        
        spread = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              topology = mkOption {
                type = types.str;
                description = "Topology key for spreading";
                example = "kubernetes.io/hostname";
              };
              
              maximum = mkOption {
                type = types.int;
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
        preStart = mkOption {
          type = types.lines;
          default = "";
          description = "Commands to run before starting";
        };
        
        postStart = mkOption {
          type = types.lines;
          default = "";
          description = "Commands to run after starting";
        };
        
        preStop = mkOption {
          type = types.lines;
          default = "";
          description = "Commands to run before stopping";
        };
        
        postStop = mkOption {
          type = types.lines;
          default = "";
          description = "Commands to run after stopping";
        };
        
        healthCheck = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              type = mkOption {
                type = types.enum [ "http" "tcp" "script" ];
                description = "Health check type";
              };
              
              config = mkOption {
                type = types.attrsOf types.anything;
                description = "Health check configuration";
              };
              
              interval = mkOption {
                type = types.str;
                default = "30s";
                description = "Check interval";
              };
              
              timeout = mkOption {
                type = types.str;
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
        isolation = mkOption {
          type = types.submodule {
            options = {
              type = mkOption {
                type = types.enum [ "vm" "container" "firecracker" "kata" "wasm" ];
                default = "vm";
                description = "Isolation technology";
              };
              
              securityLevel = mkOption {
                type = types.enum [ "standard" "hardened" "confidential" ];
                default = "standard";
                description = "Security isolation level";
              };
              
              selinux = mkOption {
                type = types.bool;
                default = true;
                description = "Enable SELinux isolation";
              };
            };
          };
          default = {};
          description = "Isolation configuration";
        };
        
        persistence = mkOption {
          type = types.submodule {
            options = {
              stateful = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the compute unit is stateful";
              };
              
              checkpoints = mkOption {
                type = types.bool;
                default = false;
                description = "Enable checkpoint/restore";
              };
              
              migration = mkOption {
                type = types.enum [ "none" "cold" "live" ];
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
    tags = mkOption {
      type = types.attrsOf (types.submodule tagDefinition);
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
    policies = mkOption {
      type = types.attrsOf (types.submodule policyTemplate);
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
    units = mkOption {
      type = types.attrsOf (types.submodule computeUnit);
      default = {};
      description = "Compute unit definitions";
    };
    
    # Global defaults
    defaults = {
      resourceMultiplier = mkOption {
        type = types.float;
        default = 1.0;
        description = "Global resource multiplier for all units";
      };
      
      defaultTags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Tags applied to all units by default";
      };
      
      scheduling = {
        algorithm = mkOption {
          type = types.enum [ "binpack" "spread" "random" "custom" ];
          default = "binpack";
          description = "Default scheduling algorithm";
        };
        
        preemption = mkOption {
          type = types.bool;
          default = false;
          description = "Allow preemption of lower priority workloads";
        };
      };
    };
  };
  
  config = {
    # Generate libvirt XML or other backend configurations
    system.activationScripts.generateComputeUnits = mkIf (cfg.units != {}) ''
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
    environment.systemPackages = with pkgs; [
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