{ config, lib, pkgs, ... }:

# Optimized Hyper-NixOS System Configuration
# Implements performance, security, and maintainability improvements

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault types optionals;
  cfg = config.hypervisor.optimized;

  # Custom packages - built from local source when available
  # These are commented out until the source code is complete

  # Rust hypervisor-lib: Core library for system operations
  # Requires: tools/rust-lib/Cargo.lock (now generated)
  # Blocked by: libvirt-sys build requirements
  # hypervisor-lib = pkgs.rustPlatform.buildRustPackage {
  #   pname = "hypervisor-lib";
  #   version = "0.1.0";
  #   src = ../../tools/rust-lib;
  #   cargoLock.lockFile = ../../tools/rust-lib/Cargo.lock;
  #   meta.broken = !pkgs.stdenv.hostPlatform.isLinux;
  # };

  # Go hypervisor-api: REST API server
  # Internal packages now implemented - build enabled
  hypervisor-api = pkgs.buildGoModule {
    pname = "hypervisor-api";
    version = "2.0.0";
    src = ../../api;
    vendorHash = null;  # Use Go module proxy

    # CGO required for sqlite
    CGO_ENABLED = 1;
    nativeBuildInputs = [ pkgs.gcc ];
    buildInputs = [ pkgs.sqlite ];

    # Build tags
    tags = [ "sqlite" ];

    meta = {
      description = "Hyper-NixOS REST API server";
      homepage = "https://github.com/MasterofNull/Hyper-NixOS";
      license = pkgs.lib.licenses.mit;
      mainProgram = "api";
    };
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

      vaultSeal = mkOption {
        type = types.enum [ "shamir" "transit" "awskms" "gcpckms" "azurekeyvault" ];
        default = "shamir";
        description = ''
          Vault seal mechanism:
          - shamir: Default Shamir's Secret Sharing (requires manual unseal)
          - transit: Auto-unseal using another Vault's transit engine
          - awskms: Auto-unseal using AWS KMS
          - gcpckms: Auto-unseal using Google Cloud KMS
          - azurekeyvault: Auto-unseal using Azure Key Vault

          Note: Auto-unseal methods require additional configuration via
          environment variables or external secret injection.
        '';
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
    environment.systemPackages = [
      # Core tools (Rust-based)
      # hypervisor-lib  # Disabled until libvirt build issues resolved
      pkgs.bat              # Better cat
      pkgs.eza              # Better ls (exa is deprecated)
      pkgs.ripgrep          # Better grep
      pkgs.fd               # Better find
      pkgs.tokei            # Code statistics
      pkgs.hyperfine        # Benchmarking

      # Go tools
      hypervisor-api        # REST API server
      
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
    # Note: hypervisor-api and hypervisor-metrics services are disabled
    # until the Go and Rust packages are fully buildable
    systemd.services = {
      # Hypervisor API service (placeholder - requires internal packages)
      # hypervisor-api = {
      #   description = "Hyper-NixOS API Server";
      #   after = [ "network.target" "libvirtd.service" ];
      #   wantedBy = [ "multi-user.target" ];
      #   serviceConfig = {
      #     Type = "notify";
      #     TimeoutStartSec = "60s";
      #     ExecStart = "${hypervisor-api}/bin/hypervisor-api";
      #     Restart = "always";
      #     RestartSec = 5;
      #     CPUSchedulingPolicy = "fifo";
      #     CPUSchedulingPriority = 50;
      #     IOSchedulingClass = "realtime";
      #     IOSchedulingPriority = 0;
      #     User = "hypervisor-api";
      #     Group = "hypervisor-api";
      #     NoNewPrivileges = true;
      #     PrivateTmp = true;
      #     ProtectSystem = "strict";
      #     ProtectHome = true;
      #     ReadWritePaths = [ "/var/lib/hypervisor" ];
      #     LimitNOFILE = 65536;
      #     LimitNPROC = 4096;
      #     MemoryHigh = "2G";
      #     MemoryMax = "4G";
      #     CPUQuota = "200%";
      #   };
      #   environment = {
      #     HYPERVISOR_CONFIG = "${configFile}";
      #     RUST_LOG = "info";
      #     GOMAXPROCS = "4";
      #   };
      # };

      # Metrics collector (placeholder - requires hypervisor-lib build)
      # hypervisor-metrics = {
      #   description = "Hyper-NixOS Metrics Collector";
      #   after = [ "libvirtd.service" ];
      #   wantedBy = [ "multi-user.target" ];
      #   serviceConfig = {
      #     Type = "simple";
      #     ExecStart = "${hypervisor-lib}/bin/hypervisor-metrics";
      #     Restart = "always";
      #     Nice = 10;
      #     IOSchedulingClass = "idle";
      #     CPUQuota = "20%";
      #   };
      # };
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
    };
    
    # HashiCorp Vault (optional)
    services.vault = mkIf cfg.security.enableVault {
      enable = true;
      package = pkgs.vault-bin;

      storageBackend = "file";
      storagePath = "/var/lib/vault";

      # Seal mechanism is configured via vaultSeal option
      # Shamir (default): No additional config needed, manual unseal required
      # Auto-unseal: Requires environment variables for cloud provider credentials
      extraConfig = ''
        ui = true

        listener "tcp" {
          address = "127.0.0.1:8200"
          tls_disable = 1
        }

        ${if cfg.security.vaultSeal == "shamir" then ''
          # Using default Shamir seal - manual unseal required after restart
          # Run: vault operator init (first time) / vault operator unseal (restarts)
        '' else if cfg.security.vaultSeal == "transit" then ''
          seal "transit" {
            address = "https://vault.example.com:8200"
            # token and key_name provided via VAULT_TOKEN and transit mount
          }
        '' else if cfg.security.vaultSeal == "awskms" then ''
          seal "awskms" {
            # Requires AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
            # kms_key_id provided via VAULT_AWSKMS_SEAL_KEY_ID
          }
        '' else if cfg.security.vaultSeal == "gcpckms" then ''
          seal "gcpckms" {
            # Requires GOOGLE_APPLICATION_CREDENTIALS
            # project, region, key_ring, crypto_key provided via env vars
          }
        '' else if cfg.security.vaultSeal == "azurekeyvault" then ''
          seal "azurekeyvault" {
            # Requires AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET
            # vault_name and key_name provided via env vars
          }
        '' else ""}
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
