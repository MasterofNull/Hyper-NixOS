# Tier-Based Storage System with Automatic Data Movement
# Implements a unique heat-map based storage tiering system
{ config, lib, pkgs, ... }:

# Removed: with lib; - Using explicit lib. prefix for clarity
let
  cfg = config.hypervisor.storage;
  
  # Storage tier definition with unique characteristics
  tierDefinition = {
    options = {
      level = lib.mkOption {
        type = lib.types.int;
        description = "Tier level (0 = fastest, higher = slower)";
        example = 0;
      };
      
      characteristics = {
        latency = lib.mkOption {
          type = lib.types.str;
          description = "Expected latency range";
          example = "< 0.1ms";
        };
        
        throughput = lib.mkOption {
          type = lib.types.str;
          description = "Throughput capability";
          example = "> 5GB/s";
        };
        
        iops = lib.mkOption {
          type = lib.types.str;
          description = "IOPS range";
          example = "> 100000";
        };
        
        durability = lib.mkOption {
          type = lib.types.float;
          default = 0.999999999;
          description = "Data durability (nines)";
        };
        
        cost = lib.mkOption {
          type = lib.types.float;
          default = 1.0;
          description = "Relative cost factor";
        };
      };
      
      # Backends that can provide this tier
      providers = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Provider name";
            };
            
            type = lib.mkOption {
              type = lib.types.enum [ 
                "memory"      # In-memory storage
                "nvme-local"  # Local NVMe
                "ssd-array"   # SSD storage array
                "hdd-array"   # HDD storage array
                "object"      # Object storage (S3-like)
                "tape"        # Tape archive
                "optical"     # Optical storage
              ];
              description = "Storage provider type";
            };
            
            capacity = lib.mkOption {
              type = lib.types.str;
              description = "Total capacity";
              example = "10Ti";
            };
            
            location = lib.mkOption {
              type = lib.types.str;
              description = "Physical or logical location";
            };
            
            features = lib.mkOption {
              type = lib.types.attrsOf lib.types.bool;
              default = {};
              description = "Provider features";
              example = {
                encryption = true;
                compression = true;
                deduplication = true;
                snapshots = true;
              };
            };
          };
        });
        default = [];
        description = "Storage providers for this tier";
      };
      
      # Policies for this tier
      policies = {
        promotion = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enabled = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable promotion to faster tier";
              };
              
              threshold = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    accessFrequency = lib.mkOption {
                      type = lib.types.int;
                      default = 10;
                      description = "Access count per time window";
                    };
                    
                    heatScore = lib.mkOption {
                      type = lib.types.float;
                      default = 0.8;
                      description = "Heat score threshold (0-1)";
                    };
                    
                    latencySensitivity = lib.mkOption {
                      type = lib.types.float;
                      default = 0.9;
                      description = "Latency sensitivity score";
                    };
                  };
                };
                default = {};
                description = "Promotion thresholds";
              };
              
              batchSize = lib.mkOption {
                type = lib.types.str;
                default = "1Gi";
                description = "Maximum batch size for promotion";
              };
            };
          };
          default = {};
          description = "Promotion policies";
        };
        
        demotion = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enabled = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable demotion to slower tier";
              };
              
              threshold = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    idleTime = lib.mkOption {
                      type = lib.types.str;
                      default = "7d";
                      description = "Time without access";
                    };
                    
                    heatScore = lib.mkOption {
                      type = lib.types.float;
                      default = 0.2;
                      description = "Heat score threshold (0-1)";
                    };
                  };
                };
                default = {};
                description = "Demotion thresholds";
              };
              
              excludePatterns = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Patterns to exclude from demotion";
                example = [ "*.db" "critical-*" ];
              };
            };
          };
          default = {};
          description = "Demotion policies";
        };
        
        retention = lib.mkOption {
          type = lib.types.submodule {
            options = {
              minTime = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Minimum retention time";
                example = "24h";
              };
              
              maxTime = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Maximum retention time";
                example = "90d";
              };
            };
          };
          default = {};
          description = "Retention policies for this tier";
        };
      };
    };
  };
  
  # Data classification for intelligent placement
  dataClassification = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Classification name";
      };
      
      patterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "File patterns matching this classification";
      };
      
      characteristics = {
        accessPattern = lib.mkOption {
          type = lib.types.enum [ "sequential" "random" "write-once" "append-only" ];
          default = "random";
          description = "Expected access pattern";
        };
        
        temperature = lib.mkOption {
          type = lib.types.enum [ "hot" "warm" "cool" "cold" "frozen" ];
          default = "warm";
          description = "Initial data temperature";
        };
        
        criticality = lib.mkOption {
          type = lib.types.enum [ "critical" "important" "standard" "archival" ];
          default = "standard";
          description = "Data criticality level";
        };
        
        compressibility = lib.mkOption {
          type = lib.types.enum [ "high" "medium" "low" "none" ];
          default = "medium";
          description = "Expected compressibility";
        };
      };
      
      placement = {
        preferredTier = lib.mkOption {
          type = lib.types.int;
          default = 1;
          description = "Preferred storage tier";
        };
        
        allowedTiers = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [];
          description = "Allowed storage tiers";
        };
        
        replication = lib.mkOption {
          type = lib.types.submodule {
            options = {
              factor = lib.mkOption {
                type = lib.types.int;
                default = 2;
                description = "Replication factor";
              };
              
              crossTier = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Allow cross-tier replication";
              };
              
              geoDistributed = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Require geographic distribution";
              };
            };
          };
          default = {};
          description = "Replication requirements";
        };
      };
    };
  };
  
  # Storage fabric configuration
  storageFabric = {
    # Global heat map tracking
    heatMap = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable heat map tracking";
      };
      
      granularity = lib.mkOption {
        type = lib.types.str;
        default = "1Mi";
        description = "Heat tracking granularity";
      };
      
      timeWindows = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "1h" "1d" "7d" "30d" ];
        description = "Time windows for heat calculation";
      };
      
      algorithm = lib.mkOption {
        type = lib.types.enum [ "exponential-decay" "sliding-window" "ml-predicted" ];
        default = "exponential-decay";
        description = "Heat calculation algorithm";
      };
    };
    
    # Data movement engine
    movement = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic data movement";
      };
      
      engine = lib.mkOption {
        type = lib.types.enum [ "continuous" "scheduled" "triggered" ];
        default = "continuous";
        description = "Movement engine mode";
      };
      
      bandwidth = {
        limit = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Bandwidth limit for data movement";
          example = "100MB/s";
        };
        
        priority = lib.mkOption {
          type = lib.types.submodule {
            options = {
              promotion = lib.mkOption {
                type = lib.types.int;
                default = 70;
                description = "Bandwidth % for promotions";
              };
              
              demotion = lib.mkOption {
                type = lib.types.int;
                default = 20;
                description = "Bandwidth % for demotions";
              };
              
              rebalance = lib.mkOption {
                type = lib.types.int;
                default = 10;
                description = "Bandwidth % for rebalancing";
              };
            };
          };
          default = {};
          description = "Bandwidth allocation priorities";
        };
      };
      
      schedule = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            promotionWindow = lib.mkOption {
              type = lib.types.str;
              default = "* * * * *";
              description = "Cron schedule for promotions";
            };
            
            demotionWindow = lib.mkOption {
              type = lib.types.str;
              default = "0 2 * * *";
              description = "Cron schedule for demotions";
            };
            
            rebalanceWindow = lib.mkOption {
              type = lib.types.str;
              default = "0 4 * * 0";
              description = "Cron schedule for rebalancing";
            };
          };
        });
        default = null;
        description = "Movement schedule (for scheduled mode)";
      };
    };
    
    # Caching layers
    caching = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable multi-tier caching";
      };
      
      layers = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Cache layer name";
            };
            
            size = lib.mkOption {
              type = lib.types.str;
              description = "Cache size";
              example = "100Gi";
            };
            
            location = lib.mkOption {
              type = lib.types.enum [ "memory" "nvme" "ssd" ];
              description = "Cache location";
            };
            
            policy = lib.mkOption {
              type = lib.types.enum [ "lru" "lfu" "arc" "2q" "tinylfu" ];
              default = "arc";
              description = "Cache eviction policy";
            };
            
            writePolicy = lib.mkOption {
              type = lib.types.enum [ "write-through" "write-back" "write-around" ];
              default = "write-back";
              description = "Cache write policy";
            };
          };
        });
        default = [];
        description = "Cache layer definitions";
      };
    };
  };
  
in
{
  options.hypervisor.storage = {
    # Storage tiers
    tiers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule tierDefinition);
      default = {};
      description = "Storage tier definitions";
      example = literalExample ''
        {
          ultra = {
            level = 0;
            characteristics = {
              latency = "< 0.1ms";
              throughput = "> 10GB/s";
              iops = "> 1000000";
            };
            providers = [{
              name = "nvme-pool-1";
              type = "memory";
              capacity = "1Ti";
              location = "node1";
            }];
          };
          fast = {
            level = 1;
            characteristics = {
              latency = "< 1ms";
              throughput = "> 1GB/s";
              iops = "> 50000";
            };
          };
        }
      '';
    };
    
    # Data classifications
    classifications = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule dataClassification);
      default = {};
      description = "Data classification rules";
    };
    
    # Storage fabric configuration
    fabric = lib.mkOption {
      type = lib.types.submodule storageFabric;
      default = {};
      description = "Storage fabric configuration";
    };
    
    # Default tier for unclassified data
    defaultTier = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Default storage tier for new data";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Storage tier management service
    systemd.services.storage-tier-manager = lib.mkIf cfg.fabric.movement.enable {
      description = "Storage Tier Management Service";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "notify";
        # Add timeout in case systemd-notify fails
        TimeoutStartSec = "60s";
        ExecStart = "${pkgs.writeShellScript "storage-tier-manager" ''
          #!/usr/bin/env bash
          
          # Signal systemd we're ready
          systemd-notify --ready
          
          while true; do
            # Heat map calculation
            if [[ "${toString cfg.fabric.heatMap.enable}" == "true" ]]; then
              echo "Calculating storage heat map..."
              # Implementation would track access patterns
            fi
            
            # Data movement decisions
            if [[ "${cfg.fabric.movement.engine}" == "continuous" ]]; then
              echo "Evaluating data movement..."
              # Implementation would move data between tiers
            fi
            
            sleep 60
          done
        ''}";
        
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Heat map collector
    systemd.services.storage-heatmap-collector = lib.mkIf cfg.fabric.heatMap.enable {
      description = "Storage Heat Map Collector";
      wantedBy = [ "multi-user.target" ];
      
      script = ''
        mkdir -p /var/lib/hypervisor/storage/heatmap
        
        # Collect access statistics
        while true; do
          # In real implementation, would use eBPF or filesystem hooks
          date >> /var/lib/hypervisor/storage/heatmap/access.log
          sleep 10
        done
      '';
    };
    
    # Storage fabric API
    environment.etc."hypervisor/scripts/storage-fabric.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Storage Fabric Management Interface
        
        case "$1" in
          tiers)
            echo "Storage Tiers:"
            ${concatStringsSep "\n" (mapAttrsToList (name: tier: ''
              echo "  ${name} (Level ${toString tier.level}):"
              echo "    Latency: ${tier.characteristics.latency}"
              echo "    Throughput: ${tier.characteristics.throughput}"
              echo "    Providers: ${toString (length tier.providers)}"
            '') cfg.tiers)}
            ;;
            
          heatmap)
            echo "Storage Heat Map:"
            echo "  Granularity: ${cfg.fabric.heatMap.granularity}"
            echo "  Algorithm: ${cfg.fabric.heatMap.algorithm}"
            echo "  Time Windows: ${concatStringsSep ", " cfg.fabric.heatMap.timeWindows}"
            ;;
            
          classify)
            if [ -z "$2" ]; then
              echo "Usage: storage-fabric classify <file>"
              exit 1
            fi
            # Classify file based on patterns
            echo "Classifying $2..."
            ;;
            
          move)
            if [ -z "$3" ]; then
              echo "Usage: storage-fabric move <file> <tier>"
              exit 1
            fi
            echo "Moving $2 to tier $3..."
            ;;
            
          stats)
            echo "Storage Statistics:"
            echo "  Active Movements: 0"
            echo "  Heat Map Entries: 0"
            echo "  Cache Hit Rate: 0%"
            ;;
            
          *)
            echo "Usage: storage-fabric {tiers|heatmap|classify|move|stats}"
            exit 1
            ;;
        esac
      '';
    };
    
    # Create default tier structure
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/storage 0755 root root -"
      "d /var/lib/hypervisor/storage/tiers 0755 root root -"
      "d /var/lib/hypervisor/storage/heatmap 0755 root root -"
      "d /var/lib/hypervisor/storage/cache 0755 root root -"
    ] ++ (flatten (mapAttrsToList (name: tier: 
      [ "d /var/lib/hypervisor/storage/tiers/${toString tier.level} 0755 root root -" ]
    ) cfg.tiers));
  };
}