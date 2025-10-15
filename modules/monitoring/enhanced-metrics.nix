# Enhanced Monitoring Integration - Enterprise Observability
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.monitoring;
  
  # Metric collection options
  metricsOptions = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable metrics collection";
      };
      
      retention = mkOption {
        type = types.str;
        default = "1y";
        description = "Metrics retention period";
      };
      
      interval = mkOption {
        type = types.int;
        default = 15;
        description = "Collection interval in seconds";
      };
      
      # RRD-style graphs (enterprise-compatible)
      graphs = {
        cpu = mkOption {
          type = types.bool;
          default = true;
          description = "Enable CPU usage graphs";
        };
        
        memory = mkOption {
          type = types.bool;
          default = true;
          description = "Enable memory usage graphs";
        };
        
        network = mkOption {
          type = types.bool;
          default = true;
          description = "Enable network I/O graphs";
        };
        
        disk = mkOption {
          type = types.bool;
          default = true;
          description = "Enable disk I/O graphs";
        };
        
        custom = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Custom graph definitions";
        };
      };
      
      # Aggregation levels
      aggregation = {
        "1min" = mkOption {
          type = types.int;
          default = 60;
          description = "1-minute aggregation samples";
        };
        
        "5min" = mkOption {
          type = types.int;
          default = 288;
          description = "5-minute aggregation samples";
        };
        
        "1hour" = mkOption {
          type = types.int;
          default = 168;
          description = "1-hour aggregation samples";
        };
        
        "1day" = mkOption {
          type = types.int;
          default = 365;
          description = "1-day aggregation samples";
        };
      };
    };
  };
  
  # External exporter options
  exporterOptions = {
    options = {
      influxdb = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable InfluxDB export";
        };
        
        endpoint = mkOption {
          type = types.str;
          default = "http://localhost:8086";
          description = "InfluxDB endpoint";
        };
        
        database = mkOption {
          type = types.str;
          default = "hypervisor";
          description = "InfluxDB database name";
        };
        
        username = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "InfluxDB username";
        };
        
        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File containing InfluxDB password";
        };
        
        retentionPolicy = mkOption {
          type = types.str;
          default = "autogen";
          description = "InfluxDB retention policy";
        };
      };
      
      prometheus = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Prometheus metrics endpoint";
        };
        
        port = mkOption {
          type = types.port;
          default = 9100;
          description = "Prometheus metrics port";
        };
        
        path = mkOption {
          type = types.str;
          default = "/metrics";
          description = "Metrics endpoint path";
        };
      };
      
      graphite = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Graphite export";
        };
        
        host = mkOption {
          type = types.str;
          default = "localhost";
          description = "Graphite host";
        };
        
        port = mkOption {
          type = types.port;
          default = 2003;
          description = "Graphite port";
        };
        
        prefix = mkOption {
          type = types.str;
          default = "hypervisor";
          description = "Metric prefix";
        };
      };
    };
  };
  
  # Alert rule options
  alertRuleOptions = {
    options = {
      condition = mkOption {
        type = types.str;
        description = "Alert condition (PromQL expression)";
      };
      
      duration = mkOption {
        type = types.str;
        default = "5m";
        description = "Duration condition must be true";
      };
      
      severity = mkOption {
        type = types.enum [ "info" "warning" "critical" ];
        default = "warning";
        description = "Alert severity";
      };
      
      annotations = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Alert annotations";
      };
      
      labels = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional alert labels";
      };
    };
  };
  
  # Generate Prometheus configuration
  generatePrometheusConfig = ''
    global:
      scrape_interval: ${toString cfg.metrics.interval}s
      evaluation_interval: ${toString cfg.metrics.interval}s
      external_labels:
        monitor: 'hypervisor'
        
    # Alerting
    alerting:
      alertmanagers:
        - static_configs:
            - targets: ['localhost:9093']
    
    # Rule files
    rule_files:
      - '/etc/prometheus/rules/*.yml'
    
    # Scrape configurations
    scrape_configs:
      # Hypervisor metrics
      - job_name: 'hypervisor'
        static_configs:
          - targets: ['localhost:${toString cfg.exporters.prometheus.port}']
      
      # Node exporter
      - job_name: 'node'
        static_configs:
          - targets: ['localhost:9100']
      
      # Libvirt exporter
      - job_name: 'libvirt'
        static_configs:
          - targets: ['localhost:9177']
      
      # VM guest agents
      - job_name: 'vm-guests'
        file_sd_configs:
          - files:
              - '/etc/prometheus/vm-targets.json'
        relabel_configs:
          - source_labels: [__address__]
            target_label: instance
            regex: '([^:]+).*'
      
      ${optionalString cfg.cluster.enable ''
      # Cluster nodes
      - job_name: 'cluster-nodes'
        static_configs:
          ${concatMapStringsSep "\n" (node: ''
          - targets: ['${node.address}:${toString cfg.exporters.prometheus.port}']
            labels:
              node: '${node}'
          '') (attrNames config.hypervisor.cluster.nodes)}
      ''}
  '';
  
  # Generate Grafana dashboard
  generateGrafanaDashboard = name: {
    "annotations" = {
      "list" = [
        {
          "builtIn" = 1;
          "datasource" = "-- Grafana --";
          "enable" = true;
          "hide" = true;
          "iconColor" = "rgba(0, 211, 255, 1)";
          "name" = "Annotations & Alerts";
          "type" = "dashboard";
        }
      ];
    };
    "editable" = true;
    "gnetId" = null;
    "graphTooltip" = 0;
    "id" = null;
    "links" = [];
    "panels" = [
      # CPU Usage Panel
      {
        "datasource" = "Prometheus";
        "fieldConfig" = {
          "defaults" = {
            "color" = {
              "mode" = "palette-classic";
            };
            "custom" = {
              "axisLabel" = "";
              "axisPlacement" = "auto";
              "barAlignment" = 0;
              "drawStyle" = "line";
              "fillOpacity" = 10;
              "gradientMode" = "none";
              "hideFrom" = {
                "tooltip" = false;
                "viz" = false;
                "legend" = false;
              };
              "lineInterpolation" = "linear";
              "lineWidth" = 1;
              "pointSize" = 5;
              "scaleDistribution" = {
                "type" = "linear";
              };
              "showPoints" = "never";
              "spanNulls" = true;
              "stacking" = {
                "group" = "A";
                "mode" = "none";
              };
              "thresholdsStyle" = {
                "mode" = "off";
              };
            };
            "mappings" = [];
            "thresholds" = {
              "mode" = "absolute";
              "steps" = [
                {
                  "color" = "green";
                  "value" = null;
                }
                {
                  "color" = "red";
                  "value" = 80;
                }
              ];
            };
            "unit" = "percent";
          };
          "overrides" = [];
        };
        "gridPos" = {
          "h" = 8;
          "w" = 12;
          "x" = 0;
          "y" = 0;
        };
        "id" = 1;
        "options" = {
          "tooltip" = {
            "mode" = "single";
          };
          "legend" = {
            "calcs" = [];
            "displayMode" = "list";
            "placement" = "bottom";
          };
        };
        "pluginVersion" = "8.0.0";
        "targets" = [
          {
            "expr" = "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            "refId" = "A";
          }
        ];
        "title" = "CPU Usage";
        "type" = "timeseries";
      }
      # Memory Usage Panel
      {
        "datasource" = "Prometheus";
        "fieldConfig" = {
          "defaults" = {
            "color" = {
              "mode" = "thresholds";
            };
            "mappings" = [];
            "thresholds" = {
              "mode" = "absolute";
              "steps" = [
                {
                  "color" = "green";
                  "value" = null;
                }
                {
                  "color" = "yellow";
                  "value" = 70;
                }
                {
                  "color" = "red";
                  "value" = 90;
                }
              ];
            };
            "unit" = "percent";
          };
          "overrides" = [];
        };
        "gridPos" = {
          "h" = 8;
          "w" = 12;
          "x" = 12;
          "y" = 0;
        };
        "id" = 2;
        "options" = {
          "orientation" = "auto";
          "reduceOptions" = {
            "values" = false;
            "calcs" = [
              "lastNotNull"
            ];
            "fields" = "";
          };
          "showThresholdLabels" = false;
          "showThresholdMarkers" = true;
        };
        "pluginVersion" = "8.0.0";
        "targets" = [
          {
            "expr" = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
            "refId" = "A";
          }
        ];
        "title" = "Memory Usage";
        "type" = "gauge";
      }
    ];
    "refresh" = "5s";
    "schemaVersion" = 30;
    "style" = "dark";
    "tags" = [ "hypervisor" name ];
    "templating" = {
      "list" = [];
    };
    "time" = {
      "from" = "now-6h";
      "to" = "now";
    };
    "timepicker" = {};
    "timezone" = "";
    "title" = "Hypervisor - ${name}";
    "uid" = "hypervisor-${name}";
    "version" = 0;
  };
in
{
  options.hypervisor.monitoring = {
    metrics = mkOption {
      type = types.submodule metricsOptions;
      default = {};
      description = "Metrics collection configuration";
    };
    
    exporters = mkOption {
      type = types.submodule exporterOptions;
      default = {};
      description = "Metric exporters configuration";
    };
    
    alerts = mkOption {
      type = types.attrsOf (types.submodule alertRuleOptions);
      default = {};
      description = "Alert rule definitions";
      example = literalExpression ''
        {
          high_cpu = {
            condition = "avg(rate(node_cpu_seconds_total{mode!=\"idle\"}[5m])) > 0.9";
            duration = "10m";
            severity = "warning";
            annotations = {
              summary = "High CPU usage detected";
              description = "CPU usage is above 90% for more than 10 minutes";
            };
          };
          
          vm_down = {
            condition = "up{job=\"vm-guests\"} == 0";
            duration = "5m";
            severity = "critical";
            annotations = {
              summary = "VM is down";
              description = "VM {{$labels.instance}} has been down for more than 5 minutes";
            };
          };
        }
      '';
    };
    
    dashboards = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Grafana dashboards";
      };
      
      custom = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = "Custom dashboard definitions";
      };
    };
    
    # Integration with existing monitoring stack
    prometheusIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Integrate with existing Prometheus setup";
    };
    
    grafanaIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Integrate with existing Grafana setup";
    };
  };
  
  config = mkMerge [
    # Prometheus configuration
    (mkIf (cfg.metrics.enable && cfg.prometheusIntegration) {
      services.prometheus = {
        enable = true;
        extraFlags = [
          "--storage.tsdb.retention.time=${cfg.metrics.retention}"
          "--storage.tsdb.retention.size=10GB"
        ];
        
        globalConfig = {
          scrape_interval = "${toString cfg.metrics.interval}s";
          evaluation_interval = "${toString cfg.metrics.interval}s";
        };
        
        scrapeConfigs = [
          {
            job_name = "hypervisor";
            static_configs = [{
              targets = [ "localhost:${toString cfg.exporters.prometheus.port}" ];
            }];
          }
          {
            job_name = "node";
            static_configs = [{
              targets = [ "localhost:9100" ];
            }];
          }
          {
            job_name = "libvirt";
            static_configs = [{
              targets = [ "localhost:9177" ];
            }];
          }
        ];
        
        rules = [
          (pkgs.writeText "hypervisor-alerts.yml" (builtins.toJSON {
            groups = [{
              name = "hypervisor";
              rules = mapAttrsToList (name: rule: {
                alert = name;
                expr = rule.condition;
                for = rule.duration;
                labels = rule.labels // {
                  severity = rule.severity;
                };
                annotations = rule.annotations;
              }) cfg.alerts;
            }];
          }))
        ];
      };
      
      # Node exporter
      services.prometheus.exporters.node = {
        enable = true;
        enabledCollectors = [
          "systemd"
          "tcpstat"
          "conntrack"
          "diskstats"
          "entropy"
          "filefd"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "netstat"
          "stat"
          "time"
          "vmstat"
          "logind"
          "interrupts"
          "ksmd"
        ];
      };
      
      # Libvirt exporter
      services.prometheus.exporters.libvirt = {
        enable = true;
      };
    })
    
    # Grafana configuration
    (mkIf (cfg.dashboards.enable && cfg.grafanaIntegration) {
      services.grafana = {
        enable = true;
        
        provision = {
          enable = true;
          
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:9090";
              isDefault = true;
            }
          ] ++ optional cfg.exporters.influxdb.enable {
            name = "InfluxDB";
            type = "influxdb";
            access = "proxy";
            url = cfg.exporters.influxdb.endpoint;
            database = cfg.exporters.influxdb.database;
            user = cfg.exporters.influxdb.username;
            secureJsonData.password = "$__file{${cfg.exporters.influxdb.passwordFile}}";
          };
          
          dashboards.settings.providers = [
            {
              name = "Hypervisor Dashboards";
              folder = "Hypervisor";
              type = "file";
              disableDeletion = false;
              updateIntervalSeconds = 10;
              options.path = "/etc/grafana/dashboards/hypervisor";
            }
          ];
        };
      };
      
      # Generate dashboards
      environment.etc = {
        "grafana/dashboards/hypervisor/overview.json" = {
          text = builtins.toJSON (generateGrafanaDashboard "Overview");
        };
      } // mapAttrs' (name: dashboard: nameValuePair
        "grafana/dashboards/hypervisor/${name}.json" {
          text = builtins.toJSON dashboard;
        }
      ) cfg.dashboards.custom;
    })
    
    # Metrics collection service
    {
      systemd.services.hypervisor-metrics = mkIf cfg.metrics.enable {
        description = "Hypervisor Metrics Collector";
        after = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          Type = "simple";
          ExecStart = pkgs.writeShellScript "metrics-collector" ''
            #!/usr/bin/env bash
            
            while true; do
              # Collect VM metrics
              for vm in $(virsh list --name); do
                if [[ -n "$vm" ]]; then
                  # CPU stats
                  cpu_stats=$(virsh cpu-stats "$vm" --total)
                  
                  # Memory stats
                  mem_stats=$(virsh dommemstat "$vm")
                  
                  # Disk stats
                  disk_stats=$(virsh domblkstat "$vm" vda)
                  
                  # Network stats
                  net_stats=$(virsh domifstat "$vm" vnet0)
                  
                  # Export to configured backends
                  ${optionalString cfg.exporters.influxdb.enable ''
                    # Send to InfluxDB
                    curl -X POST "${cfg.exporters.influxdb.endpoint}/write?db=${cfg.exporters.influxdb.database}" \
                      -d "vm_cpu,vm=$vm value=$(echo "$cpu_stats" | grep cpu_time | awk '{print $2}')"
                  ''}
                  
                  ${optionalString cfg.exporters.graphite.enable ''
                    # Send to Graphite
                    echo "${cfg.exporters.graphite.prefix}.vm.$vm.cpu $(echo "$cpu_stats" | grep cpu_time | awk '{print $2}') $(date +%s)" | \
                      nc ${cfg.exporters.graphite.host} ${toString cfg.exporters.graphite.port}
                  ''}
                fi
              done
              
              sleep ${toString cfg.metrics.interval}
            done
          '';
          
          Restart = "always";
          RestartSec = "10s";
        };
      };
      
      # Prometheus metrics endpoint
      systemd.services.hypervisor-prometheus-exporter = mkIf cfg.exporters.prometheus.enable {
        description = "Hypervisor Prometheus Exporter";
        after = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.python3}/bin/python ${pkgs.writeText "prometheus-exporter.py" ''
            import time
            import libvirt
            from prometheus_client import start_http_server, Gauge, Counter
            
            # Define metrics
            vm_count = Gauge('hypervisor_vm_count', 'Number of VMs')
            vm_cpu_usage = Gauge('hypervisor_vm_cpu_usage', 'VM CPU usage', ['vm'])
            vm_memory_usage = Gauge('hypervisor_vm_memory_usage', 'VM memory usage', ['vm'])
            vm_disk_read = Counter('hypervisor_vm_disk_read_bytes', 'VM disk read bytes', ['vm'])
            vm_disk_write = Counter('hypervisor_vm_disk_write_bytes', 'VM disk write bytes', ['vm'])
            vm_net_rx = Counter('hypervisor_vm_network_rx_bytes', 'VM network RX bytes', ['vm'])
            vm_net_tx = Counter('hypervisor_vm_network_tx_bytes', 'VM network TX bytes', ['vm'])
            
            def collect_metrics():
                conn = libvirt.open('qemu:///system')
                domains = conn.listAllDomains()
                
                vm_count.set(len(domains))
                
                for domain in domains:
                    if domain.isActive():
                        name = domain.name()
                        
                        # CPU stats
                        cpu_stats = domain.getCPUStats(True)
                        if cpu_stats:
                            vm_cpu_usage.labels(vm=name).set(cpu_stats[0]['cpu_time'] / 1e9)
                        
                        # Memory stats
                        mem_stats = domain.memoryStats()
                        if 'actual' in mem_stats:
                            vm_memory_usage.labels(vm=name).set(mem_stats['actual'] * 1024)
                        
                        # Disk stats
                        try:
                            disk_stats = domain.blockStats('vda')
                            vm_disk_read.labels(vm=name)._value.set(disk_stats[0])
                            vm_disk_write.labels(vm=name)._value.set(disk_stats[2])
                        except:
                            pass
                        
                        # Network stats
                        try:
                            net_stats = domain.interfaceStats('vnet0')
                            vm_net_rx.labels(vm=name)._value.set(net_stats[0])
                            vm_net_tx.labels(vm=name)._value.set(net_stats[4])
                        except:
                            pass
                
                conn.close()
            
            if __name__ == '__main__':
                start_http_server(${toString cfg.exporters.prometheus.port})
                
                while True:
                    collect_metrics()
                    time.sleep(${toString cfg.metrics.interval})
          ''}";
          
          Restart = "always";
          RestartSec = "10s";
        };
      };
      
      # Create metrics storage directory
      systemd.tmpfiles.rules = [
        "d /var/lib/hypervisor/metrics 0755 root root -"
      ];
    }
  ];
}