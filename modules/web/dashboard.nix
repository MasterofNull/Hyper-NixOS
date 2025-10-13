{ config, lib, pkgs, ... }:

# Web Dashboard Configuration
# Lightweight web interface for VM management

let
  # Provide a Python interpreter with required packages
  py = pkgs.python3.withPackages (ps: [ ps.flask ps.requests ]);
in
{
  config = lib.mkIf config.hypervisor.web.enable {
    # Runtime user for the web dashboard (non-login)
    # Note: hypervisor-operator user is defined in security-production.nix
    # Ensure the user has the necessary group memberships for web dashboard
    users.users.hypervisor-operator.extraGroups = lib.mkAfter [ "libvirtd" "kvm" ];
  
    # Web dashboard service
    systemd.services.hypervisor-web-dashboard = {
    description = "Hyper-NixOS Web Dashboard";
    after = [ "network.target" "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${py}/bin/python3 /etc/hypervisor/scripts/web_dashboard.py";
      
      # Run as operator user for security (defined in security-production.nix)
      User = "hypervisor-operator";
      
      # Security hardening
      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      PrivateTmp = true;
      ReadWritePaths = [
        "/var/lib/hypervisor"
        "/var/lib/libvirt"
      ];
      ReadOnlyPaths = [
        "/etc/hypervisor"
      ];
      
      # Network access needed
      PrivateNetwork = false;
      
      # Restart on failure
      Restart = "on-failure";
      RestartSec = "10s";
      
      # Capabilities
      NoNewPrivileges = true;
      
      StandardOutput = "journal";
      StandardError = "journal";
    };
    };
    
    # Create web directory structure
    systemd.tmpfiles.rules = [
    "d /var/www/hypervisor 0755 root root - -"
    "d /var/www/hypervisor/templates 0755 root root - -"
    "d /var/www/hypervisor/static 0755 root root - -"
    ];
    
    # Install template to the Flask template directory
    environment.etc."var/www/hypervisor/templates/dashboard.html" = {
    source = ../../web/templates/dashboard.html;
    mode = "0644";
    };
    
    # Firewall: Allow web dashboard on localhost only by default
    # For external access, use nginx/apache reverse proxy with authentication
    networking.firewall.interfaces."lo".allowedTCPPorts = [ config.hypervisor.web.port ];
    
    # Optional: Nginx reverse proxy with authentication
    # Uncomment to enable external access with password protection
    /*
    services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    
    virtualHosts."hypervisor.local" = {
      listen = [{ addr = "0.0.0.0"; port = 443; ssl = true; }];
      sslCertificate = "/path/to/cert.pem";
      sslCertificateKey = "/path/to/key.pem";
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        basicAuth = {
          "admin" = "hashed-password";  # Generate with: htpasswd -nb admin password
        };
      };
    };
    };
    */
  };
}
