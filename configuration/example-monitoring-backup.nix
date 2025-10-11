{ config, lib, pkgs, ... }:
{
  # Example configuration enabling monitoring and backup features
  # Copy this to /var/lib/hypervisor/configuration/monitoring-local.nix to enable
  
  # Enable Prometheus monitoring stack
  hypervisor.monitoring = {
    enablePrometheus = true;
    enableGrafana = true;
    enableAlertmanager = true;
    prometheusPort = 9090;
    grafanaPort = 3000;
  };
  
  # Enable automated backups
  hypervisor.backup = {
    enable = true;
    schedule = "daily";  # or "weekly", or systemd calendar format like "*-*-* 02:00:00"
    retention = {
      daily = 7;     # Keep 7 daily backups
      weekly = 4;    # Keep 4 weekly backups
      monthly = 3;   # Keep 3 monthly backups
    };
    destination = "/var/lib/hypervisor/backups";
    encrypt = true;       # GPG encrypt backups
    compression = "zstd"; # Fast compression with good ratio
  };
  
  # Optional: Open Grafana port for remote access (be careful!)
  # networking.firewall.allowedTCPPorts = [ 3000 ];
  
  # Optional: Configure email alerts
  # services.prometheus.alertmanager.configuration.receivers = [
  #   {
  #     name = "default";
  #     email_configs = [{
  #       to = "admin@example.com";
  #       from = "hypervisor@example.com";
  #       smarthost = "smtp.example.com:587";
  #       auth_username = "hypervisor@example.com";
  #       auth_password = "password";
  #     }];
  #   }
  # ];
}