# Monitoring Setup Guide

**Complete guide to setting up monitoring, metrics, and alerting for your hypervisor**

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Prometheus Setup](#prometheus-setup)
- [Grafana Setup](#grafana-setup)
- [Alerting](#alerting)
- [Dashboard Usage](#dashboard-usage)
- [Metrics Reference](#metrics-reference)

---

## Overview

The hypervisor includes comprehensive monitoring capabilities:

- **📊 Metrics Collection** - Prometheus exporter for host and VM metrics
- **📈 Visualization** - Grafana dashboards for real-time monitoring
- **🚨 Alerting** - Automated alerts for critical issues
- **🔍 Health Monitoring** - Continuous health checks with automation
- **📱 Dashboard** - Real-time TUI dashboard for quick overview

---

## Quick Start

### 1. Start Metrics Collection

```bash
# Run Prometheus exporter in daemon mode
PROM_DAEMON=true /etc/hypervisor/scripts/prom_exporter_enhanced.sh &

# Metrics are written to:
# /var/lib/hypervisor/metrics/hypervisor.prom

# View current metrics
cat /var/lib/hypervisor/metrics/hypervisor.prom
```

### 2. View Real-Time Dashboard

```bash
# Launch interactive TUI dashboard
/etc/hypervisor/scripts/vm_dashboard.sh

# Or from menu:
# Main Menu → More Options → VM Dashboard
```

### 3. Check System Health

```bash
# One-time health check
/etc/hypervisor/scripts/health_monitor.sh check

# Continuous monitoring
/etc/hypervisor/scripts/health_monitor.sh daemon &
```

---

## Prometheus Setup

### Installation (NixOS)

Add to `configuration.nix`:

```nix
services.prometheus = {
  enable = true;
  port = 9090;
  
  extraFlags = [
    "--storage.tsdb.retention.time=30d"
    "--storage.tsdb.retention.size=10GB"
  ];
  
  scrapeConfigs = [
    {
      job_name = "hypervisor";
      static_configs = [{
        targets = [ "localhost:9090" ];
      }];
      metrics_path = "/var/lib/hypervisor/metrics/hypervisor.prom";
      scheme = "file";
      scrape_interval = "15s";
    }
  ];
  
  rules = [
    (builtins.readFile /etc/hypervisor/monitoring/alert-rules.yml)
  ];
};
```

### Manual Setup

```bash
# 1. Copy configuration
sudo cp monitoring/prometheus.yml /etc/prometheus/
sudo cp monitoring/alert-rules.yml /etc/prometheus/

# 2. Start exporter in daemon mode
PROM_DAEMON=true \
PROM_INTERVAL=15 \
/etc/hypervisor/scripts/prom_exporter_enhanced.sh \
  /var/lib/hypervisor/metrics/hypervisor.prom &

# 3. Start Prometheus
prometheus --config.file=/etc/prometheus/prometheus.yml

# 4. Access UI
# Open browser to: http://localhost:9090
```

### Verify Metrics

```bash
# Check metrics file is being updated
watch -n 5 ls -lh /var/lib/hypervisor/metrics/hypervisor.prom

# View metrics
cat /var/lib/hypervisor/metrics/hypervisor.prom

# Query via Prometheus API
curl http://localhost:9090/api/v1/query?query=hypervisor_vms_total
```

---

## Grafana Setup

### Installation (NixOS)

Add to `configuration.nix`:

```nix
services.grafana = {
  enable = true;
  settings = {
    server = {
      http_port = 3000;
      http_addr = "127.0.0.1";
    };
    security = {
      admin_user = "admin";
      admin_password = "changeme";  # Change this!
    };
  };
  
  provision = {
    enable = true;
    datasources.settings = {
      apiVersion = 1;
      datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:9090";
          isDefault = true;
        }
      ];
    };
  };
};
```

### Import Dashboards

```bash
# 1. Access Grafana
# Open browser to: http://localhost:3000
# Login: admin / changeme (or your password)

# 2. Import dashboard
# Dashboards → Import → Upload JSON file

# 3. Select dashboard files
# monitoring/grafana-dashboard-overview.json
# monitoring/grafana-dashboard-vm-details.json (if created)
# monitoring/grafana-dashboard-host.json (if created)

# 4. Select Prometheus datasource
# Choose "Prometheus" from dropdown
```

### Dashboard Features

**Overview Dashboard:**
- Running vs stopped VMs count
- Host CPU and memory usage
- Load average over time
- Per-VM resource usage
- Disk and network I/O
- Real-time updates every 30s

**Panels:**
1. **Running VMs** - Count with trend
2. **Host Memory** - Usage percentage with thresholds
3. **Host Load** - 1/5/15 minute averages
4. **VM States** - Running/stopped over time
5. **Per-VM Memory** - Individual VM memory usage
6. **Per-VM CPU** - CPU time per VM
7. **Disk I/O** - Read/write rates
8. **Network I/O** - RX/TX rates

---

## Alerting

### Alert Rules

**File:** `monitoring/alert-rules.yml`

**Configured alerts:**

| Alert | Condition | Severity |
|-------|-----------|----------|
| **VMCrashed** | VM unexpectedly stopped | Critical |
| **HostHighMemoryUsage** | >90% for 5 min | Warning |
| **HostHighCPULoad** | Load > 2x CPUs for 5 min | Warning |
| **HostLowDiskSpace** | <10% available for 5 min | Critical |
| **VMHighMemoryUsage** | >95% for 5 min | Warning |
| **LibvirtDown** | Service stopped for 1 min | Critical |
| **NetworkDown** | Network inactive for 2 min | Warning |

### Alert Notifications

**Methods:**
1. **Prometheus Alertmanager** - Configure in `prometheus.yml`
2. **Health monitor** - Triggers custom alert script
3. **Log files** - All alerts logged

**Example alert handler:**

```bash
# scripts/alert_handler.sh (create this)
#!/usr/bin/env bash

SEVERITY="$1"
HEALTH_STATE_FILE="$2"

# Read issues from health state
issues=$(jq -r '.host_issues[], .vm_issues[]' "$HEALTH_STATE_FILE")

# Send notification (example: email)
if command -v mail >/dev/null; then
  echo "$issues" | mail -s "Hypervisor Alert: $SEVERITY" admin@example.com
fi

# Send to syslog
logger -t hypervisor -p daemon.warning "Health check: $SEVERITY - $issues"

# Custom notifications (Slack, Discord, etc.)
# Add your notification logic here
```

### Configure Alertmanager

**File:** `monitoring/alertmanager.yml` (create this)

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'

receivers:
  - name: 'default'
    email_configs:
      - to: 'admin@example.com'
        from: 'hypervisor@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'user'
        auth_password: 'pass'
```

---

## Dashboard Usage

### TUI VM Dashboard

**Access:**
```bash
/etc/hypervisor/scripts/vm_dashboard.sh

# Or from menu:
# More Options → VM Dashboard
```

**Features:**
- Real-time VM status (updates every 5s)
- Host resource usage with visual bars
- Per-VM stats (vCPUs, memory, state)
- Quick actions (start/stop all, diagnostics)

**Interactive commands:**
- `R` - Refresh now
- `S` - Start all stopped VMs
- `T` - Stop all running VMs
- `D` - Run diagnostics
- `M` - Main menu
- `Q` - Quit

**Customization:**
```bash
# Custom refresh interval
REFRESH_INTERVAL=10 /etc/hypervisor/scripts/vm_dashboard.sh

# Or pass as argument
/etc/hypervisor/scripts/vm_dashboard.sh --interval 10
```

### Health Monitoring

**Manual check:**
```bash
/etc/hypervisor/scripts/health_monitor.sh check
```

**Continuous monitoring:**
```bash
# Start health monitor daemon
/etc/hypervisor/scripts/health_monitor.sh daemon &

# Or as systemd service (add to configuration.nix):
systemd.services.hypervisor-health-monitor = {
  description = "Hypervisor Health Monitor";
  wantedBy = [ "multi-user.target" ];
  after = [ "libvirtd.service" ];
  serviceConfig = {
    ExecStart = "/etc/hypervisor/scripts/health_monitor.sh daemon";
    Restart = "always";
    RestartSec = 10;
  };
};
```

**Health state file:**
```bash
# View current health state
cat /var/lib/hypervisor/health_state.json | jq

# Example output:
{
  "timestamp": "2025-10-11T10:30:00+00:00",
  "status": "healthy",
  "issues": {
    "critical": 0,
    "warning": 0,
    "info": 0
  },
  "host_issues": [],
  "vm_issues": []
}
```

---

## Metrics Reference

### Host Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `hypervisor_uptime_seconds` | Gauge | System uptime |
| `hypervisor_memory_bytes` | Gauge | Memory stats (total/free/available/buffers/cached) |
| `hypervisor_cpu_count` | Gauge | Number of CPU cores |
| `hypervisor_load_average` | Gauge | Load average (1m/5m/15m) |
| `hypervisor_disk_bytes` | Gauge | Disk space (total/used/available) |
| `hypervisor_libvirt_up` | Gauge | Libvirt daemon status (1=up, 0=down) |

### VM Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `hypervisor_vms_total` | Gauge | VM count by state (running/stopped/all) |
| `vm_state` | Gauge | Individual VM state (1=running, 0=stopped) |
| `vm_vcpu_count` | Gauge | Number of vCPUs per VM |
| `vm_memory_bytes` | Gauge | VM memory (total/used) |
| `vm_cpu_time_seconds_total` | Counter | Cumulative CPU time |
| `vm_disk_read_bytes_total` | Counter | Cumulative disk reads |
| `vm_disk_write_bytes_total` | Counter | Cumulative disk writes |
| `vm_network_rx_bytes_total` | Counter | Cumulative network received |
| `vm_network_tx_bytes_total` | Counter | Cumulative network transmitted |

### Network Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `hypervisor_network_up` | Gauge | Network status (1=active, 0=inactive) |

### Example Queries

```promql
# Total running VMs
hypervisor_vms_total{state="running"}

# Host memory usage percentage
(hypervisor_memory_bytes{type="total"} - hypervisor_memory_bytes{type="available"}) 
/ hypervisor_memory_bytes{type="total"} * 100

# CPU usage rate per VM
rate(vm_cpu_time_seconds_total[5m])

# Network bandwidth per VM
rate(vm_network_rx_bytes_total[5m])
rate(vm_network_tx_bytes_total[5m])

# VMs with high memory usage
vm_memory_bytes{type="used"} / vm_memory_bytes{type="total"} > 0.9
```

---

## Advanced Configuration

### Custom Metrics

Add your own metrics to the exporter:

```bash
# Edit: scripts/prom_exporter_enhanced.sh

# Add custom metric
help_text "my_custom_metric" "Description of metric" >> "$buf"
type_text "my_custom_metric" "gauge" >> "$buf"
plain "my_custom_metric" "42" "$timestamp" >> "$buf"
```

### Metric Retention

```yaml
# In prometheus.yml
storage:
  tsdb:
    retention:
      time: '90d'    # Keep 90 days
      size: '50GB'   # Max 50GB
```

### High-Frequency Monitoring

```bash
# Faster metrics collection (every 5s)
PROM_DAEMON=true \
PROM_INTERVAL=5 \
/etc/hypervisor/scripts/prom_exporter_enhanced.sh &
```

### Remote Monitoring

```bash
# Expose Prometheus for remote access
# In prometheus.yml, change:
http_addr: "0.0.0.0"  # Listen on all interfaces

# ⚠️ Security: Use firewall rules or reverse proxy
# Only expose on trusted networks
```

---

## Troubleshooting

### No Metrics Appearing

**Check:**
```bash
# Is exporter running?
ps aux | grep prom_exporter

# Is metrics file being updated?
ls -lh /var/lib/hypervisor/metrics/hypervisor.prom
stat /var/lib/hypervisor/metrics/hypervisor.prom

# Can Prometheus read the file?
sudo -u prometheus cat /var/lib/hypervisor/metrics/hypervisor.prom
```

**Fix:**
```bash
# Restart exporter
pkill -f prom_exporter
PROM_DAEMON=true /etc/hypervisor/scripts/prom_exporter_enhanced.sh &

# Check file permissions
chmod 644 /var/lib/hypervisor/metrics/hypervisor.prom
```

### Dashboards Not Loading

**Check Grafana logs:**
```bash
journalctl -u grafana -n 100
```

**Verify datasource:**
1. Grafana → Configuration → Data Sources
2. Click "Prometheus"
3. Click "Test" button
4. Should show "Data source is working"

### Alerts Not Firing

**Check Prometheus alerts:**
```bash
# Access Prometheus UI
# http://localhost:9090/alerts

# Verify alert rules loaded
curl http://localhost:9090/api/v1/rules | jq
```

**Check Alertmanager:**
```bash
systemctl status alertmanager
journalctl -u alertmanager -n 50
```

---

## Best Practices

### Monitoring Strategy

1. **Collect metrics** - Run exporter continuously
2. **Visualize trends** - Use Grafana dashboards
3. **Set alerts** - For critical issues only
4. **Review regularly** - Check dashboards weekly
5. **Tune thresholds** - Adjust based on your workload

### Alert Fatigue Prevention

- Only alert on actionable issues
- Use appropriate severity levels
- Group related alerts
- Set sensible thresholds
- Implement proper escalation

### Performance Considerations

- Metric collection has minimal overhead (<1% CPU)
- 15-second interval is good for most use cases
- Store metrics for 30 days by default
- Archive older data if needed for compliance

---

## Integration with Other Tools

### Export to JSON

```bash
# Convert metrics to JSON
/etc/hypervisor/scripts/prom_exporter_enhanced.sh | \
  awk '{print "{\"metric\":\""$1"\",\"value\":"$2"}"}' | \
  jq -s '.'
```

### Webhook Alerts

```bash
# In alert_handler.sh
curl -X POST https://hooks.example.com/alerts \
  -H 'Content-Type: application/json' \
  -d "{\"status\":\"$SEVERITY\",\"message\":\"$issues\"}"
```

### External Monitoring Services

Configure Prometheus remote write to send metrics to:
- Grafana Cloud
- Datadog
- New Relic
- AWS CloudWatch

---

**Monitoring is essential for production deployments. Start with the TUI dashboard, then add Prometheus/Grafana as you scale.**
