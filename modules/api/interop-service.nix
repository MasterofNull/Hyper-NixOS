# Interoperability API Service Module
{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.interop;
  
  # Build the Go service
  interopService = pkgs.buildGoModule {
    pname = "hv-interop";
    version = "2.0.0";
    
    src = ../../api/interop;
    
    vendorSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    
    meta = {
      description = "Hyper-NixOS Interoperability API Service";
      license = lib.licenses.asl20;
    };
  };
  
  apiStyleType = lib.types.enum [
    "native"
    "enterprise-virt-v2"
    "libvirt"
    "occi"
    "openstack"
    "vmware"
  ];
in
{
  options.hypervisor.interop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the interoperability API service";
    };
    
    apiStyle = lib.mkOption {
      type = apiStyleType;
      default = "native";
      description = ''
        API style to use. Determines which virtualization platform's API to emulate.
        Options:
        - native: Native Hyper-NixOS API
        - enterprise-virt-v2: Enterprise virtualization platform compatible
        - libvirt: libvirt/virsh compatible
        - occi: Open Cloud Computing Interface
        - openstack: OpenStack Nova/Cinder compatible
        - vmware: VMware vSphere compatible
      '';
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
    
    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind to";
    };
    
    enableTLS = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable TLS/HTTPS";
    };
    
    tlsCert = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to TLS certificate";
    };
    
    tlsKey = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to TLS private key";
    };
    
    authentication = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable authentication";
      };
      
      backend = lib.mkOption {
        type = lib.types.enum [ "local" "ldap" "oauth2" ];
        default = "local";
        description = "Authentication backend to use";
      };
      
      localUsers = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            passwordHash = lib.mkOption {
              type = lib.types.str;
              description = "Hashed password (use mkpasswd)";
            };
            roles = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "user" ];
              description = "User roles";
            };
          };
        });
        default = {};
        description = "Local user definitions";
      };
    };
    
    cors = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable CORS headers";
      };
      
      allowedOrigins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "*" ];
        description = "Allowed CORS origins";
      };
    };
    
    rateLimit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable rate limiting";
      };
      
      requestsPerMinute = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Maximum requests per minute per IP";
      };
    };
    
    metrics = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Prometheus metrics endpoint";
      };
      
      path = lib.mkOption {
        type = lib.types.str;
        default = "/metrics";
        description = "Metrics endpoint path";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enableTLS -> (cfg.tlsCert != null && cfg.tlsKey != null);
        message = "TLS certificate and key must be provided when TLS is enabled";
      }
    ];
    
    # Create systemd service
    systemd.services.hv-interop = {
      description = "Hyper-NixOS Interoperability API Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      environment = {
        API_STYLE = cfg.apiStyle;
        API_PORT = toString cfg.port;
        API_BIND = cfg.bindAddress;
        API_TLS_ENABLED = if cfg.enableTLS then "true" else "false";
        API_TLS_CERT = lib.mkIf cfg.enableTLS cfg.tlsCert;
        API_TLS_KEY = lib.mkIf cfg.enableTLS cfg.tlsKey;
        API_AUTH_ENABLED = if cfg.authentication.enable then "true" else "false";
        API_AUTH_BACKEND = cfg.authentication.backend;
        API_CORS_ENABLED = if cfg.cors.enable then "true" else "false";
        API_METRICS_ENABLED = if cfg.metrics.enable then "true" else "false";
      };
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${interopService}/bin/hv-interop";
        Restart = "always";
        RestartSec = 5;
        
        # Security settings
        User = "hv-interop";
        Group = "hv-interop";
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        
        # Capabilities
        AmbientCapabilities = [];
        CapabilityBoundingSet = [];
        
        # System call filtering
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
      };
    };
    
    # Firewall rules
    networking.firewall = lib.mkIf (cfg.bindAddress != "127.0.0.1") {
      allowedTCPPorts = [ cfg.port ];
    };
    
    # Nginx reverse proxy (optional)
    services.nginx = lib.mkIf (config.services.nginx.enable && cfg.enableTLS) {
      virtualHosts."hv-api" = {
        serverName = config.networking.hostName;
        listen = [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        
        sslCertificate = cfg.tlsCert;
        sslCertificateKey = cfg.tlsKey;
        
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };
    
    # Create configuration file
    environment.etc."hypervisor/interop/config.json" = {
      mode = "0640";
      text = builtins.toJSON {
        api_style = cfg.apiStyle;
        port = cfg.port;
        bind = cfg.bindAddress;
        tls = {
          enabled = cfg.enableTLS;
          cert = cfg.tlsCert;
          key = cfg.tlsKey;
        };
        auth = {
          enabled = cfg.authentication.enable;
          backend = cfg.authentication.backend;
          users = cfg.authentication.localUsers;
        };
        cors = {
          enabled = cfg.cors.enable;
          origins = cfg.cors.allowedOrigins;
        };
        rate_limit = {
          enabled = cfg.rateLimit.enable;
          rpm = cfg.rateLimit.requestsPerMinute;
        };
        metrics = {
          enabled = cfg.metrics.enable;
          path = cfg.metrics.path;
        };
      };
    };
  };
}