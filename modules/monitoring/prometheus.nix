{ config, lib, pkgs, ... }:
{
  # Note: All options are now centralized in modules/core/options.nix

  config = lib.mkMerge [
    (lib.mkIf config.hypervisor.monitoring.enablePrometheus {
      # Prometheus for metrics collection
      services.prometheus = {
        enable = true;
        port = config.hypervisor.monitoring.prometheusPort;
        
        exporters = {
          # Efficiency: Only enable essential collectors by default
          node = {
            enable = true;
            enabledCollectors = [ 
              "systemd" "processes" "loadavg" "meminfo" 
              "netstat" "diskstats" "filesystem" "hwmon" "cpu"
            ];
          };
          
          # Efficiency: Optimized libvirt exporter with reduced overhead
          script = {
            enable = true;
            scriptPath = pkgs.writeShellScript "libvirt-exporter" ''
              #!/usr/bin/env bash
              # Security: Strict error handling
              set -euo pipefail
              
              # Efficiency: Single virsh call to get all domain info
              echo "# HELP libvirt_domain_state Domain state (1=running, 0=other)"
              echo "# TYPE libvirt_domain_state gauge"
              echo "# HELP libvirt_domain_vcpu_count Number of vCPUs"
              echo "# TYPE libvirt_domain_vcpu_count gauge"
              echo "# HELP libvirt_domain_memory_mb Memory in MB"
              echo "# TYPE libvirt_domain_memory_mb gauge"
              
              # Efficiency: Batch processing to reduce virsh calls
              virsh list --all --name 2>/dev/null | while IFS= read -r domain; do
                [[ -z "$domain" ]] && continue
                # Efficiency: Single dominfo call instead of multiple commands
                info=$(virsh dominfo "$domain" 2>/dev/null || continue)
                state=$(echo "$info" | awk '/^State:/ {print $2}')
                running=0
                [[ "$state" == "running" ]] && running=1
                echo "libvirt_domain_state{domain=\"$domain\"} $running"
                
                # Only get details for running VMs to reduce overhead
                if [[ "$running" == "1" ]]; then
                  vcpus=$(echo "$info" | awk '/^CPU\(s\):/ {print $2}')
                  memory=$(echo "$info" | awk '/^Max memory:/ {print $3}')
                  echo "libvirt_domain_vcpu_count{domain=\"$domain\"} ${vcpus:-0}"
                  echo "libvirt_domain_memory_mb{domain=\"$domain\"} ${memory:-0}"
                fi
              done
            '';
          };
        };
        
        scrapeConfigs = [
          {
            job_name = "hypervisor";
            static_configs = [{
              targets = [ 
                "localhost:${toString config.services.prometheus.exporters.node.port}"
                "localhost:${toString config.services.prometheus.exporters.script.port}"
              ];
            }];
          }
        ];
        
        # Alert rules
        ruleFiles = [ 
          (pkgs.writeText "hypervisor-alerts.yml" ''
            groups:
              - name: hypervisor
                rules:
                  - alert: HighCPUUsage
                    expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
                    for: 10m
                    labels:
                      severity: warning
                    annotations:
                      summary: "High CPU usage detected"
                      description: "CPU usage is above 90% for more than 10 minutes"
                  
                  - alert: HighMemoryUsage
                    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
                    for: 10m
                    labels:
                      severity: warning
                    annotations:
                      summary: "High memory usage detected"
                      description: "Memory usage is above 90% for more than 10 minutes"
                  
                  - alert: DiskSpaceLow
                    expr: (node_filesystem_avail_bytes{mountpoint="/var/lib/hypervisor"} / node_filesystem_size_bytes{mountpoint="/var/lib/hypervisor"}) * 100 < 10
                    for: 5m
                    labels:
                      severity: critical
                    annotations:
                      summary: "Low disk space on hypervisor storage"
                      description: "Less than 10% disk space remaining on /var/lib/hypervisor"
                  
                  - alert: VMDown
                    expr: libvirt_domain_state == 0
                    for: 5m
                    labels:
                      severity: warning
                    annotations:
                      summary: "VM {{ $labels.domain }} is down"
                      description: "Virtual machine {{ $labels.domain }} has been down for more than 5 minutes"
          '')
        ];
      };
      
      # Open firewall for Prometheus (localhost only by default)
      networking.firewall.interfaces."lo".allowedTCPPorts = lib.mkAfter [ 
        config.hypervisor.monitoring.prometheusPort 
      ];
    })
    
    (lib.mkIf config.hypervisor.monitoring.enableGrafana {
      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_port = config.hypervisor.monitoring.grafanaPort;
            http_addr = "127.0.0.1";
          };
          security = {
            admin_user = "admin";
            admin_password = "$__file{/var/lib/hypervisor/secrets/grafana-admin-password}";
          };
          analytics.reporting_enabled = false;
        };
        
        provision = {
          enable = true;
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://localhost:${toString config.hypervisor.monitoring.prometheusPort}";
              isDefault = true;
            }
          ];
          
          dashboards.settings.providers = [
            {
              name = "Hypervisor Dashboards";
              folder = "Hypervisor";
              type = "file";
              options.path = pkgs.linkFarm "grafana-dashboards" [
                {
                  name = "hypervisor-overview.json";
                  path = pkgs.writeText "hypervisor-overview.json" (builtins.toJSON {
                    # Simplified dashboard definition
                    uid = "hypervisor-overview";
                    title = "Hypervisor Overview";
                    panels = [
                      {
                        title = "CPU Usage";
                        targets = [{
                          expr = ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
                        }];
                      }
                      {
                        title = "Memory Usage";
                        targets = [{
                          expr = ''(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'';
                        }];
                      }
                      {
                        title = "Running VMs";
                        targets = [{
                          expr = ''sum(libvirt_domain_state)'';
                        }];
                      }
                    ];
                  });
                }
              ];
            }
          ];
        };
      };
      
      # Ensure secrets directory exists
      systemd.tmpfiles.rules = [
        "d /var/lib/hypervisor/secrets 0700 root root - -"
      ];
      
      # Generate default Grafana password if not exists
      system.activationScripts.grafanaPassword = ''
        if [ ! -f /var/lib/hypervisor/secrets/grafana-admin-password ]; then
          ${pkgs.openssl}/bin/openssl rand -base64 32 > /var/lib/hypervisor/secrets/grafana-admin-password
          chmod 600 /var/lib/hypervisor/secrets/grafana-admin-password
        fi
      '';
    })
    
    (lib.mkIf config.hypervisor.monitoring.enableAlertmanager {
      services.prometheus.alertmanager = {
        enable = true;
        configuration = {
          route = {
            group_by = [ "alertname" "severity" ];
            group_wait = "10s";
            group_interval = "10m";
            repeat_interval = "1h";
            receiver = "default";
          };
          receivers = [
            {
              name = "default";
              # Configure email/webhook/etc notifications here
            }
          ];
        };
      };
    })
  ];
}