# Production-Ready Hyper-NixOS Configuration
# This example shows a complete production setup with all innovative features

{ config, pkgs, lib, ... }:

{
  imports = [
    ../hardware-configuration.nix
    ../modules/virtualization/vm-config.nix
    ../modules/storage-management/storage-tiers.nix
    ../modules/clustering/mesh-cluster.nix
    ../modules/core/capability-security.nix
    ../modules/automation/backup-dedup.nix
    ../modules/virtualization/vm-composition.nix
    ../modules/monitoring/ai-anomaly.nix
  ];

  # System basics
  networking.hostName = "hyper-prod-01";
  time.timeZone = "UTC";
  
  # Hyper-NixOS Configuration
  hypervisor = {
    # Enable all innovative features
    compute.enable = true;
    storage.enable = true;
    mesh.enable = true;
    security.capabilities.enable = true;
    backup.enable = true;
    composition.enable = true;
    monitoring.ai.enable = true;

    # Tag-based compute configuration
    compute = {
      # Define tags for different workload types
      tags = {
        production = {
          category = "lifecycle";
          priority = 100;
          values = {
            resources.compute.units = 400;
            features.isolation.securityLevel = "hardened";
            features.persistence.migration = "live";
          };
        };
        
        high-performance = {
          category = "performance";
          priority = 90;
          values = {
            resources.compute.burst = 200;
            resources.memory.bandwidth = 100;
          };
        };
        
        database = {
          category = "workload";
          priority = 80;
          values = {
            resources.memory.hugepages = "2Mi";
            storage = [{
              capability = "ultra-fast-nvme";
              features = [ "encryption" "snapshots" ];
            }];
          };
        };
      };
      
      # Define policies
      policies = {
        web-tier = {
          tags = [ "production" "high-performance" ];
          defaults = {
            resources.memory.size = "4Gi";
            network = [{
              capability = "public-internet";
              features = [ "ipv6" "ddos-protection" ];
            }];
          };
        };
        
        data-tier = {
          tags = [ "production" "database" ];
          defaults = {
            resources.memory.size = "32Gi";
            workload.sla.availability = 0.999;
          };
        };
      };
      
      # Deploy compute units
      units = {
        # Web servers
        web-01 = {
          tags = [ "production" "high-performance" ];
          policies = [ "web-tier" ];
          labels = {
            app = "nginx";
            tier = "frontend";
          };
          placement.affinity = [{
            type = "anti";
            scope = "host";
            labelSelector = { app = "nginx"; };
          }];
        };
        
        web-02 = {
          tags = [ "production" "high-performance" ];
          policies = [ "web-tier" ];
          labels = {
            app = "nginx";
            tier = "frontend";
          };
        };
        
        # Database cluster
        db-primary = {
          tags = [ "production" "database" ];
          policies = [ "data-tier" ];
          labels = {
            app = "postgresql";
            role = "primary";
          };
          resources.compute.units = 800;
          storage = [{
            name = "data";
            capability = "ultra-fast-nvme";
            size = "500Gi";
            performance = {
              iops = 50000;
              throughput = "1GB/s";
            };
          }];
        };
        
        db-replica = {
          tags = [ "production" "database" ];
          policies = [ "data-tier" ];
          labels = {
            app = "postgresql";
            role = "replica";
          };
          placement.affinity = [{
            type = "anti";
            scope = "host";
            labelSelector = { app = "postgresql"; };
          }];
        };
      };
    };

    # Tiered storage configuration
    storage = {
      tiers = {
        # Tier 0: Ultra-fast memory storage
        memory = {
          level = 0;
          characteristics = {
            latency = "< 0.01ms";
            throughput = "> 20GB/s";
            iops = "> 5000000";
            durability = 0.99;
            cost = 10.0;
          };
          providers = [{
            name = "ramdisk-1";
            type = "memory";
            capacity = "64Gi";
            location = "node-local";
            features = {
              encryption = false;
              compression = false;
            };
          }];
          policies = {
            promotion.threshold = {
              accessFrequency = 100;
              heatScore = 0.95;
            };
            demotion.threshold = {
              idleTime = "5m";
              heatScore = 0.7;
            };
          };
        };
        
        # Tier 1: NVMe storage
        fast = {
          level = 1;
          characteristics = {
            latency = "< 0.1ms";
            throughput = "> 5GB/s";
            iops = "> 500000";
            durability = 0.999999;
            cost = 1.0;
          };
          providers = [
            {
              name = "nvme-pool-1";
              type = "nvme-local";
              capacity = "2Ti";
              location = "node-local";
              features = {
                encryption = true;
                compression = true;
                deduplication = true;
              };
            }
            {
              name = "nvme-pool-2";
              type = "nvme-local";
              capacity = "2Ti";
              location = "node-local";
              features = {
                encryption = true;
                compression = true;
                deduplication = true;
              };
            }
          ];
        };
        
        # Tier 2: SSD array
        standard = {
          level = 2;
          characteristics = {
            latency = "< 1ms";
            throughput = "> 500MB/s";
            iops = "> 50000";
            durability = 0.9999999;
            cost = 0.3;
          };
          providers = [{
            name = "ssd-array-1";
            type = "ssd-array";
            capacity = "20Ti";
            location = "rack-storage";
          }];
        };
        
        # Tier 3: HDD array for cold storage
        archive = {
          level = 3;
          characteristics = {
            latency = "< 10ms";
            throughput = "> 200MB/s";
            iops = "> 1000";
            durability = 0.99999999;
            cost = 0.1;
          };
          providers = [{
            name = "hdd-array-1";
            type = "hdd-array";
            capacity = "100Ti";
            location = "rack-storage";
          }];
          policies = {
            retention = {
              minTime = "30d";
              maxTime = "365d";
            };
          };
        };
      };
      
      # Data classifications
      classifications = {
        database-hot = {
          patterns = [ "*.db" "*.idx" "*-wal" ];
          characteristics = {
            accessPattern = "random";
            temperature = "hot";
            criticality = "critical";
          };
          placement = {
            preferredTier = 1;
            allowedTiers = [ 0 1 ];
          };
        };
        
        web-assets = {
          patterns = [ "*.jpg" "*.png" "*.css" "*.js" ];
          characteristics = {
            accessPattern = "sequential";
            temperature = "warm";
            compressibility = "high";
          };
          placement = {
            preferredTier = 2;
            allowedTiers = [ 1 2 3 ];
          };
        };
        
        logs = {
          patterns = [ "*.log" "*.json" ];
          characteristics = {
            accessPattern = "append-only";
            temperature = "cool";
            compressibility = "high";
          };
          placement = {
            preferredTier = 3;
            allowedTiers = [ 2 3 ];
          };
        };
      };
      
      fabric = {
        heatMap = {
          enable = true;
          algorithm = "ml-predicted";
          granularity = "256Ki";
          timeWindows = [ "1h" "6h" "1d" "7d" "30d" ];
        };
        movement = {
          enable = true;
          engine = "continuous";
          bandwidth = {
            limit = "1GB/s";
            priority = {
              promotion = 60;
              demotion = 30;
              rebalance = 10;
            };
          };
        };
      };
    };

    # Mesh clustering
    mesh = {
      enable = true;
      clusterName = "prod-cluster";
      
      node = {
        roles = [ "controller" "worker" "storage" ];
        capabilities = {
          compute = {
            available = true;
            capacity = 10000;
            specializations = [ "gpu" "high-memory" ];
          };
          storage = {
            available = true;
            tiers = [ 0 1 2 3 ];
            capacity = "124Ti";
          };
          network = {
            gateway = true;
            bandwidth = "100Gbps";
            features = [ "sr-iov" "dpdk" "rdma" ];
          };
        };
        location = {
          zone = "dc-west-1a";
          rack = "A14";
          geo = {
            latitude = 37.7749;
            longitude = -122.4194;
            region = "us-west";
          };
        };
      };
      
      consensus = {
        algorithm = "raft";
        parameters.raft = {
          electionTimeout = 150;
          heartbeatInterval = 50;
          snapshotInterval = 10000;
        };
        quorum.size = 3;
      };
      
      topology = {
        mode = "partial-mesh";
        connections = {
          strategy = "latency-optimized";
          minPeers = 3;
          maxPeers = 7;
        };
        discovery = {
          method = "static";
          staticPeers = [
            "hyper-prod-02.example.com"
            "hyper-prod-03.example.com"
          ];
        };
      };
      
      coordination = {
        scheduler = {
          algorithm = "bin-packing";
          rebalancing = {
            enable = true;
            threshold = 0.2;
            interval = "15m";
          };
        };
        stateStore = {
          backend = "embedded";
          replication = 3;
          consistency = "linearizable";
        };
      };
      
      security = {
        encryption = {
          enable = true;
          algorithm = "chacha20-poly1305";
          keyRotation = "24h";
        };
        authentication = {
          method = "mutual-tls";
          ca = "/etc/hypervisor/ca.crt";
        };
      };
    };

    # Capability-based security
    security.capabilities = {
      # Define capabilities
      capabilities = {
        admin = {
          description = "Full administrative access";
          resources = {
            compute = {
              create = true;
              modify = true;
              delete = true;
              control = true;
              console = true;
            };
            storage = {
              read = true;
              write = true;
              allocate = true;
              snapshot = true;
              tiers = [ 0 1 2 3 ];
            };
            network = {
              configure = true;
              attach = true;
              create = true;
            };
            cluster = {
              join = true;
              configure = true;
              schedule = true;
            };
          };
          operations = [ "backup" "restore" "migrate" "monitor" ];
          delegation.allowed = true;
        };
        
        developer = {
          description = "Developer access";
          resources = {
            compute = {
              create = true;
              control = true;
              console = true;
              limits = {
                maxUnits = 10;
                maxResources = 4000;
              };
            };
            storage = {
              read = true;
              write = true;
              quota = "1Ti";
              tiers = [ 1 2 ];
            };
          };
          operations = [ "monitor" ];
        };
        
        operator = {
          description = "Operations team access";
          resources = {
            compute = {
              control = true;
              console = true;
            };
            storage = {
              read = true;
              snapshot = true;
            };
          };
          operations = [ "backup" "monitor" ];
        };
        
        auditor = {
          description = "Read-only audit access";
          resources = {
            compute = {};
            storage.read = true;
          };
          operations = [ "monitor" ];
        };
      };
      
      # Assign capabilities to principals
      principals = {
        # Admin user
        admin = {
          type = "user";
          identity = {
            id = "admin@example.com";
            attributes = {
              department = "infrastructure";
              clearance = "top-secret";
            };
            authentication = {
              methods = [ "publickey" "webauthn" ];
              mfa.required = true;
            };
          };
          grants = [{
            capability = "admin";
            temporal.validity.duration = "8h";
            temporal.emergency = {
              breakGlass = true;
              notificationList = [ "security@example.com" ];
            };
          }];
          audit.logLevel = "detailed";
        };
        
        # Development team
        dev-team = {
          type = "group";
          identity.id = "developers";
          grants = [{
            capability = "developer";
            temporal = {
              validity.duration = "12h";
              schedule = {
                timezone = "America/Los_Angeles";
                windows = [{
                  days = [ "monday" "tuesday" "wednesday" "thursday" "friday" ];
                  startTime = "08:00";
                  endTime = "20:00";
                }];
              };
              usage.rateLimit = {
                requests = 1000;
                window = "1h";
              };
            };
            scope = {
              labels = {
                environment = "development";
              };
            };
          }];
        };
        
        # CI/CD service account
        ci-service = {
          type = "service";
          identity = {
            id = "ci-pipeline";
            authentication.methods = [ "certificate" ];
          };
          grants = [{
            capability = "developer";
            temporal.validity.duration = "1h";
            scope.labels = {
              purpose = "ci-build";
            };
          }];
          audit = {
            logLevel = "full";
            alerts = [{
              event = "capability_abuse";
              notify = [ "security@example.com" ];
            }];
          };
        };
      };
      
      zeroTrust = {
        continuous = {
          verification = true;
          interval = "5m";
          factors = [ "device-trust" "location" "behavior" ];
        };
        contextual.ipRestrictions = [
          "10.0.0.0/8"
          "172.16.0.0/12"
        ];
      };
    };

    # Incremental forever backup
    backup = {
      repositories = {
        primary = {
          type = "local";
          backend = {
            location = "/backup/primary";
            encryption = {
              enabled = true;
              algorithm = "aes-256-gcm";
              keyDerivation = "argon2id";
            };
            compression = {
              algorithm = "zstd";
              level = 3;
              adaptive = true;
            };
          };
          deduplication = {
            enabled = true;
            algorithm = "content-defined";
            chunkSize = {
              min = 256;
              avg = 1024;
              max = 4096;
            };
            indexing = {
              type = "lsm-tree";
              cache = "2Gi";
              persistent = true;
            };
            similarity = {
              enabled = true;
              threshold = 0.8;
              algorithm = "minhash";
            };
          };
          retention = {
            mode = "progressive";
            progressive = {
              keepAll = 7;
              rules = [
                { age = "7d"; interval = "1h"; }
                { age = "30d"; interval = "6h"; }
                { age = "90d"; interval = "1d"; }
                { age = "365d"; interval = "1w"; }
                { age = "1825d"; interval = "1m"; }
              ];
            };
            immutable = {
              enabled = true;
              period = "30d";
            };
          };
          performance = {
            parallel = {
              streams = 8;
              chunkers = 4;
            };
            caching = {
              metadata = "512Mi";
              chunks = "4Gi";
            };
          };
        };
        
        offsite = {
          type = "remote";
          backend = {
            location = "s3://backup-bucket/hyper-nixos";
            encryption.enabled = true;
          };
          deduplication.enabled = true;
        };
      };
      
      sources = {
        all-compute = {
          type = "compute-unit";
          selection.labels = {};
          strategy = {
            mode = "incremental-forever";
            consistency = "application-consistent";
            preScript = ''
              # Notify applications
              curl -X POST http://localhost:9090/backup/prepare
            '';
            postScript = ''
              # Notify completion
              curl -X POST http://localhost:9090/backup/complete
            '';
          };
          schedule.continuous = true;
          dataHandling = {
            sensitivity = "confidential";
            compliance = [ "gdpr" "hipaa" ];
            geoRestrictions = [ "us" "eu" ];
          };
        };
        
        databases = {
          type = "application";
          selection.labels = {
            app = "postgresql";
          };
          strategy = {
            mode = "incremental-forever";
            consistency = "database-consistent";
            changeDetection = "journal";
          };
          schedule = {
            continuous = true;
            window = {
              start = "02:00";
              end = "06:00";
            };
          };
        };
      };
      
      fabric = {
        cdp = {
          enabled = true;
          journalSize = "50Gi";
          granularity = "1s";
        };
        globalDedup = {
          enabled = true;
          scope = "global";
          federation = [ "hyper-prod-02" "hyper-prod-03" ];
        };
        verification = {
          automatic = true;
          schedule = "daily";
          sampling = {
            rate = 0.1;
            full = "weekly";
          };
        };
      };
    };

    # Component composition
    composition = {
      components = {
        # Base OS components
        alpine-base = {
          type = "base";
          version = "3.18";
          properties = {
            description = "Alpine Linux base";
            compatibility.architectures = [ "x86_64" "aarch64" ];
          };
          configuration = {
            packages.install = [ "alpine-base" "openrc" ];
            files."/etc/apk/repositories".content = ''
              https://dl-cdn.alpinelinux.org/alpine/v3.18/main
              https://dl-cdn.alpinelinux.org/alpine/v3.18/community
            '';
          };
        };
        
        # Runtime components
        nodejs-20 = {
          type = "runtime";
          version = "20.10.0";
          properties = {
            compatibility.requires = [ "alpine-base" ];
            provides = [ "nodejs" "npm" ];
          };
          configuration = {
            packages.install = [ "nodejs" "npm" ];
            environment = {
              NODE_ENV = "production";
              NODE_OPTIONS = "--max-old-space-size=4096";
            };
          };
        };
        
        python-3-11 = {
          type = "runtime";
          version = "3.11.6";
          properties.provides = [ "python3" "pip3" ];
          configuration.packages.install = [ "python3" "py3-pip" ];
        };
        
        # Service components
        nginx-optimized = {
          type = "service";
          properties.provides = [ "webserver" "reverse-proxy" ];
          configuration = {
            packages.install = [ "nginx" ];
            ports = [
              { internal = 80; protocol = "tcp"; }
              { internal = 443; protocol = "tcp"; }
            ];
            files."/etc/nginx/nginx.conf".content = ''
              worker_processes auto;
              worker_rlimit_nofile 65535;
              events {
                worker_connections 4096;
                use epoll;
              }
              http {
                sendfile on;
                tcp_nopush on;
                tcp_nodelay on;
                keepalive_timeout 65;
                types_hash_max_size 2048;
              }
            '';
          };
        };
        
        postgresql-15 = {
          type = "service";
          properties = {
            provides = [ "database" "postgresql" ];
            requires = [ "alpine-base" ];
          };
          configuration = {
            packages.install = [ "postgresql15" "postgresql15-contrib" ];
            volumes = [{
              name = "pgdata";
              path = "/var/lib/postgresql/data";
              type = "persistent";
            }];
            environment = {
              POSTGRES_DB = "app";
              POSTGRES_USER = "app";
              PGDATA = "/var/lib/postgresql/data";
            };
            hooks.postInstall = ''
              postgresql-setup --initdb
              systemctl enable postgresql
            '';
          };
        };
        
        # Security components
        security-hardening = {
          type = "security";
          configuration = {
            files = {
              "/etc/security/limits.conf".content = ''
                * soft nofile 65535
                * hard nofile 65535
                * soft nproc 32768
                * hard nproc 32768
              '';
              "/etc/sysctl.d/99-security.conf".content = ''
                net.ipv4.tcp_syncookies = 1
                net.ipv4.conf.all.rp_filter = 1
                kernel.randomize_va_space = 2
              '';
            };
            hooks.configure = ''
              chmod 700 /root
              find /var/log -type f -exec chmod 640 {} \;
            '';
          };
        };
        
        # Monitoring components
        prometheus-exporter = {
          type = "monitoring";
          configuration = {
            packages.install = [ "prometheus-node-exporter" ];
            ports = [{ internal = 9100; }];
            hooks.postInstall = ''
              systemctl enable prometheus-node-exporter
            '';
          };
        };
      };
      
      # Blueprints
      blueprints = {
        web-app = {
          description = "Production web application stack";
          components = [
            { component = "alpine-base"; }
            { component = "nodejs-20"; }
            { component = "nginx-optimized"; }
            { component = "security-hardening"; }
            { component = "prometheus-exporter"; }
          ];
          parameters = {
            appName = {
              type = "string";
              description = "Application name";
            };
            domain = {
              type = "string";
              description = "Domain name";
            };
          };
          connections = [
            {
              from = "nginx-optimized.ports.80";
              to = "nodejs-20.ports.3000";
            }
          ];
        };
        
        database-server = {
          description = "PostgreSQL database server";
          components = [
            { component = "alpine-base"; }
            { component = "postgresql-15"; }
            { component = "security-hardening"; }
            { component = "prometheus-exporter"; }
          ];
          parameters = {
            dbName = {
              type = "string";
              default = "app";
            };
            maxConnections = {
              type = "integer";
              default = 200;
            };
          };
        };
        
        microservice = {
          description = "Microservice template";
          components = [
            { component = "alpine-base"; }
            {
              component = "python-3-11";
              condition = "runtime == 'python'";
            }
            {
              component = "nodejs-20";
              condition = "runtime == 'nodejs'";
            }
            { component = "security-hardening"; }
            { component = "prometheus-exporter"; }
          ];
          parameters = {
            runtime = {
              type = "string";
              validation = "runtime in ['python', 'nodejs']";
            };
            port = {
              type = "integer";
              default = 8080;
            };
          };
        };
      };
      
      # Instances
      instances = {
        frontend-1 = {
          blueprint = "web-app";
          parameters = {
            appName = "frontend";
            domain = "app.example.com";
          };
        };
        
        api-1 = {
          blueprint = "microservice";
          parameters = {
            runtime = "nodejs";
            port = 3001;
          };
        };
        
        db-1 = {
          blueprint = "database-server";
          parameters = {
            dbName = "production";
            maxConnections = 500;
          };
          placement.node = "hyper-prod-03";
        };
      };
    };

    # AI-driven monitoring
    monitoring.ai = {
      enable = true;
      
      models = {
        # Anomaly detection
        general-anomaly = {
          type = "isolation-forest";
          training = {
            dataSource = "prometheus";
            features = [
              "cpu_usage"
              "memory_usage"
              "disk_io_rate"
              "network_packets"
              "context_switches"
              "load_average"
            ];
            window = "14d";
            updateInterval = "daily";
            validation.splitRatio = 0.8;
          };
          parameters.isolationForest = {
            estimators = 200;
            contamination = 0.05;
          };
        };
        
        # Capacity prediction
        capacity-lstm = {
          type = "lstm";
          training = {
            features = [
              "cpu_usage"
              "memory_usage"
              "disk_usage"
              "network_bandwidth"
            ];
            window = "90d";
            updateInterval = "weekly";
          };
          parameters.lstm = {
            layers = [ 128 64 32 ];
            dropout = 0.3;
            lookback = 168;  # 7 days
            horizon = 168;   # 7 days ahead
          };
        };
        
        # Failure prediction
        disk-failure = {
          type = "gradient-boost";
          training = {
            features = [
              "smart_raw_read_error_rate"
              "smart_reallocated_sectors"
              "smart_spin_retry_count"
              "smart_temperature"
              "io_errors"
              "io_latency_p99"
            ];
            window = "180d";
          };
          inference.threshold = 0.8;
        };
        
        # Pattern clustering
        workload-patterns = {
          type = "clustering";
          training = {
            features = [
              "cpu_pattern"
              "memory_pattern"
              "io_pattern"
              "network_pattern"
            ];
            window = "30d";
          };
        };
      };
      
      rules = {
        # High severity anomalies
        critical-anomaly = {
          description = "Critical system anomaly";
          detection = {
            models = [ "general-anomaly" ];
            sensitivity = 0.9;
            persistence = 2;
          };
          patterns.temporal = [{
            name = "sudden-spike";
            type = "spike";
            parameters = {
              threshold = 3.0;  # 3x normal
              duration = "30s";
            };
          }];
          actions = {
            alert = {
              severity = "critical";
              channels = [ "pagerduty" "slack" ];
              cooldown = "30m";
            };
            analysis = {
              rootCause = true;
              impact = true;
            };
          };
        };
        
        # Capacity warnings
        capacity-warning = {
          description = "Capacity threshold approaching";
          detection = {
            models = [ "capacity-lstm" ];
            combineMode = "any";
          };
          actions = {
            alert = {
              severity = "warning";
              channels = [ "email" "slack" ];
            };
            autoRemediation = {
              enabled = true;
              actions = [{
                type = "scale";
                parameters = {
                  resource = "compute";
                  factor = 1.2;
                };
                confidence = 0.85;
              }];
              approval = "semi-automatic";
            };
          };
        };
        
        # Disk failure prediction
        disk-prefailure = {
          description = "Disk likely to fail soon";
          detection = {
            models = [ "disk-failure" ];
            sensitivity = 0.7;
          };
          actions = {
            alert = {
              severity = "error";
              channels = [ "email" "ticket" ];
            };
            autoRemediation = {
              enabled = true;
              actions = [{
                type = "migrate";
                parameters = {
                  evacuate = true;
                  priority = "high";
                };
                confidence = 0.9;
              }];
            };
          };
        };
      };
      
      prediction = {
        capacity = {
          enable = true;
          horizons = [ "1h" "6h" "24h" "7d" "30d" ];
          resources = [ "cpu" "memory" "disk" "network" ];
          confidence = 0.95;
        };
        failure = {
          enable = true;
          components = [ "disk" "memory" "network" "power" ];
          leadTime = "48h";
        };
        optimization = {
          enable = true;
          targets = [ "cost" "performance" "energy" ];
          constraints = {
            minPerformance = 0.9;
            maxCost = 10000;
          };
        };
      };
      
      pipeline = {
        ingestion.sources = [
          {
            name = "prometheus";
            type = "prometheus";
            endpoint = "http://localhost:9090";
            interval = "10s";
          }
          {
            name = "node-logs";
            type = "logs";
            endpoint = "/var/log/messages";
            interval = "1s";
          }
        ];
        storage = {
          backend = "timescaledb";
          retention = "180d";
        };
      };
      
      settings = {
        engine = "tensorflow";
        gpu = {
          enable = true;
          device = "cuda:0";
        };
        distributed = {
          enable = true;
          workers = 3;
        };
      };
    };
  };

  # System services
  services = {
    # GraphQL API
    nginx = {
      enable = true;
      virtualHosts."api.example.com" = {
        forceSSL = true;
        enableACME = true;
        locations."/graphql" = {
          proxyPass = "http://localhost:8081";
          proxyWebsockets = true;
        };
      };
    };
    
    # Monitoring
    prometheus = {
      enable = true;
      globalConfig = {
        scrape_interval = "10s";
        evaluation_interval = "10s";
      };
      scrapeConfigs = [
        {
          job_name = "hypervisor";
          static_configs = [{
            targets = [ "localhost:9100" ];
          }];
        }
      ];
    };
    
    grafana = {
      enable = true;
      provision = {
        enable = true;
        datasources = [{
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
        }];
      };
    };
  };

  # Networking
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 8081 9090 3000 ];
    };
    
    # High-performance networking
    interfaces.bond0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "10.0.0.10";
        prefixLength = 24;
      }];
    };
  };

  # Boot configuration
  boot = {
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
      "hugepages=1024"
      "transparent_hugepage=never"
    ];
    
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.dirty_ratio" = 10;
      "vm.dirty_background_ratio" = 5;
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
    };
  };

  # This value determines the NixOS release
  system.stateVersion = "24.05";
}