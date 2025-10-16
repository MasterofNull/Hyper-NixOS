# Mesh-Based Clustering with Consensus Algorithms
# Implements a decentralized mesh topology with pluggable consensus
{ config, lib, pkgs, ... }:

# Removed: with lib; - Using explicit lib. prefix for clarity
let
  cfg = config.hypervisor.mesh;
  
  # Node identity and capabilities
  nodeDefinition = {
    options = {
      id = lib.mkOption {
        type = lib.types.str;
        description = "Unique node identifier (auto-generated if empty)";
        default = "";
      };
      
      capabilities = {
        compute = lib.mkOption {
          type = lib.types.submodule {
            options = {
              available = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Can host compute workloads";
              };
              
              capacity = lib.mkOption {
                type = lib.types.int;
                default = 1000;
                description = "Compute capacity units";
              };
              
              specializations = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Specialized compute capabilities";
                example = [ "gpu" "fpga" "quantum" ];
              };
            };
          };
          default = {};
          description = "Compute capabilities";
        };
        
        storage = lib.mkOption {
          type = lib.types.submodule {
            options = {
              available = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Can provide storage";
              };
              
              tiers = lib.mkOption {
                type = lib.types.listOf lib.types.int;
                default = [ 1 ];
                description = "Available storage tiers";
              };
              
              capacity = lib.mkOption {
                type = lib.types.str;
                default = "1Ti";
                description = "Total storage capacity";
              };
            };
          };
          default = {};
          description = "Storage capabilities";
        };
        
        network = lib.mkOption {
          type = lib.types.submodule {
            options = {
              gateway = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can act as network gateway";
              };
              
              bandwidth = lib.mkOption {
                type = lib.types.str;
                default = "1Gbps";
                description = "Network bandwidth capacity";
              };
              
              features = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Network features";
                example = [ "sr-iov" "dpdk" "rdma" ];
              };
            };
          };
          default = {};
          description = "Network capabilities";
        };
      };
      
      location = {
        zone = lib.mkOption {
          type = lib.types.str;
          default = "default";
          description = "Availability zone";
        };
        
        rack = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Rack identifier";
        };
        
        geo = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              latitude = lib.mkOption { type = lib.types.float; };
              longitude = lib.mkOption { type = lib.types.float; };
              region = lib.mkOption { type = lib.types.str; };
            };
          });
          default = null;
          description = "Geographic location";
        };
      };
      
      roles = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [
          "controller"    # Participates in control plane
          "worker"        # Runs workloads
          "storage"       # Provides storage
          "edge"          # Edge node
          "witness"       # Witness-only (for quorum)
        ]);
        default = [ "worker" ];
        description = "Node roles in the mesh";
      };
    };
  };
  
  # Consensus configuration
  consensusDefinition = {
    algorithm = lib.mkOption {
      type = lib.types.enum [ "raft" "pbft" "tendermint" "avalanche" "hotstuff" ];
      default = "raft";
      description = "Consensus algorithm to use";
    };
    
    parameters = {
      raft = lib.mkOption {
        type = lib.types.submodule {
          options = {
            electionTimeout = lib.mkOption {
              type = lib.types.int;
              default = 150;
              description = "Election timeout in milliseconds";
            };
            
            heartbeatInterval = lib.mkOption {
              type = lib.types.int;
              default = 50;
              description = "Heartbeat interval in milliseconds";
            };
            
            snapshotInterval = lib.mkOption {
              type = lib.types.int;
              default = 10000;
              description = "Snapshot interval (log entries)";
            };
            
            maxInflightMsgs = lib.mkOption {
              type = lib.types.int;
              default = 256;
              description = "Maximum inflight messages";
            };
          };
        };
        default = {};
        description = "Raft consensus parameters";
      };
      
      pbft = lib.mkOption {
        type = lib.types.submodule {
          options = {
            faultTolerance = lib.mkOption {
              type = lib.types.int;
              default = 1;
              description = "Number of faulty nodes to tolerate";
            };
            
            batchSize = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "Transaction batch size";
            };
            
            checkpointPeriod = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "Checkpoint period";
            };
          };
        };
        default = {};
        description = "PBFT consensus parameters";
      };
      
      tendermint = lib.mkOption {
        type = lib.types.submodule {
          options = {
            blockTime = lib.mkOption {
              type = lib.types.int;
              default = 1000;
              description = "Target block time in ms";
            };
            
            validatorSetSize = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "Maximum validator set size";
            };
          };
        };
        default = {};
        description = "Tendermint consensus parameters";
      };
    };
    
    quorum = {
      size = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Quorum size (auto-calculated if null)";
      };
      
      voters = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Explicit list of voting nodes";
      };
      
      observers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Non-voting observer nodes";
      };
    };
  };
  
  # Mesh topology configuration
  topologyDefinition = {
    mode = lib.mkOption {
      type = lib.types.enum [ "full-mesh" "partial-mesh" "hierarchical" "dynamic" ];
      default = "partial-mesh";
      description = "Mesh topology mode";
    };
    
    connections = {
      strategy = lib.mkOption {
        type = lib.types.enum [ "nearest" "random" "capacity-weighted" "latency-optimized" ];
        default = "nearest";
        description = "Connection strategy";
      };
      
      minPeers = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Minimum peer connections";
      };
      
      maxPeers = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Maximum peer connections";
      };
      
      gossipFanout = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Gossip protocol fanout";
      };
    };
    
    discovery = {
      method = lib.mkOption {
        type = lib.types.enum [ "static" "dns" "mdns" "consul" "etcd" "kubernetes" ];
        default = "mdns";
        description = "Node discovery method";
      };
      
      interval = lib.mkOption {
        type = lib.types.str;
        default = "30s";
        description = "Discovery interval";
      };
      
      staticPeers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Static peer addresses";
      };
    };
    
    routing = {
      algorithm = lib.mkOption {
        type = lib.types.enum [ "shortest-path" "load-balanced" "geo-aware" "cost-optimized" ];
        default = "shortest-path";
        description = "Routing algorithm";
      };
      
      metrics = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "latency" "bandwidth" "reliability" "cost" ]);
        default = [ "latency" ];
        description = "Metrics to consider for routing";
      };
      
      updateInterval = lib.mkOption {
        type = lib.types.str;
        default = "10s";
        description = "Routing table update interval";
      };
    };
  };
  
  # Distributed coordination
  coordinationDefinition = {
    scheduler = {
      algorithm = lib.mkOption {
        type = lib.types.enum [ 
          "random"           # Random placement
          "round-robin"      # Round-robin across nodes
          "least-loaded"     # Place on least loaded node
          "bin-packing"      # Optimize resource utilization
          "spread"           # Maximize spreading
          "gang"             # Gang scheduling for related workloads
          "fair-share"       # Fair resource sharing
          "priority-based"   # Priority queue based
        ];
        default = "least-loaded";
        description = "Workload scheduling algorithm";
      };
      
      constraints = {
        enableAffinity = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable affinity constraints";
        };
        
        enableAntiAffinity = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable anti-affinity constraints";
        };
        
        maxSchedulingTime = lib.mkOption {
          type = lib.types.str;
          default = "100ms";
          description = "Maximum time for scheduling decision";
        };
      };
      
      rebalancing = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable automatic rebalancing";
        };
        
        threshold = lib.mkOption {
          type = lib.types.float;
          default = 0.2;
          description = "Imbalance threshold (0-1)";
        };
        
        interval = lib.mkOption {
          type = lib.types.str;
          default = "5m";
          description = "Rebalancing check interval";
        };
      };
    };
    
    stateStore = {
      backend = lib.mkOption {
        type = lib.types.enum [ "embedded" "etcd" "consul" "tikv" ];
        default = "embedded";
        description = "Distributed state store backend";
      };
      
      replication = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "State replication factor";
      };
      
      consistency = lib.mkOption {
        type = lib.types.enum [ "eventual" "strong" "linearizable" ];
        default = "strong";
        description = "Consistency model";
      };
    };
    
    locks = {
      implementation = lib.mkOption {
        type = lib.types.enum [ "local" "redlock" "chubby" "zab" ];
        default = "redlock";
        description = "Distributed lock implementation";
      };
      
      defaultTimeout = lib.mkOption {
        type = lib.types.str;
        default = "30s";
        description = "Default lock timeout";
      };
      
      enableFencing = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable lock fencing tokens";
      };
    };
  };
  
in
{
  options.hypervisor.mesh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable mesh clustering";
    };
    
    # This node's configuration
    node = lib.mkOption {
      type = lib.types.submodule nodeDefinition;
      default = {};
      description = "This node's configuration";
    };
    
    # Cluster name
    clusterName = lib.mkOption {
      type = lib.types.str;
      default = "hypervisor-mesh";
      description = "Mesh cluster name";
    };
    
    # Consensus configuration
    consensus = lib.mkOption {
      type = lib.types.submodule consensusDefinition;
      default = {};
      description = "Consensus algorithm configuration";
    };
    
    # Topology configuration
    topology = lib.mkOption {
      type = lib.types.submodule topologyDefinition;
      default = {};
      description = "Mesh topology configuration";
    };
    
    # Coordination configuration
    coordination = lib.mkOption {
      type = lib.types.submodule coordinationDefinition;
      default = {};
      description = "Distributed coordination configuration";
    };
    
    # Security
    security = {
      encryption = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable mesh encryption";
        };
        
        algorithm = lib.mkOption {
          type = lib.types.enum [ "aes-gcm" "chacha20-poly1305" "aes-cbc" ];
          default = "chacha20-poly1305";
          description = "Encryption algorithm";
        };
        
        keyRotation = lib.mkOption {
          type = lib.types.str;
          default = "24h";
          description = "Key rotation interval";
        };
      };
      
      authentication = {
        method = lib.mkOption {
          type = lib.types.enum [ "psk" "pki" "mutual-tls" "spiffe" ];
          default = "mutual-tls";
          description = "Authentication method";
        };
        
        ca = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "CA certificate path";
        };
      };
    };
    
    # Observability
    observability = {
      tracing = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable distributed tracing";
        };
        
        backend = lib.mkOption {
          type = lib.types.enum [ "jaeger" "zipkin" "otlp" ];
          default = "otlp";
          description = "Tracing backend";
        };
      };
      
      metrics = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable mesh metrics";
        };
        
        exportInterval = lib.mkOption {
          type = lib.types.str;
          default = "10s";
          description = "Metrics export interval";
        };
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Generate node ID if not provided
    system.activationScripts.generateNodeId = ''
      if [ ! -f /var/lib/hypervisor/mesh/node-id ]; then
        mkdir -p /var/lib/hypervisor/mesh
        ${pkgs.util-linux}/bin/uuidgen > /var/lib/hypervisor/mesh/node-id
      fi
    '';
    
    # Mesh node service
    systemd.services.hypervisor-mesh-node = {
      description = "Hypervisor Mesh Node";
      # Don't auto-start mesh clustering by default
      # Enable with: systemctl enable hypervisor-mesh-node
      # wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      # Don't require network - allow boot to continue if network is unavailable
      # Using 'wants' instead of 'requires' prevents boot hangs
      wants = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "notify";
        # Add timeout for mesh node startup to prevent boot hangs
        TimeoutStartSec = "60s";
        ExecStart = "${pkgs.writeShellScript "mesh-node" ''
          #!/usr/bin/env bash
          
          NODE_ID=$(cat /var/lib/hypervisor/mesh/node-id)
          
          echo "Starting mesh node: $NODE_ID"
          echo "Cluster: ${cfg.clusterName}"
          echo "Consensus: ${cfg.consensus.algorithm}"
          echo "Topology: ${cfg.topology.mode}"
          
          # Signal systemd
          systemd-notify --ready
          
          # Main loop
          while true; do
            # In real implementation:
            # - Maintain peer connections
            # - Participate in consensus
            # - Handle work scheduling
            # - Update routing tables
            sleep 5
          done
        ''}";
        
        Restart = "always";
        RestartSec = 10;
        
        # Security
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/hypervisor/mesh" ];
      };
    };
    
    # Consensus engine
    systemd.services.hypervisor-consensus = lib.mkIf (elem "controller" cfg.node.roles) {
      description = "Hypervisor Consensus Engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "hypervisor-mesh-node.service" ];
      
      serviceConfig = {
        Type = "simple";
        # Add timeout to prevent boot hangs
        TimeoutStartSec = "60s";
        ExecStart = "${pkgs.writeShellScript "consensus-engine" ''
          #!/usr/bin/env bash
          
          echo "Starting ${cfg.consensus.algorithm} consensus engine"
          
          case "${cfg.consensus.algorithm}" in
            raft)
              echo "Raft: election timeout ${toString cfg.consensus.parameters.raft.electionTimeout}ms"
              ;;
            pbft)
              echo "PBFT: fault tolerance ${toString cfg.consensus.parameters.pbft.faultTolerance}"
              ;;
            *)
              echo "Consensus algorithm: ${cfg.consensus.algorithm}"
              ;;
          esac
          
          # Consensus loop
          while true; do
            sleep 1
          done
        ''}";
        
        Restart = "always";
      };
    };
    
    # Mesh CLI tool
    environment.systemPackages = [
      (writeScriptBin "hv-mesh" ''
        #!${pkgs.bash}/bin/bash
        # Mesh cluster management tool
        
        case "$1" in
          status)
            echo "Mesh Status:"
            echo "  Cluster: ${cfg.clusterName}"
            echo "  Node ID: $(cat /var/lib/hypervisor/mesh/node-id 2>/dev/null || echo 'not initialized')"
            echo "  Consensus: ${cfg.consensus.algorithm}"
            echo "  Topology: ${cfg.topology.mode}"
            echo "  Roles: ${concatStringsSep ", " cfg.node.roles}"
            ;;
            
          peers)
            echo "Peer Connections:"
            echo "  Discovery: ${cfg.topology.discovery.method}"
            echo "  Min peers: ${toString cfg.topology.connections.minPeers}"
            echo "  Max peers: ${toString cfg.topology.connections.maxPeers}"
            ;;
            
          consensus)
            echo "Consensus State:"
            echo "  Algorithm: ${cfg.consensus.algorithm}"
            echo "  Quorum size: ${toString (cfg.consensus.quorum.size or "auto")}"
            ;;
            
          schedule)
            echo "Scheduler:"
            echo "  Algorithm: ${cfg.coordination.scheduler.algorithm}"
            echo "  Rebalancing: ${if cfg.coordination.scheduler.rebalancing.enable then "enabled" else "disabled"}"
            ;;
            
          *)
            echo "Usage: hv-mesh {status|peers|consensus|schedule}"
            exit 1
            ;;
        esac
      '')
    ];
    
    # Network configuration for mesh
    networking.firewall = lib.mkIf cfg.enable {
      allowedTCPPorts = [ 7946 7947 ];  # Mesh communication ports
      allowedUDPPorts = [ 7946 7947 ];
    };
    
    # State directories
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/mesh 0700 root root -"
      "d /var/lib/hypervisor/mesh/state 0700 root root -"
      "d /var/lib/hypervisor/mesh/consensus 0700 root root -"
    ];
  };
}