{ config, lib, pkgs, ... }:

# Optimized Hyper-NixOS System Configuration
# Implements performance, security, and maintainability improvements

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.optimized;
  
  # Custom packages
  hypervisor-lib = pkgs.rustPlatform.buildRustPackage {
    pname = "hypervisor-lib";
    version = "0.1.0";
    src = ../../tools/rust-lib;
    cargoLock.lockFile = ../../tools/rust-lib/Cargo.lock;
  };
  
  hypervisor-api = pkgs.buildGoModule {
    pname = "hypervisor-api";
    version = "2.0.0";
    src = ../../api;
    vendorSha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
  };
  
  # Configuration
  configFile = pkgs.writeText "hypervisor.toml" (builtins.readFile ../../config/hypervisor.toml);
in
{
  options.hypervisor.optimized = {
    enable = mkEnableOption "Enable optimized Hyper-NixOS stack";
    
    performance = {
      enableHugepages = mkOption {
        type = types.bool;
        default = true;
        description = "Enable transparent hugepages for better VM performance";
      };
      
      cpuGovernor = mkOption {
        type = types.enum [ "performance" "powersave" "ondemand" "conservative" ];
        default = "performance";
        description = "CPU frequency governor";
      };
      
      ioScheduler = mkOption {
        type = types.enum [ "none" "mq-deadline" "bfq" "kyber" ];
        default = "none";
        description = "I/O scheduler for NVMe/SSD";
      };
    };
    
    security = {
      enableVault = mkOption {
        type = types.bool;
        default = false;
        description = "Enable HashiCorp Vault for secrets management";
      };
      
      enableFIPS = mkOption {
        type = types.bool;
        default = false;
        description = "Enable FIPS 140-2 compliance mode";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # System packages
    environment.systemPackages =  [
      # Core tools (Rust-based)
    pkgs.hypervisor-lib
    pkgs.bat              # Better cat
    pkgs.exa              # Better ls
    pkgs.ripgrep          # Better grep
    pkgs.fd               # Better find
    pkgs.tokei            # Code statistics
    pkgs.hyperfine        # Benchmarking
      
      # Go tools
    pkgs.hypervisor-api
      
      # Development tools
    pkgs.rustup
    pkgs.go
    pkgs.nodejs
      
      # System tools
    pkgs.htop
    pkgs.iotop
    pkgs.iftop
    pkgs.nethogs
    pkgs.sysstat
    pkgs.dstat
      
      # Security tools
    pkgs.vault-bin
    pkgs.age
    pkgs.sops
      
      # Container tools
    pkgs.podman
    pkgs.buildah
    pkgs.skopeo
      
      # Monitoring
    pkgs.prometheus
    pkgs.grafana
    pkgs.loki
    pkgs.promtail
    ];
    
    # Performance optimizations
    boot.kernelParams = [
      "mitigations=off"  # Disable CPU vulnerability mitigations for performance
      "transparent_hugepage=always"
      "intel_pstate=disable"  # For manual CPU governor control
    ] ++ optionals cfg.performance.enableHugepages [
      "hugepagesz=2M"
      "hugepages=1024"
    ];
    
    # CPU governor
    powerManagement.cpuFreqGovernor = cfg.performance.cpuGovernor;
    
    # I/O scheduler
    services.udev.extraRules = ''
      # Set I/O scheduler for NVMe devices
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="${cfg.performance.ioScheduler}"
      # Set I/O scheduler for SATA SSDs
      ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="${cfg.performance.ioScheduler}"
    '';
    
    # Kernel parameters optimization
    boot.kernel.sysctl = {
      # Network performance
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.ipv4.tcp_rmem" = "4096 87380 134217728";
      "net.ipv4.tcp_wmem" = "4096 65536 134217728";
      "net.core.netdev_max_backlog" = 5000;
      "net.ipv4.tcp_congestion" = "bbr";
      "net.core.default_qdisc" = "fq";
      
      # VM performance
      "vm.swappiness" = 10;
      "vm.dirty_ratio" = 15;
      "vm.dirty_background_ratio" = 5;
      "vm.vfs_cache_pressure" = 50;
      
      # File system
      "fs.file-max" = 2097152;
      "fs.inotify.max_user_watches" = 524288;
    };
    
    # Systemd optimizations
    systemd.services = {
      # Hypervisor API service
      hypervisor-api = {
        description = "Hyper-NixOS API Server";
        after = [ "network.target" "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          Type = "notify";
          ExecStart = "${hypervisor-api}/bin/hypervisor-api";
          Restart = "always";
          RestartSec = 5;
          
          # Performance
          CPUSchedulingPolicy = "fifo";
          CPUSchedulingPriority = 50;
          IOSchedulingClass = "realtime";
          IOSchedulingPriority = 0;
          
          # Security
          User = "hypervisor-api";
          Group = "hypervisor-api";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ "/var/lib/hypervisor" ];
          
          # Resource limits
          LimitNOFILE = 65536;
          LimitNPROC = 4096;
          MemoryHigh = "2G";
          MemoryMax = "4G";
          CPUQuota = "200%";
        };
        
        environment = {
          HYPERVISOR_CONFIG = "${configFile}";
          RUST_LOG = "info";
          GOMAXPROCS = "4";
        };
      };
      
      # Metrics collector
      hypervisor-metrics = {
        description = "Hyper-NixOS Metrics Collector";
        after = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          Type = "simple";
          ExecStart = "${hypervisor-lib}/bin/hypervisor-metrics";
          Restart = "always";
          
          # Low priority background service
          Nice = 10;
          IOSchedulingClass = "idle";
          CPUQuota = "20%";
        };
      };
    };
    
    # Users and groups
    users.users.hypervisor-api = {
      isSystemUser = true;
      group = "hypervisor-api";
      extraGroups = [ "libvirtd" "kvm" ];
    };
    users.groups.hypervisor-api = {};
    
    # VictoriaMetrics for efficient metrics storage
    services.victoriametrics = {
      enable = true;
      retentionPeriod = "12";  # months
      extraOptions = [
        "-storageDataPath=/var/lib/victoriametrics"
        "-httpListenAddr=:8428"
        "-promscrape.config=${./prometheus.yml}"
      ];
    };
    
    # NATS for event streaming
    services.nats = {
      enable = true;
      serverName = "hypervisor-nats";
      jetstream = true;
      
      settings = {
        max_connections = 1000;
        max_payload = "8MB";
        
        jetstream = {
          store_dir = "/var/lib/nats/jetstream";
          max_memory_store = "1GB";
          max_file_store = "10GB";
        };
        
        cluster = {
          name = "hypervisor-cluster";
          routes = [];
        };
      };
    };
    
    # Podman for containers
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      
      defaultNetwork.settings = {
        dns_enabled = true;
        ipv6_enabled = true;
      };
      
      # Enable rootless containers
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
    
    # HashiCorp Vault (optional)
    services.vault = mkIf cfg.security.enableVault {
      enable = true;
      package = pkgs.vault-bin;
      
      storageBackend = "file";
      storagePath = "/var/lib/vault";
      
      # Development mode for now
      # TODO: Configure proper seal mechanism
      extraConfig = ''
        ui = true
        
        listener "tcp" {
          address = "127.0.0.1:8200"
          tls_disable = 1
        }
      '';
    };
    
    # Firewall rules
    networking.firewall = {
      allowedTCPPorts = [
        8080  # API
        8428  # VictoriaMetrics
        9090  # Prometheus compatible endpoint
      ];
      
      # Internal services only
      interfaces."lo".allowedTCPPorts = [
        4222  # NATS
        8200  # Vault
      ];
    };
    
    # Logging configuration
    services.journald.extraConfig = ''
      SystemMaxUse=1G
      SystemKeepFree=2G
      MaxRetentionSec=1month
      ForwardToSyslog=no
      Compress=yes
    '';
    
    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor 0750 root libvirtd - -"
      "d /var/log/hypervisor 0750 root libvirtd - -"
      "f ${configFile} 0640 root libvirtd - -"
    ];
  };
}