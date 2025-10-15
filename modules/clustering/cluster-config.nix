# Cluster Configuration Module - Enterprise High Availability
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.cluster;
  
  # Node configuration options
  nodeOptions = {
    options = {
      nodeId = mkOption {
        type = types.int;
        description = "Unique node ID in cluster (1-255)";
        example = 1;
      };
      
      address = mkOption {
        type = types.str;
        description = "IP address or hostname of the node";
        example = "192.168.1.10";
      };
      
      priority = mkOption {
        type = types.int;
        default = 50;
        description = "Node priority for quorum decisions (1-255)";
      };
      
      votes = mkOption {
        type = types.int;
        default = 1;
        description = "Number of votes for quorum";
      };
      
      roles = mkOption {
        type = types.listOf (types.enum [ "master" "compute" "storage" "backup" ]);
        default = [ "compute" ];
        description = "Node roles in the cluster";
      };
    };
  };
  
  # High Availability group options
  haGroupOptions = {
    options = {
      nodes = mkOption {
        type = types.listOf types.str;
        description = "List of node names in this HA group";
        example = [ "node1" "node2" "node3" ];
      };
      
      restricted = mkOption {
        type = types.bool;
        default = false;
        description = "Restrict VMs to only run on these nodes";
      };
      
      nofailback = mkOption {
        type = types.bool;
        default = false;
        description = "Prevent automatic failback to original node";
      };
      
      max_restart = mkOption {
        type = types.int;
        default = 3;
        description = "Maximum restart attempts";
      };
      
      max_relocate = mkOption {
        type = types.int;
        default = 3;
        description = "Maximum relocation attempts";
      };
    };
  };
  
  # Fencing device options
  fencingDeviceOptions = {
    options = {
      type = mkOption {
        type = types.enum [ "ipmi" "ilo" "idrac" "apc" "manual" ];
        description = "Fencing device type";
      };
      
      address = mkOption {
        type = types.str;
        description = "Device address or hostname";
      };
      
      username = mkOption {
        type = types.str;
        description = "Device username";
      };
      
      passwordFile = mkOption {
        type = types.path;
        description = "File containing device password";
      };
      
      options = mkOption {
        type = types.attrs;
        default = {};
        description = "Additional device-specific options";
      };
    };
  };
  
  # Generate Corosync configuration
  generateCorosyncConfig = ''
    totem {
        version: 2
        cluster_name: ${cfg.name}
        transport: ${cfg.transport}
        
        ${optionalString (cfg.transport == "knet") ''
        crypto_cipher: ${cfg.crypto.cipher}
        crypto_hash: ${cfg.crypto.hash}
        ''}
        
        ${optionalString (cfg.network.rrp.enable) ''
        rrp_mode: ${cfg.network.rrp.mode}
        ''}
    }
    
    nodelist {
        ${concatStringsSep "\n" (mapAttrsToList (name: node: ''
        node {
            name: ${name}
            nodeid: ${toString node.nodeId}
            
            ring0_addr: ${node.address}
            ${optionalString (cfg.network.rrp.enable && node ? ring1_addr) ''
            ring1_addr: ${node.ring1_addr}
            ''}
            
            quorum_votes: ${toString node.votes}
        }
        '') cfg.nodes)}
    }
    
    quorum {
        provider: corosync_votequorum
        expected_votes: ${toString cfg.expectedVotes}
        ${optionalString (cfg.twoNode) "two_node: 1"}
        ${optionalString (cfg.waitForAll) "wait_for_all: 1"}
        ${optionalString (cfg.lastManStanding.enable) ''
        last_man_standing: 1
        last_man_standing_window: ${toString cfg.lastManStanding.window}
        ''}
    }
    
    logging {
        to_syslog: yes
        debug: ${if cfg.debug then "on" else "off"}
        timestamp: on
    }
  '';
  
  # Generate Pacemaker CIB base configuration
  generatePacemakerConfig = ''
    <cib crm_feature_set="3.0.14" validate-with="pacemaker-3.0">
      <configuration>
        <crm_config>
          <cluster_property_set id="cib-bootstrap-options">
            <nvpair id="cib-bootstrap-options-have-watchdog" name="have-watchdog" value="${if cfg.watchdog.enable then "true" else "false"}"/>
            <nvpair id="cib-bootstrap-options-dc-version" name="dc-version" value="2.0.0"/>
            <nvpair id="cib-bootstrap-options-cluster-infrastructure" name="cluster-infrastructure" value="corosync"/>
            <nvpair id="cib-bootstrap-options-cluster-name" name="cluster-name" value="${cfg.name}"/>
            <nvpair id="cib-bootstrap-options-stonith-enabled" name="stonith-enabled" value="${if cfg.fencing.enable then "true" else "false"}"/>
            <nvpair id="cib-bootstrap-options-no-quorum-policy" name="no-quorum-policy" value="${cfg.noQuorumPolicy}"/>
            ${optionalString (cfg.migrationLimit != null) ''
            <nvpair id="cib-bootstrap-options-migration-limit" name="migration-limit" value="${toString cfg.migrationLimit}"/>
            ''}
          </cluster_property_set>
        </crm_config>
        <nodes>
          ${concatStringsSep "\n" (mapAttrsToList (name: node: ''
          <node id="${toString node.nodeId}" uname="${name}"/>
          '') cfg.nodes)}
        </nodes>
        <resources/>
        <constraints/>
      </configuration>
    </cib>
  '';
in
{
  options.hypervisor.cluster = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable clustering support";
    };
    
    name = mkOption {
      type = types.str;
      default = "hypervisor-cluster";
      description = "Cluster name";
    };
    
    nodeName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "This node's name in the cluster";
    };
    
    nodes = mkOption {
      type = types.attrsOf (types.submodule nodeOptions);
      default = {};
      description = "Cluster node definitions";
      example = literalExpression ''
        {
          node1 = {
            nodeId = 1;
            address = "192.168.1.10";
            priority = 100;
            roles = [ "master" "compute" ];
          };
          node2 = {
            nodeId = 2;
            address = "192.168.1.11";
            roles = [ "compute" "storage" ];
          };
          node3 = {
            nodeId = 3;
            address = "192.168.1.12";
            roles = [ "compute" "backup" ];
          };
        }
      '';
    };
    
    # Network configuration
    network = {
      clusterNetwork = mkOption {
        type = types.str;
        default = "0.0.0.0/0";
        description = "Network for cluster communication";
        example = "10.10.10.0/24";
      };
      
      bindAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Address to bind cluster services";
      };
      
      multicast = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Use multicast for cluster communication";
        };
        
        address = mkOption {
          type = types.str;
          default = "239.192.0.1";
          description = "Multicast address";
        };
        
        port = mkOption {
          type = types.port;
          default = 5405;
          description = "Multicast port";
        };
      };
      
      rrp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable redundant ring protocol";
        };
        
        mode = mkOption {
          type = types.enum [ "passive" "active" ];
          default = "passive";
          description = "RRP mode";
        };
      };
      
      migration = {
        network = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Dedicated network for VM migration";
          example = "10.10.20.0/24";
        };
        
        rateLimit = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Migration bandwidth limit in MB/s";
        };
        
        encryption = mkOption {
          type = types.bool;
          default = true;
          description = "Encrypt migration traffic";
        };
      };
    };
    
    # Transport configuration
    transport = mkOption {
      type = types.enum [ "udp" "udpu" "knet" ];
      default = "knet";
      description = "Cluster transport protocol";
    };
    
    # Crypto configuration
    crypto = {
      cipher = mkOption {
        type = types.enum [ "none" "aes256" "aes192" "aes128" ];
        default = "aes256";
        description = "Encryption cipher for cluster communication";
      };
      
      hash = mkOption {
        type = types.enum [ "none" "md5" "sha1" "sha256" "sha384" "sha512" ];
        default = "sha256";
        description = "Hash algorithm for cluster communication";
      };
    };
    
    # Quorum configuration
    expectedVotes = mkOption {
      type = types.int;
      default = 0;
      description = "Expected number of votes (0 = auto-calculate)";
    };
    
    twoNode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable two-node cluster mode";
    };
    
    waitForAll = mkOption {
      type = types.bool;
      default = false;
      description = "Wait for all nodes on startup";
    };
    
    lastManStanding = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable last man standing algorithm";
      };
      
      window = mkOption {
        type = types.int;
        default = 10000;
        description = "LMS window in milliseconds";
      };
    };
    
    noQuorumPolicy = mkOption {
      type = types.enum [ "stop" "freeze" "ignore" "suicide" ];
      default = "stop";
      description = "Policy when cluster loses quorum";
    };
    
    # High Availability configuration
    ha = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable high availability features";
      };
      
      groups = mkOption {
        type = types.attrsOf (types.submodule haGroupOptions);
        default = {};
        description = "HA group definitions";
        example = literalExpression ''
          {
            critical = {
              nodes = [ "node1" "node2" "node3" ];
              restricted = true;
              nofailback = false;
            };
            
            general = {
              nodes = [ "node2" "node3" "node4" ];
              restricted = false;
            };
          }
        '';
      };
      
      defaultGroup = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default HA group for VMs";
      };
    };
    
    # Fencing configuration
    fencing = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable node fencing";
      };
      
      devices = mkOption {
        type = types.attrsOf (types.submodule fencingDeviceOptions);
        default = {};
        description = "Fencing device configurations";
      };
      
      watchdog = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Watchdog device path";
        example = "/dev/watchdog";
      };
    };
    
    # Watchdog configuration
    watchdog = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable watchdog support";
      };
      
      device = mkOption {
        type = types.str;
        default = "/dev/watchdog";
        description = "Watchdog device";
      };
      
      interval = mkOption {
        type = types.int;
        default = 5;
        description = "Watchdog interval in seconds";
      };
    };
    
    # Resource limits
    migrationLimit = mkOption {
      type = types.nullOr types.int;
      default = 2;
      description = "Maximum concurrent migrations";
    };
    
    # Monitoring
    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable cluster monitoring";
      };
      
      interval = mkOption {
        type = types.int;
        default = 30;
        description = "Monitoring interval in seconds";
      };
    };
    
    # Debug options
    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug logging";
    };
  };
  
  config = mkIf cfg.enable {
    # Validate configuration
    assertions = [
      {
        assertion = cfg.nodes != {};
        message = "At least one cluster node must be defined";
      }
      {
        assertion = cfg.nodeName != "" && cfg.nodes ? ${cfg.nodeName};
        message = "This node (${cfg.nodeName}) must be defined in cluster.nodes";
      }
      {
        assertion = cfg.twoNode -> length (attrNames cfg.nodes) == 2;
        message = "Two-node mode requires exactly 2 nodes";
      }
      {
        assertion = all (node: node.nodeId >= 1 && node.nodeId <= 255) (attrValues cfg.nodes);
        message = "Node IDs must be between 1 and 255";
      }
    ];
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      corosync
      pacemaker
      pcs
      fence-agents
      resource-agents
      crmsh
      dlm
    ] ++ optional cfg.fencing.enable fence-virt
      ++ optional cfg.monitoring.enable hawk;
    
    # Corosync configuration
    environment.etc."corosync/corosync.conf" = {
      text = generateCorosyncConfig;
      mode = "0644";
    };
    
    # Corosync service
    systemd.services.corosync = {
      description = "Corosync Cluster Engine";
      after = [ "network.target" ];
      requires = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "notify";
        ExecStart = "${pkgs.corosync}/sbin/corosync -f";
        ExecStop = "${pkgs.corosync}/sbin/corosync-cfgtool -H";
        Restart = "on-failure";
        RestartSec = "10s";
        
        # Security settings
        PrivateTmp = true;
        ProtectSystem = "full";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };
    
    # Pacemaker service
    systemd.services.pacemaker = mkIf cfg.ha.enable {
      description = "Pacemaker High Availability Cluster Manager";
      after = [ "corosync.service" ];
      requires = [ "corosync.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.pacemaker}/sbin/pacemakerd -f";
        Restart = "on-failure";
        RestartSec = "10s";
        
        # Pacemaker needs more privileges
        PrivateTmp = true;
        ProtectHome = true;
      };
      
      preStart = ''
        # Wait for corosync to be ready
        for i in {1..30}; do
          if ${pkgs.corosync}/sbin/corosync-cfgtool -s >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done
      '';
    };
    
    # Cluster management scripts
    environment.etc."hypervisor/scripts/cluster-status.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Show cluster status
        
        echo "=== Corosync Status ==="
        ${pkgs.corosync}/sbin/corosync-cfgtool -s
        echo
        
        echo "=== Corosync Members ==="
        ${pkgs.corosync}/sbin/corosync-cmapctl | grep members
        echo
        
        ${optionalString cfg.ha.enable ''
        echo "=== Pacemaker Status ==="
        ${pkgs.pacemaker}/bin/crm_mon -1
        echo
        
        echo "=== Cluster Resources ==="
        ${pkgs.pacemaker}/bin/crm_resource -L
        ''}
      '';
    };
    
    environment.etc."hypervisor/scripts/cluster-join.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Join node to cluster
        
        set -euo pipefail
        
        if [[ $# -ne 1 ]]; then
            echo "Usage: $0 <existing-node-address>"
            exit 1
        fi
        
        PEER_NODE="$1"
        
        echo "Joining cluster via node: $PEER_NODE"
        
        # Copy cluster configuration from peer
        scp "root@$PEER_NODE:/etc/corosync/corosync.conf" /etc/corosync/
        scp "root@$PEER_NODE:/etc/corosync/authkey" /etc/corosync/
        
        # Start services
        systemctl start corosync
        ${optionalString cfg.ha.enable "systemctl start pacemaker"}
        
        echo "Cluster join complete!"
      '';
    };
    
    # Firewall rules for cluster communication
    networking.firewall = mkIf cfg.enable {
      allowedTCPPorts = [
        5404  # Corosync
        5405  # Corosync
        2224  # Pacemaker
        3121  # Pacemaker
        21064 # DLM
      ];
      
      allowedUDPPorts = [
        5404  # Corosync
        5405  # Corosync
      ];
    };
    
    # Kernel parameters for clustering
    boot.kernel.sysctl = {
      "net.ipv4.ip_nonlocal_bind" = 1;
      "net.ipv6.ip_nonlocal_bind" = 1;
    };
    
    # Create cluster state directory
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/cluster 0750 root root -"
      "d /var/lib/corosync 0750 root root -"
      "d /var/lib/pacemaker 0750 hacluster haclient -"
    ];
    
    # Create cluster users/groups
    users.users.hacluster = {
      isSystemUser = true;
      group = "haclient";
      description = "Pacemaker cluster user";
    };
    
    users.groups.haclient = {};
  };
}